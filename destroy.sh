#!/bin/bash
fargatecli service scale fargate-web-app 0
fargatecli service destroy fargate-web-app
