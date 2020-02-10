#!/bin/bash
[[ -f config.sh ]] && source config.sh

fargatecli service update fargate-web-app --cpu 1024 --memory 2048
fargatecli service scale fargate-web-app 1
