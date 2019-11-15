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

// ProtectEnv protects a collection of environment variables.  Returns a function for use with defer in order to reset
// the previous values.
//
// defer ProtectEnv(t, "alpha")()
func ProtectEnv(t *testing.T, keys ...string) func() {
	t.Helper()

	type state struct {
		value string
		ok    bool
	}

	previous := make(map[string]state)
	for _, key := range keys {
		value, ok := os.LookupEnv(key)
		previous[key] = state{value, ok}
	}

	return func() {
		for k, v := range previous {
			if v.ok {
				if err := os.Setenv(k, v.value); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := os.Unsetenv(k); err != nil {
					t.Fatal(err)
				}
			}
		}
	}
}
