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
  apt-get update -qq && \
  echo ' ===> Installing eatmydata to speed up APT' && \
  apt-get install -qq -yy --no-install-recommends eatmydata && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get upgrade' && \
  apt-get upgrade -qq -yy && \
  echo ' ===> Installing base OS dependencies' && \
  apt-get install -qq -yy --no-install-recommends sudo curl gnupg ca-certificates tzdata && \
  echo " ===> Creating $APP_USER user" && \
  adduser $APP_USER --gecos '' --disabled-password && \
  echo " ===> Workaround for sudo error" && \
  (echo 'Set disable_coredump false' > /etc/sudo.conf) && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup

# ubuntu-dev
FROM ubuntu AS ubuntu-dev
ENV LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so'
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  echo ' ===> Running apt-get update' && \
  apt-get update -qq && \
  echo ' ===> Installing ruby build tools' && \
  apt-get install -qq -yy --no-install-recommends patch gawk g++ gcc autoconf automake bison libtool make patch pkg-config git && \
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
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update -qq && \
  echo ' ===> Installing ruby libraries' && \
  apt-get install -qq -yy --no-install-recommends libsqlite3-dev libpq-dev libsodium-dev \
    libc6-dev libffi-dev libgdbm-dev libncurses5-dev libyaml-dev zlib1g-dev libgmp-dev \
    libreadline-dev libssl-dev liblzma-dev && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup

# ruby-bundle
FROM ruby-dev AS ruby-bundle
ARG BUNDLER_VERSION
ARG APP_DIR
ARG APP_USER
ARG GEM_USER_DIR
COPY --chown=$APP_USER:$APP_USER Gemfile* $APP_DIR/
USER $APP_USER
RUN --mount=type=cache,target="/home/app/.gem",uid=1000,gid=1000,sharing=locked \
  echo " ===> gem install bundler" && \
  gem install --user bundler -v=${BUNDLER_VERSION} --conservative
RUN --mount=type=cache,target="/home/app/.gem",uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target="/home/app/.bundle",uid=1000,gid=1000,sharing=locked \
  cd $APP_DIR && \
  export PATH="${GEM_USER_DIR}/bin:${PATH}" && \
  echo " ===> bundle install" && \
  bundle config set path $HOME/.gem && \
  bundle install --quiet --jobs `nproc`

# ruby-bundle-no-cache
FROM ruby-bundle AS ruby-bundle-no-cache
USER $APP_USER
RUN --mount=type=cache,target="/home/app/.bundle",uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target="/home/app/.gem",uid=1000,gid=1000,sharing=locked \
  mkdir -p ~/ruby-bundle && \
  cp -R ~/.bundle ~/ruby-bundle/.bundle && \
  cp -R ~/.gem ~/ruby-bundle/.gem && \
  rm -rf ~/ruby-bundle/.bundle/cache ~/ruby-bundle/.gem/ruby/*/cache

# node-dev
FROM ubuntu-dev AS node-dev
COPY --from=node /usr/local /usr/local

# node-yarn
FROM node-dev AS node-yarn
ARG APP_DIR
ARG APP_USER
USER $APP_USER
COPY --chown=$APP_USER:$APP_USER package.json yarn.lock $APP_DIR/
RUN --mount=type=cache,target="/app/node_modules",uid=1000,gid=1000,sharing=locked \
  cd $APP_DIR && \
  echo ' ===> yarn install' && \
  yarn install --quiet --check-files

FROM node-yarn AS node-yarn-no-cache
USER $APP_USER
RUN --mount=type=cache,target="/app/node_modules",uid=1000,gid=1000,sharing=locked \
  mkdir -p ~/node-yarn && \
  cp -R $APP_DIR/node_modules ~/node-yarn/node_modules

# ubuntu-s6
FROM ubuntu AS ubuntu-s6
RUN \
  echo ' ===> Installing s6 supervisor' && \
  (curl -sSL 'https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz' | tar xzf - --skip-old-files -C /)

# rails
FROM ubuntu-s6 AS rails
COPY --from=ruby /usr/local /usr/local
COPY --from=node /usr/local /usr/local
ARG APP_DIR
ARG GEM_USER_DIR
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update -qq && \
  # echo ' ===> Installing wkhtmltopdf dependencies' && \
  # apt-get install -qq -yy --no-install-recommends libxrender1 libfontconfig1 libxext6 && \
  # echo ' ===> Install file utility' && \
  # apt-get install -qq -yy --no-install-recommends file && \
  # echo ' ===> Installing PostgreSQL 10 client' && \
  # apt-get install -qq -yy --no-install-recommends postgresql-client-10 && \
  echo ' ===> Installing Ruby runtime dependencies' && \
  apt-get install -qq -yy --no-install-recommends libyaml-0-2 libffi7 libsodium23 && \
  echo ' ===> Installing extra packages' && \
  apt-get install -qq -yy --no-install-recommends jq htop ncdu strace less silversearcher-ag vim-tiny nano && \
  update-alternatives --install /usr/bin/vim vim /usr/bin/vim.tiny 1 && \
  echo ' ===> Installing nginx' && \
  apt-get install -qq -yy --no-install-recommends nginx-light && \
  echo ' ===> Installing SSH' && \
  apt-get install -qq -yy --no-install-recommends openssh-server openssh-client && \
  echo ' ===> Cleanup' && \
  ubuntu-cleanup
COPY docker/etc/ssh/sshd_config /etc/ssh/sshd_config
ARG USERS
RUN ["/bin/bash", "-c", "\
  while IFS= read -r line; do \
    IFS=' ' read username public_key_url group passwd <<< \"$line\"; \
    echo \" ===> Creating $username user\" && \
    adduser $username --gecos '' --disabled-password && \
    mkdir -p /home/$username/.ssh && \
    usermod -aG $group $username && \
    usermod --password \"$passwd\" $username && \
    curl -sSL $public_key_url >> /home/$username/.ssh/authorized_keys && \
    chmod 700 /home/$username/.ssh && \
    chmod 600 /home/$username/.ssh/* && \
    chown -R $username:$username /home/$username/.ssh ; \
  done <<< \"$USERS\" "]

COPY --from=ruby-bundle-no-cache --chown=$APP_USER:$APP_USER /home/$APP_USER/ruby-bundle /home/$APP_USER
COPY --from=node-yarn-no-cache --chown=$APP_USER:$APP_USER /home/$APP_USER/node-yarn $APP_DIR
COPY --from=code --chown=$APP_USER:$APP_USER $APP_DIR $APP_DIR

# rails-app
FROM rails
COPY docker/services.d /etc/services.d
EXPOSE 22 3000
USER root
ENTRYPOINT ["/init"]
