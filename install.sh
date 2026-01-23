#!/usr/bin/env bash
set -euo pipefail

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 変数定義
REPO="k-aoshima/aether-deck-release"
INSTALL_DIR="${AETHER_INSTALL_DIR:-$HOME/.local/aether-deck}"
BIN_DIR="/usr/local/bin"
TEMP_DIR=$(mktemp -d)
VERSION=""
ROLLBACK_DIR=""

# クリーンアップ関数
cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

# エラーハンドリング
error_exit() {
  echo -e "${RED}❌ Error: $1${NC}" >&2
  if [ -n "$ROLLBACK_DIR" ] && [ -d "$ROLLBACK_DIR" ]; then
    echo -e "${YELLOW}Rolling back installation...${NC}"
    if [ -f "$BIN_DIR/aether" ]; then
      sudo rm -f "$BIN_DIR/aether"
    fi
    if [ -d "$ROLLBACK_DIR" ]; then
      rm -rf "$ROLLBACK_DIR"
    fi
  fi
  cleanup
  exit 1
}

trap cleanup EXIT
trap 'error_exit "Script interrupted"' INT TERM

# ログ関数
log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

# システム情報の検出
detect_system() {
  log_info "Detecting system information..."
  
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  
  case "$OS" in
    Darwin)
      OS_NAME="macOS"
      ;;
    Linux)
      OS_NAME="Linux"
      ;;
    *)
      error_exit "Unsupported operating system: $OS"
      ;;
  esac
  
  case "$ARCH" in
    x86_64)
      ARCH_NAME="x64"
      ;;
    arm64|aarch64)
      ARCH_NAME="arm64"
      ;;
    *)
      error_exit "Unsupported architecture: $ARCH"
      ;;
  esac
  
  log_success "Detected: $OS_NAME ($ARCH_NAME)"
}

# 依存関係の確認
check_dependencies() {
  log_info "Checking dependencies..."
  
  # Node.jsの確認
  if ! command -v node &> /dev/null; then
    error_exit "Node.js is not installed. Please install Node.js 20 or higher from https://nodejs.org/"
  fi
  
  NODE_VERSION=$(node -v | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
  
  if [ "$NODE_MAJOR" -lt 20 ]; then
    error_exit "Node.js version 20 or higher is required. Current version: $NODE_VERSION"
  fi
  
  log_success "Node.js version: $NODE_VERSION"
  
  # npmまたはyarnの確認
  if command -v yarn &> /dev/null; then
    PACKAGE_MANAGER="yarn"
    log_success "Found yarn"
  elif command -v npm &> /dev/null; then
    PACKAGE_MANAGER="npm"
    log_success "Found npm"
  else
    error_exit "Neither yarn nor npm is installed. Please install one of them."
  fi
  
  # macOSの場合、Xcode Command Line Toolsの確認
  if [ "$OS" = "Darwin" ]; then
    if ! xcode-select -p &> /dev/null; then
      log_warning "Xcode Command Line Tools may not be installed."
      log_warning "If node-pty build fails, install with: xcode-select --install"
    else
      log_success "Xcode Command Line Tools found"
    fi
  fi
}

# 最新リリースの検出
get_latest_version() {
  log_info "Fetching latest release version..."
  
  if ! command -v curl &> /dev/null; then
    error_exit "curl is not installed. Please install curl."
  fi
  
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
  
  # GitHub Personal Access Tokenが設定されている場合は使用
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    HTTP_CODE=$(curl -s -o /tmp/release_response.json -w "%{http_code}" -H "Authorization: token ${GITHUB_TOKEN}" "$API_URL")
    RELEASE_INFO=$(cat /tmp/release_response.json)
    rm -f /tmp/release_response.json
  else
    HTTP_CODE=$(curl -s -o /tmp/release_response.json -w "%{http_code}" "$API_URL")
    RELEASE_INFO=$(cat /tmp/release_response.json)
    rm -f /tmp/release_response.json
  fi
  
  # HTTPステータスコードを確認
  if [ "$HTTP_CODE" != "200" ]; then
    ERROR_MSG=$(echo "$RELEASE_INFO" | grep -o '"message": *"[^"]*"' | head -n 1 | cut -d '"' -f 4)
    if [ "$HTTP_CODE" = "404" ]; then
      if [ -n "$ERROR_MSG" ]; then
        error_exit "Release not found (HTTP 404): $ERROR_MSG. Please create a release first by running: git tag v0.1.0 && git push origin v0.1.0"
      else
        error_exit "Release not found (HTTP 404). No releases available. Please create a release first by running: git tag v0.1.0 && git push origin v0.1.0"
      fi
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
      error_exit "Authentication failed (HTTP $HTTP_CODE). If this is a private repository, please set GITHUB_TOKEN environment variable with a token that has 'repo' scope."
    else
      error_exit "Failed to fetch latest version (HTTP $HTTP_CODE): $ERROR_MSG"
    fi
  fi
  
  VERSION=$(echo "$RELEASE_INFO" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
  
  if [ -z "$VERSION" ]; then
    # エラーメッセージを確認
    ERROR_MSG=$(echo "$RELEASE_INFO" | grep -o '"message": *"[^"]*"' | head -n 1 | cut -d '"' -f 4)
    if [ -n "$ERROR_MSG" ]; then
      error_exit "Failed to parse version: $ERROR_MSG. If this is a private repository, please set GITHUB_TOKEN environment variable."
    else
      error_exit "Failed to parse version from release information. Please check your internet connection and try again."
    fi
  fi
  
  log_success "Latest version: $VERSION"
}

# リリースのダウンロード
download_release() {
  log_info "Downloading release tarball..."
  
  TAG="v${VERSION}"
  TARBALL_NAME="aether-deck-${VERSION}.tar.gz"
  
  # GitHubリリースAPIからアセットURLを取得
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
  log_info "Fetching release information..."
  
  # GitHub Personal Access Tokenが設定されている場合は使用
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    RELEASE_INFO=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$API_URL")
  else
    RELEASE_INFO=$(curl -s "$API_URL")
  fi
  
  # アセットURLを取得
  TARBALL_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url": *"[^"]*'"${TARBALL_NAME}"'[^"]*"' | cut -d '"' -f 4)
  
  if [ -z "$TARBALL_URL" ]; then
    # アセットが見つからない場合、フォールバックとしてタグアーカイブを試す
    log_warning "Release asset not found, trying tag archive..."
    TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
    
    # プライベートリポジトリの場合、認証が必要な可能性がある
    HTTP_CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" "$TARBALL_URL")
    if [ "$HTTP_CODE" != "200" ]; then
      if [ "$HTTP_CODE" = "404" ]; then
        error_exit "Release not found. This repository may be private. Please set GITHUB_TOKEN environment variable with a Personal Access Token that has 'repo' scope."
      else
        error_exit "Failed to access release (HTTP $HTTP_CODE). Please check your internet connection and try again."
      fi
    fi
  fi
  
  TARBALL_FILE="${TEMP_DIR}/${TARBALL_NAME}"
  
  log_info "Downloading from: $TARBALL_URL"
  
  # GitHub Personal Access Tokenが設定されている場合は使用
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    if ! curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" -o "$TARBALL_FILE" "$TARBALL_URL"; then
      error_exit "Failed to download release tarball. Please check your internet connection and GITHUB_TOKEN."
    fi
  else
    if ! curl -fsSL -o "$TARBALL_FILE" "$TARBALL_URL"; then
      error_exit "Failed to download release tarball. Please check your internet connection and try again. If this is a private repository, please set GITHUB_TOKEN environment variable."
    fi
  fi
  
  log_success "Downloaded tarball"
  
  # 展開
  log_info "Extracting tarball..."
  cd "$TEMP_DIR"
  tar -xzf "$TARBALL_FILE"
  
  # package.jsonが存在するか確認（直接展開されている場合）
  # リリースアセットの場合：bin/, lib/, package.json などが直接展開される
  if [ -f "package.json" ]; then
    SOURCE_DIR="$TEMP_DIR"
    log_success "Files extracted directly to: $SOURCE_DIR"
  else
    # タグアーカイブの場合：aether-deck-0.1.2/ のようなサブディレクトリができる
    # ただし、find が bin/ などのディレクトリを見つける可能性があるので、
    # すべてのディレクトリを確認して、package.json を含むものを探す
    EXTRACTED_DIR=""
    for dir in $(find . -maxdepth 1 -type d ! -name . ! -name "*.tar.gz" | sort); do
      dir=$(echo "$dir" | sed 's|^\./||')
      if [ -f "${dir}/package.json" ]; then
        EXTRACTED_DIR="$dir"
        break
      fi
    done
    
    if [ -z "$EXTRACTED_DIR" ]; then
      # package.jsonが見つからない場合、もう一度現在のディレクトリを確認
      if [ -f "package.json" ]; then
        SOURCE_DIR="$TEMP_DIR"
        log_success "Files extracted directly to: $SOURCE_DIR"
      else
        error_exit "Failed to find package.json in extracted tarball"
      fi
    else
      SOURCE_DIR="${TEMP_DIR}/${EXTRACTED_DIR}"
      log_success "Extracted to: $SOURCE_DIR"
    fi
  fi
  
  # デバッグ: SOURCE_DIRの内容を確認
  if [ ! -f "${SOURCE_DIR}/package.json" ]; then
    error_exit "package.json not found at ${SOURCE_DIR}/package.json"
  fi
  
  if [ ! -d "${SOURCE_DIR}/bin" ]; then
    error_exit "bin directory not found at ${SOURCE_DIR}/bin"
  fi
}

# 依存関係のインストール
install_dependencies() {
  log_info "Installing dependencies..."
  
  cd "$SOURCE_DIR"
  
  if [ "$PACKAGE_MANAGER" = "yarn" ]; then
    if [ -f "yarn.lock" ]; then
      yarn install --frozen-lockfile
    else
      yarn install
    fi
  else
    if [ -f "package-lock.json" ]; then
      npm ci
    else
      npm install
    fi
  fi
  
  log_success "Dependencies installed"
}

# アプリケーションのビルド
build_application() {
  log_info "Checking if build is needed..."
  
  cd "$SOURCE_DIR"
  
  # .nextディレクトリが存在する場合はビルド済みとみなしてスキップ
  if [ -d ".next" ]; then
    log_success "Build artifacts found (.next directory exists), skipping build"
    return 0
  fi
  
  # scripts/ディレクトリが存在しない場合、prebuildスクリプトを一時的に無効化
  if [ ! -d "scripts" ]; then
    log_info "scripts/ directory not found, temporarily disabling prebuild script"
    if [ -f "package.json" ]; then
      # package.jsonのバックアップを作成
      cp package.json package.json.bak
      # prebuildスクリプトを一時的に無効化
      if command -v node >/dev/null 2>&1; then
        node -e "
          const fs = require('fs');
          const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
          if (pkg.scripts && pkg.scripts.prebuild) {
            pkg.scripts.prebuild = 'echo \"Skipping prebuild (scripts/ not found)\"';
            fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
          }
        "
      fi
    fi
  fi
  
  log_info "Building application..."
  
  if [ "$PACKAGE_MANAGER" = "yarn" ]; then
    yarn build
  else
    npm run build
  fi
  
  # package.jsonのバックアップを復元
  if [ -f "package.json.bak" ]; then
    mv package.json.bak package.json
  fi
  
  log_success "Application built"
}

# バイナリのインストール
install_binary() {
  log_info "Installing aether command..."
  
  # 既存のインストールを確認
  if [ -f "$BIN_DIR/aether" ]; then
    log_warning "Existing installation found at $BIN_DIR/aether"
    log_info "This will be upgraded to version $VERSION"
  fi
  
  # インストールディレクトリの作成
  mkdir -p "$INSTALL_DIR"
  
  # ソースファイルをコピー
  log_info "Copying files to $INSTALL_DIR..."
  
  # 必要なファイルとディレクトリをコピー
  cp -r "$SOURCE_DIR/bin" "$INSTALL_DIR/"
  cp -r "$SOURCE_DIR/lib" "$INSTALL_DIR/"
  cp -r "$SOURCE_DIR/server" "$INSTALL_DIR/"
  cp "$SOURCE_DIR/server.js" "$INSTALL_DIR/"
  cp "$SOURCE_DIR/package.json" "$INSTALL_DIR/"
  
  # .nextディレクトリが存在する場合はコピー
  if [ -d "$SOURCE_DIR/.next" ]; then
    cp -r "$SOURCE_DIR/.next" "$INSTALL_DIR/"
  fi
  
  # yarn.lockまたはpackage-lock.jsonをコピー
  if [ -f "$SOURCE_DIR/yarn.lock" ]; then
    cp "$SOURCE_DIR/yarn.lock" "$INSTALL_DIR/"
  elif [ -f "$SOURCE_DIR/package-lock.json" ]; then
    cp "$SOURCE_DIR/package-lock.json" "$INSTALL_DIR/"
  fi
  
  # node_modulesをコピー
  if [ -d "$SOURCE_DIR/node_modules" ]; then
    log_info "Copying node_modules (this may take a while)..."
    cp -r "$SOURCE_DIR/node_modules" "$INSTALL_DIR/"
  fi
  
  log_success "Files copied to $INSTALL_DIR"
  
  # シンボリックリンクの作成（sudoが必要）
  log_info "Creating symlink in $BIN_DIR (requires sudo)..."
  
  # aetherスクリプトのパスを更新
  AETHER_SCRIPT="$INSTALL_DIR/bin/aether"
  
  # シンボリックリンクを作成
  if sudo ln -sf "$AETHER_SCRIPT" "$BIN_DIR/aether"; then
    log_success "Symlink created: $BIN_DIR/aether -> $AETHER_SCRIPT"
  else
    error_exit "Failed to create symlink. Please check sudo permissions."
  fi
  
  # 実行権限の確認
  chmod +x "$AETHER_SCRIPT"
  
  log_success "aether command installed"
}

# メイン処理
main() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Aether Deck Installation Script     ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""
  
  detect_system
  check_dependencies
  get_latest_version
  download_release
  install_dependencies
  build_application
  install_binary
  
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   Installation Complete!              ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}✓${NC} Aether Deck version ${VERSION} has been installed successfully!"
  echo ""
  echo "You can now use the 'aether' command from anywhere:"
  echo "  $ aether"
  echo ""
  echo "For help, run:"
  echo "  $ aether --help"
  echo ""
}

# スクリプトの実行
main
