#!/bin/bash
[[ -f config.sh ]] && source config.sh
docker build --build-arg WEEKLY_ID=$(date +%G-%V) -t fargate-web-app ..
