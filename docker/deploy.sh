#!/bin/bash
[[ -f config.sh ]] && source config.sh
fargatecli service deploy fargate-web-app
./start.sh
