#!/bin/sh
# Writes /app/browser/env.json from the BE_URL environment variable right
# before serving, so the same built image can point at different backends
# per environment/deploy without a rebuild - just change the Railway
# variable and restart.
set -eu

BE_URL="${BE_URL:-}"

cat > /app/browser/env.json <<EOF
{"beUrl":"${BE_URL}"}
EOF

# --cors: this is a Native Federation *remote* - a host shell on a different
# origin loads remoteEntry.json and the exposed component's JS via import(),
# which needs CORS-enabled responses to succeed cross-origin.
exec serve -s /app/browser -l "${PORT:-4201}" --cors
