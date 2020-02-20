#!/bin/bash
[[ -f config.sh ]] && source config.sh
DOCKER_BUILDKIT=1 docker build --build-arg WEEKLY_ID=$WEEKLY_ID -t fargate-web-app ..
