#!/bin/sh
docker run \
  -v ./archetypes:/home/ubuntu/hugo/archetypes:ro \
  -v ./assets:/home/ubuntu/hugo/assets:ro \
  -v ./config.toml:/home/ubuntu/hugo/config.toml:ro \
  -v ./content:/home/ubuntu/hugo/content:ro \
  -v ./drafts:/home/ubuntu/hugo/drafts:ro \
  -v ./images:/home/ubuntu/hugo/images:ro \
  -v ./layouts:/home/ubuntu/hugo/layouts:ro \
  -v ./public:/home/ubuntu/hugo/public:rw \
  -v ./release.sh:/home/ubuntu/hugo/release.sh:ro \
  -v ./resources:/home/ubuntu/hugo/resources:rw \
  -v ./static:/home/ubuntu/hugo/static:ro \
 --rm -it local/hugo:0.145 /bin/bash -c 'cd hugo && ./release.sh'
