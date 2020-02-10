#!/bin/bash
[[ -f config.sh ]] && source config.sh
./stop.sh
fargatecli service destroy fargate-web-app
