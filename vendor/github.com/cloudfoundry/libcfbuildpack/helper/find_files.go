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

package helper

import (
	"os"
	"path/filepath"
	"regexp"
)

// FindFiles searches a directory structure for files matching the provided pattern, returning their full paths if found.
func FindFiles(root string, pattern *regexp.Regexp) ([]string, error) {
	var f []string

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if m := pattern.MatchString(path); m {
			f = append(f, path)
		}

		return nil
	})

	return f, err
}
