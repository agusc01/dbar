# Repository instructions

- Write all code, comments, output, documentation and tests in English.
- Use POSIX `/bin/sh` and keep compatibility with Alpine Linux (BusyBox `ash`).
- Do not depend on Bash, Fish, Python, cron or a status-bar replacement.
- Use the existing `agusc01/dwm` X11 status colors and `xsetroot` for display.
- Keep module sampling separate from rendering and from process control.
- Do not overwrite existing user configuration or executable names.
- Avoid system-wide persistent services; launch only from a running X11 session.
- Install each Alpine package using its own `doas apk add` command with an inline English comment.
- Test shell syntax, display output, color toggles and process lifecycle before release.
