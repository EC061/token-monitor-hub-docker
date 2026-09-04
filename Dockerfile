FROM node:22-alpine
RUN apk add --no-cache git tini
WORKDIR /app

# Rebuild = upgrade: upstream is cloned at BUILD time, not baked in.
# 1Panel -> Rebuild, or GH Action rebuilds + Watchtower pulls (see docker-publish.yml).
ARG UPSTREAM_REF=main
RUN git clone --depth 1 --branch ${UPSTREAM_REF} https://github.com/Javis603/token-monitor.git /tmp/upstream \
 && cp -a /tmp/upstream/src ./src \
 && cp /tmp/upstream/package.json ./package.json \
 && (cp /tmp/upstream/package-lock.json ./package-lock.json || true) \
 && rm -rf /tmp/upstream \
 && npm install --omit=dev --no-audit --no-fund || true \
 && mkdir -p /app/data \
 && node --check src/hub/server.js

ENV NODE_ENV=production \
    TOKEN_MONITOR_PORT=17321 \
    TOKEN_MONITOR_HOST=0.0.0.0 \
    TOKEN_MONITOR_DATA_FILE=/app/data/devices.json

EXPOSE 17321
VOLUME ["/app/data"]
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/hub/server.js"]
