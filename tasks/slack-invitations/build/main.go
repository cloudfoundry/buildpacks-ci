package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	server := &http.Server{
		Addr: fmt.Sprintf(":%s", os.Getenv("PORT")),
		Handler: http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			http.Redirect(w, req, os.Getenv("INVITE_URL"), http.StatusTemporaryRedirect)
		}),
	}

	log.Fatal(server.ListenAndServe())
}
