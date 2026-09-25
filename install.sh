#!/bin/bash

# upSSH installer — copies the command and the Omarchy bar plugin into place,
# enables the widget and syncs the menu. Safe to re-run: it upgrades over an
# existing install and never touches ~/.config/upssh (your servers and vault).

set -uo pipefail

PLUGIN_ID="io.github.wegnix.upssh"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
DATA_DIR="$HOME/.config/upssh"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  %s\033[0m\n' "$*"; }
fail() { printf '\033[31m  %s\033[0m\n' "$*" >&2; }

bold "upSSH installer"
echo

# ------------------------------------------------------------- dependências
missing=()
for c in bash jq gum ssh gpg python3 column; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if ((${#missing[@]})); then
  fail "Missing required commands: ${missing[*]}"
  info "On Omarchy / Arch:  sudo pacman -S --needed ${missing[*]}"
  exit 1
fi

optional=()
command -v sshpass >/dev/null 2>&1 || optional+=(sshpass)
command -v zenity >/dev/null 2>&1 || optional+=(zenity)
if ((${#optional[@]})); then
  warn "Optional commands missing: ${optional[*]}"
  info "sshpass → password logins · zenity → file dialogs in the panel"
  info "Install with:  sudo pacman -S --needed ${optional[*]}"
  echo
fi

command -v omarchy-shell >/dev/null 2>&1 || {
  warn "omarchy-shell not found — installing the command only, without the bar widget."
  NO_SHELL=1
}

# -------------------------------------------------------------------- ficheiros
install -Dm755 "$SRC/bin/upssh" "$BIN_DIR/upssh"
info "command   → $BIN_DIR/upssh"

if [[ -z ${NO_SHELL:-} ]]; then
  mkdir -p "$PLUGIN_DIR"
  install -Dm644 "$SRC/plugin/manifest.json" "$PLUGIN_DIR/manifest.json"
  install -Dm644 "$SRC/plugin/UpsshPanel.qml" "$PLUGIN_DIR/UpsshPanel.qml"
  info "bar plugin → $PLUGIN_DIR"
fi

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
info "data      → $DATA_DIR (untouched if it already existed)"

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) warn "$BIN_DIR is not on your PATH — add it to your shell profile." ;;
esac

# --------------------------------------------------------------------- idioma
echo
if [[ -t 0 ]]; then
  read -rp "  Language / Idioma — [e]nglish or [p]ortuguês? (e/p) " answer
  case "${answer,,}" in
  p*) "$BIN_DIR/upssh" lang pt >/dev/null && info "Language set to Portuguese." ;;
  e*) "$BIN_DIR/upssh" lang en >/dev/null && info "Language set to English." ;;
  *) info "Keeping the language detected from \$LANG." ;;
  esac
fi

# ---------------------------------------------------------------------- shell
if [[ -z ${NO_SHELL:-} ]]; then
  echo
  omarchy-shell shell rescanPlugins >/dev/null 2>&1
  sleep 1
  if omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1; then
    info "Widget enabled in the bar."
  else
    warn "Could not enable the widget automatically."
    info "Run:  omarchy plugin enable $PLUGIN_ID"
  fi
  # O qmlcache do Quickshell guarda o caminho anterior de um ficheiro .qml
  # renomeado; um restart limpa-o e evita um falso "File name case mismatch".
  omarchy restart shell >/dev/null 2>&1 || true
fi

"$BIN_DIR/upssh" menu-sync >/dev/null 2>&1 && info "Omarchy menu synced."

echo
bold "Done."
info "Run 'upssh' for the terminal UI, or click the upSSH icon in the bar."
info "Super → type 'ssh' opens the menu with your servers."
echo
