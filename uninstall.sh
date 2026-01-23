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
  
  # 環境変数で確認をスキップできるようにする
  if [ "${AETHER_UNINSTALL_YES:-}" = "1" ] || [ "${AETHER_UNINSTALL_YES:-}" = "true" ]; then
    log_info "Auto-confirming uninstallation (AETHER_UNINSTALL_YES is set)"
    return 0
  fi
  
  # 標準入力が端末でない場合（パイプ経由など）は確認をスキップ
  # [ -t 0 ] は標準入力が端末（TTY）かどうかをチェック
  # curl | bash の場合、標準入力はパイプなので false になる
  if [ ! -t 0 ]; then
    log_info "Non-interactive mode detected. Proceeding with uninstallation..."
    return 0
  fi
  
  # 標準出力が端末でない場合も非対話的と判断
  if [ ! -t 1 ]; then
    log_info "Non-interactive mode detected. Proceeding with uninstallation..."
    return 0
  fi
  
  # 対話的環境の場合のみ確認プロンプトを表示
  # ただし、read コマンドが失敗する可能性があるため、エラーハンドリングを追加
  if ! read -p "Are you sure you want to uninstall Aether Deck? (y/N): " -n 1 -r 2>/dev/null; then
    # read が失敗した場合（非対話的環境など）は自動的に続行
    log_info "Non-interactive mode detected. Proceeding with uninstallation..."
    return 0
  fi
  
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
    
    # 非対話的環境では sudo で実行するように促す
    if [ ! -t 0 ]; then
      log_error "Cannot remove $BIN_DIR/aether in non-interactive mode."
      log_warning "Please run with sudo:"
      echo ""
      echo "  curl -fsSL https://raw.githubusercontent.com/k-aoshima/aether-deck-release/main/uninstall.sh | sudo bash"
      echo ""
      return 1
    fi
    
    # 対話的環境では sudo を試行
    if sudo rm -f "$BIN_DIR/aether" 2>/dev/null; then
      log_success "Removed $BIN_DIR/aether"
    else
      log_error "Failed to remove $BIN_DIR/aether. You may need to run with sudo."
      log_warning "Please run: sudo rm -f $BIN_DIR/aether"
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
