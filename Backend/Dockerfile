FROM node:20-alpine AS deps

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci

FROM deps AS build

COPY . .
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /usr/src/app
ENV NODE_ENV=production

COPY package*.json ./
COPY --from=deps /usr/src/app/node_modules ./node_modules
RUN npm prune --omit=dev && npm cache clean --force

COPY --from=build /usr/src/app/dist ./dist
COPY --from=build /usr/src/app/migrations ./migrations

EXPOSE 3000
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/ready').then(response => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["npm", "start"]
