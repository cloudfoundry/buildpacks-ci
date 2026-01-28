package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/internal/factory"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) < 2 {
		return fmt.Errorf("usage: %s <destination>", os.Args[0])
	}

	destDir := os.Args[1]

	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("reading stdin: %w", err)
	}

	req, err := factory.ParseInRequest(input)
	if err != nil {
		return fmt.Errorf("parsing request: %w", err)
	}

	factory.SetupGithubToken(&req.Source)

	fmt.Fprintf(os.Stderr, "%s\n", input)

	versionData, err := factory.In(req.Source, req.Version)
	if err != nil {
		return fmt.Errorf("fetching version data: %w", err)
	}

	dataFilePath := filepath.Join(destDir, "data.json")
	dataJSON := map[string]interface{}{
		"source":  req.Source,
		"version": versionData,
	}
	dataBytes, err := json.MarshalIndent(dataJSON, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling data.json: %w", err)
	}

	if err := os.WriteFile(dataFilePath, dataBytes, 0644); err != nil {
		return fmt.Errorf("writing data.json: %w", err)
	}

	versionBytes, err := json.Marshal(versionData)
	if err != nil {
		return fmt.Errorf("marshaling version: %w", err)
	}
	fmt.Fprintf(os.Stderr, "%s\n", string(versionBytes))

	response := factory.InResponse{
		Version: req.Version,
	}
	responseBytes, err := json.Marshal(response)
	if err != nil {
		return fmt.Errorf("marshaling response: %w", err)
	}

	fmt.Println(string(responseBytes))
	return nil
}
