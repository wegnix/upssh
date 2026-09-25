#!/bin/bash

# Removes upSSH. Your servers and the password vault are kept unless you
# explicitly ask for them to go.

set -uo pipefail

PLUGIN_ID="io.github.wegnix.upssh"
BIN="$HOME/.local/bin/upssh"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
DATA_DIR="$HOME/.config/upssh"
MENU="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

info() { printf '  %s\n' "$*"; }

# Tira as entradas geradas do menu antes de o comando desaparecer.
if [[ -f $MENU ]]; then
  python3 - "$MENU" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
out, skip = [], False
for line in p.read_text(encoding="utf-8").split("\n"):
    if line.strip().startswith("// >>> upssh"): skip = True; continue
    if line.strip().startswith("// <<< upssh"): skip = False; continue
    if not skip: out.append(line)
p.write_text("\n".join(out), encoding="utf-8")
PYEOF
  info "Menu entries removed."
fi

command -v omarchy >/dev/null 2>&1 && omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1
# A pasta do plugin é nossa por construção; o comando em ~/.local/bin pode
# não ser, por isso só sai se provarmos que nos pertence.
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

if [[ -e $BIN || -L $BIN ]]; then
  if owns_upssh "$BIN"; then
    rm -f "$BIN" && info "Command removed."
  else
    info "$BIN was not installed by upSSH — left untouched."
  fi
fi

rm -rf "$PLUGIN_DIR" && info "Bar plugin removed."
command -v omarchy >/dev/null 2>&1 && omarchy restart shell >/dev/null 2>&1

if [[ -d $DATA_DIR ]]; then
  echo
  info "Your servers and password vault are still in $DATA_DIR"
  if [[ -t 0 ]]; then
    read -rp "  Delete them too? This cannot be undone. (y/N) " a
    [[ ${a,,} == y* ]] && rm -rf "$DATA_DIR" && info "Data deleted."
  fi
fi

echo
info "upSSH uninstalled."
