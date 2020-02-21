#!/bin/bash
[[ -f config.sh ]] && source config.sh
DOCKER_BUILDKIT=1 docker build \
  --build-arg WEEKLY_ID=$WEEKLY_ID \
  --build-arg RUBY_VERSION=$RUBY_VERSION \
  --build-arg NODE_VERSION=$NODE_VERSION \
  --build-arg BUNDLER_VERSION=$BUNDLER_VERSION \
  -t fargate-web-app ..
