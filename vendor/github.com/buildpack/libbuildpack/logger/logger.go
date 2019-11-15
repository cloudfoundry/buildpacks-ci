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

package logger

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/buildpack/libbuildpack/internal"
)

// Logger is a type that contains references to the console output for debug and info logging levels.
type Logger struct {
	debug *bufio.Writer
	info  *bufio.Writer
}

// Debug prints output to the configured debug writer, interpolating the format and any arguments and adding a newline
// at the end.  If debug logging is not enabled, nothing is printed.
func (l Logger) Debug(format string, args ...interface{}) {
	if !l.IsDebugEnabled() {
		return
	}

	s := fmt.Sprintf(format, args...)
	_, _ = fmt.Fprintf(l.debug, "%s\n", s)
	_ = l.debug.Flush()
}

// Info prints output to the configured info writer, interpolating the format and any arguments and adding a newline
// at the end.  If info logging is not enabled, nothing is printed.
func (l Logger) Info(format string, args ...interface{}) {
	if !l.IsInfoEnabled() {
		return
	}

	s := fmt.Sprintf(format, args...)
	_, _ = fmt.Fprintf(l.info, "%s\n", s)
	_ = l.info.Flush()
}

// IsDebugEnabled returns true if debug logging is enabled, false otherwise.
func (l Logger) IsDebugEnabled() bool {
	return l.debug != nil
}

// IsInfoEnabled returns true if info logging is enabled, false otherwise.
func (l Logger) IsInfoEnabled() bool {
	return l.info != nil
}

// DefaultLogger creates a new instance of Logger, suppressing debug output unless BP_DEBUG is set.
func DefaultLogger(platform string) (Logger, error) {
	_, e := os.LookupEnv("BP_DEBUG")

	p, err := internal.FileExists(filepath.Join(platform, "env", "BP_DEBUG"))
	if err != nil {
		return Logger{}, err
	}

	if e || p {
		return NewLogger(os.Stderr, os.Stdout), nil
	}

	return NewLogger(nil, os.Stdout), nil
}

// NewLogger creates a new instance of Logger, configuring the debug and info writers to use.  If writer is nil, that
// logging level is disabled.
func NewLogger(debug io.Writer, info io.Writer) Logger {
	var logger Logger

	if debug != nil {
		logger.debug = bufio.NewWriter(debug)
	}

	if info != nil {
		logger.info = bufio.NewWriter(info)
	}

	return logger
}
