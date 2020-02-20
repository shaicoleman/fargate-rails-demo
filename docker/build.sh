#!/bin/bash
[[ -f config.sh ]] && source config.sh
docker build --build-arg WEEKLY_ID=$WEEKLY_ID -t fargate-web-app ..
