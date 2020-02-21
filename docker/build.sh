#!/bin/bash
[[ -f config.sh ]] && source config.sh
echo DOCKER_BUILDKIT=1 docker build --build-arg WEEKLY_ID=$WEEKLY_ID --build-arg RUBY_VERSION=$RUBY_VERSION --build-arg NODE_VERSION=$NODE_VERSION -t fargate-web-app ..
DOCKER_BUILDKIT=1 docker build --build-arg WEEKLY_ID=$WEEKLY_ID --build-arg RUBY_VERSION=$RUBY_VERSION --build-arg NODE_VERSION=$NODE_VERSION -t fargate-web-app ..
