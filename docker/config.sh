#!/bin/bash
source secrets.sh
export WEEKLY_ID=$(date --utc +%G-%V)
export RUBY_VERSION=$(<../.ruby-version)
export NODE_VERSION=$(<../.node-version)
export BUNDLER_VERSION=$(grep -oPz 'BUNDLED WITH\n\s+\K\S+' ../Gemfile.lock | tr -d '\000')
export APP_USER=app
export APP_DIR=/app
export GEM_USER_DIR="/home/$APP_USER/.gem/ruby/$(grep -oP '^\d+\.\d+' <<< "$RUBY_VERSION").0"
