#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPTPATH=$(dirname $SCRIPT)

set -e
COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-m MANIFEST_FILE][-h]"
USING_DEPLOYED_MANIFEST=false

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Shows summary of basic settings for either the current deployment (default) or a specified bosh manifest.

optional arguments:
  -m MANIFEST_FILE
        A bosh manifest from which to show a summary
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts :m:h opt; do
    case $opt in
        m)
            MANIFEST_FILE="$OPTARG"
            if [ -z "$MANIFEST_FILE" ]; then
                echo $BASIC_USAGE
                >&2 echo "No bosh manifest file was specified."
                exit 1
            elif (echo "$MANIFEST_FILE" | grep -qE "^[^/].*"); then
                MANIFEST_FILE="`pwd`/$MANIFEST_FILE"
            fi

            if ! [ -e "$MANIFEST_FILE" ]; then
                echo $BASIC_USAGE
                >&2 echo "Manifest file cannot be found."
                exit 1
            elif ! [ -f "$MANIFEST_FILE" ]; then
                echo $BASIC_USAGE
                >&2 echo "Manifest must be a file."
                exit 1
            fi;;
        h)
            showUsage
            exit 0;;
        \?)
            echo $BASIC_USAGE
            >&2 echo "Found bad option: -$OPTARG"
            exit 1;;
    esac
done

if [ -z "$MANIFEST_FILE" ]; then
    USING_DEPLOYED_MANIFEST=true
    MANIFEST_FILE=$WORKSPACE/"deployed-manifest.yml"
    $BOSH_CMD -n -e lite -d $DEPLOYMENT_NAME manifest > $MANIFEST_FILE

    DEPLOYMENT_FOUND_COUNT=`$BOSH_CMD -e lite deployments | grep $DEPLOYMENT_NAME | wc -l`
    if [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
        echo "No active deployment found. Nothing to do..."
        exit 0
    elif ! [ -s "$MANIFEST_FILE" ]; then
        echo "Downloaded manifest file for deployment $DEPLOYMENT_NAME is empty. Nothing to do..."
        exit 0
    fi
fi


if [ "$(cat $MANIFEST_FILE | grep cert_pem | wc -l)" -le "0" ]; then
    CERT_ENABLED=false
else
    CERT_ENABLED=true
fi

VMR_JOBS=$(py "getManifestJobNames" $MANIFEST_FILE)
for JOB_NAME in ${VMR_JOBS[@]}; do
    JOB=$(py "getManifestJobByName" $MANIFEST_FILE $JOB_NAME)
    VMR_JOB_NAME=$(echo $JOB | shyaml get-value name)
    POOL=$(echo $JOB | shyaml get-value properties.pool_name)
    NUM_INSTANCE=$(echo $JOB | shyaml get-value instances)

    POOL_NAMES+=($POOL)
    VMR_JOB_NAMES+=($VMR_JOB_NAME)
    NUM_INSTANCES+=($NUM_INSTANCE)

    if [ "$(py "isValidPoolName" "$POOL")" -eq 0 ]; then
        echo $BASIC_USAGE
        >&2 echo "Sorry, I don't seem to know about pool name: ${POOL_NAME[i]}"
        exit 1
    fi

    SOLACE_DOCKER_IMAGE_NAME+=($(py "getSolaceDockerImageName" $POOL))

    if [ "$(py "getHaEnabled" $POOL)" -eq "1" ]; then
        HA_ENABLED+=(true)
    else
        HA_ENABLED+=(false)
    fi
done

if $USING_DEPLOYED_MANIFEST && [ -e "$MANIFEST_FILE" ]; then
    rm $MANIFEST_FILE
fi

getReleaseNameAndVersion

echo "Bosh Settings Summary"
echo "    SOLACE VMR     $SOLACE_VMR_BOSH_RELEASE_VERSION - $SOLACE_VMR_BOSH_RELEASE_FILE"
echo "    Deployment     $DEPLOYMENT_NAME"
echo

for i in "${!POOL_NAMES[@]}"; do
    echo "    VMR JOB NAME   ${VMR_JOB_NAMES[i]}"
    echo "    CERT_ENABLED   $CERT_ENABLED"
    echo "    HA_ENABLED     ${HA_ENABLED[i]}"
    echo "    NUM_INSTANCES  ${NUM_INSTANCES[i]}"

#    INSTANCE_COUNT=0
#    while [ "$INSTANCE_COUNT" -lt "${NUM_INSTANCES[i]}" ];  do
#         echo "    VM/$INSTANCE_COUNT           ${VMR_JOB_NAMES[i]}/$INSTANCE_COUNT"
#         let INSTANCE_COUNT=INSTANCE_COUNT+1
#    done
    echo
done

