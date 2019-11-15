package utils

import (
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"os"

	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
)

func RandStringRunes(n int) string {
	runes := []rune("abcdefghijklmnopqrstuvwxyz1234567890")
	b := make([]rune, n)
	for i := range b {
		b[i] = runes[rand.Intn(len(runes))]
	}
	return string(b)
}

func NewGitClient(ctx context.Context) *github.Client {
	git_token := os.Getenv("GIT_TOKEN")

	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: git_token},
	)
	tc := oauth2.NewClient(ctx, ts)

	client := github.NewClient(tc)
	if git_token == "" {
		fmt.Println("Using unauthorized github api, consider setting the GIT_TOKEN environment variable")
		fmt.Println("More info on Github tokens here: https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line")
		client = github.NewClient(http.DefaultClient)
	}

	return client
}
