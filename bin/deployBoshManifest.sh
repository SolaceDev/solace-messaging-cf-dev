#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")
export LOG_FILE=${LOG_FILE:-"/tmp/bosh_deploy.log"}

set -e
COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-h] MANIFEST_FILE"

function showHelp(){
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Deploys the specified bosh manifest into bosh-lite.

positional arguments:
  MANIFEST_FILE Manifest that will be deployed

optional arguments:
  -h            show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts ":h" arg; do
    case "$arg" in
        h) showHelp && exit 0;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

shift $((OPTIND - 1))

MANIFEST_FILE="$1"
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
fi

getReleaseNameAndVersion

$SCRIPTPATH/getBoshInfo.sh -m $MANIFEST_FILE

echo "Checking for existing deployment..."

DEPLOYMENT_FOUND_COUNT=`2>&1 $BOSH_CMD deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$DEPLOYMENT_FOUND_COUNT" -gt "0" ]; then
   echo "A bosh deployment is already done."
   echo
   shutdownAllVMRJobs
else
   echo "No existing bosh deployment found. Continuing..."
fi

echo "Will deploy bosh manifest file $MANIFEST_FILE"
echo "You can see deployment logs in $LOG_FILE"
echo

prepareBosh
uploadAndDeployRelease

DEPLOYMENT_FOUND_COUNT=`2>&1 bosh -e lite deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
    echo "Bosh deployment $DEPLOYMENT_NAME cannot be found. Exiting..."
    exit 1
fi

POOL_NAMES=$(py "getPoolNames")
echo "Looking for Jobs in Pools $POOL_NAMES"
VM_JOBS=`2>&1 bosh -e lite vms | awk '{ print $1 }' | grep -Eo "($(echo ${POOL_NAMES[*]} | tr ' ' '|'))/(.*)" | tr '\n' ' '`

if [ -z "$VM_JOBS" ]; then
    echo "No deployed VMs could be found."
    exit 1
fi

echo "bosh deployment is present, VMs called:"
for VM in ${VM_JOBS[@]}; do
  echo "    $VM"
done

echo
echo "You can ssh to them using: bosh -e lite ssh [VM_NAME]"
echo "  e.g. bosh -e lite -d $DEPLOYMENT_NAME ssh ${VM_JOBS[0]}"
echo
