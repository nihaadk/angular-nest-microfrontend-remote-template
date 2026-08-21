# Standalone static Angular build (a Native Federation remote). Deploy as
# its own Railway service with this directory (fe/) as the root - separate
# from be/.
#
# Relevant Railway variables on this service:
#   PORT     set automatically by Railway
#   BE_URL   e.g. https://<this-remote>-be.up.railway.app (no trailing slash)
#            Tip: reference the be service directly instead of hardcoding:
#            BE_URL=https://${{be.RAILWAY_PUBLIC_DOMAIN}}
#
# Once deployed, add this remote to the host shell's REMOTES_JSON:
#   { "<name>": "https://<this-service-domain>/remoteEntry.json" }

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
RUN npm install -g serve@14
COPY --from=build /app/dist/fe/browser ./browser
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

ENV PORT=4201
EXPOSE 4201
ENTRYPOINT ["./docker-entrypoint.sh"]
