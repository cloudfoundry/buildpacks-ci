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
	"encoding/json"
	"io/ioutil"
	"path/filepath"

	"github.com/buildpack/libbuildpack/application"
)

// FindMainModule examines a package.json file in the root of the Application and returns the value for "main" if it
// exists.  If it does not exist, returns false.
func FindMainModule(application application.Application) (string, bool, error) {
	p := filepath.Join(application.Root, "package.json")
	if exists, err := FileExists(p); err != nil {
		return "", false, err
	} else if !exists {
		return "", false, nil
	}

	c, err := ioutil.ReadFile(p)
	if err != nil {
		return "", false, err
	}

	var j map[string]interface{}
	if err := json.Unmarshal(c, &j); err != nil {
		return "", false, err
	}

	m, ok := j["main"].(string)
	if !ok {
		return "", false, nil
	}

	path := filepath.Join(application.Root, m)

	if exists, err := FileExists(path); err != nil {
		return "", false, err
	} else if !exists {
		return "", false, nil
	}

	return path, true, nil
}
