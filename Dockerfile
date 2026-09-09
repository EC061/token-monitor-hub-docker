FROM node:22-alpine
RUN apk add --no-cache git tini
WORKDIR /app

# Rebuild = upgrade: upstream is fetched at BUILD time, not baked in.
# UPSTREAM_REF accepts a branch (1Panel rebuilds) or an exact commit SHA
# (GH Action pins the SHA it detected, so image == recorded commit).
#
# Fail-closed install: any failed dependency installation fails the build
# immediately (no `|| true` anywhere). `npm ci` requires package-lock.json;
# if upstream ever removes the lockfile the plain `cp` below fails loudly
# instead of silently changing install behavior.
#
# --ignore-scripts is safe here: the standalone hub import path
# (src/hub/server.js -> src/shared/*.js) only needs pure-JS modules at
# startup (dotenv is lazily required by loadDotEnv). Upstream has no
# postinstall hook; the only prod install script is koffi's native binding
# (unused by the hub), and tokscale vendoring is an explicit manual script
# (scripts/ensure-vendored-tokscale.js), not a lifecycle hook. Skipping
# scripts also avoids running native postinstalls under emulation.
ARG UPSTREAM_REF=main
RUN git init -q /tmp/upstream \
 && git -C /tmp/upstream remote add origin https://github.com/Javis603/token-monitor.git \
 && git -C /tmp/upstream fetch -q --depth 1 origin ${UPSTREAM_REF} \
 && git -C /tmp/upstream checkout -q FETCH_HEAD \
 && cp -a /tmp/upstream/src ./src \
 && cp /tmp/upstream/package.json ./package.json \
 && cp /tmp/upstream/package-lock.json ./package-lock.json \
 && rm -rf /tmp/upstream \
 && npm ci --omit=dev --no-audit --no-fund --ignore-scripts \
 && mkdir -p /app/data \
 && node --check src/hub/server.js \
 && node -e "require('dotenv'); require('undici'); require('semver');" \
 && node -e "require('./src/hub/server.js')"

# Runtime defaults live in compose (TOKEN_MONITOR_PORT/HOST) and server.js
# (17321 / 0.0.0.0). Kept out of ENV: Docker lint flags TOKEN_* in ENV as
# potential secrets, and these are plain non-sensitive config.
ENV NODE_ENV=production \
    TOKEN_MONITOR_DATA_FILE=/app/data/devices.json

EXPOSE 17321
VOLUME ["/app/data"]
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/hub/server.js"]
