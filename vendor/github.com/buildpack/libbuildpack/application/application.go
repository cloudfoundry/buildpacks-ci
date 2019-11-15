/*
 * Copyright 2018-2019 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package application

import (
	"os"

	"github.com/buildpack/libbuildpack/internal"
	"github.com/buildpack/libbuildpack/logger"
)

// Application represents the application being processed by buildpacks.
type Application struct {
	// Root is the path to the root directory of the application.
	Root string

	logger logger.Logger
}

// DefaultApplication creates a new instance of Application, extracting the Root path from the working directory.
func DefaultApplication(logger logger.Logger) (Application, error) {
	root, err := os.Getwd()
	if err != nil {
		return Application{}, err
	}

	if logger.IsDebugEnabled() {
		contents, err := internal.DirectoryContents(root)
		if err != nil {
			return Application{}, err
		}
		logger.Debug("Application contents: %s", contents)
	}

	return Application{root, logger}, nil
}
