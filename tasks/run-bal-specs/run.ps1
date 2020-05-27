$ErrorActionPreference = "Stop";
$env:GOPATH="C:\go-" + (-join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_}))
trap { $host.SetShouldExit(1); cmd.exe /c rd /q /s $env:GOPATH }

$env:CREDENTIAL_FILTER_WHITELIST="SystemDrive,SystemRoot,SERVICE_ID,NUMBER_OF_PROCESSORS,PROCESSOR_LEVEL,WINSW_SERVICE_ID,__PIPE_SERVICE_NAME,GOPATH,USERPROFILE"
$env:PATH=$env:GOPATH + "/bin;C:/go/bin;C:/var/vcap/bosh/bin;" + $env:PATH
$buildDir=$env:GOPATH + "/src/code.cloudfoundry.org/buildpackapplifecycle"
md -Force $buildDir
cp bal-develop/* $buildDir -recurse

push-location $buildDir
  echo "Go version: "
  go version
  go get -t ./...

  echo "Running tests..."
  $(& "c:\var\vcap\packages\ginkgo\bin\ginkgo.exe" -r -race; $ExitCode="$LastExitCode")
pop-location

cmd.exe /c rd /q /s $env:GOPATH

Exit $ExitCode
