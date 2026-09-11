#!/bin/bash
# Writes the database credentials where the gamemode can read them, then hands
# off to srcds.
#
# Credentials cannot travel as "+convar value" on the srcds command line: those
# execute against a console that does not yet know the convar, because the
# gamemode's Lua has not loaded. They would also be visible in the host's
# process list. A file in the data directory sidesteps both.
set -euo pipefail

CONFIG_DIR=/home/steam/server/garrysmod/data/axis

json_escape() {
    printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/db.json" <<JSON
{
    "host": "$(json_escape "${AXIS_DB_HOST:-mariadb}")",
    "port": ${AXIS_DB_PORT:-3306},
    "name": "$(json_escape "${AXIS_DB_NAME:-axis}")",
    "user": "$(json_escape "${AXIS_DB_USER:-axis}")",
    "pass": "$(json_escape "${AXIS_DB_PASSWORD:-}")"
}
JSON

chmod 600 "$CONFIG_DIR/db.json"

echo "[entrypoint] wrote $CONFIG_DIR/db.json (host ${AXIS_DB_HOST:-mariadb}, db ${AXIS_DB_NAME:-axis})"

exec "$@"
