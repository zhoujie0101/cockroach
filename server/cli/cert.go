// Copyright 2015 The Cockroach Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied. See the License for the specific language governing
// permissions and limitations under the License. See the AUTHORS file
// for names of contributors.
//
// Author: Marc Berhault (marc@cockroachlabs.com)

package cli

import (
	"flag"
	"fmt"

	"github.com/cockroachdb/cockroach/security"

	"code.google.com/p/go-commander"
)

// A mkCACert command generates a CA certificate and stores it
// in the cert directory.
var mkCACertCmd = &commander.Command{
	UsageLine: "mk-ca-cert [options]",
	Short:     "create CA cert and key",
	Long: `
Generates a new key pair, a new CA certificate and writes them to
individual files in the directory specified by --certs (required).
`,
	Run:  runMkCACert,
	Flag: *flag.CommandLine,
}

// runMkCACert generates key pair and CA certificate and writes them
// to their corresponding files.
func runMkCACert(cmd *commander.Command, args []string) {
	err := security.RunMakeCACert(Context)
	if err != nil {
		fmt.Fprintf(osStderr, "failed to generate CA certificate: %s\n", err)
		osExit(1)
		return
	}
}

// A mkNodeCert command generates a node certificate and stores it
// in the cert directory.
var mkNodeCertCmd = &commander.Command{
	UsageLine: "mk-node-cert [options] <host 1> <host 2> ... <host N>",
	Short:     "create node cert and key\n",
	Long: `
Generates a new key pair, a new node certificate and writes them to
individual files in the directory specified by --certs (required).
The certs directory should contain a CA cert and key.
At least one host should be passed in (either IP address of dns name).
`,
	Run:  runMkNodeCert,
	Flag: *flag.CommandLine,
}

// runMkNodeCert generates key pair and CA certificate and writes them
// to their corresponding files.
func runMkNodeCert(cmd *commander.Command, args []string) {
	err := security.RunMakeNodeCert(Context, args)
	if err != nil {
		fmt.Fprintf(osStderr, "failed to generate node certificate: %s\n", err)
		osExit(1)
		return
	}
}
