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

	"gopkg.in/yaml.v2"
)

func ReadBuildpackYaml(buildpackYAMLPath string, config interface{}) error {
	f, err := os.Open(buildpackYAMLPath)
	if err != nil {
		return err
	}
	fi, err := os.Stat(buildpackYAMLPath)
	if err != nil {
		return err
	}

	size := fi.Size()
	if size == 0 {
		return nil
	}

	dec := yaml.NewDecoder(f)

	return dec.Decode(config)
}
