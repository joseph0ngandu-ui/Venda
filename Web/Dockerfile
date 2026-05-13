FROM node:20-alpine AS deps

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci

FROM deps AS build

COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /usr/src/app/dist /usr/share/nginx/html
COPY --from=build /usr/src/app/public/manifest.webmanifest /usr/share/nginx/html/manifest.webmanifest
COPY --from=build /usr/src/app/public/sw.js /usr/share/nginx/html/sw.js

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health >/dev/null || exit 1
