#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_cleanup.log"

set -e

COMMON_PARAMS=""

while getopts a opt; do
  case $opt in
    a)
      POOL_NAMES=$(python3 -c "import commonUtils; commonUtils.getPoolNames()")
      for POOL in ${POOL_NAMES[@]}; do
        VM_FOUND_COUNT=`bosh vms | grep $POOL | wc -l`
        if [ "$VM_FOUND_COUNT" -gt "0" ]; then
          COMMON_PARAMS+=" -p $POOL:$VM_FOUND_COUNT"
        fi
      done
      ;;
  esac
done

OPTIND=1 #Reset getopts

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON $COMMON_PARAMS

cd $SCRIPTPATH/..

echo "Logs in file $LOG_FILE"

for I in ${!VM_JOB[@]}; do
     echo
     echo "Cleanup    VM/$I           ${VM_JOB[I]}"
     shutdownVMRJobs ${VM_JOB[I]} | tee $LOG_FILE
done

deleteDeploymentAndRelease | tee $LOG_FILE
deleteOrphanedDisks | tee $LOG_FILE
resetServiceBrokerEnvironment
