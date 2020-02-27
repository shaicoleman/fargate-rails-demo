# syntax=docker/dockerfile:experimental
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md

ARG NODE_VERSION
ARG RUBY_VERSION

# ruby
FROM docker.io/ruby:${RUBY_VERSION}-slim-buster AS ruby
RUN \
  echo ' ===> Uninstalling optional gems' && \
  gem uninstall --install-dir /usr/local/lib/ruby/gems/* --executables \
    $(gem list | grep -v 'default: ' | cut -d' ' -f1) && \
  echo ' ===> Ruby Cleanup' && \
  rm -rf /usr/local/lib/ruby/gems/*/cache

# node
FROM docker.io/node:${NODE_VERSION}-buster-slim AS node
RUN \
  echo ' ===> Moving yarn to /usr/local' && \
  mv /opt/yarn-* /usr/local/yarn && \
  ln -fs /usr/local/yarn/bin/yarn /usr/local/bin/yarn && \
  ln -fs /usr/local/yarn/bin/yarnpkg /usr/local/bin/yarnpkg && \
  echo ' ===> Node Cleanup' && \
  rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/docker-entrypoint.sh \
         /usr/local/bin/npm /usr/local/bin/npx && \
  find /usr/local/include/node/openssl/archs/* -maxdepth 0 -not -name 'linux-x86_64' -type d -exec rm -rf {} +

# ubuntu
FROM docker.io/ubuntu:20.04 AS ubuntu
COPY docker/scripts /usr/local/bin
ARG APP_USER
ARG WEEKLY_ID
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  echo ' ===> Setting up scripts' && \
  chmod +x /usr/local/bin/ubuntu-cleanup && \
  echo ' ===> Enabling apt cache' && \
  rm -f /etc/apt/apt.conf.d/docker-clean && \
  (echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache) && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing eatmydata to speed up APT' && \
  apt-get -yy install eatmydata && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get upgrade' && \
  apt-get -yy upgrade && \
  echo ' ===> Installing base OS dependencies' && \
  apt-get install -q -yy --no-install-recommends sudo curl gnupg ca-certificates tzdata && \
  echo " ===> Creating $APP_USER user" && \
  adduser $APP_USER --gecos '' --disabled-password && \
  echo " ===> Workaround for sudo error" && \
  (echo 'Set disable_coredump false' > /etc/sudo.conf) && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup

# ubuntu-dev
FROM ubuntu AS ubuntu-dev
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing ruby build tools' && \
  apt-get install -q -yy --no-install-recommends patch gawk g++ gcc autoconf automake bison libtool make patch pkg-config git && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup

# code
FROM ubuntu AS code
ARG APP_DIR
ARG APP_USER
COPY --chown=$APP_USER:$APP_USER . $APP_DIR/
RUN \
  cd $APP_DIR && \
  rm -rf Dockerfile docker/ spec/ test/

# ruby-dev
FROM ubuntu-dev AS ruby-dev
COPY --from=ruby /usr/local /usr/local
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing ruby libraries' && \
  apt-get install -q -yy --no-install-recommends libc6-dev libffi-dev libgdbm-dev libncurses5-dev \
    libsqlite3-dev libyaml-dev zlib1g-dev libgmp-dev libreadline-dev libssl-dev liblzma-dev libpq-dev && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup

# ruby-bundle
FROM ruby-dev AS ruby-bundle
ARG BUNDLER_VERSION
ARG APP_DIR
ARG APP_USER
ARG GEM_USER_DIR
USER $APP_USER
COPY --chown=$APP_USER:$APP_USER Gemfile* $APP_DIR/
RUN --mount=type=cache,target="/home/app/.bundle/cache",uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target="/home/app/.gem/ruby/2.6.0/cache",uid=1000,gid=1000,sharing=locked \
  cd $APP_DIR && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  export PATH="${GEM_USER_DIR}/bin:${PATH}" && \
  echo " ===> gem install bundler" && \
  gem install --user bundler -v=${BUNDLER_VERSION} && \
  echo " ===> bundle install (`nproc` jobs)" && \
  bundle config set path "$HOME/.gem" && \
  bundle install --jobs `nproc`

# ruby-bundle-no-cache
FROM ruby-bundle AS ruby-bundle-no-cache
ARG BUNDLE_USER_DIR
ARG GEM_USER_DIR
RUN \
  rm -rf $BUNDLE_USER_DIR/cache $GEM_USER_DIR/cache

# node-dev
FROM ubuntu-dev AS node-dev
COPY --from=node /usr/local /usr/local

# node-yarn
FROM node-dev AS node-yarn
ARG APP_DIR
ARG APP_USER
USER $APP_USER
COPY --chown=$APP_USER:$APP_USER package.json yarn.lock $APP_DIR/
RUN \
  cd $APP_DIR && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> yarn install' && \
  yarn install --check-files

# ubuntu-s6
FROM ubuntu AS ubuntu-s6
RUN \
  echo ' ===> Installing s6 supervisor' && \
  (curl -sSL 'https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz' | tar xzf - --skip-old-files -C /)

# rails
FROM ubuntu-s6 AS rails
ARG APP_DIR
ARG GEM_USER_DIR
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  # echo ' ===> Installing wkhtmltopdf dependencies' && \
  # apt-get install -q -yy --no-install-recommends libxrender1 libfontconfig1 libxext6 && \
  # echo ' ===> Install file utility' && \
  # apt-get install -q -yy --no-install-recommends file && \
  # echo ' ===> Installing PostgreSQL 10 client' && \
  # apt-get install -q -yy --no-install-recommends postgresql-client-10 && \
  echo ' ===> Installing Ruby runtime dependencies' && \
  apt-get install -q -yy --no-install-recommends libyaml-0-2 libffi7 && \
  curl -sSL http://ftp.uk.debian.org/debian/pool/main/r/readline/libreadline7_7.0-5_amd64.deb -o /tmp/libreadline7_amd64.deb && \
  dpkg -i /tmp/libreadline7_amd64.deb && \
  rm -f /tmp/libreadline7_amd64.deb && \
  echo ' ===> Installing extra packages' && \
  apt-get install -q -yy --no-install-recommends jq htop ncdu strace less silversearcher-ag vim-tiny nano && \
  update-alternatives --install /usr/bin/vim vim /usr/bin/vim.tiny 1 && \
  echo ' ===> Installing nginx' && \
  apt-get install -q -yy --no-install-recommends nginx-light && \
  echo ' ===> Installing SSH' && \
  apt-get install -q -yy --no-install-recommends openssh-server openssh-client && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup
COPY --from=ruby /usr/local /usr/local
COPY --from=node /usr/local /usr/local
COPY --from=ruby-bundle-no-cache --chown=$APP_USER:$APP_USER $GEM_USER_DIR $GEM_USER_DIR
COPY --from=ruby-bundle-no-cache --chown=$APP_USER:$APP_USER $APP_DIR/.bundle $APP_DIR/.bundle
COPY --from=node-yarn --chown=$APP_USER:$APP_USER $APP_DIR/node_modules $APP_DIR/node_modules
COPY --from=code --chown=$APP_USER:$APP_USER $APP_DIR $APP_DIR

# rails-app
FROM rails
COPY docker/services.d /etc/services.d
EXPOSE 22 3000
USER root
ENTRYPOINT ["/init"]
