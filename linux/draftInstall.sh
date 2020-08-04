#!/bin/bash

# This is a customized version of the script found at:
# https://github.com/kubernetes/helm/blob/master/scripts/get
# It is optimized to run in a container.

PROJECT_NAME="draft"

: ${INSTALL_DIR:="/usr/local/bin"}

# initArch discovers the architecture for this system.
initArch() {
  ARCH=$(uname -m)
  case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="armv7";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

# initOS discovers the operating system for this system.
initOS() {
  OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

  case "$OS" in
    # Minimalist GNU for Windows
    mingw*) OS='windows';;
  esac
}

# verifySupported checks that the os/arch combination is supported for
# binary builds.
verifySupported() {
  local supported="linux-amd64\ndarwin-amd64\nlinux-386"
  if ! echo "${supported}" | grep -q "${OS}-${ARCH}"; then
    echo "No prebuild binary for ${OS}-${ARCH}."
    echo "To build from source, go to https://github.com/Azure/draft"
    exit 1
  fi

  if ! type "curl" > /dev/null && ! type "wget" > /dev/null; then
    echo "Either curl or wget is required"
    exit 1
  fi
}

# checkLatestVersion checks the latest available version.
checkLatestVersion() {
  # Use the GitHub releases webpage for the project to find the latest version for this project.
  local latest_url="https://github.com/Azure/draft/releases/latest"
  if type "curl" > /dev/null; then
    TAG=$(curl -Ls -o /dev/null -w %{url_effective} $latest_url | grep -oE "[^/]+$" )
  elif type "wget" > /dev/null; then
    TAG=$(wget $latest_url --server-response -O /dev/null 2>&1 | awk '/^  Location: /{DEST=$2} END{ print DEST}' | grep -oE "[^/]+$")
  fi
  if [ "x$TAG" == "x" ]; then
    echo "Cannot determine latest tag."
    exit 1
  fi
}

# downloadFile downloads the latest binary package and also the checksum
# for that binary.
downloadFile() {
  DIST="$PROJECT_NAME-$TAG-$OS-$ARCH.tar.gz"
  DOWNLOAD_URL="https://azuredraft.blob.core.windows.net/draft/$DIST"
  CHECKSUM_URL="$DOWNLOAD_URL.sha256"
  TEMP_FILE="/tmp/$DIST"
  CHECKSUM_FILE="/tmp/$DIST.sha256"
  echo "Downloading $DOWNLOAD_URL"
  if type "curl" > /dev/null; then
    curl -SsL "$CHECKSUM_URL" -o "$CHECKSUM_FILE"
  elif type "wget" > /dev/null; then
    wget -q -O "$CHECKSUM_FILE" "$CHECKSUM_URL"
  fi
  if type "curl" > /dev/null; then
    curl -SsL "$DOWNLOAD_URL" -o "$TEMP_FILE"
  elif type "wget" > /dev/null; then
    wget -q -O "$TEMP_FILE" "$DOWNLOAD_URL"
  fi
}

# installFile verifies the SHA256 for the file, then unpacks and
# installs it.
installFile() {
  TEMP="/tmp/$PROJECT_NAME"
  local sum=$(openssl sha1 -sha256 ${TEMP_FILE} | awk '{print $2}')
  local expected_sum=$(cat ${CHECKSUM_FILE})
  if [ "$sum" != "$expected_sum" ]; then
    echo "SHA sum of $TEMP does not match. Aborting."
    exit 1
  fi

  mkdir -p "$TEMP"
  tar xf "$TEMP_FILE" -C "$TEMP"
  TMP_BIN="$TEMP/$OS-$ARCH/$PROJECT_NAME"
  echo "Preparing to install into ${INSTALL_DIR} (sudo)"
  cp "$TMP_BIN" "$INSTALL_DIR"
}

# fail_trap is executed if an error occurs.
fail_trap() {
  result=$?
  if [ "$result" != "0" ]; then
    echo "Failed to install $PROJECT_NAME"
    echo -e "\tFor support, go to https://github.com/Azure/draft."
  fi
  exit $result
}

# Execution
# Stop execution on any error
trap "fail_trap" EXIT
set -e
initArch
initOS
verifySupported
checkLatestVersion
downloadFile
installFile
