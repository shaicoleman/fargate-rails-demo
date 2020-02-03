#!/bin/bash
[[ -f config.sh ]] && source config.sh
fargatecli service info fargate-web-app
