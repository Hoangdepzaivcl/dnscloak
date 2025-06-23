#!/bin/bash

FORCE=0
VERBOSE=0
CACHEOFF=0

while [[ "$1" != "" ]]; do
  case $1 in
    --force )             FORCE=1 ;;
    --verbose )           VERBOSE=1 ;;
    --with-gocache-off )  CACHEOFF=1 ;;
    * ) exit 1 ;;
  esac
  shift
done

if [[ "$CORDOVA_CMDLINE" != "" ]]; then
  PLATFORMPATH="$(dirname "$0")/../../platforms/ios/"
else
  PLATFORMPATH="$(dirname "$0")/../platforms/ios/"
fi

if [[ $FORCE != 1 && -d "${PLATFORMPATH}Dnscryptproxy.framework" ]]; then
  echo "Framework exists, skipping..."
  exit 0
fi

echo "Building Go framework"
cd "$PLATFORMPATH"
REPOROOT=$(pwd)

# Setup Go build env
export GOPATH=$REPOROOT/.build
export PATH="$GOPATH/bin:$(go env GOPATH)/bin:$PATH"

PKGPATH="$GOPATH/src/github.com/jedisct1/dnscrypt-proxy"
GOMOBILE_FLAGS=""
export GO111MODULE=on

if [[ $CACHEOFF == 1 ]]; then
  go clean -cache
fi

if [[ $VERBOSE == 1 ]]; then
  set -v
  GOMOBILE_FLAGS="-v"
fi

# Start clean
rm -rf "$GOPATH"
mkdir -p "$GOPATH"

rm -rf Dnscryptproxy.framework/

# Install gomobile if not exists
if ! command -v gomobile >/dev/null 2>&1; then
  echo "Installing gomobile..."
  go install golang.org/x/mobile/cmd/gomobile@latest
  gomobile init
fi

# Clone dnscrypt-proxy
mkdir -p "$(dirname "$PKGPATH")"
cd "$(dirname "$PKGPATH")"
git clone https://github.com/jedisct1/dnscrypt-proxy.git
cd dnscrypt-proxy
git remote add dnscloak https://github.com/s-s/dnscrypt-proxy.git || true
git fetch dnscloak --quiet
git checkout ios --quiet

# Prepare source
cd dnscrypt-proxy

VERSION_LINE=$(grep 'AppVersion[[:space:]]*=' main.go || echo 'AppVersion = "(unknown)"')

# Clean up
rm -f main.go *_linux.go *_windows.go privilege*.go
rm -rf vendor

# Rewrite package
find . -name '*.go' -exec sed -i '' 's/package main/package dnscrypt/g' {} +
find . -name '*.go' -exec sed -i '' 's/proxy.dropPrivilege/\/\/proxy.dropPrivilege/g' {} +

# Copy framework sources
cp -R "$REPOROOT/../../framework/"* ./

# Save version
cat > ios/version.go <<EOS
package dnscryptproxy
const (
  $VERSION_LINE
)
EOS

# Build iOS framework
gomobile bind -target ios $GOMOBILE_FLAGS ./ios

# Move final framework
mv dnscryptproxy.framework "$REPOROOT/Dnscryptproxy.framework"

# Cleanup
rm -rf "$GOPATH"
