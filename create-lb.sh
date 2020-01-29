#!/bin/bash
fargatecli service create --lb fargate-web-lb --port http:3000
