#!/bin/bash

export DEPLOYMENT_NAME="solace_pubsub"
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/bosh_deploy.log"}

######################################

export BOSH_IP=${BOSH_IP:-"192.168.50.6"}
export BOSH_CMD="/usr/local/bin/bosh"
export BOSH_CLIENT=${BOSH_CLIENT:-admin}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET:-admin}
export BOSH_NON_INTERACTIVE${BOSH_NON_INTERACTIVE:-true}
export BOSH_ENVIRONMENT=${BOSH_ENVIRONMENT:-"lite"}

export STEMCELL_VERSION=${STEMCELL_VERSION:-"3586.40"}
export STEMCELL=${STEMCELL:-"ubuntu-trusty"}

export REQUIRED_STEMCELLS=${REQUIRED_STEMCELLS:-"$STEMCELL:$STEMCELL_VERSION"}

export VM_MEMORY=${VM_MEMORY:-8192}
export VM_CPUS=${VM_CPUS:-4}
export VM_DISK_SIZE=${VM_DISK_SIZE:-"65_536"}
export VM_EPHEMERAL_DISK_SIZE=${VM_EPHEMERAL_DISK_SIZE:-"32_768"}
export VM_SWAP=${VM_SWAP:-8192}

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


function loadStemcells() { 

 for REQUIRED_STEMCELL in $REQUIRED_STEMCELLS; do

  export STEMCELL=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $1 }' )
  export STEMCELL_VERSION=$( echo "$REQUIRED_STEMCELL" | awk -F\: '{ print $2 }' )
  export STEMCELL_NAME="bosh-stemcell-${STEMCELL_VERSION}-warden-boshlite-${STEMCELL}-go_agent.tgz"
  export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"
  FOUND_STEMCELL=$( bosh stemcells | grep bosh-warden-boshlite-${STEMCELL}-go_agent | grep $STEMCELL_VERSION | wc -l)
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
 DEPLOYMENT_FOUND_COUNT=$(bosh deployments --json | jq '.Tables[].Rows[] | .name ' | sed 's/\"//g' | grep "^$SELECTED_DEPLOYMENT\$" | wc -l )
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ] && [ ! -z $ERRAND_NAME ]; then

  FOUND_ERRAND=$( bosh -d $SELECTED_DEPLOYMENT errands --json | jq ".Tables[].Rows[] | .name " | grep "$ERRAND_NAME" | wc -l )
  if [ $FOUND_ERRAND -eq "1" ]; then
     bosh -d $SELECTED_DEPLOYMENT run-errand $ERRAND_NAME
  else
     echo "Errand [$ERRAND_NAME] not found for deployment $SELECTED_DEPLOYMENT]"
  fi

 else
     echo "Deployment [$SELECTED_DEPLOYMENT] not found: $DEPLOYMENT_FOUND_COUNT, or missing required errand name [$ERRAND_NAME]"
 fi

}

function deleteSolaceDeployment() {
  SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}
  runErrand $SELECTED_DEPLOYMENT delete-all
  deleteDeployment $SELECTED_DEPLOYMENT
  deleteOrphanedDisks $SELECTED_DEPLOYMENT
}

function deleteDeployment() {

 SELECTED_DEPLOYMENT=${1:-$DEPLOYMENT_NAME}

 DEPLOYMENT_FOUND_COUNT=$(bosh deployments --json | jq '.Tables[].Rows[] | .name ' | sed 's/\"//g' | grep "^$SELECTED_DEPLOYMENT\$" | wc -l )
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then

  bosh -d $SELECTED_DEPLOYMENT delete-deployment

 else
     echo "Deployment [$SELECTED_DEPLOYMENT] not found: $DEPLOYMENT_FOUND_COUNT"
 fi

}

function deleteSolaceReleases() {

 SOLACE_PUBSUB_RELEASE_FOUND_COUNT=`bosh releases | grep -v solace-pubsub-broker | grep solace-pubsub | wc -l`
 if [ "$SOLACE_PUBSUB_RELEASE_FOUND_COUNT" -gt "0" ]; then
     # solace-pubsub
     echo "Deleting release solace-pubsub"
     bosh -n delete-release solace-pubsub
 else
     echo "No solace-pubsub release found: $SOLACE_PUBSUB_RELEASE_FOUND_COUNT"
 fi

 SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-pubsub-broker | wc -l`
 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -gt "0" ]; then
     # solace-pubsub-broker
     echo "Deleting release solace-pubsub-broker"
     bosh -n delete-release solace-pubsub-broker
 else
     echo "No solace-pubsub-broker release found: $SOLACE_MESSAGING_RELEASE_FOUND_COUNT"
 fi

}

function resume_bosh_lite_vm() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Starting [$BOSH_VM]"
        vboxmanage startvm $BOSH_VM --type headless
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi

}

function savestate_bosh_lite_vm() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Saving the state of [$BOSH_VM]"
        vboxmanage controlvm $BOSH_VM savestate
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi

}

function take_bosh_lite_vm_snapshot() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Taking snapshot of [$BOSH_VM] as $1"
        vboxmanage snapshot $BOSH_VM take $1
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi

}

function restore_bosh_lite_vm_snapshot() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Restoring snapshot of [$BOSH_VM] as $1"
        vboxmanage snapshot $BOSH_VM restore $1
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi

}

function list_bosh_lite_vm_snapshot() {

checkRequiredTools vboxmanage

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Listing snapshot of [$BOSH_VM]"
        vboxmanage snapshot $BOSH_VM list
   else
        echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
        exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi

}

function check_bucc() {

(
 cd $WORKSPACE
 if [ ! -d bucc ]; then
  git clone https://github.com/starkandwayne/bucc.git
 else
  (cd bucc; git pull)
 fi
)

export PATH=$PATH:$WORKSPACE/bucc/bin

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
sed -i "/vm_memory:/c\vm_memory: $VM_MEMORY" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_cpus:/c\vm_cpus: $VM_CPUS" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_ephemeral_disk:/c\vm_ephemeral_disk: $VM_EPHEMERAL_DISK_SIZE" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl

echo "vm_disk_size: $VM_DISK_SIZE" >> $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
cp -f $SCRIPTPATH/vm-size.yml $WORKSPACE/bucc/ops/cpis/virtualbox/

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

bucc env > $WORKSPACE/bosh_env.sh
echo "export PATH=\$PATH:$SCRIPTPATH" >> $WORKSPACE/bosh_env.sh

source $WORKSPACE/bosh_env.sh
echo "Updating runtime-config to activate bosh-dns" 
bosh -n update-runtime-config $SCRIPTPATH/runtime-config.yml
}

function bosh_lite_vm_additions() {

source $WORKSPACE/bosh_env.sh
setup_bosh_lite_routes
setup_bosh_lite_swap

}

function destroy_bosh_lite_vm() {

checkRequiredTools vboxmanage

check_bucc

source <($WORKSPACE/bucc/bin/bucc env)

if [ -d $WORKSPACE/bucc/state ] && [ -f $WORKSPACE/bucc/vars.yml ]; then
   $WORKSPACE/bucc/bin/bucc down && $WORKSPACE/bucc/bin/bucc clean
fi

if [ -f $WORKSPACE/bosh_env.sh ]; then
   rm -f $WORKSPACE/bosh_env.sh
fi

if [ -f $WORKSPACE/.bosh_env ]; then
   rm -f $WORKSPACE/.bosh_env
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

 check_bucc

 echo
 echo "Adding swap of $VM_SWAP. You may need to accept the authenticity of host $BOSH_GW_HOST when requested"
 echo

 echo "Adding $VM_SWAP of swap space"
 ssh-keygen -f ~/.ssh/known_hosts -R $BOSH_ENVIRONMENT
 ssh-keyscan -H $BOSH_ENVIRONMENT >> ~/.ssh/known_hosts
 bucc ssh "sudo fallocate -l ${VM_SWAP}M /var/vcap/store/swapfile"
 bucc ssh "sudo chmod 600 /var/vcap/store/swapfile"
 bucc ssh "sudo mkswap /var/vcap/store/swapfile"
 bucc ssh "sudo swapon /var/vcap/store/swapfile"
 bucc ssh "sudo swapon -s"

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
