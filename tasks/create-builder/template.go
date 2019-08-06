package main

import (
	"fmt"
	"log"
	"os"
	templ "text/template"
)

var VersionString = "unset"

func main() {
	v := struct {
		Version string
	}{
		Version: VersionString,
	}

	template := templ.Must(templ.ParseFiles("buildpack.toml"))
	f, err := os.OpenFile("buildpack.toml", os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		log.Fatal(fmt.Errorf("failed to open buildpack.toml : %s", err))
	}

	err = template.Execute(f, v)
	if err != nil {
		log.Fatal(fmt.Errorf("failed to write template to buildpack.toml : %s", err))
	}

}
