#!/bin/bash
[[ -f config.sh ]] && source config.sh
from=../
to=/tmp/fargate-rails-demo-build/
rsync -avz --quiet --delete --exclude=.git/ --exclude-from=<(git -C ${from} ls-files --exclude-standard -oi --directory) ${from} ${to}
cache_dir=../tmp/cache/docker
mkdir -p $cache_dir

# Pull new images if weekly ID changed
weekly_id_file=$cache_dir/weekly_id
[ -f "$weekly_id_file" ] && old_weekly_id=$(<$weekly_id_file)
if [[ "$old_weekly_id" != "$WEEKLY_ID" ]]; then
  docker pull docker.io/ruby:${RUBY_VERSION}-slim-buster &
  docker pull docker.io/node:${NODE_VERSION}-buster-slim &
  docker pull docker.io/ubuntu:20.04 &
  wait
fi

DOCKER_BUILDKIT=1 docker build \
  --build-arg WEEKLY_ID=$WEEKLY_ID \
  --build-arg RUBY_VERSION=$RUBY_VERSION \
  --build-arg NODE_VERSION=$NODE_VERSION \
  --build-arg BUNDLER_VERSION=$BUNDLER_VERSION \
  --file ../Dockerfile \
  -t fargate-web-app ${to} &&
(echo $WEEKLY_ID > $weekly_id_file)
