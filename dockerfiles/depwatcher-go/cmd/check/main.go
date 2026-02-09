package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/internal/factory"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("reading stdin: %w", err)
	}

	req, err := factory.ParseCheckRequest(input)
	if err != nil {
		return fmt.Errorf("parsing request: %w", err)
	}

	factory.SetupGithubToken(&req.Source)
	defer os.Unsetenv("GITHUB_TOKEN") // Clean up token on exit

	// Log sanitized request (after token has been moved to environment)
	sanitized, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("marshaling sanitized request: %w", err)
	}
	fmt.Fprintf(os.Stderr, "%s\n", sanitized)

	versions, err := factory.Check(req.Source, req.Version)
	if err != nil {
		return fmt.Errorf("checking versions: %w", err)
	}

	// Ensure we always return an array, never null (Concourse resource protocol requirement)
	if versions == nil {
		versions = []base.Internal{}
	}

	output, err := json.Marshal(versions)
	if err != nil {
		return fmt.Errorf("marshaling response: %w", err)
	}

	fmt.Println(string(output))
	return nil
}
