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
	"os"
	"strings"
)

// Credentials is the collection of credentials available exposed by a service.
type Credentials map[string]interface{}

// FindServiceCredentials returns the credentials payload for given service.  The selected service is one who's
// BindingName, InstanceName, Label, or Tags contain the filter and has the required credentials.  Returns the
// credentials and true if exactly one service is matched, otherwise false.
//
// NOTE: This function should ONLY be used in helper applications executed at launch time.  It is BY DESIGN that
// credential values are not available when the buildpack is executing.
func FindServiceCredentials(filter string, credentials ...string) (Credentials, bool, error) {
	services, err := services()
	if err != nil {
		return nil, false, err
	}

	match := make([]service, 0)
	for _, s := range services {
		if matchesService(s, filter) && matchesCredentials(s, credentials) {
			match = append(match, s)
		}
	}

	if len(match) != 1 {
		return nil, false, nil
	}

	return match[0].Credentials, true, nil
}

func any(s string, candidates []string) bool {
	for _, c := range candidates {
		if strings.Contains(c, s) {
			return true
		}
	}

	return false
}

func matchesBindingName(service service, filter string) bool {
	return strings.Contains(service.BindingName, filter)
}

func matchesCredentials(service service, credentials []string) bool {
	candidates := service.Credentials

	for _, c := range credentials {
		if _, ok := candidates[c]; !ok {
			return false
		}
	}

	return true
}

func matchesInstanceName(service service, filter string) bool {
	return strings.Contains(service.InstanceName, filter)
}

func matchesLabel(service service, filter string) bool {
	return strings.Contains(service.Label, filter)
}

func matchesService(service service, filter string) bool {
	return matchesBindingName(service, filter) ||
		matchesInstanceName(service, filter) ||
		matchesLabel(service, filter) ||
		matchesTag(service, filter)
}

func matchesTag(service service, filter string) bool {
	return any(filter, service.Tags)
}

func services() ([]service, error) {
	e, ok := os.LookupEnv("CNB_SERVICES")
	if !ok {
		return []service{}, nil
	}

	var in map[string][]json.RawMessage
	if err := json.Unmarshal([]byte(e), &in); err != nil {
		return nil, err
	}

	var services []service
	for _, raws := range in {
		for _, raw := range raws {
			var s service

			if err := json.Unmarshal(raw, &s); err != nil {
				return nil, err
			}

			services = append(services, s)
		}
	}

	return services, nil
}

type service struct {
	// BindingName is the binding name of this service.
	BindingName string `json:"binding_name"`

	// Credentials is the collection of credentials.
	Credentials Credentials `json:"credentials"`

	// InstanceName is the instance name of this service.
	InstanceName string `json:"instance_name"`

	// Label is the type of service.
	Label string `json:"label"`

	// Tags is the collection of tags of the service.
	Tags []string `json:"tags"`
}
