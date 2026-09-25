# upSSH

SSH access manager for [Omarchy](https://omarchy.org/). Your servers organised
in groups, reachable from the bar, the Omarchy menu or a terminal UI — with
passwords kept in a GPG-encrypted vault instead of a shell script's comments.

Available in **English** and **Portuguese**.

![The upSSH panel in the Omarchy bar](docs/panel.png)

> The servers above are fictional. `docs/demo-servers.json` holds them, so
> screenshots never carry real hosts.

## What it does

- **Groups** — organise servers however you work: internal, external, customers.
- **Key or password login** — passwords live in an AES-256 GPG vault unlocked by
  one master password, cached by `gpg-agent` so you type it once per session.
  They reach `ssh` through an environment variable scoped to that one command,
  never through `argv`, so they never show up in `ps`.
- **First connection** shows you the host key fingerprint and asks before
  saving it to `known_hosts`, instead of failing silently under `sshpass`.
- **Three ways in** — a bar widget with a searchable panel, the Omarchy menu
  (`Super`, then type `ssh`), or `upssh` in a terminal.
- **Import / export** — plain JSON to share a server list, or an encrypted
  `.gpg` bundle (with passwords) to move to another machine.

## Install

From the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/wegnix/upssh.git --enable
~/.config/omarchy/plugins/io.github.wegnix.upssh/bin/upssh link
```

The second line puts `upssh` on your `PATH` so the terminal UI works too. The
bar widget and the Omarchy menu work without it — they call the copy that ships
inside the plugin folder, by absolute path.

If `~/.local/bin/upssh` already exists and was not installed by upSSH, nothing
is overwritten: `link` refuses and offers `--name`, the installer says so and
carries on, and the uninstaller leaves that file alone.

Or clone and run the installer, which does both in one step:

```bash
git clone https://github.com/wegnix/upssh.git
cd upssh
./install.sh
```

Re-running the installer upgrades in place and never touches your data.

**Required:** `bash`, `jq`, `gum`, `openssh`, `gnupg`, `python3` — all already present on a stock Omarchy.
**Optional:** `sshpass` for password logins, `zenity` for the panel's file dialogs.

```bash
sudo pacman -S --needed sshpass zenity
```

## Use

| Where | How |
|---|---|
| Bar | Click the upSSH icon · right click syncs the menu |
| Menu | `Super`, then `ssh` |
| Terminal | `upssh` |

```
upssh                       Terminal UI: group → server → connect
upssh connect <id>          Connect straight to a server
upssh add | edit | remove   Manage servers
upssh passwd                Set or change a server password
upssh export [--with-passwords] [file]
upssh import <file> [--on-conflict substituir|manter|copiar]
upssh lang [pt|en]          Show or change the language
upssh master                Change the vault master password
```

## Where things live

```
~/.local/bin/upssh                                command
~/.config/omarchy/plugins/io.github.wegnix.upssh  bar widget + bundled command
~/.config/upssh/servers.json                      servers, no passwords
~/.config/upssh/secrets.gpg                       passwords, AES-256
~/.config/upssh/config.json                       preferences (language)
```

The Omarchy menu entries are generated into a marked block inside
`~/.config/omarchy/extensions/omarchy-menu.jsonc`. Everything outside that block
is left alone, and the block is rewritten on every change — don't edit it by hand.

## About the vault

`secrets.gpg` is a symmetrically encrypted OpenPGP file: AES-256, salted and
iterated s2k, SHA-512. The master password is **not stored anywhere** — lose it
and the server passwords are gone, which is the point.

Reads go through `gpg-agent`, so the master password lives in the agent's
locked memory (never swapped) rather than in this script. Set the cache
lifetime in `~/.gnupg/gpg-agent.conf`:

```
default-cache-ttl 3600
max-cache-ttl 28800
```

The vault protects your passwords at rest. It does not protect them from
someone at your unlocked session — no more than your SSH keys do.

## Uninstall

```bash
./uninstall.sh
```

Removes the command, the widget and the menu entries. It asks separately before
deleting your servers and vault.

## License

MIT © Wesley Farias
