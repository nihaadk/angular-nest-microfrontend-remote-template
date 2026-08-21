# Standalone NestJS API for this remote. Deploy as its own Railway service
# with this directory (be/) as the root - separate from fe/.
#
# Relevant Railway variables on this service:
#   PORT           set automatically by Railway
#   CORS_ORIGINS   comma-separated, e.g. https://<this-remote>-fe.up.railway.app

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist

CMD ["node", "dist/main.js"]
