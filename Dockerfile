# ---------- Etapa 1: build ----------
FROM node:24-alpine AS build
WORKDIR /app

RUN npm install -g pnpm@11.7.0

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN pnpm build \
 && pnpm prune --prod

# ---------- Etapa 2: runtime ----------
FROM node:24-alpine AS runtime
LABEL org.opencontainers.image.title="tarea-final" \
      org.opencontainers.image.authors="Elias Bahamondes" \
      org.opencontainers.image.source="https://github.com/Cockfla/lab3"

ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

COPY --from=build --chown=node:node /app/package.json ./
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist

USER node
EXPOSE 3000
CMD ["node", "dist/main"]
