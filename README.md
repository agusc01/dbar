# dbar

Lightweight X11 status bar for [agusc01/dwm](https://github.com/agusc01/dwm), written in POSIX `sh` for Alpine Linux. It shows CPU, memory, network, optional battery, ALSA playback volume, root disk usage, optional CPU temperature, Bluetooth status, optional screen brightness and clock and supports colored or monochrome status. Monochrome mode emits plain text without any embedded color codes.

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

Temperature reads CPU-specific sensors from `/sys/class/hwmon` or CPU thermal zones, hides unavailable sensors (as on many virtual machines), and turns orange at 70°C or red at 85°C by default. Bluetooth uses the existing BlueZ installation and is hidden without an adapter. Powered off shows only red `󰂲`; powered on shows green `󰂯`, adding a number only if one or more devices are connected (e.g. `󰂯 2`). Connected means currently connected, not merely paired; BlueZ commands use a two-second timeout each. Temperature refreshes every 10 seconds and Bluetooth every 15 seconds. No additional packages or daemons are required.

Brightness displays as `󰃠 75%` between battery and ALSA volume, using the first readable backlight in `/sys/class/backlight`. It prefers `actual_brightness` and falls back to `brightness`, rounds to a whole percent, and is hidden when no valid backlight is present (as may happen in virtual machines). Low brightness is not an alert, so this segment has no warning colors. It refreshes every 5 seconds. No new packages or daemons are needed.

## Temporary per-segment click debugging

This feature requires the companion `agusc01/dwm` segment-click changes. The root-window status contains invisible `@{x}` module markers that dwm removes before drawing. `dbar preview` remains ordinary, untagged text. Colored and monochrome status both support clicks. Only visible segments receive click targets.

Click a segment with the left, middle or right mouse button to open `st`, print the identified module and button, and keep the terminal open until Enter is pressed. No system settings are changed. The mouse wheel is deliberately not bound, so scrolling cannot open a flood of terminals.

The temporary module IDs are `c=cpu`, `m=ram`, `n=wifi` (network), `b=battery`, `l=brightness`, `v=volume`, `d=disk`, `t=temperature`, `h=bluetooth`, and `k=clock`. The network segment keeps the stable `n` ID when switching between Wi-Fi, Ethernet and offline status. To test the dispatcher manually from X11, run `sh ~/.config/dbar/dbar click n 1`. The window prints `wifi` and `Mouse button: left`. These are *diagnostic placeholders*; configurable actions will be added later.

Install the updated dwm fork before enabling this dbar branch. Older dwm versions do not recognize module markers and may display them literally. The exact text width and hit boxes are calculated by the same new dwm parser.

## Tests

```sh
sh tests/run.sh
```

Tests use a mocked `xsetroot` and simulated network routes, power supply entries, ALSA mixer responses, disk usage, CPU sensor files, Bluetooth states backlight readings, and mocked debug-click terminals, and do not require a graphical session. The tests copy only the required runtime files to isolated temporary directories (never `.git`), clean them up without interactive deletion prompts, and preserve the checkout's `color-mode` setting.
