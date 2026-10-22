#!/bin/sh
set -eu

# X11 status publisher.
doas apk add xsetroot  # Update the dwm status bar through the X root window name.

# Install user commands without replacing existing entries.
source_directory="$HOME/.config/dbar/commands"
binary_directory="$HOME/.local/bin"
mkdir -vp "$binary_directory"

for command in \
    dbar_start dbar_stop dbar_restart dbar_status \
    dbar_refresh dbar_colors_on dbar_colors_off; do
    source_file="$source_directory/$command"
    destination_file="$binary_directory/$command"
    if [ ! -f "$source_file" ]; then
        echo "Error: Missing command: $source_file" >&2
        exit 1
    fi
    if [ -e "$destination_file" ] || [ -L "$destination_file" ]; then
        echo "Existing command preserved: $destination_file"
        continue
    fi
    ln -sv "$source_file" "$destination_file"
done

case ":$PATH:" in
    *":$binary_directory:"*) ;;
    *)
        echo "Note: Add $binary_directory to your shell PATH to use dbar_* commands."
        echo 'For Fish: fish_add_path -U ~/.local/bin'
        ;;
esac

echo 'dbar installed. Run dbar_start from a dwm terminal.'
