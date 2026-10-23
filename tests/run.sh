#!/bin/sh
set -eu

# Run a smoke test against mocked X11 while using only POSIX tools.
source_repository=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
temporary_directory=$(mktemp -d)
trap 'HOME="$temporary_directory/home" DBAR_HOME="$temporary_directory/home/.config/dbar" sh "$repository/dbar" stop >/dev/null 2>&1 || :; rm -R "$temporary_directory"' 0

mkdir -p "$temporary_directory/home/.config"
mkdir -p "$temporary_directory/bin"
cp -R "$source_repository" "$temporary_directory/home/.config/dbar"
repository="$temporary_directory/home/.config/dbar"

cat > "$temporary_directory/bin/xsetroot" <<'MOCK'
#!/bin/sh
[ "$1" = -name ] || exit 1
printf '%s\n' "$2" >> "$DBAR_TEST_OUTPUT"
MOCK
chmod +x "$temporary_directory/bin/xsetroot"

cat > "$temporary_directory/bin/doas" <<'MOCK'
#!/bin/sh
[ "$1" = apk ] && [ "$2" = add ] && [ "$3" = xsetroot ]
MOCK
chmod +x "$temporary_directory/bin/doas"

unset XDG_RUNTIME_DIR XDG_CACHE_HOME || :
HOME="$temporary_directory/home"
DBAR_HOME="$HOME/.config/dbar"
DBAR_TEST_OUTPUT="$temporary_directory/output"
DISPLAY=:99
PATH="$temporary_directory/bin:$PATH"
export HOME DBAR_HOME DBAR_TEST_OUTPUT DISPLAY PATH

# All executables must parse as POSIX shell.
for script in "$repository/dbar" "$repository/install.sh" "$repository/config.sh" \
              "$repository"/lib/*.sh "$repository"/modules/*.sh \
              "$repository"/commands/*; do
    sh -n "$script"
done

# The installer must expose shell-independent commands without running apk in tests.
sh "$repository/install.sh" >/dev/null
[ -L "$HOME/.local/bin/dbar_start" ]
[ -L "$HOME/.local/bin/dbar_colors_off" ]

# The bar can preview content before X11 starts.
preview=$(sh "$repository/dbar" preview)
. "$repository/config.sh"
case "$preview" in
    *"$DBAR_CPU_ICON --"*"$DBAR_MEMORY_ICON "*"$DBAR_CLOCK_ICON "*)
        ;;
    *)
        echo 'Error: Missing expected status icons.' >&2
        exit 1
        ;;
esac

# Color modes must persist and produce distinct output.
sh "$repository/dbar" colors-off >/dev/null
[ "$(cat "$HOME/.config/dbar/color-mode")" = off ]
monochrome=$(sh "$repository/dbar" preview)
case "$monochrome" in
    "$DBAR_CPU_ICON --$DBAR_SEPARATOR$DBAR_MEMORY_ICON "*"$DBAR_SEPARATOR$DBAR_CLOCK_ICON "[0-9][0-9]:[0-9][0-9])
        ;;
    *)
        echo 'Error: Unexpected monochrome status formatting.' >&2
        exit 1
        ;;
esac

# Monochrome mode must not emit control bytes, including color reset codes.
if printf '%s' "$monochrome" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome mode contains control bytes.' >&2
    exit 1
fi

sh "$repository/dbar" colors-on >/dev/null
colored=$(sh "$repository/dbar" preview)
[ "$monochrome" != "$colored" ]

# Colored mode must keep using the custom dwm control-byte palette.
if ! printf '%s' "$colored" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Colored mode has no color control bytes.' >&2
    exit 1
fi

# An earlier session may leave an empty lock and a dead PID behind.
mkdir -p "$HOME/.cache/dbar/lock"
printf '%s\n' '99999999' > "$HOME/.cache/dbar/dbar.pid"

# Launch the daemon, recover the abandoned lock, and reuse the active PID.
"$repository/commands/dbar_start" >/dev/null
[ "$(cat "$HOME/.cache/dbar/dbar.pid")" != 99999999 ]
sh "$repository/dbar" status >/dev/null
pid_before=$(cat "$HOME/.cache/dbar/dbar.pid")
"$repository/commands/dbar_start" >/dev/null
pid_after=$(cat "$HOME/.cache/dbar/dbar.pid")
[ "$pid_before" = "$pid_after" ]
[ -s "$DBAR_TEST_OUTPUT" ]

# Switching modes must trigger an immediate new root-window status value.
lines_before=$(wc -l < "$DBAR_TEST_OUTPUT")
"$repository/commands/dbar_colors_off" >/dev/null
sleep 2
sh "$repository/dbar" status >/dev/null
lines_after=$(wc -l < "$DBAR_TEST_OUTPUT")
[ "$lines_after" -gt "$lines_before" ]
"$repository/commands/dbar_colors_on" >/dev/null
"$repository/commands/dbar_refresh" >/dev/null
sleep 2
sh "$repository/dbar" status >/dev/null

# Stop and wait for the PID file and lock to disappear.
"$repository/commands/dbar_stop" >/dev/null
sleep 2
[ ! -f "$HOME/.cache/dbar/dbar.pid" ]
[ ! -d "$HOME/.cache/dbar/lock" ]

if sh "$repository/dbar" status >/dev/null 2>&1; then
    echo 'Error: dbar still appears to be running.' >&2
    exit 1
fi

# A nonempty lock is never erased, even if no dbar process is active.
mkdir -p "$HOME/.cache/dbar/lock"
printf 'preserve\n' > "$HOME/.cache/dbar/lock/protected"
if sh "$repository/dbar" run >/dev/null 2>&1; then
    echo 'Error: dbar started despite a nonempty runtime lock.' >&2
    exit 1
fi
[ "$(cat "$HOME/.cache/dbar/lock/protected")" = preserve ]
rm -v "$HOME/.cache/dbar/lock/protected"
rmdir -v "$HOME/.cache/dbar/lock"

printf '%s\n' 'All dbar smoke tests passed.' 
