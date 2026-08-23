#!/usr/bin/env bash
#
# railway-deploy.sh — deploys this configured remote to a Railway project
# as two services, named after the project: <project>-FE and <project>-BE.
#
# Run this AFTER setup.sh has already configured fe/ and be/.
#
# Uses `railway up`, which uploads a directory straight to Railway and
# builds it there - no GitHub repo, no push needed. Run from inside fe/ or
# be/, that also means there's no separate "Root Directory" / "Dockerfile
# Path" to configure or get out of sync (a bug hit twice deploying this
# project's own shell/remote-template by hand).
#
# Safe to re-run: checks what already exists (project, each service, each
# domain) before creating anything, so you can use this again later to
# redeploy after code changes, or to add the shell URL once you know it.
#
# Usage:
#   ./railway-deploy.sh <project> [shell-fe-url]
#
#   <project>       Railway project to deploy into. If a project with this
#                   exact name already exists in your account, it's reused
#                   (services are added to it); otherwise a new project
#                   with this name is created. Case is preserved as given -
#                   e.g. <project>=REMOTE-2 creates/uses services named
#                   REMOTE-2-FE and REMOTE-2-BE.
#   [shell-fe-url]  Optional - the host shell's public frontend URL (e.g.
#                   https://my-shell-fe.up.railway.app). If given, it's
#                   added to this remote's backend CORS_ORIGINS, since the
#                   remote's component runs inside the shell's page once
#                   embedded and its fetch calls carry the shell's origin.
#
# Example:
#   ./railway-deploy.sh REMOTE-2 https://my-shell-fe.up.railway.app
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FE_DIR="$SCRIPT_DIR/fe"
BE_DIR="$SCRIPT_DIR/be"

usage() {
  cat <<EOF
Usage: $(basename "$0") <project> [shell-fe-url]

  <project>       Railway project to deploy into - reused if it already
                   exists, created otherwise. Services are named
                   <project>-FE and <project>-BE (case preserved).
  [shell-fe-url]  Optional host shell frontend URL, added to CORS_ORIGINS.

Example:
  $(basename "$0") REMOTE-2 https://my-shell-fe.up.railway.app
EOF
  exit 1
}

[[ $# -ge 1 ]] || usage

PROJECT_NAME="$1"
SHELL_FE_URL="${2:-}"
FE_SERVICE="${PROJECT_NAME}-FE"
BE_SERVICE="${PROJECT_NAME}-BE"

command -v railway >/dev/null 2>&1 || {
  echo "Error: Railway CLI not found. Install: https://docs.railway.com/guides/cli" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "Error: python3 is required (used to parse Railway CLI JSON output)." >&2
  exit 1
}
railway whoami >/dev/null 2>&1 || {
  echo "Error: not logged in to Railway. Run 'railway login' first." >&2
  exit 1
}
if [[ ! -d "$FE_DIR" || ! -d "$BE_DIR" ]]; then
  echo "Error: expected fe/ and be/ next to this script (in $SCRIPT_DIR)." >&2
  exit 1
fi

# The federation name (set by setup.sh) is only needed for the REMOTES_JSON
# line printed at the end - independent of the Railway project/service
# names, which come from $PROJECT_NAME instead.
FEDERATION_NAME="$(sed -n "s/.*name: '\([^']*\)'.*/\1/p" "$FE_DIR/federation.config.mjs" | head -1)"
if [[ -z "$FEDERATION_NAME" ]]; then
  echo "Error: could not read the remote's name from fe/federation.config.mjs." >&2
  exit 1
fi

echo "→ Deploying to Railway project '$PROJECT_NAME' ($FE_SERVICE + $BE_SERVICE)"

# --- Resolve or create the project ------------------------------------------
LIST_JSON="$(railway list --json)"
PROJECT_ID="$(echo "$LIST_JSON" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    if p['name'] == '$PROJECT_NAME' and not p.get('deletedAt'):
        print(p['id'])
        break
")"

if [[ -n "$PROJECT_ID" ]]; then
  echo "→ Project '$PROJECT_NAME' already exists, reusing it"
  ENVIRONMENT_ID="$(echo "$LIST_JSON" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    if p['id'] == '$PROJECT_ID':
        print(p['environments']['edges'][0]['node']['id'])
        break
")"
else
  echo "→ Project '$PROJECT_NAME' doesn't exist yet, creating it and deploying $BE_SERVICE"
  (cd "$BE_DIR" && railway up --new -y --name "$PROJECT_NAME" --service "$BE_SERVICE" .)
  LIST_JSON="$(railway list --json)"
  PROJECT_ID="$(echo "$LIST_JSON" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    if p['name'] == '$PROJECT_NAME' and not p.get('deletedAt'):
        print(p['id'])
        break
")"
  ENVIRONMENT_ID="$(echo "$LIST_JSON" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    if p['id'] == '$PROJECT_ID':
        print(p['environments']['edges'][0]['node']['id'])
        break
")"
fi

echo "→ Project: $PROJECT_ID"

# --- Ensure both services exist, then (re)deploy each -----------------------
service_exists() {
  railway status --json --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
names = [s['node']['serviceName'] for e in d['environments']['edges'] for s in e['node']['serviceInstances']['edges']]
print('$1' in names)
"
}
deploy_service() {
  local service="$1" dir="$2"
  if [[ "$(service_exists "$service")" != "True" ]]; then
    echo "→ Creating $service"
    railway add --service "$service" --project "$PROJECT_ID" --json >/dev/null
  fi
  echo "→ Deploying $service"
  (cd "$dir" && railway up -y --service "$service" --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" .)
}

# BE_SERVICE may already be deployed above as part of creating a new
# project - deploying it again here is harmless (just a redeploy) and keeps
# this path identical whether the project was just created or already
# existed.
deploy_service "$BE_SERVICE" "$BE_DIR"
deploy_service "$FE_SERVICE" "$FE_DIR"

# --- Domains ------------------------------------------------------------------
# Deliberately NOT passing --port to `railway domain`: an explicit target
# port broke Railway's in-container port auto-detection for this exact
# template (502 "Application failed to respond"), fixed by recreating
# domains without one. Let Railway detect it.
get_domain() {
  railway domain list --service "$1" --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" --json 2>/dev/null \
    | python3 -c 'import json,sys; d=json.load(sys.stdin).get("domains",[]); print(d[0]["domain"] if d else "")'
}
ensure_domain() {
  local service="$1"
  local domain
  domain="$(get_domain "$service")"
  if [[ -z "$domain" ]]; then
    echo "→ Generating a domain for $service" >&2
    domain="$(railway domain --service "$service" --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" --json \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["domain"].replace("https://",""))')"
  fi
  echo "$domain"
}

BE_DOMAIN="$(ensure_domain "$BE_SERVICE")"
FE_DOMAIN="$(ensure_domain "$FE_SERVICE")"

# --- Variables ------------------------------------------------------------------
CORS_ORIGINS="https://$FE_DOMAIN"
if [[ -n "$SHELL_FE_URL" ]]; then
  CORS_ORIGINS="$CORS_ORIGINS,$SHELL_FE_URL"
fi

railway variable set "BE_URL=https://$BE_DOMAIN" \
  --service "$FE_SERVICE" --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" --json >/dev/null
railway variable set "CORS_ORIGINS=$CORS_ORIGINS" \
  --service "$BE_SERVICE" --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID" --json >/dev/null

cat <<EOF

✅ Deployed to Railway project '$PROJECT_NAME'

  Frontend ($FE_SERVICE): https://$FE_DOMAIN
  Backend  ($BE_SERVICE): https://$BE_DOMAIN

Add this to the host shell's REMOTES_JSON variable:

  {"$FEDERATION_NAME":"https://$FE_DOMAIN/remoteEntry.json"}
EOF

if [[ -z "$SHELL_FE_URL" ]]; then
  cat <<EOF

Note: no shell URL was given, so $BE_SERVICE's CORS_ORIGINS only allows
$FE_SERVICE's own origin. Once you know the shell's public FE URL, re-run:
  ./railway-deploy.sh $PROJECT_NAME https://<shell-fe-domain>
EOF
fi
