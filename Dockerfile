# syntax=docker/dockerfile:1.0-experimental
FROM timbru31/ruby-node:2.7-slim
ENV RAILS_ENV="production"
ENV NODE_ENV="production"
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"
WORKDIR /opt/mastodon
ENTRYPOINT ["/usr/bin/tini", "--"]
EXPOSE 3000 4000

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/mastodon/bin"

# Create the mastodon user
ARG UID=991
ARG GID=991
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && \
  echo "Etc/UTC" > /etc/localtime && \
  apt-get install -y --no-install-recommends whois wget && \
  addgroup --gid $GID mastodon && \
  useradd -m -u $UID -g $GID -d /opt/mastodon mastodon && \
  echo "mastodon:$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256)" | chpasswd && \
  rm -rf /var/lib/apt/lists/*

# Install mastodon runtime deps
RUN apt-get update && \
  apt-get -y --no-install-recommends install \
  libssl1.1 libpq5 imagemagick ffmpeg libjemalloc2 \
  libicu-dev libprotobuf17 libidn11 libyaml-0-2 \
  file ca-certificates tzdata libreadline-dev gcc tini && \
  ln -s /opt/mastodon /mastodon && \
  gem install bundler && \
  rm -rf /var/cache && \
  rm -rf /var/lib/apt/lists/*

COPY Gemfile* package.json yarn.lock /opt/mastodon/

RUN cd /opt/mastodon && \
  bundle config set deployment 'true' && \
  bundle config set without 'development test' && \
  bundle install -j"$(nproc)" && \
  yarn install --frozen-lockfile

# Copy over mastodon source, and dependencies from building, and set permissions
COPY --chown=mastodon:mastodon . /opt/mastodon

# Set the run user
USER mastodon

# Precompile assets
RUN --mount=type=cache,target=/opt/mastodon/node_modules cd ~ && \
  OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile && \
  yarn cache clean

