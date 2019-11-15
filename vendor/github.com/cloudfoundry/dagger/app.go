package dagger

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"code.cloudfoundry.org/lager"
	"github.com/cloudfoundry/packit"
	"github.com/pkg/errors"
)

type App struct {
	ImageName   string
	CacheImage  string
	ContainerID string
	Memory      string
	Env         map[string]string
	buildLogs   *bytes.Buffer
	logProc     *exec.Cmd
	port        string
	fixtureName string
	healthCheck HealthCheck
}

type HealthCheck struct {
	command  string
	interval string
	timeout  string
}

func NewApp(fixturePath, imageName, cacheImage string, buildLogs *bytes.Buffer, env map[string]string) App {
	return App{
		ImageName:   imageName,
		CacheImage:  cacheImage,
		buildLogs:   buildLogs,
		Env:         env,
		fixtureName: fixturePath,
	}
}

func (a *App) Start() error {
	return a.StartWithCommand("")
}

func (a *App) StartWithCommand(startCmd string) error {
	if a.Env["PORT"] == "" {
		a.Env["PORT"] = "8080"
	}

	args := []string{"run", "-d", "-p", a.Env["PORT"], "-P"}
	if a.Memory != "" {
		args = append(args, "--memory", a.Memory)
	}

	if a.healthCheck.command == "" {
		a.healthCheck.command = fmt.Sprintf("curl --fail http://localhost:%s || exit 1", a.Env["PORT"])
	}
	args = append(args, "--health-cmd", a.healthCheck.command)

	if a.healthCheck.interval != "" {
		args = append(args, "--health-interval", a.healthCheck.interval)
	}

	if a.healthCheck.timeout != "" {
		args = append(args, "--health-timeout", a.healthCheck.timeout)
	}

	envTemplate := "%s=%s"
	for k, v := range a.Env {
		envString := fmt.Sprintf(envTemplate, k, v)
		args = append(args, "-e", envString)
	}

	args = append(args, a.ImageName)
	if startCmd != "" {
		args = append(args, startCmd)
	}

	dockerLogger := lager.NewLogger("docker")
	docker := packit.NewExecutable("docker", dockerLogger)
	log, _, err := docker.Execute(packit.Execution{
		Args: args,
	})

	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("failed to run docker image: %s\n with command: %s", a.ImageName, args))
	}

	a.ContainerID = log[:12]

	ticker := time.NewTicker(1 * time.Second)
	timeOut := time.After(2 * time.Minute)
docker:
	for {
		select {
		case <-ticker.C:
			health, err := exec.Command("docker", "inspect", "-f", "{{.State.Health}}", a.ContainerID).CombinedOutput()
			if err != nil {
				return errors.Wrap(err, fmt.Sprintf("failed to docker inspect health of container: %s\n with health status: %s\n", a.ContainerID, string(health)))
			}

			status := strings.TrimSuffix(string(health), "\n")
			if status != "<nil>" {
				// Split string by space and remove curly brace in front
				status = strings.Split(string(status), " ")[0][1:]
				status = strings.TrimSpace(status)
			}

			if status == "unhealthy" {
				logs, _ := a.Logs()
				return errors.Errorf("app failed to start: %s\n%s\n", a.fixtureName, logs)
			}

			if status == "healthy" || status == "<nil>" {
				break docker
			}
		case <-timeOut:
			return fmt.Errorf("timed out waiting for app : %s", a.fixtureName)
		}
	}

	log, _, err = docker.Execute(packit.Execution{
		Args: []string{"container", "port", a.ContainerID},
	})
	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("docker error: failed to get port from container: %s", a.ContainerID))
	}

	ports := strings.Split(log, ":")

	if len(ports) > 1 {
		a.port = strings.TrimSpace(ports[1])
	} else {
		return fmt.Errorf("unable to get port map from docker")
	}

	return nil
}

func (a *App) Destroy() error {
	if a == nil {
		return nil
	}

	dockerLogger := lager.NewLogger("docker")
	docker := packit.NewExecutable("docker", dockerLogger)

	cntrExists, err := DockerArtifactExists(a.ContainerID)
	if err != nil {
		return fmt.Errorf("failed to find container %s: %s", a.ContainerID, err)
	}

	if cntrExists {
		_, _, err := docker.Execute(packit.Execution{
			Args: []string{"stop", a.ContainerID},
		})
		if err != nil {
			return fmt.Errorf("failed to stop container %s: %s", a.ContainerID, err)
		}

		_, _, err = docker.Execute(packit.Execution{
			Args: []string{"rm", a.ContainerID, "-f", "--volumes"},
		})
		if err != nil {
			return fmt.Errorf("failed to remove container %s: %s", a.ContainerID, err)
		}
	}

	imgExists, err := DockerArtifactExists(a.ImageName)
	if err != nil {
		return fmt.Errorf("failed to find image %s: %s", a.ImageName, err)
	}

	if imgExists {
		_, _, err = docker.Execute(packit.Execution{
			Args: []string{"rmi", a.ImageName, "-f"},
		})
		if err != nil {
			return fmt.Errorf("failed to remove image %s: %s", a.ImageName, err)
		}
	}

	cacheExists, err := DockerArtifactExists(a.CacheImage)
	if err != nil {
		return fmt.Errorf("failed to find cache image %s: %s", a.CacheImage, err)
	}

	if cacheExists {
		_, _, err = docker.Execute(packit.Execution{
			Args: []string{"rmi", a.CacheImage, "-f"},
		})
		if err != nil {
			return fmt.Errorf("failed to remove cache image %s: %s", a.CacheImage, err)
		}
	}

	cacheBuildVolumeExists, err := DockerArtifactExists(fmt.Sprintf("%s.build", a.CacheImage))
	if err != nil {
		return fmt.Errorf("failed to find cache build volume %s.build: %s", a.CacheImage, err)
	}

	if cacheBuildVolumeExists {
		_, _, err = docker.Execute(packit.Execution{
			Args: []string{"volume", "rm", fmt.Sprintf("%s.build", a.CacheImage)},
		})
		if err != nil {
			return fmt.Errorf("failed to remove cache build volume %s.build: %s", a.CacheImage, err)
		}
	}

	cacheLaunchVolumeExists, err := DockerArtifactExists(fmt.Sprintf("%s.launch", a.CacheImage))
	if err != nil {
		return fmt.Errorf("failed to find cache launch volume %s.launch: %s", a.CacheImage, err)
	}

	if cacheLaunchVolumeExists {
		_, _, err = docker.Execute(packit.Execution{
			Args: []string{"volume", "rm", fmt.Sprintf("%s.launch", a.CacheImage)},
		})
		if err != nil {
			return fmt.Errorf("failed to remove cache launch volume %s.launch: %s", a.CacheImage, err)
		}
	}

	_, _, err = docker.Execute(packit.Execution{
		Args: []string{"image", "prune", "-f"},
	})
	if err != nil {
		return fmt.Errorf("failed to prune images: %s", err)
	}

	*a = App{}
	return nil
}

func (a *App) Logs() (string, error) {
	docker := packit.NewExecutable("docker", lager.NewLogger("docker"))
	log, _, err := docker.Execute(packit.Execution{
		Args: []string{"logs", a.ContainerID},
	})
	if err != nil {
		return "", err
	}

	return stripColor(log), nil
}

func (a *App) BuildLogs() string {
	return stripColor(a.buildLogs.String())
}

func (a *App) SetHealthCheck(command, interval, timeout string) {
	a.healthCheck = HealthCheck{
		command:  command,
		interval: interval,
		timeout:  timeout,
	}
}

func (a *App) Files(path string) ([]string, error) {
	// Ensures that the error and results from "Permission denied" don't get sent to the output
	docker := packit.NewExecutable("docker", lager.NewLogger("docker"))

	log, _, err := docker.Execute(packit.Execution{
		Args: []string{
			"run", a.ImageName,
			"find", "./..", fmt.Sprintf("-wholename *%s* 2>&1 | grep -v \"Permission denied\"", path),
		},
	})
	if err != nil {
		return []string{}, err
	}

	return strings.Split(log, "\n"), nil
}

func (a *App) Info() (cID string, imageID string, cacheID []string, e error) {
	volumes, err := getCacheVolumes()
	if err != nil {
		return "", "", []string{}, err
	}

	return a.ContainerID, a.ImageName, volumes, nil
}

func (a App) GetBaseURL() string {
	return fmt.Sprintf("http://localhost:%s", a.port)
}

func (a *App) HTTPGet(path string) (string, map[string][]string, error) {
	resp, err := http.Get(fmt.Sprintf("%s%s", a.GetBaseURL(), path))
	if err != nil {
		return "", nil, err
	}

	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", nil, fmt.Errorf("received bad response from application")
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", nil, err
	}

	return string(body), resp.Header, nil
}

func (a *App) HTTPGetBody(path string) (string, error) {
	resp, _, err := a.HTTPGet(path)
	return resp, err
}

func stripColor(input string) string {
	const ansi = "[\u001B\u009B][[\\]()#;?]*(?:(?:(?:[a-zA-Z\\d]*(?:;[a-zA-Z\\d]*)*)?\u0007)|(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PRZcf-ntqry=><~]))"

	var re = regexp.MustCompile(ansi)
	return re.ReplaceAllString(input, "")
}

func getCacheVolumes() ([]string, error) {
	docker := packit.NewExecutable("docker", lager.NewLogger("docker"))
	log, _, err := docker.Execute(packit.Execution{
		Args: []string{"volume", "ls", "-q"},
	})
	if err != nil {
		return []string{}, err
	}

	outputArr := strings.Split(log, "\n")
	var finalVolumes []string
	for _, line := range outputArr {
		if strings.Contains(line, "pack-cache") {
			finalVolumes = append(finalVolumes, line)
		}
	}
	return outputArr, nil
}

func DockerArtifactExists(name string) (bool, error) {
	docker := packit.NewExecutable("docker", lager.NewLogger("docker"))
	_, errLog, err := docker.Execute(packit.Execution{
		Args: []string{"inspect", name},
	})
	if err != nil {
		if strings.Contains(errLog, "No such object") {
			return false, nil
		}

		return false, err
	}

	return true, nil
}
