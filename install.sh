#!/bin/bash

# upSSH installer — copies the command and the Omarchy bar plugin into place,
# enables the widget and syncs the menu. Safe to re-run: it upgrades over an
# existing install and never touches your servers or vault in ~/.config/upssh
# (it only creates that folder, mode 700, when it does not exist yet).

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
for c in bash jq gum ssh gpg python3 column flock; do
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

# Quem instalou com `omarchy plugin add` tem na pasta do plugin um clone git
# gerido pelo Omarchy. Copiar ficheiros por cima sujava esse clone e partia o
# `omarchy plugin update`; nesse caso é esse o caminho de actualização.
SELF_INSTALL=""
if [[ $(readlink -f "$SRC") == "$(readlink -f "$PLUGIN_DIR" 2>/dev/null)" ]]; then
  SELF_INSTALL=1
elif [[ -d $PLUGIN_DIR/.git ]]; then
  fail "$PLUGIN_DIR is a git clone managed by 'omarchy plugin add'."
  info "Update it with:  omarchy plugin update $PLUGIN_ID"
  info "or run this installer from that folder:  $PLUGIN_DIR/install.sh"
  exit 1
fi

put() {
  install -Dm"$1" "$2" "$3" || { fail "Could not write $3 — installation stopped."; exit 1; }
}

# -------------------------------------------------------------------- ficheiros
# Nunca escrever por cima de um comando que não é nosso: um `upssh` alheio
# em ~/.local/bin fica intacto e o widget continua a funcionar sem ele.
owns_upssh() {
  local path="$1" resolved
  [[ -e $path || -L $path ]] || return 1
  resolved=$(readlink -f "$path" 2>/dev/null) || return 1
  case "$resolved" in
  "$PLUGIN_DIR"/*) return 0 ;;
  esac
  # O marcador só existe a partir da 1.0.2; as versões anteriores são nossas
  # na mesma e reconhecem-se por esta constante, que mais nada usa.
  grep -qm1 -e "^# upssh-plugin-id: $PLUGIN_ID\$" -e '^EXPORT_MAGIC="upssh-export"$' "$resolved" 2>/dev/null
}

if [[ -e $BIN_DIR/upssh || -L $BIN_DIR/upssh ]] && ! owns_upssh "$BIN_DIR/upssh"; then
  LINK_SKIPPED=1
  warn "$BIN_DIR/upssh already exists and was not installed by upSSH — left untouched."
  info "The bar widget and the Omarchy menu do not need it."
  info "For the terminal UI, run the bundled copy or pick another name:"
  info "  $PLUGIN_DIR/bin/upssh"
  info "  $PLUGIN_DIR/bin/upssh link --name upssh-plugin"
else
  put 755 "$SRC/bin/upssh" "$BIN_DIR/upssh"
  info "command   → $BIN_DIR/upssh"
fi

if [[ -z ${NO_SHELL:-} ]]; then
  if [[ -n $SELF_INSTALL ]]; then
    info "bar plugin → $PLUGIN_DIR (already in place)"
  else
    put 644 "$SRC/manifest.json" "$PLUGIN_DIR/manifest.json"
    put 644 "$SRC/UpsshPanel.qml" "$PLUGIN_DIR/UpsshPanel.qml"
    put 755 "$SRC/bin/upssh" "$PLUGIN_DIR/bin/upssh"
    info "bar plugin → $PLUGIN_DIR"
  fi
fi

if [[ -d $DATA_DIR ]]; then
  info "data      → $DATA_DIR (existing, left as is)"
else
  mkdir -m 700 -p "$DATA_DIR" || { fail "Could not create $DATA_DIR"; exit 1; }
  info "data      → $DATA_DIR (created, mode 700)"
fi

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) warn "$BIN_DIR is not on your PATH — add it to your shell profile." ;;
esac

UPSSH_CMD="$BIN_DIR/upssh"
[[ -n ${LINK_SKIPPED:-} ]] && UPSSH_CMD="$PLUGIN_DIR/bin/upssh"
# Sem shell do Omarchy e com um `upssh` alheio no PATH não há cópia nossa
# para correr: o idioma e o menu ficam para quando houver.
[[ -x $UPSSH_CMD ]] || UPSSH_CMD=""

# --------------------------------------------------------------------- idioma
echo
if [[ -t 0 && -n $UPSSH_CMD ]]; then
  read -rp "  Language / Idioma — [e]nglish or [p]ortuguês? (e/p) " answer
  case "${answer,,}" in
  p*) "$UPSSH_CMD" lang pt >/dev/null && info "Language set to Portuguese." ;;
  e*) "$UPSSH_CMD" lang en >/dev/null && info "Language set to English." ;;
  *) info "Keeping the language detected from \$LANG." ;;
  esac
fi

# ---------------------------------------------------------------------- shell
# UPSSH_NO_SHELL=1 salta os comandos `omarchy` (útil para testar o instalador
# num HOME temporário sem mexer no shell que está a correr).
if [[ -z ${NO_SHELL:-} && -z ${UPSSH_NO_SHELL:-} ]]; then
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

if [[ -n $UPSSH_CMD ]]; then
  if "$UPSSH_CMD" menu-sync >/dev/null; then
    info "Omarchy menu synced."
  else
    warn "The Omarchy menu was not updated (see the message above)."
  fi
fi

echo
bold "Done."
if [[ -z $UPSSH_CMD ]]; then
  info "Nothing runnable was installed: without omarchy-shell there is no bar plugin,"
  info "and $BIN_DIR/upssh belongs to another program. Remove or rename it and re-run."
elif [[ -n ${LINK_SKIPPED:-} ]]; then
  info "Click the upSSH icon in the bar, or run $PLUGIN_DIR/bin/upssh for the terminal UI."
else
  info "Run 'upssh' for the terminal UI, or click the upSSH icon in the bar."
fi
[[ -n $UPSSH_CMD ]] && info "Super → type 'ssh' opens the menu with your servers."
echo
