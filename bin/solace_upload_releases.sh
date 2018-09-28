#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

source $SCRIPTPATH/bosh-common.sh
loadStemcells

for RELEASE_FILE in `ls $WORKSPACE/releases/*.tgz`; do
  RELEASE=$(basename $RELEASE_FILE)
  echo "Uploading release $RELEASE"
  bosh upload-release $RELEASE_FILE
  if [[ $? -ne 0 ]]; then
     echo "Failed to upload-release $RELEASE_FILE"
     exit 1
  fi
done

bosh releases
