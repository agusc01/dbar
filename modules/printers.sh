#!/bin/sh

PRINTER_COUNT=0
PRINTER_JOBS=0

# Read configured CUPS printers and non-completed jobs without making changes.
update_printers() {
    PRINTER_COUNT=0
    PRINTER_JOBS=0

    printer_command=${DBAR_LPSTAT:-lpstat}
    command -v "$printer_command" >/dev/null 2>&1 || return 0

    # Alpine BusyBox provides timeout; avoid blocking dbar on CUPS outages.
    printer_timeout=${DBAR_TIMEOUT:-timeout}
    command -v "$printer_timeout" >/dev/null 2>&1 || return 0

    printer_list=$(LC_ALL=C "$printer_timeout" 2 "$printer_command" -p 2>/dev/null) ||
        return 0

    PRINTER_COUNT=$(printf '%s\n' "$printer_list" | awk '
        $1 == "printer" && NF >= 2 { count++ }
        END { print count + 0 }
    ')
    [ "$PRINTER_COUNT" -gt 0 ] || return 0

    # Keep the printer icon if the queue cannot be read.
    printer_queue=$(LC_ALL=C "$printer_timeout" 2 "$printer_command" \
        -W not-completed -o 2>/dev/null) || return 0

    PRINTER_JOBS=$(printf '%s\n' "$printer_queue" | awk '
        NF > 0 { count++ }
        END { print count + 0 }
    ')
}
