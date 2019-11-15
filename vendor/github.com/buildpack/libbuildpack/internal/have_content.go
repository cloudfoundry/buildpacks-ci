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
	"fmt"
	"io/ioutil"

	"github.com/onsi/gomega/types"
)

func HaveContent(expected string) types.GomegaMatcher {
	return &haveContentMatcher{
		expected: expected,
	}
}

type haveContentMatcher struct {
	expected string
}

func (m *haveContentMatcher) Match(actual interface{}) (bool, error) {
	path, ok := actual.(string)
	if !ok {
		return false, fmt.Errorf("HaveContent matcher expects a path")
	}

	b, err := ioutil.ReadFile(path)
	if err != nil {
		return false, fmt.Errorf("failed to read file: %s", err.Error())
	}

	return string(b) == m.expected, nil
}

func (m *haveContentMatcher) FailureMessage(actual interface{}) string {
	return fmt.Sprintf("Expected\n\t%#v\nto contain\n\t%#v", actual, m.expected)
}

func (m *haveContentMatcher) NegatedFailureMessage(actual interface{}) string {
	return fmt.Sprintf("Expected\n\t%#v\nnot to contain\n\t%#v", actual, m.expected)
}
