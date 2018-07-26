$ErrorActionPreference = "Stop";
$env:GOPATH="C:\go-" + (-join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_}))
trap { $host.SetShouldExit(1); cmd.exe /c rd /q /s $env:GOPATH }

$env:CREDENTIAL_FILTER_WHITELIST="SystemDrive,SystemRoot,SERVICE_ID,NUMBER_OF_PROCESSORS,PROCESSOR_LEVEL,WINSW_SERVICE_ID,__PIPE_SERVICE_NAME,GOPATH,USERPROFILE"

$env:PATH=$env:GOPATH + "/bin;C:/go/bin;C:/var/vcap/bosh/bin;" + $env:PATH

$buildDir=$env:GOPATH + "/src/code.cloudfoundry.org/buildpackapplifecycle"
md -Force $buildDir

echo "Moving buildpackapplifecycle onto the gopath..."
cp bal-develop/* $buildDir -recurse

# install git
echo "#### Attempting to install git"
$urlPath = "https://github.com/git-for-windows/git/releases/download/v2.18.0.windows.1/Git-2.18.0-64-bit.exe"
$urlSplit = $urlPath.split('/')
$filename = (Resolve-Path .\).ToString() + '\' + $urlSplit[$urlSplit.length - 1]
$webclient = New-Object "System.Net.WebClient"
$webclient.DownloadFile($urlPath, $filename)
invoke-item $filename
echo "#### Maybe installed git"

push-location $buildDir

  go get -t ./...
  go get github.com/onsi/ginkgo/ginkgo

  go get github.com/pivotal-cf-experimental/concourse-filter
  push-location ../../github.com/pivotal-cf-experimental/concourse-filter
    go build
  pop-location

  $(& ginkgo -r; $ExitCode="$LastExitCode") | concourse-filter

  if ($ExitCode) {
    echo "Running tests for windows2012R2 tag..."
    $env:TAR_URL="https://s3.amazonaws.com/bosh-windows-dependencies/tar-1503683828.exe"
    $(& ginkgo -tags windows2012R2 -r; $ExitCode="$LastExitCode") | concourse-filter
  }

pop-location

cmd.exe /c rd /q /s $env:GOPATH

Exit $ExitCode
