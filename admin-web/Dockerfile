FROM node:20-alpine AS build
WORKDIR /app
ENV COREPACK_NPM_REGISTRY=https://mirrors.cloud.tencent.com/npm/ \
    NPM_CONFIG_REGISTRY=https://mirrors.cloud.tencent.com/npm/ \
    npm_config_registry=https://mirrors.cloud.tencent.com/npm/
RUN corepack enable
COPY .npmrc ./
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY admin-web/package.json admin-web/package.json
RUN pnpm install --frozen-lockfile
COPY admin-web ./admin-web
RUN pnpm --filter admin-web build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/admin-web/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
