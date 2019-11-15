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
	"fmt"
	"os"
)

// ApplicationRoutes is a map of route name to ApplicationRoute.
type ApplicationRoutes map[string]ApplicationRoute

// ApplicationRoute represents a route exposed by the platform to an application.
type ApplicationRoute struct {
	// Port is the port exposed as part of the route.
	Port int `json:"port"`

	// URI is the URI exposed by the route.
	URI string `json:"uri"`
}

// DefaultApplicationRoutes creates a new instance of ApplicationRoutes, extracting the value from the
// CNB_APP_ROUTES environment variable.
func DefaultApplicationRoutes() (ApplicationRoutes, error) {
	a, ok := os.LookupEnv("CNB_APP_ROUTES")
	if !ok {
		return nil, fmt.Errorf("CNB_APP_ROUTES not set")
	}

	var ar ApplicationRoutes
	if err := json.Unmarshal([]byte(a), &ar); err != nil {
		return nil, err
	}

	return ar, nil
}
