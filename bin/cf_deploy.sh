#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}

export CF_DEPLOYMENT_VERSION=${CF_DEPLOYMENT_VERSION:-"v4.2.0"}

source $SCRIPTPATH/bosh-common.sh

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

if [ -f bosh_env.sh ]; then
 source bosh_env.sh
fi

if [ ! -d $WORKSPACE/cf-deployment ]; then
 ( cd $WORKSPACE; git clone https://github.com/cloudfoundry/cf-deployment.git )
fi

(cd $WORKSPACE/cf-deployment; git fetch --all; git checkout tags/$CF_DEPLOYMENT_VERSION)

cd $WORKSPACE/cf-deployment

loadStemcells

echo "Loading cloud-config iaas-support/bosh-lite/cloud-config.yml"
bosh update-cloud-config $SCRIPTPATH/../cf-solace-messaging-deployment/iaas-support/bosh-lite/cloud-config.yml

bosh -d cf deploy cf-deployment.yml \
	-o operations/bosh-lite.yml \
	-o operations/use-compiled-releases.yml \
	-o $SCRIPTPATH/operations/trusted_certs.yml \
	-o $SCRIPTPATH/operations/credhub.yml \
	--vars-store $WORKSPACE/deployment-vars.yml \
	-l $SCRIPTPATH/cf_trusted-ca-cert-for-apps.yml \
	-v system_domain=$SYSTEM_DOMAIN
        
if [ "$?" -ne "0" ]; then
  echo "ABORTING: cf-deployment was not successful"
  exit 1
fi

if [ -f $SCRIPTPATH/cf_env.sh ]; then
  $SCRIPTPATH/cf_env.sh 
[[ $? -eq 0 ]] && {
	echo "Create a system/system org and space"
	cf target -o system
	cf create-space system
	cf target -o system
	cf m
}
fi

## This is for development. Open up security groups to support easy deployment and testing.
if [ -f $SCRIPTPATH/apply_open_security_groups.sh ]; then
  $SCRIPTPATH/apply_open_security_groups.sh
fi

echo "Setup environment for TCP Routes" 
$SCRIPTPATH/setup_tcp_routing.sh

echo
echo "TIP: To deploy CF-MYSQL on bosh you should run \"$SCRIPTPATH/cf_mysql_deploy.sh\""
echo
