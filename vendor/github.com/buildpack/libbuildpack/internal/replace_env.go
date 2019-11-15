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
	"testing"
)

// ReplaceEnv replaces an environment variable.  Returns a function for use with defer in order to reset the previous
// value.
//
// defer ReplaceEnv(t, "alpha", "bravo")()
func ReplaceEnv(t *testing.T, key string, value string) func() {
	t.Helper()

	previous, ok := os.LookupEnv(key)
	if err := os.Setenv(key, value); err != nil {
		t.Fatal(err)
	}

	return func() {
		if ok {
			if err := os.Setenv(key, previous); err != nil {
				t.Fatal(err)
			}
		} else {
			if err := os.Unsetenv(key); err != nil {
				t.Fatal(err)
			}
		}
	}
}
