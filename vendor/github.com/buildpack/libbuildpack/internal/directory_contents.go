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

package internal

import (
	"os"
	"path/filepath"
	"sort"
)

// DirectoryContents walks the tree of files below a given root and returns their relative paths.
func DirectoryContents(root string) ([]string, error) {
	var contents []string

	if err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		contents = append(contents, rel)
		return nil
	}); err != nil {
		return nil, err
	}

	sort.Strings(contents)
	return contents, nil
}
