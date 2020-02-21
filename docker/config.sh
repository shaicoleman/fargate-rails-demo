#!/bin/bash
export AWS_PROFILE=cashanalytics-dev
export AWS_DEFAULT_REGION=eu-west-1
export WEEKLY_ID=$(date +%G-%V)
export RUBY_VERSION=$(<../.ruby-version)
export NODE_VERSION=$(<../.node-version)
