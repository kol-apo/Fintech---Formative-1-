# =============================================================================
# Stage 1: builder
# Install ALL dependencies (including devDependencies) so we can run tests
# and any build steps before producing the final image.
# =============================================================================
FROM node:20-slim AS builder

# Set /app as the working directory for all subsequent instructions
WORKDIR /app

# Copy package manifests first so Docker can cache the dependency layer.
# If only source files change, this layer is reused and npm ci is skipped.
COPY momosim/package*.json ./

# Install every dependency listed in package-lock.json exactly (reproducible).
# npm ci is stricter and faster than npm install for CI/container builds.
RUN npm ci

# Copy the rest of the application source code into the image
COPY momosim/ .

# =============================================================================
# Stage 2: production
# Lean runtime image — no devDependencies, no build tools, smaller attack surface.
# =============================================================================
FROM node:20-slim AS production

# Install dumb-init: a tiny init process that forwards OS signals (SIGTERM etc.)
# correctly to the Node process so graceful shutdown works inside Docker.
RUN apt-get update \
    && apt-get install -y --no-install-recommends dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Set /app as the working directory
WORKDIR /app

# Copy only the package manifests so we can install production deps cleanly
COPY momosim/package*.json ./

# Install production dependencies only — keeps the image small and secure
RUN npm ci --omit=dev

# Copy application source from the builder stage (avoids re-copying devDeps)
COPY --from=builder /app/data       ./data
COPY --from=builder /app/routes     ./routes
COPY --from=builder /app/services   ./services
COPY --from=builder /app/server.js  ./server.js

# Create a dedicated non-root group and user.
# Running as root inside a container is a security risk — if the process is
# compromised an attacker would have root access to the container filesystem.
RUN groupadd --gid 1001 nodejs \
    && useradd --uid 1001 --gid nodejs --shell /bin/bash --create-home appuser \
    && chown -R appuser:nodejs /app

# Drop privileges — all instructions after this run as appuser, not root
USER appuser

# Document the port the application listens on (does not actually publish it;
# use -p or docker-compose ports: to publish at runtime)
EXPOSE 3000

# Health check: Docker will poll this every 30 s.
# Uses Node's built-in http module — no extra tools needed in the slim image.
# Returns exit 0 (healthy) when /api/accounts responds with HTTP 200.
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD node -e "\
        require('http').get('http://localhost:3000/api/accounts', (res) => { \
            process.exit(res.statusCode === 200 ? 0 : 1); \
        }).on('error', () => process.exit(1));"

# Use dumb-init as PID 1 so signals are forwarded properly to Node
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]
