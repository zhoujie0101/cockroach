#!/bin/bash

set -eu

PKG=${PKG:-./...}

TestCopyrightHeaders() {
  echo "checking for missing license headers"
  ! git grep -LE '^// (Copyright|Code generated by)' -- '*.go'
}

TestTimeutil() {
  echo "checking for time.Now and time.Since calls (use timeutil instead)"
  ! git grep -nE 'time\.(Now|Since)' -- '*.go' | grep -vE '^util/(log|timeutil)/\w+\.go\b'
}

TestEnvutil() {
  echo "checking for os.Getenv calls (use envutil.EnvOrDefault*() instead)"
  ! git grep -nF 'os.Getenv' -- '*.go' | grep -vE '^((util/(log|envutil|sdnotify))|acceptance(/.*)?)/\w+\.go\b'
}

TestProtoClone() {
  echo "checking for proto.Clone calls (use protoutil.Clone instead)"
  ! git grep -nE '\.Clone\([^)]+\)' -- '*.go' | grep -vF 'protoutil.Clone' | grep -vE '^util/protoutil/clone(_test)?\.go\b'
}

TestProtoMarshal() {
  echo "checking for proto.Marshal calls (use protoutil.Marshal instead)"
  ! git grep -nE '\.Marshal\([^)]+\)' -- '*.go' | grep -vE '(json|yaml|protoutil)\.Marshal' | grep -vE '^util/protoutil/marshal(_test)?\.go\b'
}

TestGrpc() {
  echo "checking for grpc.NewServer calls (use rpc.NewServer instead)"
  ! git grep -nF 'grpc.NewServer()' -- '*.go' | grep -vE '^rpc/context(_test)?\.go\b'
}

TestMissingLeakTest() {
  echo "checking for missing defer leaktest.AfterTest"
  util/leaktest/check-leaktest.sh
}

TestMisspell() {
  ! git ls-files | xargs misspell | grep -vF 'No Exceptions'
}

TestTabsInShellScripts() {
  echo "checking for tabs in shell scripts"
  ! git grep -F "$(echo -ne '\t')" -- '*.sh'
}

TestForbiddenImports() {
  echo "checking for forbidden imports"
  go list -f '{{ $ip := .ImportPath }}{{ range .Imports}}{{ $ip }}: {{ println . }}{{end}}{{ range .TestImports}}{{ $ip }}: {{ println . }}{{end}}{{ range .XTestImports}}{{ $ip }}: {{ println . }}{{end}}' "$PKG" | \
       grep -E ' (github.com/golang/protobuf/proto|github.com/satori/go\.uuid|log|path)$' | \
       grep -Ev 'cockroach/(base|security|util/(log|randutil|stop)): log$' | \
       grep -vF 'util/uuid: github.com/satori/go.uuid' | tee forbidden.log; \
    if grep -E ' path$' forbidden.log > /dev/null; then \
       echo; echo "Consider using 'path/filepath' instead of 'path'."; echo; \
    fi; \
    if grep -E ' log$' forbidden.log > /dev/null; then \
       echo; echo "Consider using 'util/log' instead of 'log'."; echo; \
    fi; \
    if grep -E ' github.com/golang/protobuf/proto$' forbidden.log > /dev/null; then \
       echo; echo "Consider using 'gogo/protobuf/proto' instead of 'golang/protobuf/proto'."; echo; \
    fi; \
    if grep -E ' github.com/satori/go\.uuid$' forbidden.log > /dev/null; then \
       echo; echo "Consider using 'util/uuid' instead of 'satori/go.uuid'."; echo; \
    fi; \
    test ! -s forbidden.log
  ret=$?
  rm -f forbidden.log
  return $ret
}

TestImportNames() {
    echo "checking for named imports"
    if git grep -h '^\(import \|[[:space:]]*\)\(\|[a-z]* \)"database/sql"$' -- '*.go' | grep -v '\<gosql "database/sql"'; then
        echo "Import 'database/sql' as 'gosql' to avoid confusion with 'cockroach/sql'."
        return 1
    fi
    return 0
}


TestIneffassign() {
  ! ineffassign . | grep -vF '.pb.go' # gogo/protobuf#152
}

TestErrcheck() {
  errcheck -ignore 'bytes:Write.*,io:Close,net:Close,net/http:Close,net/rpc:Close,os:Close,database/sql:Close' "$PKG"
}

TestReturnCheck() {
  returncheck "$PKG"
}

TestVet() {
  ! go tool vet . 2>&1 | \
    grep -vE '^vet: cannot process directory .git' | \
    grep -vE '^server/admin\..*\go:.+: constant [0-9]+ not a string in call to Errorf'
  # To return proper HTTP error codes (e.g. 404 Not Found), we need to use
  # grpc.Errorf, which has an error code as its first parameter. 'go vet'
  # doesn't like that the first parameter isn't a format string.
}

TestVetShadow() {
  ! go tool vet --shadow . 2>&1 | \
    grep -vE '(declaration of (pE|e)rr shadows|^vet: cannot process directory \.git)' | \
    grep -vE '\.pb\.gw\.go'
}

TestGolint() {
  ! golint "$PKG" | \
    grep -vE '(\.pb\.go|\.pb\.gw\.go|embedded\.go|_string\.go|LastInsertId|sql/parser/(yaccpar|sql\.y):)'
  # https://golang.org/pkg/database/sql/driver/#Result :(
}

TestVarcheck() {
  ! varcheck -e "$PKG" | \
    grep -vE '(_string.go|sql/parser/(yacctab|sql\.y)|\.pb\.go)'
}

TestGofmtSimplify() {
  ! gofmt -s -d -l . 2>&1 | grep -vE '^\.git/'
}

TestGoimports() {
  ! goimports -l . | grep -vF 'No Exceptions'
}

TestUnused() {
  ! unused -exported ./... | grep -vE '(\.pb\.go:|/C:|_string.go:|embedded.go:|parser/(yacc|sql.y)|util/interval/interval.go:|_cgo|Mutex)'
}

# Run all the tests, wrapped in a similar output format to "go test"
# so we can use go2xunit to generate reports in CI.

failed=0

runcheck() {
  local name="$1"
  shift
  echo "=== RUN $name"
  local output
  if output=$(eval "$name"); then
    echo "--- PASS: $name (0.0s)"
  else
    echo "$output"
    echo "--- FAIL: $name (0.0s)"
    failed=1
  fi
}

# "declare -F" lists all the defined functions, in the form
# declare -f runcheck
# declare -f TestUnused
for i in $(declare -F|cut -d' ' -f3|grep '^Test'); do
  runcheck $i
done

if [ "$failed" = "0" ]; then
  echo "ok check-style 0.0s"
else
  echo "FAIL check-style 0.0s"
  exit 1
fi
