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
	"io/ioutil"
	"os"
	"path/filepath"
)

// CopyDirectory copies source to destination recursively.
func CopyDirectory(source string, destination string) error {
	files, err := ioutil.ReadDir(source)
	if err != nil {
		return err
	}

	for _, f := range files {
		s := filepath.Join(source, f.Name())
		d := filepath.Join(destination, f.Name())

		if m := f.Mode(); m&os.ModeSymlink != 0 {
			if err := CopySymlink(s, d); err != nil {
				return err
			}
		} else if f.IsDir() {
			if err := CopyDirectory(s, d); err != nil {
				return err
			}
		} else {
			if err := CopyFile(s, d); err != nil {
				return err
			}
		}
	}

	return nil
}
