#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE=${LOG_FILE:-"/tmp/bosh_cleanup.log"}

set -e
COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-h]"

function showHelp(){
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Cleanup the entire bosh deployment and uninstall the service broker.

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

DEPLOYMENT_FOUND_COUNT=`bosh -e lite deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
  echo "No deployments detected."
  echo "Will cleanup any orphaned disks"
  deleteOrphanedDisks | tee $LOG_FILE
  echo
  echo "Terminating cleanup..."
  exit 0
fi

echo "Tearind down the entire $DEPLOYMENT_NAME BOSH deployment"
echo "Logs in file $LOG_FILE"

DEPLOYMENT_FOUND_COUNT=`bosh -e lite deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$DEPLOYMENT_FOUND_COUNT" -gt "0" ]; then
   shutdownAllVMRJobs
fi


deleteDeploymentAndRelease | tee $LOG_FILE
deleteOrphanedDisks | tee $LOG_FILE


