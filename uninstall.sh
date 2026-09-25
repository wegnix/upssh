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
rm -rf "$PLUGIN_DIR" && info "Bar plugin removed."
rm -f "$BIN" && info "Command removed."
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
