#!/usr/bin/env sh
set -e

REPO="3tio/3t-mcp-releases"
BINARY="stt-cli"

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Darwin)
    case "$ARCH" in
      arm64)  TARGET="aarch64-apple-darwin" ;;
      x86_64) TARGET="x86_64-apple-darwin" ;;
      *) echo "error: unsupported architecture: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  Linux)
    case "$ARCH" in
      x86_64)          TARGET="x86_64-unknown-linux-gnu" ;;
      aarch64 | arm64) TARGET="aarch64-unknown-linux-gnu" ;;
      *) echo "error: unsupported architecture: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "error: unsupported OS: $OS" >&2
    exit 1
    ;;
esac

LATEST=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"tag_name"' \
  | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "$LATEST" ]; then
  echo "error: could not determine latest release" >&2
  exit 1
fi

ARCHIVE_NAME="${BINARY}-${TARGET}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${LATEST}/${ARCHIVE_NAME}"
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${LATEST}/checksums.txt"

if [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS="${TMP_DIR}/checksums.txt"

echo "Downloading ${BINARY} ${LATEST} (${TARGET})..."
curl -sSfL "$URL" -o "$ARCHIVE"
curl -sSfL "$CHECKSUMS_URL" -o "$CHECKSUMS"

echo "Verifying checksum..."
EXPECTED=$(awk -v f="${ARCHIVE_NAME}" '$2 == f {print $1}' "$CHECKSUMS")
if [ -z "$EXPECTED" ]; then
  echo "error: ${ARCHIVE_NAME} not found in checksums.txt" >&2
  exit 1
fi
MATCH_COUNT=$(awk -v f="${ARCHIVE_NAME}" '$2 == f {n++} END {print n+0}' "$CHECKSUMS")
if [ "$MATCH_COUNT" -gt 1 ]; then
  echo "error: multiple entries for ${ARCHIVE_NAME} in checksums.txt" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$ARCHIVE" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
else
  echo "error: sha256sum or shasum not found — cannot verify checksum" >&2
  exit 1
fi

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "error: checksum mismatch for ${ARCHIVE_NAME}" >&2
  echo "  expected: ${EXPECTED}" >&2
  echo "  actual:   ${ACTUAL}" >&2
  exit 1
fi

tar -xz -C "$INSTALL_DIR" -f "$ARCHIVE" "$BINARY"
chmod +x "${INSTALL_DIR}/${BINARY}"

# Remove macOS quarantine attribute if present
if [ "$OS" = "Darwin" ]; then
  xattr -d com.apple.quarantine "${INSTALL_DIR}/${BINARY}" 2>/dev/null || true
fi

echo "Installed ${BINARY} ${LATEST} to ${INSTALL_DIR}/${BINARY}"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "Note: add ${INSTALL_DIR} to your PATH to use ${BINARY}" ;;
esac
