# dbar

Lightweight X11 status bar for [agusc01/dwm](https://github.com/agusc01/dwm), written in POSIX `sh` for Alpine Linux. It shows CPU, memory and clock and supports colored or monochrome status. Monochrome mode emits plain text without any embedded color codes.

## Install

```sh
git clone https://github.com/agusc01/dbar ~/.config/dbar
sh ~/.config/dbar/install.sh
```

The installer installs the Alpine `xsetroot` package and adds shell-independent commands as symlinks in `~/.local/bin`, without replacing existing names. If that directory is not on your PATH, add it once, for example in Fish: `fish_add_path -U ~/.local/bin`.

## Use

Run from a terminal inside dwm:

```sh
dbar_start
dbar_status
dbar_colors_off
dbar_colors_on
dbar_refresh
dbar_restart
dbar_stop
```

The color mode is stored in `~/.config/dbar/color-mode` and survives restarts. Commands do not depend on Fish or Bash. The companion `init-alpine` configuration starts the bar automatically after installing it; `dbar` itself can also be started or stopped manually.

You can test output in a plain terminal using `sh ~/.config/dbar/dbar preview`.

The compact status is `CPU 15% · RAM 40% · 14:45` (example values). The color sequences are designed for the custom `agusc01/dwm` statuscolors patch. Module sample intervals and thresholds are in `config.sh`; its CPU module uses `/proc/stat` and memory uses `/proc/meminfo`. Runtime files live in `${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/dbar`. If a session ends abruptly, startup can recover an empty, unchanged, abandoned lock after a short safety check. A live process or nonempty lock is never removed automatically; inspect `dbar.log` if startup still fails.

## Tests

```sh
sh tests/run.sh
```

Tests use a mocked `xsetroot` and do not require a graphical session.
