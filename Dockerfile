FROM ubuntu:18.04
COPY --from=ruby:2.6.5-slim /usr/local /usr/local

RUN \
  echo ' ===> Running apt-get update' && \
  apt-get update && \
  echo ' ===> Installing eatmydata to speed up APT' && \
  apt-get -yy install eatmydata && \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  export DEBIAN_FRONTEND 'noninteractive' && \
  echo ' ===> Running apt-get upgrade' && \
  apt-get -yy upgrade && \
  echo ' ===> Installing base OS dependencies' && \
  apt-get install -q -yy --no-install-recommends sudo curl gnupg ca-certificates tzdata && \
  echo ' ===> Adding PostgreSQL repository' && \
  (curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main' > /etc/apt/sources.list.d/postgresql.list) && \
  echo ' ===> Adding Node repository' && \
  (curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] https://deb.nodesource.com/node_12.x bionic main' > /etc/apt/sources.list.d/node-12.list) && \
  echo ' ===> Adding Yarn repository' && \
  (curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - 2>/dev/null) && \
  (echo 'deb [arch=amd64] https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list) && \
  echo ' ===> Running apt-get update' && \
  apt-get update

RUN \
  export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
  export DEBIAN_FRONTEND 'noninteractive' && \
  echo ' ===> Install file utility' && \
  (cd /tmp && \
   curl -sSL -O http://ftp.uk.debian.org/debian/pool/main/f/file/libmagic-mgc_5.35-4+deb10u1_amd64.deb && \
   curl -sSL -O http://ftp.uk.debian.org/debian/pool/main/f/file/libmagic1_5.35-4+deb10u1_amd64.deb && \
   curl -sSL -O http://ftp.uk.debian.org/debian/pool/main/f/file/file_5.35-4+deb10u1_amd64.deb && \
   dpkg -i file_*.deb libmagic*.deb && \
   rm -f file_*.deb libmagic*.deb) && \
  echo ' ===> Installing git' && \
  apt-get install -q -yy --no-install-recommends git && \
  echo ' ===> Installing ruby build tools' && \
  apt-get install -q -yy --no-install-recommends patch gawk g++ gcc autoconf automake bison libtool make patch pkg-config sqlite3 && \
  echo ' ===> Installing ruby libraries' && \
  apt-get install -q -yy --no-install-recommends libc6-dev libffi-dev libgdbm-dev libncurses5-dev \
    libsqlite3-dev libyaml-dev zlib1g-dev libgmp-dev libreadline-dev libssl-dev liblzma-dev && \
  echo ' ===> Installing nodejs' && \
  apt-get install -q -yy --no-install-recommends nodejs && \
  echo ' ===> Installing yarn' && \
  apt-get install -q -yy --no-install-recommends yarn && \
  echo ' ===> Installing PostgreSQL 10 client and libraries' && \
  apt-get install -q -yy --no-install-recommends postgresql-client-10 libpq-dev && \
  echo ' ===> Installing wkhtmltopdf dependencies' && \
  apt-get install -q -yy --no-install-recommends libxrender1 libfontconfig1 libxext6

WORKDIR /app
COPY Gemfile* .ruby-version /app/
RUN \
    export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
    echo ' ===> bundle install' && \
    gem install bundler && \
    bundle config --global --jobs 4 && \
    bundle install --jobs `nproc`

COPY package.json yarn.lock /app/
RUN \
    export LD_PRELOAD='/usr/lib/x86_64-linux-gnu/libeatmydata.so' && \
    echo ' ===> yarn install' && \
    yarn install --check-files

COPY *.js *.json *.ru *.md Rakefile .browserslistrc .gitignore /app/
COPY app /app/app/
COPY bin /app/bin/
COPY config /app/config/
COPY db /app/db/
COPY lib /app/lib/
COPY public/*.* /app/public/
COPY vendor /vendor/

EXPOSE 3000

CMD ["bin/rails", "s", "-p", "3000", "-b", "0.0.0.0"]
