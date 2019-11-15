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
	"os"
	"testing"
)

// Console represents the standard console objects, stdin, stdout, and stderr.
type Console struct {
	errRead  *os.File
	errWrite *os.File
	inRead   *os.File
	inWrite  *os.File
	outRead  *os.File
	outWrite *os.File
}

// Err returns a string representation of captured stderr.
func (c Console) Err(t *testing.T) string {
	t.Helper()

	err := c.errWrite.Close()
	if err != nil {
		t.Fatal(err)
	}

	bytes, err := ioutil.ReadAll(c.errRead)
	if err != nil {
		t.Fatal(err)
	}

	return string(bytes)
}

// In writes a string and closes the connection once complete.
func (c Console) In(t *testing.T, string string) {
	t.Helper()

	_, err := fmt.Fprint(c.inWrite, string)
	if err != nil {
		t.Fatal(err)
	}

	err = c.inWrite.Close()
	if err != nil {
		t.Fatal(err)
	}
}

// Out returns a string representation of captured stdout.
func (c Console) Out(t *testing.T) string {
	t.Helper()

	err := c.outWrite.Close()
	if err != nil {
		t.Fatal(err)
	}

	bytes, err := ioutil.ReadAll(c.outRead)
	if err != nil {
		t.Fatal(err)
	}

	return string(bytes)
}

// ReplaceConsole replaces the console files (os.Stderr, os.Stdin, os.Stdout).  Returns a function for use with defer in
// order to reset the previous values
//
// c, d := ReplaceConsole(t)
// defer d()
func ReplaceConsole(t *testing.T) (Console, func()) {
	t.Helper()

	var console Console
	var err error

	errPrevious := os.Stderr
	console.errRead, console.errWrite, err = os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stderr = console.errWrite

	inPrevious := os.Stdin
	console.inRead, console.inWrite, err = os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdin = console.inRead

	outPrevious := os.Stdout
	console.outRead, console.outWrite, err = os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = console.outWrite

	return console, func() {
		os.Stderr = errPrevious
		os.Stdin = inPrevious
		os.Stdout = outPrevious
	}
}
