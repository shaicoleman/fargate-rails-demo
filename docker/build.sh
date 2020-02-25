#!/bin/bash
if ! [ -x "$(command -v envsubst)" ]; then
  echo "Error: envsubst not installed. To install on Ubuntu run:" >&2
  echo "sudo apt-get install gettext-base" >&2
  exit 1
fi

[[ -f config.sh ]] && source config.sh
dockerfile=../Dockerfile
from=../
to=/tmp/fargate-rails-demo-build/
rsync -avz --quiet --delete --exclude=.git/ --exclude-from=<(git -C ${from} ls-files --exclude-standard -oi --directory) ${from} ${to}
cache_dir=../tmp/cache/docker
mkdir -p $cache_dir

# Pull new images if weekly ID changed
weekly_id_file=$cache_dir/weekly_id
[ -f "$weekly_id_file" ] && old_weekly_id=$(<$weekly_id_file)
if [[ "$old_weekly_id" != "$WEEKLY_ID" ]]; then
  grep -oP 'FROM \Kdocker.io/\S+' $dockerfile | envsubst | xargs -I {} docker pull "{}" &
  wait
fi

DOCKER_BUILDKIT=1 docker build \
  --build-arg APP_DIR=$APP_DIR \
  --build-arg APP_USER=$APP_USER \
  --build-arg WEEKLY_ID=$WEEKLY_ID \
  --build-arg RUBY_VERSION=$RUBY_VERSION \
  --build-arg NODE_VERSION=$NODE_VERSION \
  --build-arg BUNDLER_VERSION=$BUNDLER_VERSION \
  --file $dockerfile \
  -t fargate-web-app ${to} &&
(echo $WEEKLY_ID > $weekly_id_file)
