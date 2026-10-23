# dbar

Lightweight X11 status bar for [agusc01/dwm](https://github.com/agusc01/dwm), written in POSIX `sh` for Alpine Linux. It shows CPU, memory, network, optional battery, ALSA playback volume, root disk usage and clock and supports colored or monochrome status. Monochrome mode emits plain text without any embedded color codes.

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

Example: ` 15% | 󰍛 40% | 󰖩 | 󰁹 85% |  14:45` (Wi-Fi and battery) or ` 15% | 󰍛 40% | 󰈀 |  14:45` (Ethernet, no battery). Network indicates the default routed interface and physical link, not verified Internet access. Battery is hidden when absent and reads the first available battery. The modules use `/proc/net/route`, `/proc/net/ipv6_route`, and `/sys/class` without network requests. Network and battery refresh independently; configure intervals and thresholds in `config.sh`. Muted or zero-volume ALSA playback displays only the `󰖁` icon (no text or percentage); systems with no usable ALSA playback control omit volume entirely. The disk percentage comes from `df -P /`, with orange at 75% and red at 90%. Volume refreshes every 5 seconds and disk every 60 seconds. The Nerd Font icons and the ` | ` separator can be customized in `config.sh`. Install a Nerd Font to display the symbols; `init-alpine` already installs `font-ubuntu-nerd`. The color sequences are designed for the custom `agusc01/dwm` statuscolors patch. Module sample intervals and thresholds are in `config.sh`; its CPU module uses `/proc/stat` and memory uses `/proc/meminfo`. Runtime files live in `${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/dbar`. If a session ends abruptly, startup can recover an empty, unchanged, abandoned lock after a short safety check. A live process or nonempty lock is never removed automatically; inspect `dbar.log` if startup still fails.

## Tests

```sh
sh tests/run.sh
```

Tests use a mocked `xsetroot` and simulated network routes, power supply entries, ALSA mixer responses and disk usage, and do not require a graphical session.
