package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"sort"
	"strings"
	"time"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type NodeLTSWatcher struct {
	client base.HTTPClient
}

type nodeScheduleInfo struct {
	Start       string `json:"start"`
	LTS         string `json:"lts"`
	Maintenance string `json:"maintenance"`
	End         string `json:"end"`
	Codename    string `json:"codename"`
}

func NewNodeLTSWatcher(client base.HTTPClient) *NodeLTSWatcher {
	return &NodeLTSWatcher{client: client}
}

func (w *NodeLTSWatcher) Check() ([]base.Internal, error) {
	versions, err := w.versionNumbers()
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, v := range versions {
		internals = append(internals, base.Internal{Ref: v})
	}

	sort.Slice(internals, func(i, j int) bool {
		vi, err1 := semver.Parse(internals[i].Ref)
		vj, err2 := semver.Parse(internals[j].Ref)
		if err1 != nil || err2 != nil {
			return internals[i].Ref < internals[j].Ref
		}
		return vi.LessThan(vj)
	})

	return internals, nil
}

func (w *NodeLTSWatcher) In(ref string) (base.Release, error) {
	nodeWatcher := NewNodeWatcher(w.client)
	return nodeWatcher.In(ref)
}

func (w *NodeLTSWatcher) getLTSLine() (int, error) {
	resp, err := w.client.Get("https://raw.githubusercontent.com/nodejs/Release/main/schedule.json")
	if err != nil {
		return 0, fmt.Errorf("fetching node LTS schedule: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, fmt.Errorf("reading LTS schedule: %w", err)
	}

	var schedule map[string]nodeScheduleInfo
	if err := json.Unmarshal(body, &schedule); err != nil {
		return 0, fmt.Errorf("parsing LTS schedule: %w", err)
	}

	now := time.Now()
	var latestLTS int

	for version, info := range schedule {
		if info.LTS == "" {
			continue
		}

		ltsDate, err := time.Parse("2006-01-02", info.LTS)
		if err != nil {
			continue
		}

		if ltsDate.After(now) {
			continue
		}

		versionNum := 0
		fmt.Sscanf(strings.TrimPrefix(version, "v"), "%d", &versionNum)

		if versionNum > latestLTS {
			latestLTS = versionNum
		}
	}

	if latestLTS == 0 {
		return 0, fmt.Errorf("no LTS version found")
	}

	return latestLTS, nil
}

func (w *NodeLTSWatcher) versionNumbers() ([]string, error) {
	latestLTS, err := w.getLTSLine()
	if err != nil {
		return nil, err
	}

	resp, err := w.client.Get("https://nodejs.org/dist/index.json")
	if err != nil {
		return nil, fmt.Errorf("fetching node releases: %w", err)
	}
	defer resp.Body.Close()

	var releases []nodeRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("decoding node releases: %w", err)
	}

	var versions []string
	for _, release := range releases {
		version := strings.TrimPrefix(release.Version, "v")
		ver, err := semver.Parse(version)
		if err != nil {
			continue
		}

		if ver.Major == latestLTS {
			versions = append(versions, version)
		}
	}

	return versions, nil
}
