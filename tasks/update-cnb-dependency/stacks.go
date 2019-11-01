package main

import (
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
)

type Stack struct {
	ID string
}

type Stacks []Stack

const AnyStack = "any-stack"
const TinyStack = "tiny"

func determineStacks(buildMetadataPath string, dep Dependency, depOrchestratorConfig DependencyOrchestratorConfig) ([]string, error) {
	stackRegexp := regexp.MustCompile(`\/(?:\.|\d)*-(.*)\.json$`)
	matches := stackRegexp.FindStringSubmatch(buildMetadataPath)
	if len(matches) != 2 {
		return nil, errors.New(fmt.Sprintf("expected to find one stack name in filename (%s) but found: %v", filepath.Base(buildMetadataPath), matches[1:]))
	}
	stack := matches[1]

	if stack == AnyStack {
		return handleAnyStack(dep, depOrchestratorConfig)
	} else if stackIsDeprecated(stack, depOrchestratorConfig.DeprecatedStacks) {
		return nil, nil
	}

	for stackName, stackID := range depOrchestratorConfig.V3Stacks {
		if stack == stackName {
			return []string{stackID}, nil
		}
	}
	return nil, errors.New(fmt.Sprintf("%s is not a valid stack", stack))
}

func handleAnyStack(dep Dependency, config DependencyOrchestratorConfig) ([]string, error) {
	var stacks []string
	for stack, stackID := range config.V3Stacks {
		if stack == TinyStack && !includeTiny(dep.ID, config.IncludeTiny) {
			continue
		}
		stacks = append(stacks, stackID)
	}

	if len(stacks) == 0 {
		return nil, errors.New("stack is 'any-stack' but no stacks are configured, check dependency-builds.yml")
	}
	return stacks, nil
}

func stackIsDeprecated(stack string, deprecatedStacks []string) bool {
	return arrayContains(stack, deprecatedStacks)
}

func includeTiny(id string, includeTinyStacks []string) bool {
	return arrayContains(id, includeTinyStacks)
}
