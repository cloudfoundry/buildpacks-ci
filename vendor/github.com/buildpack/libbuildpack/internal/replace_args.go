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

// ReplaceArgs replaces the current command line arguments (os.Args) with a new collection of values.  Returns a
// function suitable for use with defer in order to reset the previous values
//
//  defer ReplaceArgs(t, "alpha")()
func ReplaceArgs(t *testing.T, args ...string) func() {
	t.Helper()

	previous := os.Args
	os.Args = args

	return func() { os.Args = previous }
}
