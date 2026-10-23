#!/bin/sh
set -eu

# Exercise all debug-click mappings without launching a graphical terminal.
repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

mkdir -p "$fixture/bin"
cat > "$fixture/bin/st" <<'MOCK'
#!/bin/sh
[ "$1" = -e ] && [ "$2" = sh ] && [ "$3" = -c ] || exit 1
shift
exec "$@" </dev/null
MOCK
chmod +x "$fixture/bin/st"
PATH="$fixture/bin:$PATH"
export PATH

while read -r id label; do
    [ -n "$id" ] || continue
    for button in 1 2 3; do
        output=$(sh "$repository/dbar" click "$id" "$button")
        case "$output" in
            "$label"*"Press Enter to close..."*) ;;
            *)
                echo "Error: Debug terminal did not identify $label." >&2
                exit 1 ;;
        esac
        case "$button:$output" in
            1:*"Mouse button: left"*) ;;
            2:*"Mouse button: middle"*) ;;
            3:*"Mouse button: right"*) ;;
            *)
                echo 'Error: Incorrect mouse-button identification.' >&2
                exit 1 ;;
        esac
    done
done <<'MODULES'
c cpu
m ram
n wifi
b battery
l brightness
v volume
d disk
t temperature
h bluetooth
u usb
p printer
k clock
MODULES

for invalid in 'z 1' 'n 4' 'n invalid'; do
    # Arguments are intentional shell words from a fixed test fixture.
    if sh "$repository/dbar" click $invalid >/dev/null 2>&1; then
        echo 'Error: Unrecognized click action unexpectedly succeeded.' >&2
        exit 1
    fi
done

if sh "$repository/dbar" click n >/dev/null 2>&1; then
    echo 'Error: Incomplete click action unexpectedly succeeded.' >&2
    exit 1
fi

printf '%s\n' 'Debug click mappings passed.'
