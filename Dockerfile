FROM node:22-alpine
RUN apk add --no-cache git tini
WORKDIR /app

# Rebuild = upgrade: upstream is fetched at BUILD time, not baked in.
# UPSTREAM_REF accepts a branch (1Panel rebuilds) or an exact commit SHA
# (GH Action pins the SHA it detected, so image == recorded commit).
ARG UPSTREAM_REF=main
RUN git init -q /tmp/upstream \
 && git -C /tmp/upstream remote add origin https://github.com/Javis603/token-monitor.git \
 && git -C /tmp/upstream fetch -q --depth 1 origin ${UPSTREAM_REF} \
 && git -C /tmp/upstream checkout -q FETCH_HEAD \
 && cp -a /tmp/upstream/src ./src \
 && cp /tmp/upstream/package.json ./package.json \
 && (cp /tmp/upstream/package-lock.json ./package-lock.json || true) \
 && rm -rf /tmp/upstream \
 && npm install --omit=dev --no-audit --no-fund || true \
 && mkdir -p /app/data \
 && node --check src/hub/server.js

# Runtime defaults live in compose (TOKEN_MONITOR_PORT/HOST) and server.js
# (17321 / 0.0.0.0). Kept out of ENV: Docker lint flags TOKEN_* in ENV as
# potential secrets, and these are plain non-sensitive config.
ENV NODE_ENV=production \
    TOKEN_MONITOR_DATA_FILE=/app/data/devices.json

EXPOSE 17321
VOLUME ["/app/data"]
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/hub/server.js"]
