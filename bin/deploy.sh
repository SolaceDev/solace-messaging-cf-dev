#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e

export MANIFEST_FILE=${MANIFEST_FILE:-$WORKSPACE/bosh-solace-manifest.yml}

export TILE_FILE=${TILE_FILE:-$WORKSPACE/*.pivotal}
export TILE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/-ubuntu101-enterprise//g' | sed 's/\.pivotal//g' )
export TEMPLATE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/-ubuntu101-enterprise//g' | sed 's/\.pivotal//g' | awk -F\- '{ print $1 }' )
export TILE_FILE_PATH=$(readlink -f "$TILE_FILE")
export TEMPLATE_DIR=/home/ubuntu/solace-messaging-cf-dev/templates/$TILE_VERSION 
export DEFAULT_CONFIG_FILE=${DEFAULT_CONFIG_FILE:-$TEMPLATE_DIR/deployment_properties.yml}

export GEN_NEW_MANIFEST_FILE=true

export TILE_METADATA_FILE=${TILE_METADATA_MANIFEST_FILE:-$WORKSPACE/metadata/solace-messaging.yml}

## Default using Evaluation edition
export EDITION_OPT="evaluation"

export CMD_NAME=`basename $0`
export BASIC_USAGE="usage: $CMD_NAME [-m MANIFEST_FILE][-c CI_CONFIG_FILE][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Deploy BOSH VMRs.

Default: A basic bosh-lite manifest will be generated and deployed with 1 instance of Shared-VMR, the service broker will be installed.

Note: the -m and -c options cannot be used simultaneously

optional arguments:
  -e    Use the enterprise vmr edition
  -m MANIFEST_FILE
        Manifest that will be deployed
  -c CI_CONFIG_FILE
        A Concourse property file from which a new bosh-manifest will be generated
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

export USE_EXISTING=false
export USE_CI_FILE=false

while getopts :em:c:h opt; do
    case $opt in
        e)  EDITION_OPT="enterprise";;
        m)
            EXISTING_MANIFEST_FILE="$OPTARG"
	    USE_EXISTING=true
	    GEN_NEW_MANIFEST_FILE=false
	    ;;
        c)
            CI_CONFIG_FILE="$OPTARG"
	    USE_CI_FILE=true
            GEN_NEW_MANIFEST_FILE=false;;
        h)
            showUsage
            exit 0;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

if $USE_EXISTING; then
  echo "Will use bosh-lite manifest file $EXISTING_MANIFEST_FILE"
  if ! [ "$EXISTING_MANIFEST_FILE" -ef "$MANIFEST_FILE" ]; then
	cp $EXISTING_MANIFEST_FILE $MANIFEST_FILE
 	echo "Copied $EXISTING_MANIFEST_FILE to $MANIFEST_FILE"
  fi
  echo
fi	

if $USE_CI_FILE; then
  echo "Using VMR edition $EDITION_OPT"
  echo "Will convert CI-config file to bosh-lite manifest file:"
  echo "    Input CI-Config:      $OPTARG"
  echo "    Output Bosh Manifest: $MANIFEST_FILE"
  $SCRIPTPATH/parser/converter.py --edition="$EDITION_OPT" --in-file="$CI_CONFIG_FILE" --in-meta-file=$TILE_METADATA_FILE --out-file="$MANIFEST_FILE"
  echo
fi
            
if [ -n "$EXISTING_MANIFEST_FILE" ] && [ -n "$CI_CONFIG_FILE" ]; then
    showUsage
    >&2 echo "The -m and -c options cannot be used simultaneously"
    exit 1
fi

if $GEN_NEW_MANIFEST_FILE; then
    echo "A new manifest will be generated..."
    echo "Will convert DEFAULT-config file to bosh-lite manifest file:"
    echo "    Input CI-Config:      $DEFAULT_CONFIG_FILE"
    echo "    Output Bosh Manifest: $MANIFEST_FILE"
    $SCRIPTPATH/parser/converter.py --edition="$EDITION_OPT" --in-file="$DEFAULT_CONFIG_FILE" --in-meta-file=$TILE_METADATA_FILE --out-file="$MANIFEST_FILE"
    echo "MANIFEST_FILE set to $MANIFEST_FILE"
    echo
fi

$SCRIPTPATH/pcf_prepare.sh
echo
$SCRIPTPATH/optimizeManifest.py $MANIFEST_FILE
echo
$SCRIPTPATH/deployBoshManifest.sh $MANIFEST_FILE
