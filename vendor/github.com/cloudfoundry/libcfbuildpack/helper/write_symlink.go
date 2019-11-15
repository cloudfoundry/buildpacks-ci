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
	"fmt"
	"os"
	"path/filepath"
)

// WriteSymlink creates newName as a symbolic link to oldName.  Before writing, it creates all required parent
// directories for the newName.
func WriteSymlink(oldName string, newName string) error {
	if err := os.MkdirAll(filepath.Dir(newName), 0755); err != nil {
		return err
	}

	if err := os.Symlink(oldName, newName); err != nil {
		return fmt.Errorf("error while creating '%s' as symlink to '%s': %v", newName, oldName, err)
	}

	return nil
}
