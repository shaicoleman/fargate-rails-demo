#!/bin/bash
[[ -f config.sh ]] && source config.sh
docker build -t fargate-web-app .
