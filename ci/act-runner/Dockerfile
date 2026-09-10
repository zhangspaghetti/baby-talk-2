ARG ACT_RUNNER_BASE_IMAGE=ghcr.io/catthehacker/ubuntu:act-24.04@sha256:5d6a17640b25694988b9db5a4145537b9918e5430116b2cf90d84e837609b382
FROM ${ACT_RUNNER_BASE_IMAGE}

ARG ACT_RUNNER_BASE_IMAGE
ARG ACT_RUNNER_RECIPE_SHA256

USER root

LABEL org.babytalk.act.base-image="${ACT_RUNNER_BASE_IMAGE}" \
      org.babytalk.act.recipe-sha256="${ACT_RUNNER_RECIPE_SHA256}" \
      org.babytalk.act.playwright-system-deps="chromium-ubuntu24.04-x64"

# Keep the package set aligned with Playwright's pinned Ubuntu 24.04 Chromium
# dependency table. Building this layer once avoids apt downloads in every act job.
RUN sed -i \
      -e 's|http://archive.ubuntu.com/ubuntu/|https://mirrors.aliyun.com/ubuntu/|g' \
      -e 's|http://security.ubuntu.com/ubuntu/|https://mirrors.aliyun.com/ubuntu/|g' \
      /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      fonts-freefont-ttf \
      fonts-ipafont-gothic \
      fonts-liberation \
      fonts-noto-color-emoji \
      fonts-tlwg-loma-otf \
      fonts-unifont \
      fonts-wqy-zenhei \
      libasound2t64 \
      libatk-bridge2.0-0t64 \
      libatk1.0-0t64 \
      libatspi2.0-0t64 \
      libcairo2 \
      libcups2t64 \
      libdbus-1-3 \
      libdrm2 \
      libfontconfig1 \
      libfreetype6 \
      libgbm1 \
      libglib2.0-0t64 \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libx11-6 \
      libxcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxkbcommon0 \
      libxrandr2 \
      xfonts-cyrillic \
      xfonts-scalable \
      xvfb \
    && rm -rf /var/lib/apt/lists/*

ENV BABYTALK_ACT_PLAYWRIGHT_SYSTEM_DEPS=chromium-ubuntu24.04-x64
