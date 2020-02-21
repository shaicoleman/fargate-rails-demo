# node
ARG NODE_VERSION
ARG RUBY_VERSION

FROM node:${NODE_VERSION}-buster-slim AS node
ARG WEEKLY_ID
RUN \
  echo ' ===> Moving yarn to /usr/local' && \
  mv /opt/yarn-* /usr/local/yarn && \
  ln -fs /usr/local/yarn/bin/yarn /usr/local/bin/yarn && \
  ln -fs /usr/local/yarn/bin/yarnpkg /usr/local/bin/yarnpkg && \
  echo ' ===> Node Cleanup' && \
  rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/docker-entrypoint.sh \
         /usr/local/bin/npm /usr/local/bin/npx && \
  find /usr/local/include/node/openssl/archs/* -maxdepth 0 -not -name 'linux-x86_64' -type d -exec rm -rf {} +

# ruby
FROM ruby:${RUBY_VERSION}-slim-buster AS ruby
ARG WEEKLY_ID
RUN \
  echo ' ===> Uninstalling optional gems' && \
  gem uninstall --install-dir /usr/local/lib/ruby/gems/* --executables \
    $(gem list | grep -v 'default: ' | cut -d' ' -f1) && \
  echo ' ===> Ruby Cleanup' && \
  rm -rf /usr/local/lib/ruby/gems/*/cache

# shared-base
FROM ubuntu:20.04 AS shared-base
ARG WEEKLY_ID
RUN \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing eatmydata to speed up APT' && \
  apt-get -yy install eatmydata && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get upgrade' && \
  apt-get -yy upgrade && \
  echo ' ===> Installing base OS dependencies' && \
  apt-get install -q -yy --no-install-recommends sudo curl gnupg ca-certificates tzdata && \
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /var/lib/apt/lists/
COPY --from=ruby /usr/local /usr/local
COPY --from=node /usr/local /usr/local

# build-base
FROM shared-base AS build-base
RUN \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing ruby build tools' && \
  apt-get install -q -yy --no-install-recommends patch gawk g++ gcc autoconf automake bison libtool make patch pkg-config && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /var/lib/apt/lists/

# build-bundler
FROM build-base AS build-bundler
RUN \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing ruby libraries' && \
  apt-get install -q -yy --no-install-recommends libc6-dev libffi-dev libgdbm-dev libncurses5-dev \
    libsqlite3-dev libyaml-dev zlib1g-dev libgmp-dev libreadline-dev libssl-dev liblzma-dev libpq-dev && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /var/lib/apt/lists/

COPY Gemfile* .ruby-version /app/
WORKDIR /app
RUN \
    export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
    echo " ===> bundle install (`nproc` jobs)" && \
    gem install bundler && \
    bundle config --global --jobs 4 && \
    bundle install --jobs `nproc` && \
    echo ' ===> Cleanup' && \
    rm -rf /usr/local/lib/ruby/gems/*/cache/

# build-yarn
FROM build-base AS build-yarn
COPY package.json yarn.lock /app/
WORKDIR /app
RUN \
    export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
    echo ' ===> yarn install' && \
    yarn install --check-files

# build-app-code
FROM scratch AS build-app-code
COPY Gemfile* *.js *.json *.lock *.ru *.md Rakefile .browserslistrc .gitignore /app/
COPY app /app/app/
COPY bin /app/bin/
COPY config /app/config/
COPY db /app/db/
COPY lib /app/lib/
COPY public/*.* /app/public/
COPY vendor /vendor/

# runtime
FROM shared-base

RUN \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  echo ' ===> Installing s6 supervisor' && \
  (curl -sSL 'https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz' | tar xzf - --skip-old-files -C /) && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Running apt-get upgrade' && \
  apt-get -yy upgrade && \
  echo ' ===> Installing wkhtmltopdf dependencies' && \
  apt-get install -q -yy --no-install-recommends libxrender1 libfontconfig1 libxext6 && \
  echo ' ===> Install file utility' && \
  apt-get install -q -yy --no-install-recommends file && \
  echo ' ===> Installing PostgreSQL 10 client' && \
  apt-get install -q -yy --no-install-recommends postgresql-client-10 && \
  echo ' ===> Installing Ruby runtime dependencies' && \
  apt-get install -q -yy --no-install-recommends libyaml-0-2 libffi7 && \
  echo ' ===> Installing extra packages' && \
  apt-get install -q -yy --no-install-recommends jq htop ncdu strace sqlite3 less silversearcher-ag vim-tiny nano && \
  update-alternatives --install /usr/bin/vim vim /usr/bin/vim.tiny 1 && \
  echo ' ===> Installing nginx' && \
  apt-get install -q -yy --no-install-recommends nginx-full && \
  echo ' ===> Installing SSH' && \
  apt-get install -q -yy --no-install-recommends openssh-server openssh-client && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /var/lib/apt/lists/

COPY --from=build-bundler /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=build-yarn /app/node_modules /app/node_modules
COPY --from=build-app-code /app /app
COPY docker/services.d /etc/services.d

ENTRYPOINT ["/init"]
WORKDIR /app
EXPOSE 22 3000
