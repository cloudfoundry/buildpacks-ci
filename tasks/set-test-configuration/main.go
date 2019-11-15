package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"

	"github.com/cloudfoundry/dagger"
)

func main() {
	configFilepath := os.Args[1]
	stack := os.Args[2]

	config, err := dagger.ParseConfig(configFilepath)
	if err != nil {
		log.Fatal(err)
	}
	if config.Builder != stack {
		config.Builder = stack
		updatedConfigBytes, _ := json.Marshal(&config)
		err = ioutil.WriteFile(configFilepath, updatedConfigBytes, 0644)
		if err != nil {
			log.Fatal(err)
		}
	}
}
