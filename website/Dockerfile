FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm AS build
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . ./

ARG VITE_API_BASE_URL=http://localhost:17101
ARG VITE_SIGNALR_HUB_URL=http://localhost:17101/videocallhub
ARG VITE_APP_VERSION=1.0.0-local
ARG VITE_ADMIN_EMAILS=

ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_SIGNALR_HUB_URL=$VITE_SIGNALR_HUB_URL
ENV VITE_APP_VERSION=$VITE_APP_VERSION
ENV VITE_ADMIN_EMAILS=$VITE_ADMIN_EMAILS

RUN npm run build

FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm AS runtime
WORKDIR /app

ARG VITE_APP_VERSION=1.0.0-local
ARG VCS_REF=local

LABEL org.opencontainers.image.title="Forever Love Chat Website"
LABEL org.opencontainers.image.version=$VITE_APP_VERSION
LABEL org.opencontainers.image.revision=$VCS_REF

ENV NODE_ENV=production
ENV PORT=8080

COPY server.mjs ./
COPY --from=build /app/dist ./dist

EXPOSE 8080

CMD ["node", "server.mjs"]
