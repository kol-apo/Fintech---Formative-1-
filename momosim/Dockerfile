# Small, current LTS base image
FROM node:20-alpine

# npm 10.8.2 (bundled with this image) ships tar 6.2.1, vulnerable to
# CVE-2026-59873 (CRITICAL - DoS via crafted gzip bomb). npm 11 is the
# newest major still compatible with Node 20 (node:20-alpine has yet to
# rebuild with a fix) and bundles tar 7.5.19, which resolves it.
RUN npm install -g npm@11

WORKDIR /app

# Install dependencies first so this layer is cached until package*.json changes
COPY package*.json ./
RUN npm ci --omit=dev

# Copy the application source (.dockerignore keeps node_modules, tests, etc. out)
COPY . .

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Don't run as root inside the container
USER node

CMD ["node", "server.js"]
