#!/bin/sh

# This script was created from 
# OCP 4 upgrade paths 
# accessible at 
# https://access.redhat.com/solutions/4583231

CURRENT_VERSION=4.10.32;
CHANNEL_NAME=stable-4.11;

usage () {
   echo "usage is : $0 current_ocp_version channel_name  "
   echo "      ocp_version is like 4.10.20       "
   echo "      channel_name is like stable-4.10  "
}

if [ "X${1}X" != "XX" ]; then
   CURRENT_VERSION="${1}"
else
   usage
   exit 0
fi

if [ "X${2}X" != "XX" ]; then
   CHANNEL_NAME="${2}"
else
   usage
   exit 0
fi

curl -sH 'Accept:application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${CHANNEL_NAME}" | jq -r --arg CURRENT_VERSION "${CURRENT_VERSION}" '. as $graph | $graph.nodes | map(.version=='\"$CURRENT_VERSION\"') | index(true) as $orig | $graph.edges | map(select(.[0] == $orig)[1]) | map($graph.nodes[.].version) | sort_by(.)'
