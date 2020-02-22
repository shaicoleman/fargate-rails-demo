#!/bin/bash
[[ -f config.sh ]] && source config.sh
from=../
to=/tmp/fargate-rails-demo-build/
rsync -avz --quiet --delete --exclude=.git/ --exclude-from=<(git -C ${from} ls-files --exclude-standard -oi --directory) ${from} ${to}

DOCKER_BUILDKIT=1 docker build \
  --build-arg WEEKLY_ID=$WEEKLY_ID \
  --build-arg RUBY_VERSION=$RUBY_VERSION \
  --build-arg NODE_VERSION=$NODE_VERSION \
  --build-arg BUNDLER_VERSION=$BUNDLER_VERSION \
  -t fargate-web-app ${to}
