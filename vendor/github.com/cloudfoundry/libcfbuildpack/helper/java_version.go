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
	"github.com/Masterminds/semver"
)

var java9, _ = semver.NewVersion("9")

// After Java8 returns true if a version is greater than or equal to 8.0.0 and false if less.
func AfterJava8(version *semver.Version) bool {
	return !BeforeJava9(version)
}

// BeforeJava9 returns true if a version is less 9.0.0 and false if greater.
func BeforeJava9(version *semver.Version) bool {
	return version.LessThan(java9)
}
