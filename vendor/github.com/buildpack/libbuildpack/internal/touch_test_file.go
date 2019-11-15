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
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

// TouchTestFile writes a zero-length file during testing.
func TouchTestFile(t *testing.T, elem ...string) {
	filename := filepath.Join(elem...)

	if err := os.MkdirAll(filepath.Dir(filename), 0755); err != nil {
		t.Fatal(err)
	}

	if err := ioutil.WriteFile(filename, []byte{}, 0644); err != nil {
		t.Fatal(err)
	}
}
