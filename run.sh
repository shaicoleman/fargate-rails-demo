#!/bin/bash
[[ -f config.sh ]] && source config.sh
docker run --rm -p 3000:3000 fargate-web-app:latest
