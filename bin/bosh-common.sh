#!/bin/bash

export DEPLOYMENT_NAME="solace_pubsub"
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/bosh_deploy.log"}
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

######################################

export BOSH_IP=${BOSH_IP:-"192.168.50.6"}
export BOSH_CMD="/usr/local/bin/bosh"
export BOSH_CLIENT=${BOSH_CLIENT:-admin}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET:-admin}
export BOSH_ENVIRONMENT=${BOSH_ENVIRONMENT:-"lite"}

export STEMCELL_VERSION=${STEMCELL_VERSION:-"170.69"}
export STEMCELL=${STEMCELL:-"ubuntu-xenial"}

export REQUIRED_STEMCELLS=${REQUIRED_STEMCELLS:-"$STEMCELL:$STEMCELL_VERSION"}

export VM_MEMORY=${VM_MEMORY:-10240}
export VM_CPUS=${VM_CPUS:-6}
export VM_DISK_SIZE=${VM_DISK_SIZE:-"65_536"}
export VM_EPHEMERAL_DISK_SIZE=${VM_EPHEMERAL_DISK_SIZE:-"32_768"}
export VM_SWAP=${VM_SWAP:-10240}

export BUCC_HOME=${BUCC_HOME:-$SCRIPTPATH/../bucc}
export BUCC_STATE_ROOT=${BUCC_STATE_ROOT:-$WORKSPACE/BOSH_LITE_VM/state}
export BUCC_VARS_FILE=${BUCC_VARS_FILE:-$WORKSPACE/BOSH_LITE_VM/vars.yml}
export BUCC_STATE_STORE=${BUCC_STATE_STORE:-$BUCC_STATE_ROOT/state.json}
export BUCC_VARS_STORE=${BUCC_VARS_STORE:-$BUCC_STATE_ROOT/creds.yml}

export BOSH_ENV_FILE=${BOSH_ENV_FILE:-$WORKSPACE/bosh_env.sh}
export DOT_BOSH_ENV_FILE=${DOT_BOSH_ENV_FILE:-$WORKSPACE/.env}

export TEMP_DIR=$(mktemp -d)

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

function cleanupWorkTemp() {
 if [ -d $TEMP_DIR ]; then
    rm -rf $TEMP_DIR
 fi
}
trap cleanupWorkTemp EXIT INT TERM HUP

function targetBosh() {

  ## Setup to access target bosh-lite
  BOSH_TARGET_LOG=$( $BOSH_CMD alias-env lite -e $BOSH_IP )
  if [ $? -eq 0 ]; then
     # Login will rely on BOSH_* env vars..
     BOSH_LOGIN_LOG=$( BOSH_CLIENT=$BOSH_CLIENT BOSH_CLIENT_SECRET=$BOSH_CLIENT_SECRET $BOSH_CMD log-in )
     if [ $? -eq 0 ]; then
        export BOSH_ACCESS=1
     else
        export BOSH_ACCESS=0
        echo $BOSH_LOGIN_LOG
     fi
  else
     export BOSH_ACCESS=0
     echo $BOSH_TARGET_LOG
  fi
}

function loadWorkspaceReleases() {

 for REQUIRED_STEMCELL in $REQUIRED_STEMCELLS; do

  STEMCELL=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $1 }' )
  STEMCELL_VERSION=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $2 }' )

  for release in $(ls $WORKSPACE/*-*-$STEMCELL-$STEMCELL_VERSION-*.tgz | grep -v "bosh-stemcell" | grep -v "go_agent" ); do 
      echo "Loading release matching stemcell $STEMCELL/$STEMCELL_VERSION: $release"
      bosh upload-release $release
  done

 done

}

function loadWorkspaceStemcells() {

 for stemcell_file in $(ls $WORKSPACE/bosh-stemcell-*-warden-boshlite-*-go_agent.tgz); do 
      echo "Loading $stemcell_file"
      bosh upload-stemcell $stemcell_file
 done

}

function loadStemcells() { 

 for REQUIRED_STEMCELL in $REQUIRED_STEMCELLS; do

  export STEMCELL=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $1 }' )
  export STEMCELL_VERSION=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $2 }' )
  export STEMCELL_NAME="bosh-stemcell-${STEMCELL_VERSION}-warden-boshlite-${STEMCELL}-go_agent.tgz"
  export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/$STEMCELL_VERSION/$STEMCELL_NAME"
  FOUND_STEMCELL=$( bosh stemcells --json | jq ".Tables[].Rows[] | select(.os == \"$STEMCELL\")  | select ((.version == \"${STEMCELL_VERSION}\" ) or (.version==\"${STEMCELL_VERSION}*\")) | .name " | wc -l)
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
     if [ ! -f $WORKSPACE/$STEMCELL_NAME ]; then
	echo "Downloading required stemcell $STEMCELL_NAME"
        curl $STEMCELL_URL -o $WORKSPACE/$STEMCELL_NAME -s
     fi
     bosh upload-stemcell $WORKSPACE/$STEMCELL_NAME
     if [ $? -ne 0 ]; then
	echo "Failed to upload required stemcell $STEMCELL_NAME to bosh"
	exit 1
     fi
  else
     echo "Stemcell found [$STEMCELL_NAME]/[$STEMCELL_VERSION]"
  fi

 done

}

function deleteAllOrphanedDisks() {

ORPHANED_DISKS_COUNT=$( bosh disks --orphaned --json | jq ".Tables[].Rows[] | .disk_cid" | sed 's/\"//g' | wc -l )
ORPHANED_DISKS=$( bosh disks --orphaned --json | jq ".Tables[].Rows[] | .disk_cid" | sed 's/\"//g' )

if [ "$ORPHANED_DISKS_COUNT" -gt "0" ]; then

 for DISK_ID in $ORPHANED_DISKS; do
        echo "Will delete $DISK_ID"
        bosh -n delete-disk $DISK_ID
        echo
        echo "Orphaned Disk $DISK_ID was deleted"
        echo
 done

else
   echo "no orphaned disks found: $ORPHANED_DISKS_COUNT"
fi

}

function deleteOrphanedDisks() {

SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}

ORPHANED_DISKS_COUNT=$( bosh disks --orphaned --json | jq ".Tables[].Rows[] | select(.deployment | contains(\"$SELECTED_DEPLOYMENT\")) | .disk_cid" | sed 's/\"//g' | wc -l )
ORPHANED_DISKS=$( bosh disks --orphaned --json | jq ".Tables[].Rows[] | select(.deployment | contains(\"$SELECTED_DEPLOYMENT\")) | .disk_cid" | sed 's/\"//g' )


if [ "$ORPHANED_DISKS_COUNT" -gt "0" ]; then

 for DISK_ID in $ORPHANED_DISKS; do
        echo "Will delete $DISK_ID"
        bosh -n delete-disk $DISK_ID
        echo
        echo "Orphaned Disk $DISK_ID was deleted"
        echo
 done

else
   echo "Deployment [$SELECTED_DEPLOYMENT] - no orphaned disks found: $ORPHANED_DISKS_COUNT"
fi

}

#################################

function shutdownVMRJobs() {

 echo "In shutdownVMRJobs"

 VM_JOB=$1

 echo "Looking for VM job $VM_JOB" 
 VM_FOUND_COUNT=`$BOSH_CMD vms | grep $VM_JOB | wc -l`
 VM_RUNNING_FOUND_COUNT=`$BOSH_CMD vms --json | jq '.Tables[].Rows[] | select(.process_state=="running") | .instance' | grep $VM_JOB |  wc -l`
 DEPLOYMENT_FOUND_COUNT=$(bosh deployments --json | jq '.Tables[].Rows[] | .name ' | sed 's/\"//g' | grep "^$DEPLOYMENT_NAME\$" | wc -l )
 RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep -v solace-pubsub-broker | grep solace-pubsub | wc -l`

 if [ "$VM_RUNNING_FOUND_COUNT" -eq "1" ]; then

   echo "Will stop monit jobs if any are running on $DEPLOYMENT_NAME / $VM_JOB"
   $BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit stop all" 

   RUNNING_COUNT=`$BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary" | grep running | wc -l`
   MAX_WAIT=60
   while [ "$RUNNING_COUNT" -gt "0" ] && [ "$MAX_WAIT" -gt "0" ]; do
   	echo "Waiting for monit to finish shutdown - found $RUNNING_COUNT still running"
	sleep 5
        let MAX_WAIT=MAX_WAIT-5
        RUNNING_COUNT=`$BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary " | grep running | wc -l`
   done
 else
  echo "Did not find running job $VM_JOB"
 fi

}

function getReleaseNameAndVersion() {
    SOLACE_PUBSUB_BOSH_RELEASE_FILE_MATCHER=`ls $WORKSPACE/releases/solace-pubsub-*.tgz | grep -v solace-pubsub-broker`
    for f in $SOLACE_PUBSUB_BOSH_RELEASE_FILE_MATCHER; do
      if ! [ -e "$f" ]; then
        echo "Could not find solace-pubsub bosh release file: $SOLACE_PUBSUB_BOSH_RELEASE_FILE_MATCHER"
        exit 1
      fi

      export SOLACE_PUBSUB_BOSH_RELEASE_FILE="$f"
      break
    done
    export SOLACE_PUBSUB_BOSH_RELEASE_VERSION_FULL=$(basename $SOLACE_PUBSUB_BOSH_RELEASE_FILE | sed 's/solace-pubsub-//g' | sed 's/.tgz//g' )
    export SOLACE_PUBSUB_BOSH_RELEASE_VERSION=$(basename $SOLACE_PUBSUB_BOSH_RELEASE_FILE | sed 's/solace-pubsub-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )
    export SOLACE_PUBSUB_BOSH_RELEASE_VERSION_DEV=$(basename $SOLACE_PUBSUB_BOSH_RELEASE_FILE | sed 's/solace-pubsub-//g' | sed 's/.tgz//g' | awk -F\- '{ print $2 }' )
    echo "Determined SOLACE_PUBSUB_BOSH_RELEASE_VERSION_FULL $SOLACE_PUBSUB_BOSH_RELEASE_VERSION_FULL"
    echo "Determined SOLACE_PUBSUB_BOSH_RELEASE_VERSION $SOLACE_PUBSUB_BOSH_RELEASE_VERSION"
    echo "Determined SOLACE_PUBSUB_BOSH_RELEASE_VERSION_DEV $SOLACE_PUBSUB_BOSH_RELEASE_VERSION_DEV"


    SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER="$WORKSPACE/releases/solace-pubsub-broker-*.tgz"
    for f in $SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER; do
      if ! [ -e "$f" ]; then
        echo "Could not find solace-pubsub-broker bosh release file: $SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER"
        exit 1
      fi

      export SOLACE_MESSAGING_BOSH_RELEASE_FILE="$f"
      break
    done
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-pubsub-broker-//g' | sed 's/.tgz//g' )
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-pubsub-broker-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-pubsub-broker-//g' | sed 's/.tgz//g' | awk -F\- '{ print $2 }' )
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL"
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION $SOLACE_MESSAGING_BOSH_RELEASE_VERSION"
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV"

}

function uploadReleases() {

echo "in function uploadReleases. SOLACE_MESSAGING_BOSH_RELEASE_FILE: $SOLACE_MESSAGING_BOSH_RELEASE_FILE"

SOLACE_MESSAGING_BOSH_RELEASE_FILE=${SOLACE_MESSAGING_BOSH_RELEASE_FILE:-`ls $WORKSPACE/releases/solace-pubsub-broker-*.tgz | tail -1`}
SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep solace-pubsub-broker | wc -l`

if [ -f $SOLACE_MESSAGING_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -gt "0" ]; then
  UPLOADED_RELEASE_VERSION=`$BOSH_CMD releases | grep solace-pubsub-broker | awk '{ print $4 }'`
  # remove trailing '*'
  UPLOADED_RELEASE_VERSION="${UPLOADED_RELEASE_VERSION%\*}"
  echo "Determined solace-pubsub-broker uploaded version $UPLOADED_RELEASE_VERSION"
 fi

 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -eq "0" ] || \
    [ "$SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL" '>' "$UPLOADED_RELEASE_VERSION" ]; then
  echo "Will upload release $SOLACE_MESSAGING_BOSH_RELEASE_FILE"

  $BOSH_CMD upload-release $SOLACE_MESSAGING_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "A solace-pubsub-broker release with version greater than or equal to $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL already exists. Skipping release upload..."
 fi

fi

SOLACE_PUBSUB_BOSH_RELEASE_FILE=${SOLACE_PUBSUB_BOSH_RELEASE_FILE:-`ls $WORKSPACE/releases/solace-pubsub-*.tgz | grep -v solace-pubsub-broker | tail -1`}
RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep -v solace-pubsub-broker | grep solace-pubsub | wc -l`

echo "in function uploadReleases. SOLACE_PUBSUB_BOSH_RELEASE_FILE: $SOLACE_PUBSUB_BOSH_RELEASE_FILE"

if [ -f $SOLACE_PUBSUB_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$RELEASE_FOUND_COUNT" -gt "0" ]; then
  UPLOADED_RELEASE_VERSION=`$BOSH_CMD releases | grep -v solace-broker-pubsub | grep solace-pubsub | awk '{ print $4 }'`
  # remove trailing '*'
  UPLOADED_RELEASE_VERSION="${UPLOADED_RELEASE_VERSION%\*}"
 fi

 if [ "$RELEASE_FOUND_COUNT" -eq "0" ] || \
    [ "$SOLACE_PUBSUB_BOSH_RELEASE_VERSION_FULL" '>' "$UPLOADED_RELEASE_VERSION" ]; then
  echo "Will upload release $SOLACE_PUBSUB_BOSH_RELEASE_FILE"

  $BOSH_CMD upload-release $SOLACE_PUBSUB_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "A solace-pubsub release with version greater than or equal to $SOLACE_PUBSUB_BOSH_RELEASE_VERSION_FULL already exists. Skipping release upload..."
 fi

else
 >&2 echo "Could not locate a release file in $WORKSPACE/releases/solace-pubsub-*.tgz"
 exit 1
fi

}

function runErrand() {

 SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}
 ERRAND_NAME=$2
 INSTANCE_NAME=${3:-"management/first"}
 DEPLOYMENT_FOUND_COUNT=$(bosh deployments --json | jq '.Tables[].Rows[] | .name ' | sed 's/\"//g' | grep "^$SELECTED_DEPLOYMENT\$" | wc -l )
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ] && [ ! -z $ERRAND_NAME ]; then

  FOUND_ERRAND=$( bosh -d $SELECTED_DEPLOYMENT errands --json | jq ".Tables[].Rows[] | select(.name == \"$ERRAND_NAME\") | .name " | grep "$ERRAND_NAME" | wc -l )
  if [ $FOUND_ERRAND -eq "1" ]; then
     echo "Running [ bosh -d $SELECTED_DEPLOYMENT run-errand $ERRAND_NAME --instance=$INSTANCE_NAME --when-changed ]"
     bosh -d $SELECTED_DEPLOYMENT run-errand $ERRAND_NAME --instance=$INSTANCE_NAME --when-changed
  else
     echo "Errand [$ERRAND_NAME] not found for deployment [$SELECTED_DEPLOYMENT]"
  fi

 else
     echo "Deployment [$SELECTED_DEPLOYMENT] not found: $DEPLOYMENT_FOUND_COUNT, or missing required errand name [$ERRAND_NAME]"
 fi

}

function deleteSolaceDeployment() {
  SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}
  runErrand $SELECTED_DEPLOYMENT delete-all-service-instances management/first
  runErrand $SELECTED_DEPLOYMENT delete-all management/first
  deleteDeployment $SELECTED_DEPLOYMENT
  deleteOrphanedDisks $SELECTED_DEPLOYMENT
  deleteAllOrphanedDisks
}

function deleteDeployment() {

 SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}

 DEPLOYMENT_FOUND_COUNT=$(bosh deployments --json | jq '.Tables[].Rows[] | .name ' | sed 's/\"//g' | grep "^$SELECTED_DEPLOYMENT\$" | wc -l )
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then

  bosh -n -d $SELECTED_DEPLOYMENT delete-deployment

 else
     echo "Deployment [$SELECTED_DEPLOYMENT] not found: $DEPLOYMENT_FOUND_COUNT"
 fi

}

function deleteBOSHRelease() {

BOSH_RELEASE=$1
MATCHING_RELEASES_LIST=$( bosh releases --json | jq -r ".Tables[].Rows[] | select((.name == \"$BOSH_RELEASE\")) | .version" )
MATCHING_UNUSED_RELEASES=$( echo "$MATCHING_RELEASES_LIST" | grep -v "*" )
MATCHING_UNUSED_RELEASES_COUNT=$( echo "$MATCHING_UNUSED_RELEASES" | awk -v RS="" -v OFS=',' '$1=$1' | wc -l )
MATCHING_USED_RELEASES=$( echo "$MATCHING_RELEASES_LIST" | grep "*" )
MATCHING_USED_RELEASES_COUNT=$( echo "$MATCHING_USED_RELEASES" | awk -v RS="" -v OFS=',' '$1=$1' | wc -l )
echo "Found [ $MATCHING_UNUSED_RELEASES_COUNT : unused ] and [ $MATCHING_USED_RELEASES_COUNT : in-use ] release(s) for [ $BOSH_RELEASE ]"

if [ "$MATCHING_UNUSED_RELEASES_COUNT" -gt "0" ]; then
 for MATCHING_RELEASE_VERSION in $MATCHING_UNUSED_RELEASES; do
   echo "Deleting [ $BOSH_RELEASE/$MATCHING_RELEASE_VERSION ]"
   bosh -n delete-release $BOSH_RELEASE/$MATCHING_RELEASE_VERSION
 done
fi

}

function deleteSolaceReleases() {
  
 deleteBOSHRelease solace-pubsub-broker
 deleteBOSHRelease solace-pubsub
 deleteBOSHRelease solace-service-adapter
 deleteBOSHRelease solace-bosh-dns-aliases

}



function bosh_lite_vm_common() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo $1 [$BOSH_VM]
        eval $2
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi
}

function delete_bosh_lite_vm_snapshot() {
    bosh_lite_vm_common "Deleting snapshot $1 of" "vboxmanage snapshot \$BOSH_VM delete $1"
}

function savestate_bosh_lite_vm() {
    bosh_lite_vm_common "Saving the state of" "vboxmanage controlvm \$BOSH_VM savestate"
}

function resume_bosh_lite_vm() {
    bosh_lite_vm_common "Starting" "vboxmanage startvm \$BOSH_VM --type headless"
    bosh_lite_vm_syncdatetime
}

function restore_bosh_lite_vm_snapshot() {
    bosh_lite_vm_common "Restoring snapshot as $1 of" "vboxmanage snapshot \$BOSH_VM restore $1"
}

function take_bosh_lite_vm_snapshot() {
    bosh_lite_vm_common "Taking snapshot as $1 of" "vboxmanage snapshot \$BOSH_VM take $1"
}

function restore_current_bosh_lite_vm_snapshot() {
    bosh_lite_vm_common "Restoring current snapshot of" "vboxmanage snapshot \$BOSH_VM restorecurrent"
}

function list_bosh_lite_vm_snapshot() {
    bosh_lite_vm_common "Listing snapshot of " "vboxmanage snapshot \$BOSH_VM list"
}

function poweroff() {
    bosh_lite_vm_common "Powering off" "vboxmanage controlvm \$BOSH_VM poweroff"
}

function check_bucc() {

(
 cd $SCRIPTPATH/..
 if [ ! -d bucc ]; then
  git clone https://github.com/starkandwayne/bucc.git
 else
  (cd bucc; git pull)
 fi
)
export PATH=$PATH:$BUCC_HOME/bin

if [ ! -d $WORKSPACE/BOSH_LITE_VM ]; then
    mkdir $WORKSPACE/BOSH_LITE_VM
    mkdir -p $BUCC_STATE_ROOT

    # Migrate old state directory if found
    if [ -d $WORKSPACE/bucc/state ]; then
         mv $WORKSPACE/bucc/state/* $BUCC_STATE_ROOT
         rmdir $WORKSPACE/bucc/state
    fi

    # Migrate old vars if found
    if [ -f $WORKSPACE/bucc/vars.yml ]; then
       mv $WORKSPACE/bucc/vars.yml $BUCC_VARS_FILE
    fi

fi

}

function create_bosh_lite_vm() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
	echo "Exiting $SCRIPT: You seem to already have an existing BOSH-lite VM [$BOSH_VM]"
	exit 1
   fi
   unset BOSH_VM
fi

check_bucc

echo "Setting VM_MEMORY [ $VM_MEMORY ], VM_CPUS [ $VM_CPUS ], VM_EPHEMERAL_DISK_SIZE [ $VM_EPHEMERAL_DISK_SIZE ], VM_DISK_SIZE [ $VM_DISK_SIZE ]"
sed -i "/vm_memory:/c\vm_memory: $VM_MEMORY" $BUCC_HOME/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_cpus:/c\vm_cpus: $VM_CPUS" $BUCC_HOME/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_ephemeral_disk:/c\vm_ephemeral_disk: $VM_EPHEMERAL_DISK_SIZE" $BUCC_HOME/ops/cpis/virtualbox/vars.tmpl

echo "vm_disk_size: $VM_DISK_SIZE" >> $BUCC_HOME/ops/cpis/virtualbox/vars.tmpl
cp -f $SCRIPTPATH/vm-size.yml $BUCC_HOME/ops/cpis/virtualbox/

## Capture running VMS before
vboxmanage list runningvms > $TEMP_DIR/running_vms.before

bucc up --cpi virtualbox --lite --debug 

## Capture running VMS after
vboxmanage list runningvms > $TEMP_DIR/running_vms.after

BOSH_VM=$( diff --changed-group-format='%>' --unchanged-group-format='' $TEMP_DIR/running_vms.before $TEMP_DIR/running_vms.after | awk '{ print $1 }' | sed 's/\"//g' )

vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

if [[ $? -eq 0 ]]; then
   echo $BOSH_VM > $WORKSPACE/.boshvm
   echo "Running BOSH-lite VM is [$BOSH_VM] : Saved to $WORKSPACE/.boshvm"
fi

create_bosh_env_file

source $BOSH_ENV_FILE
echo "Updating runtime-config to activate bosh-dns" 
bosh -n update-runtime-config $SCRIPTPATH/runtime-config.yml
}

function prepare_bosh_env() {

bucc env 
echo "export PATH=\$PATH:$SCRIPTPATH"
echo "export BUCC_HOME=\${BUCC_HOME:-$SCRIPTPATH/../bucc}"
echo "export BUCC_STATE_ROOT=\${BUCC_STATE_ROOT:-\$WORKSPACE/BOSH_LITE_VM/state}"
echo "export BUCC_VARS_FILE=\${BUCC_VARS_FILE:-\$WORKSPACE/BOSH_LITE_VM/vars.yml}"
echo "export BUCC_STATE_STORE=\${BUCC_STATE_STORE:-\$BUCC_STATE_ROOT/state.json}"
echo "export BUCC_VARS_STORE=\${BUCC_VARS_STORE:-\$BUCC_STATE_ROOT/creds.yml}"

}

function create_bosh_env_file() {

check_bucc
prepare_bosh_env > $BOSH_ENV_FILE
echo "Prepared: $BOSH_ENV_FILE"
echo "To use it \"source $BOSH_ENV_FILE\""

}

function bosh_lite_vm_additions() {

source $BOSH_ENV_FILE
setup_bosh_lite_routes
setup_bosh_lite_swap

}

function destroy_bosh_lite_vm() {

checkRequiredTools vboxmanage

check_bucc

source <($BUCC_HOME/bin/bucc env)

if [ -d $BUCC_STATE_ROOT ] && [ -f $BUCC_VARS_FILE ]; then
   $BUCC_HOME/bin/bucc down && $BUCC_HOME/bin/bucc clean
fi

if [ -f $BOSH_ENV_FILE ]; then
   rm -f $BOSH_ENV_FILE
fi

if [ -f $DOT_BOSH_ENV_FILE ]; then
   rm -f $DOT_BOSH_ENV_FILE
fi

if [ -f $WORKSPACE/deployment-vars.yml ]; then
   rm -f $WORKSPACE/deployment-vars.yml
fi

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Exiting $SCRIPT: The BOSH-lite VM [$BOSH_VM] is still running?"
        exit 1
   fi
   rm -f $WORKSPACE/.boshvm
   unset BOSH_VM
fi

}

function platform() {
    if [ "$(uname)" == "Darwin" ]; then
        echo "darwin"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        echo "linux"
    fi
}

function setup_bosh_lite_routes() {

 echo
 echo "Adding routes, you may need to enter your credentials to grant sudo permissions"
 echo

    case $(platform) in
        darwin)
            sudo route delete -net 10.244.0.0/16    $BOSH_GW_HOST
            sudo route add -net 10.244.0.0/16    $BOSH_GW_HOST
            ;;
        linux)
            sudo route del -net 10.244.0.0/16 gw $BOSH_GW_HOST
            sudo route add -net 10.244.0.0/16 gw $BOSH_GW_HOST
            ;;
    esac

}

function setup_bosh_lite_swap() {

 checkRequiredTools ssh-keygen ssh-keyscan

 if [ ! -z "$VM_SWAP" ] && [ "$VM_SWAP" -gt "0" ]; then

   check_bucc

   echo
   echo "Adding swap space VM_SWAP [ $VM_SWAP ]"
   echo "You may need to accept the authenticity of host $BOSH_GW_HOST when requested"
   echo

   if [ ! -d ~/.ssh/ ]; then
      mkdir -p ~/.ssh
      chmod 700 ~/.ssh
   fi
   ssh-keygen -f ~/.ssh/known_hosts -R $BOSH_ENVIRONMENT
   ssh-keyscan -H $BOSH_ENVIRONMENT >> ~/.ssh/known_hosts
   bucc ssh "sudo fallocate -l ${VM_SWAP}M /var/vcap/store/swapfile"
   bucc ssh "sudo chmod 600 /var/vcap/store/swapfile"
   bucc ssh "sudo mkswap /var/vcap/store/swapfile"
   bucc ssh "sudo swapon /var/vcap/store/swapfile"
   bucc ssh "sudo swapon -s"

 else
   echo "Not adding swap space VM_SWAP [ $VM_SWAP ]"
 fi

}


function resetBOSHEnv() {
  unset BOSH_GW_HOST
  unset BOSH_GW_PRIVATE_KEY
  unset BOSH_GW_USER
  unset BOSH_CLIENT
  unset BOSH_ENVIRONMENT
  unset BOSH_CLIENT_SECRET
  unset BOSH_CA_CERT
}

function produceBOSHEnvVars() {
  echo "bosh_host: $BOSH_IP"
  echo "bosh_admin_password: $BOSH_CLIENT_SECRET"
  echo "bosh_disable_ssl_cert_verification: false"
  echo "bosh_root_ca_cert: |"
  sed 's/^/    /g' <<< "$BOSH_CA_CERT"
}

function bosh_lite_vm_syncdatetime() {

 DATE_STR=$( date -u +"%Y/%m/%d" )
 TIME_STR=$( date -u +"%H:%M:%S" )
 echo "Setting date and time of bosh-lite vm  [ $DATE_STR $TIME_STR ]"
 bucc ssh "sudo date --set $DATE_STR; sudo date --set $TIME_STR; date"

}
