#!/bin/bash

AUTH_FILE=/home/kni/.docker/config.json

REG_IMAGE=$1
REG_DEST=registry.poc4.ecocenter.fr:8443/init/oc-mirror-metadata

IMAGE=$(echo $REG_IMAGE | cut -d/ -f2-)

echo skopeo copy --all --preserve-digests --authfile ${AUTH_FILE} docker://$REG_IMAGE docker://$REG_DEST/$IMAGE
