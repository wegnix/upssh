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

# UPSSH_NO_SHELL=1 skips the `omarchy` commands (useful for testing the
# script in a temporary HOME without touching the running shell).
have_omarchy() { [[ -z ${UPSSH_NO_SHELL:-} ]] && command -v omarchy >/dev/null 2>&1; }

# Removes the generated menu entries before the command goes away. The file
# is rewritten in full (temp file in the same folder + rename, keeping the
# original mode); a dotfiles link is followed to the real file and kept.
MENU_CLEAN_PY='
import os, re, sys, tempfile

path = os.path.realpath(sys.argv[1])
text = open(path, encoding="utf-8").read()
lines = text.split("\n")
# Only deletes blocks with both an opening and a closing marker; a broken
# block leaves the file intact, so the user entries after it are not lost.
kinds = [
    "begin" if l.strip().startswith("// >>> upssh") else "end"
    for l in lines
    if l.strip().startswith(("// >>> upssh", "// <<< upssh"))
]
if not kinds:
    sys.exit(5)
if kinds != ["begin", "end"] * (len(kinds) // 2):
    sys.exit(3)
out, skip = [], False
for line in lines:
    t = line.strip()
    if t.startswith("// >>> upssh"):
        skip = True
    elif t.startswith("// <<< upssh"):
        skip = False
    elif not skip:
        out.append(line)
result = "\n".join(out)
# Without the block, a file left as just "{ }" holds nothing from the user
# and is removed — unless it is a link (dotfiles): then the target file
# belongs to the user and stays, just without our entries.
if re.sub(r"\s", "", result) == "{}" and not os.path.islink(sys.argv[1]):
    os.unlink(path)
    sys.exit(6)
mode = os.stat(path).st_mode & 0o7777
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".omarchy-menu.upssh.")
with os.fdopen(fd, "w", encoding="utf-8") as f:
    f.write(result)
os.chmod(tmp, mode)
os.replace(tmp, path)
'

if [[ -L $MENU && ! -e $MENU ]]; then
  info "$MENU is a broken link — left untouched."
elif [[ -f $MENU ]]; then
  python3 -c "$MENU_CLEAN_PY" "$MENU"
  case $? in
  0) info "Menu entries removed." ;;
  5) ;;
  6) info "Menu entries removed (the menu file held nothing else, so it was deleted)." ;;
  3) info "The upSSH block in $MENU is incomplete — file left untouched; remove the block by hand." ;;
  *) info "Could not update $MENU — file left untouched." ;;
  esac
fi
# Versions before 1.0.3 kept a copy of the menu next to it. It may hold
# user entries, so it is not deleted: we only warn about it.
[[ -f $MENU.bak ]] && info "Note: $MENU.bak was left by an older upSSH version; delete it if you do not need it."

have_omarchy && omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1

# The plugin folder is ours by construction; the command in ~/.local/bin may
# not be, so it is only removed if we can prove it belongs to us.
owns_upssh() {
  local path="$1" resolved
  [[ -e $path || -L $path ]] || return 1
  resolved=$(readlink -f "$path" 2>/dev/null) || return 1
  case "$resolved" in
  "$PLUGIN_DIR"/*) return 0 ;;
  esac
  # The marker only exists from 1.0.2 on; earlier versions are still ours
  # and are recognised by this constant, which nothing else uses.
  grep -qm1 -e "^# upssh-plugin-id: $PLUGIN_ID\$" -e '^EXPORT_MAGIC="upssh-export"$' "$resolved" 2>/dev/null
}

BIN_REMOVED=""
if [[ -e $BIN || -L $BIN ]]; then
  if owns_upssh "$BIN"; then
    rm -f "$BIN" && BIN_REMOVED=1 && info "Command removed."
  else
    info "$BIN was not installed by upSSH — left untouched."
  fi
fi

# Links created with `upssh link --name <name>` point to the plugin folder
# or to the command this script just removed; only those are removed. A
# link to a foreign `upssh` (which was kept) is not ours.
for l in "$HOME"/.local/bin/*; do
  [[ -L $l && $l != "$BIN" ]] || continue
  target=$(readlink -f "$l" 2>/dev/null) || continue
  if [[ $target == "$PLUGIN_DIR"/* || (-n $BIN_REMOVED && $target == "$BIN") ]]; then
    rm -f "$l" && info "Link removed: $l"
  fi
done

rm -rf "$PLUGIN_DIR" && info "Bar plugin removed."
have_omarchy && omarchy restart shell >/dev/null 2>&1

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
