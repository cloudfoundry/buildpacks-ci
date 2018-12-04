$ErrorActionPreference='Stop'
trap {
    write-error $_
    exit 1
}

$env:GOPATH = Join-Path -Path $PWD "gopath"
$env:PATH = $env:GOPATH + "/bin;" + $env:PATH

$env:GO111MODULE = "on"
mkdir -p $env:GOPATH/src/github.com/cloudfoundry/
cp -r libbuildpack $env:GOPATH/src/github.com/cloudfoundry/
cd $env:GOPATH/src/github.com/cloudfoundry/libbuildpack

go.exe get -t ./...
go get github.com/onsi/ginkgo/ginkgo
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error installing ginkgo"
    Write-Error $_
    exit 1
}

ginkgo.exe -r -race -keepGoing -focus=Stager
if ($LASTEXITCODE -ne 0) {
    Write-Host "Gingko returned non-zero exit code: $LASTEXITCODE"
    Write-Error $_
    exit 1
}

ginkgo.exe -r -race -keepGoing -focus=command
if ($LASTEXITCODE -ne 0) {
    Write-Host "Gingko returned non-zero exit code: $LASTEXITCODE"
    Write-Error $_
    exit 1
}
