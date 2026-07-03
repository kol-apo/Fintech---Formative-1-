# Small, current LTS base image
FROM node:20-alpine

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
