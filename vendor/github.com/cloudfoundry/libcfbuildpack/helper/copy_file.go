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
)

// CopyFile copies source to destination.  Before writing, it creates all required parent directories for the
// destination.
func CopyFile(source string, destination string) error {
	s, err := os.Open(source)
	if err != nil {
		return err
	}

	defer s.Close()

	i, err := s.Stat()
	if err != nil {
		return err
	}

	return WriteFileFromReader(destination, i.Mode(), s)
}
