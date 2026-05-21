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

URL="https://github.com/${REPO}/releases/download/${LATEST}/${BINARY}-${TARGET}.tar.gz"

if [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

echo "Downloading ${BINARY} ${LATEST} (${TARGET})..."
curl -sSfL "$URL" | tar -xz -C "$INSTALL_DIR" "$BINARY"
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
