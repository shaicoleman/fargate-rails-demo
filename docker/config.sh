#!/bin/bash
export AWS_PROFILE=cashanalytics-dev
export AWS_DEFAULT_REGION=eu-west-1

export WEEKLY_ID=$(date --utc +%G-%V)
export RUBY_VERSION=$(<../.ruby-version)
export NODE_VERSION=$(<../.node-version)
export BUNDLER_VERSION=$(grep -oPz 'BUNDLED WITH\n\s+\K\S+' ../Gemfile.lock | tr -d '\000')
