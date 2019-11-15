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
	"archive/zip"
	"os"
)

// ExtractZip extracts source ZIP file to a destination directory.  An arbitrary number of top-level directory
// components can be stripped from each path.
func ExtractZip(source string, destination string, stripComponents int) error {
	z, err := zip.OpenReader(source)
	if err != nil {
		return err
	}
	defer z.Close()

	for _, f := range z.File {
		target := strippedPath(f.Name, destination, stripComponents)
		if target == "" {
			continue
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
		} else {
			if err := writeFile(f, target); err != nil {
				return err
			}
		}
	}

	return nil
}

func writeFile(file *zip.File, target string) error {
	in, err := file.Open()
	if err != nil {
		return err
	}
	defer in.Close()

	return WriteFileFromReader(target, file.Mode(), in)
}
