# syntax=docker/dockerfile:1
# Build always runs on the builder CPU (amd64 on GitHub Actions).
# Target-arch prod deps are downloaded via npm --cpu/--os (no QEMU node execution).
FROM --platform=$BUILDPLATFORM node:20-bookworm-slim AS build

ARG TARGETARCH
WORKDIR /app

COPY package*.json ./
COPY web/package*.json ./web/
RUN npm ci && npm --prefix web ci

COPY tsconfig.json ./
COPY src ./src
COPY web ./web
RUN npm run build:all

# Reinstall production deps for the image target architecture without emulating it.
RUN CPU="$TARGETARCH"; \
    if [ "$TARGETARCH" = "amd64" ]; then CPU=x64; fi; \
    rm -rf node_modules && \
    npm ci --omit=dev --cpu="$CPU" --os=linux && \
    npm cache clean --force

FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/web/dist ./web/dist

RUN mkdir -p /app/data

EXPOSE 6446

CMD ["node", "dist/main.js"]
