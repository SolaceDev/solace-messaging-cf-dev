#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

BOSH_LITE_AWS=${BOSH_LITE_AWS:-$WORKSPACE/bosh-lite-aws}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ ! -d $BOSH_LITE_AWS ]; then
   mkdir -p $BOSH_LITE_AWS
fi

export REQUIRED_AWS_VARS="ACCESS_KEY_ID SECRET_ACCESS_KEY REGION AZ DEFAULT_KEY_NAME PRIVATE_KEY DEFAULT_SECURITY_GROUP SUBNET_ID EXTERNAL_IP"

export JUMPBOX_KEY=$BOSH_LITE_AWS/.jumpbox.key

export BOSH_CLIENT=admin
export BOSH_ENVIRONMENT=$EXTERNAL_IP

if [ -f $BOSH_LITE_AWS/creds.yml ]; then
  export BOSH_CLIENT_SECRET=$(bosh int $BOSH_LITE_AWS/creds.yml --path /admin_password)
  export BOSH_CA_CERT=$(bosh int $BOSH_LITE_AWS/creds.yml --path /director_ssl/ca)
fi

export BOSH_GW_HOST=$BOSH_ENVIRONMENT
export BOSH_GW_PRIVATE_KEY=$JUMPBOX_KEY
export BOSH_GW_USER=jumpbox

## Supports CF Deployment given EXTERNAL_IP
export SYSTEM_DOMAIN=${EXTERNAL_IP}.sslip.io
