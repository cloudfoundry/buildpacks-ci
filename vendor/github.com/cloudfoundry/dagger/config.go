package dagger

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
)

type TestConfig struct {
	Builder        string              `json:"builder"`
	BuildpackOrder map[string][]string `json:"buildpackOrder"`
}

func ParseConfig(configPath string) (TestConfig, error) {
	var config TestConfig
	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		return config, err
	}

	jsonReader := bytes.NewReader(configData)
	decoder := json.NewDecoder(jsonReader)
	decoder.Decode(&config)

	return config, nil
}
