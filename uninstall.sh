#!/usr/bin/env bash
set -euo pipefail

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 変数定義
BIN_DIR="/usr/local/bin"
INSTALL_DIR="${AETHER_INSTALL_DIR:-$HOME/.local/aether-deck}"

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

# 確認プロンプト
confirm_uninstall() {
  echo ""
  echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}║   Aether Deck Uninstallation          ║${NC}"
  echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
  echo ""
  echo "This will remove:"
  
  if [ -f "$BIN_DIR/aether" ]; then
    echo "  - $BIN_DIR/aether"
  fi
  
  if [ -d "$INSTALL_DIR" ]; then
    echo "  - $INSTALL_DIR (entire directory)"
  fi
  
  echo ""
  read -p "Are you sure you want to uninstall Aether Deck? (y/N): " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
  fi
}

# バイナリの削除
remove_binary() {
  if [ -f "$BIN_DIR/aether" ]; then
    log_info "Removing $BIN_DIR/aether (requires sudo)..."
    
    if sudo rm -f "$BIN_DIR/aether"; then
      log_success "Removed $BIN_DIR/aether"
    else
      log_error "Failed to remove $BIN_DIR/aether. You may need to run with sudo."
      return 1
    fi
  else
    log_info "No binary found at $BIN_DIR/aether"
  fi
}

# インストールディレクトリの削除
remove_install_dir() {
  if [ -d "$INSTALL_DIR" ]; then
    log_info "Removing $INSTALL_DIR..."
    
    if rm -rf "$INSTALL_DIR"; then
      log_success "Removed $INSTALL_DIR"
    else
      log_error "Failed to remove $INSTALL_DIR"
      return 1
    fi
  else
    log_info "No installation directory found at $INSTALL_DIR"
  fi
}

# メイン処理
main() {
  confirm_uninstall
  
  echo ""
  log_info "Starting uninstallation..."
  
  remove_binary
  remove_install_dir
  
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   Uninstallation Complete!           ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}✓${NC} Aether Deck has been uninstalled successfully!"
  echo ""
  echo "Note: Configuration files in your home directory (if any) were not removed."
  echo ""
}

# スクリプトの実行
main
