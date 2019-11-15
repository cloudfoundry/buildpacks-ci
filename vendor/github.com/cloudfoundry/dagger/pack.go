package dagger

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"sort"
	"sync"

	"code.cloudfoundry.org/lager"
	"github.com/buildpack/libbuildpack/logger"
	"github.com/cloudfoundry/dagger/utils"
	"github.com/cloudfoundry/packit"
)

const (
	Tiny              = "org.cloudfoundry.stacks.tiny"
	CFLinuxFS3        = "org.cloudfoundry.stacks.cflinuxfs3"
	Bionic            = "io.buildpacks.stacks.bionic"
	DefaultBuildImage = "cloudfoundry/build:full-cnb"
	DefaultRunImage   = "cloudfoundry/run:full-cnb"
	TestBuilderImage  = "cloudfoundry/cnb:cflinuxfs3"
	Cflinuxfs3Builder = "cloudfoundry/cnb:cflinuxfs3"
	BionicBuilder     = "cloudfoundry/cnb:bionic"
	logBufferSize     = 1024
)

var (
	logQueue                chan chan []byte
	stdoutMutex             sync.Mutex
	queueIsInitialized      bool
	queueIsInitializedMutex sync.Mutex
	builderMap              = map[string]string{
		"cflinuxfs3": Cflinuxfs3Builder,
		"bionic":     BionicBuilder,
	}
)

type Executable interface {
	Execute(packit.Execution) (stdout, stderr string, err error)
}

type Pack struct {
	dir        string
	image      string
	env        map[string]string
	buildpacks []string
	offline    bool
	executable Executable
	verbose    bool
	builder    string
}

type PackOption func(Pack) Pack

func PackBuild(appDir string, buildpacks ...string) (*App, error) {
	return NewPack(
		appDir,
		RandomImage(),
		SetBuildpacks(buildpacks...),
	).Build()
}

func PackBuildWithEnv(appDir string, env map[string]string, buildpacks ...string) (*App, error) {
	return NewPack(
		appDir,
		RandomImage(),
		SetEnv(env),
		SetBuildpacks(buildpacks...),
	).Build()
}

// This pack builds an app from appDir into appImageName, to allow specifying an image name in a test
func PackBuildNamedImage(appImage, appDir string, buildpacks ...string) (*App, error) {
	return NewPack(
		appDir,
		SetImage(appImage),
		SetBuildpacks(buildpacks...),
	).Build()
}

func PackBuildNamedImageWithEnv(appImage, appDir string, env map[string]string, buildpacks ...string) (*App, error) {
	return NewPack(
		appDir,
		SetImage(appImage),
		SetEnv(env),
		SetBuildpacks(buildpacks...),
	).Build()
}

func SetImage(image string) PackOption {
	return func(pack Pack) Pack {
		pack.image = image
		return pack
	}
}

func RandomImage() PackOption {
	return func(pack Pack) Pack {
		pack.image = utils.RandStringRunes(16)
		return pack
	}
}

func SetEnv(env map[string]string) PackOption {
	return func(pack Pack) Pack {
		pack.env = env
		return pack
	}
}

func SetBuildpacks(buildpacks ...string) PackOption {
	return func(pack Pack) Pack {
		pack.buildpacks = append(pack.buildpacks, buildpacks...)
		return pack
	}
}

func SetOffline() PackOption {
	return func(pack Pack) Pack {
		pack.offline = true
		return pack
	}
}

func SetVerbose() PackOption {
	return func(pack Pack) Pack {
		pack.verbose = true
		return pack
	}
}

func SetBuilder(builder string) PackOption {
	return func(pack Pack) Pack {
		pack.builder = builder
		return pack
	}
}

func NewPack(dir string, options ...PackOption) Pack {
	var w io.Writer
	queueIsInitializedMutex.Lock()
	if queueIsInitialized {
		log := make(chan []byte, logBufferSize)
		logQueue <- log
		cw := newChanWriter(log)
		w = cw
		defer cw.Close()
	} else {
		w = os.Stdout
	}
	queueIsInitializedMutex.Unlock()

	buildLogs := &bytes.Buffer{}

	logger.NewLogger(io.MultiWriter(w, buildLogs), io.MultiWriter(w, buildLogs))

	pack := Pack{
		dir:        dir,
		executable: packit.NewExecutable("pack", lager.NewLogger("pack")),
	}

	for _, option := range options {
		pack = option(pack)
	}

	return pack
}

func (p Pack) Build() (*App, error) {
	builderImage, err := getBuilderImage(p.builder)
	if err != nil {
		return nil, err
	}

	packArgs := []string{"build", p.image, "--builder", builderImage}
	for _, bp := range p.buildpacks {
		packArgs = append(packArgs, "--buildpack", bp)
	}

	keys := []string{}
	for key := range p.env {
		keys = append(keys, key)
	}

	sort.Strings(keys)

	for _, key := range keys {
		packArgs = append(packArgs, "-e", fmt.Sprintf("%s=%s", key, p.env[key]))
	}

	if p.offline {
		// probably want to pull here?
		dockerLogger := lager.NewLogger("docker")
		dockerExec := packit.NewExecutable("docker", dockerLogger)

		stdout, stderr, err := dockerExec.Execute(packit.Execution{
			Args: []string{"pull", builderImage},
		})
		if err != nil {
			return nil, fmt.Errorf("failed to pull %s\n with stdout %s\n stderr %s\n%s", builderImage, stdout, stderr, err.Error())
		}
		packArgs = append(packArgs, "--network", "none", "--no-pull")
	}

	if p.verbose {
		packArgs = append(packArgs, "-v")
	}

	buildLogs := bytes.NewBuffer(nil)
	_, _, err = p.executable.Execute(packit.Execution{
		Args:   packArgs,
		Stdout: buildLogs,
		Stderr: buildLogs,
		Dir:    p.dir,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to pack build with output: %s\n %s\n", buildLogs, err.Error())
	}

	sum := sha256.Sum256([]byte(fmt.Sprintf("index.docker.io/library/%s:latest", p.image))) //This is how pack makes cache image names
	cacheImage := fmt.Sprintf("pack-cache-%x", sum[:6])

	app := NewApp(p.dir, p.image, cacheImage, buildLogs, make(map[string]string))
	return &app, nil
}

type chanWriter struct {
	channel chan []byte
}

func newChanWriter(c chan []byte) *chanWriter {
	return &chanWriter{c}
}

func (c *chanWriter) Write(p []byte) (n int, err error) {
	c.channel <- append([]byte{}, p...) // Create a copy to avoid mutation of backing slice
	return len(p), nil
}

func (c *chanWriter) Close() {
	close(c.channel)
}

func SyncParallelOutput(f func()) {
	startOutputStream()
	defer stopOutputStream()
	f()
}

func startOutputStream() {
	fmt.Println("Starting to stream output...")
	logQueue = make(chan chan []byte, 1024) // Arbitrary buffer size to reduce blocking
	queueIsInitializedMutex.Lock()
	queueIsInitialized = true
	queueIsInitializedMutex.Unlock()
	go printLoop()
}

func stopOutputStream() {
	close(logQueue)
	fmt.Println("Stopped streaming output.")
}

func printLoop() {
	for log := range logQueue {
		printLog(log)
	}
}

func printLog(log chan []byte) {
	for line := range log {
		stdoutMutex.Lock()
		fmt.Print(string(line))
		stdoutMutex.Unlock()
	}
}

func getBuilderImage(packBuilder string) (string, error) {
	if packBuilder == "" {
		return Cflinuxfs3Builder, nil
	}

	val, found := builderMap[packBuilder]
	if !found {
		return "", fmt.Errorf("please use either 'bionic' or 'cflinuxfs3' as input keys to SetBuilder")
	}

	return val, nil
}
