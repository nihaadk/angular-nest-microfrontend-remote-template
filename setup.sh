#!/usr/bin/env bash
#
# setup.sh — configures this cloned remote-template in place.
#
# Renames the Native Federation remote, sets FE/BE ports, updates package
# names and on-page text, and resets git history to a single fresh commit.
# Run this once, right after cloning.
#
# Usage:
#   ./setup.sh <name> [fe-port] [be-port]
#
# Example:
#   ./setup.sh orders 4202 3002
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <name> [fe-port] [be-port]

  <name>      Kebab-case name for this remote (e.g. 'orders' or
              'user-profile'). Used as: the Native Federation remote name
              (federation.config.mjs), the package name prefix, and the
              manifest key / route path a host shell will use to load it.
  [fe-port]   Dev-server port for 'ng serve' (default: 4202)
  [be-port]   Port for the NestJS backend (default: 3002)

Example:
  $(basename "$0") orders 4202 3002
EOF
  exit 1
}

[[ $# -ge 1 ]] || usage

NAME="$1"
FE_PORT="${2:-4202}"
BE_PORT="${3:-3002}"

if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: <name> must be kebab-case (a-z, 0-9, -), e.g. 'orders'." >&2
  exit 1
fi

if [[ ! "$FE_PORT" =~ ^[0-9]+$ || ! "$BE_PORT" =~ ^[0-9]+$ ]]; then
  echo "Error: ports must be numbers." >&2
  exit 1
fi

FE_DIR="$SCRIPT_DIR/fe"
BE_DIR="$SCRIPT_DIR/be"

if [[ ! -d "$FE_DIR" || ! -d "$BE_DIR" ]]; then
  echo "Error: expected fe/ and be/ next to this script (in $SCRIPT_DIR)." >&2
  exit 1
fi

# Title Case for display text, e.g. "user-profile" -> "User Profile"
# (deliberately via awk instead of sed \U/bash ${x^}: neither macOS's
# default sed nor its default bash support portable case conversion.)
DISPLAY_NAME="$(printf '%s' "$NAME" | awk -F- '{
  for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)
  print
}' OFS=' ')"

# Portable sed -i (GNU vs. BSD/macOS)
sedi() {
  local pattern="$1"; shift
  if sed --version >/dev/null 2>&1; then
    sed -i -e "$pattern" "$@"
  else
    sed -i '' -e "$pattern" "$@"
  fi
}

echo "→ Configuring remote '$NAME' (display name: '$DISPLAY_NAME', FE: $FE_PORT, BE: $BE_PORT)"

echo "→ federation.config.mjs: federation name"
sedi "s/name: 'remote-template'/name: '$NAME'/" "$FE_DIR/federation.config.mjs"

echo "→ angular.json: dev-server port"
sedi "s/\"port\": 4201/\"port\": $FE_PORT/" "$FE_DIR/angular.json"

echo "→ public/env.json: local-dev default backend URL"
sedi "s#http://localhost:3001#http://localhost:$BE_PORT#" "$FE_DIR/public/env.json"

echo "→ app.html / app.spec.ts / index.html: display text"
sedi "s/Remote Template/$DISPLAY_NAME/g" "$FE_DIR/src/app/app.html" "$FE_DIR/src/app/app.spec.ts"
sedi "s/<title>Fe<\/title>/<title>$DISPLAY_NAME<\/title>/" "$FE_DIR/src/index.html"

echo "→ package.json names (fe/be)"
sedi "s/\"name\": \"fe\"/\"name\": \"$NAME-fe\"/" "$FE_DIR/package.json"
sedi "s/\"name\": \"be\"/\"name\": \"$NAME-be\"/" "$BE_DIR/package.json"

echo "→ main.ts: port + CORS origin"
sedi "s/process.env.PORT ?? 3001/process.env.PORT ?? $BE_PORT/" "$BE_DIR/src/main.ts"
sedi "s#http://localhost:4201#http://localhost:$FE_PORT#" "$BE_DIR/src/main.ts"

echo "→ .env.example: default port + CORS origin"
sedi "s/3001/$BE_PORT/" "$BE_DIR/.env.example"
sedi "s#http://localhost:4201#http://localhost:$FE_PORT#" "$BE_DIR/.env.example"

echo "→ resetting git history to a single fresh commit"
rm -rf "$SCRIPT_DIR/.git"
git -C "$SCRIPT_DIR" init -q
git -C "$SCRIPT_DIR" add -A
git -C "$SCRIPT_DIR" commit -q -m "Initial commit: $NAME (from remote-template)"

cat <<EOF

✅ Configured as '$NAME'

Next steps:
  cd fe && npm install && npm start   # http://localhost:$FE_PORT
  cd be && npm install && npm start   # http://localhost:$BE_PORT

You can now delete this script (setup.sh) - it's done its job.

Ready for Railway: run ./railway-deploy.sh <project> to deploy this (two
services, <project>-FE/<project>-BE, via 'railway up' - no GitHub repo
needed). Reuses <project> if it already exists, creates it otherwise. See
its own comments, or README.md's Deployment section, for details.

To make a host shell load and navigate to this remote:

  1. Add it to the host's remotes manifest, e.g. the REMOTES_JSON variable
     on shell/be:
       { "$NAME": "https://<this-remote-fe-domain>/remoteEntry.json" }

  2. Add a route in the host that lazy-loads it:
       {
         path: '$NAME',
         loadComponent: () =>
           loadRemoteModule('$NAME', './Component').then((m) => m.App),
       }

  3. Add a nav entry (with a translation key in the host's i18n files):
       { labelKey: 'nav.$NAME', path: '/$NAME' }

  Note: the 'name' in fe/federation.config.mjs (already set to '$NAME') must
  exactly match the key you use in the host's manifest - Native Federation
  registers a remote under its own declared name, not the manifest key you
  request it by.
EOF
