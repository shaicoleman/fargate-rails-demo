#!/bin/bash
[[ -f config.sh ]] && source config.sh
fargatecli service create --lb fargate-web-lb --port http:3000
