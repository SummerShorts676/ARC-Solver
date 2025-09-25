# Multi-stage Dockerfile for Next.js (App Router)
# Uses Node 20 Alpine and enables glibc compatibility needed by Next.js SWC

# Base image
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Install dependencies (dev deps included for building)
FROM base AS deps
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
# Install using the available lockfile
RUN set -eux; \
  if [ -f yarn.lock ]; then \
    corepack enable && yarn --frozen-lockfile; \
  elif [ -f pnpm-lock.yaml ]; then \
    corepack enable && pnpm install --frozen-lockfile; \
  elif [ -f package-lock.json ]; then \
    npm ci; \
  else \
    npm install; \
  fi

# Build the application
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NODE_ENV=production
RUN npm run build

# Production runtime image
FROM base AS runner
ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

# Copy necessary files for running `next start`
COPY package.json ./
COPY --from=builder /app/next.config.mjs ./next.config.mjs
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
# Use the deps layer node_modules (then prune dev deps)
COPY --from=deps /app/node_modules ./node_modules
RUN npm prune --omit=dev || true

USER nextjs
EXPOSE 3000
ENV PORT=3000

# Start the Next.js server
CMD ["npm", "run", "start"]
