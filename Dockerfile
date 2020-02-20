# shared-base
FROM ubuntu:20.04 AS shared-base
ARG WEEKLY_ID
COPY --from=ruby:2.6.5-slim-buster /usr/local /usr/local
COPY --from=node:12-buster-slim /usr/local /usr/local
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
  echo ' ===> Adding Yarn repository' && \
  (curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing yarn' && \
  apt-get install -q -yy --no-install-recommends yarn && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /usr/local/lib/ruby/gems/2.6.0/cache/ /var/lib/apt/lists/

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
    echo ' ===> bundle install' && \
    gem install bundler && \
    bundle config --global --jobs 4 && \
    bundle install --jobs `nproc` && \
    echo ' ===> Cleanup' && \
    rm -rf /usr/local/lib/ruby/gems/2.6.0/cache/

# build-yarn
FROM build-base AS build-yarn
COPY package.json yarn.lock /app/
WORKDIR /app
RUN \
    export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
    echo ' ===> yarn install' && \
    yarn install --check-files

# build-rails
FROM build-bundler AS build-rails
COPY *.js *.json *.lock *.ru *.md Rakefile .browserslistrc .gitignore /app/
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
  apt-get install -q -yy --no-install-recommends libyaml-dev && \
  echo ' ===> Installing extra packages' && \
  apt-get install -q -yy --no-install-recommends jq htop ncdu strace git sqlite3 less silversearcher-ag vim nano && \
  echo ' ===> Installing nginx' && \
  apt-get install -q -yy --no-install-recommends nginx-full && \
  echo ' ===> Installing SSH' && \
  apt-get install -q -yy --no-install-recommends openssh-server openssh-client && \
  echo ' ===> Cleanup' && \
  apt-get clean && rm -rf /var/lib/apt/lists/

COPY --from=build-rails /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=build-yarn /app/node_modules /app/node_modules
COPY --from=build-rails /app /app
COPY docker/services.d /etc/services.d

ENTRYPOINT ["/init"]
WORKDIR /app
EXPOSE 22 3000
