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
	"archive/tar"
	"io"
	"os"
)

func handleTar(source io.Reader, destination string, stripComponents int) error {
	t := tar.NewReader(source)

	for {
		f, err := t.Next()
		if err == io.EOF {
			break
		}

		target := strippedPath(f.Name, destination, stripComponents)
		if target == "" {
			continue
		}

		info := f.FileInfo()
		if info.IsDir() {
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
		} else if info.Mode()&os.ModeSymlink != 0 {
			if err := WriteSymlink(f.Linkname, target); err != nil {
				return err
			}
		} else {
			if err := WriteFileFromReader(target, info.Mode(), t); err != nil {
				return err
			}
		}
	}

	return nil
}
