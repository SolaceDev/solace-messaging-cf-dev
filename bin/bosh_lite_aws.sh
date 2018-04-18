#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export BOSH_LITE_AWS=${BOSH_LITE_AWS:-$WORKSPACE/bosh-lite-aws}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ ! -d $BOSH_LITE_AWS ]; then
   mkdir -p $BOSH_LITE_AWS
fi

if [ ! -d $BOSH_LITE_AWS/bosh-deployment ]; then
   ( 
     cd $BOSH_LITE_AWS
     git clone https://github.com/cloudfoundry/bosh-deployment.git
   )
else
   ( 
     cd $BOSH_LITE_AWS/bosh-deployment
     git pull
   )
fi

source $SCRIPTPATH/bosh-common.sh

function run_bosh_aws_cmd() {

 if [ -z $1 ]; then
    echo "Need a bosh cmd to run"
    exit 1
 fi

 (
   cd $BOSH_LITE_AWS 
   bosh $1 bosh-deployment/bosh.yml \
    --state=state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o bosh-deployment/bosh-lite.yml \
    -o bosh-deployment/bosh-lite-runc.yml \
    -o bosh-deployment/jumpbox-user.yml \
    -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
    -v director_name=$DIRECTOR_NAME \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    -v access_key_id=$ACCESS_KEY_ID \
    -v secret_access_key=$SECRET_ACCESS_KEY \
    -v region=$REGION \
    -v az=$AZ \
    -v default_key_name=$DEFAULT_KEY_NAME \
    -v default_security_groups="[$DEFAULT_SECURITY_GROUP]" \
    --var-file private_key=$PRIVATE_KEY \
    -v subnet_id=$SUBNET_ID \
    -v external_ip=$EXTERNAL_IP
 )

}

function showUsage() {
    echo
    echo "Usage: $SCRIPT [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -h                   Show Command options "
    echo "  -c                   Creates the BOSH-lite AWS VM"
    echo "  -d                   Destroys the BOSH-lite AWS VM"
}


function create_bosh_lite_aws() {
    run_bosh_aws_cmd create-env 

}

function load_bosh_aws_env() {

    source $SCRIPTPATH/bosh_aws_env.sh

    ## Setup bosh env alias and capture $JUMPBOX_KEY
    bosh alias-env bosh-lite-aws -e $BOSH_ENVIRONMENT --ca-cert "$BOSH_CA_CERT"

}

function destroy_bosh_lite_vm() {
    load_bosh_aws_env
    run_bosh_aws_cmd delete-env 
    if [ -f $BOSH_LITE_AWS/creds.yml ]; then
       rm -f $BOSH_LITE_AWS/creds.yml
    fi
    if [ ! -f $JUMPBOX_KEY ]; then
         rm -f $JUMPBOX_KEY
    fi
}

checkRequiredVariables $REQUIRED_AWS_VARS

while getopts "hcdsrn" arg; do
    case "${arg}" in
        c)
	    ## Create the VM and do additional tasks
	    create_bosh_lite_aws
            load_bosh_aws_env

	    echo
	    echo "TIP: To access bosh you should \"source $SCRIPTPATH/bosh_aws_env.sh\""
	    echo
	    echo "TIP: To deploy Cloud Foundry on bosh you should run \"$SCRIPTPATH/cf_deploy.sh\""
	    echo
            ;;
        d) 
	    destroy_bosh_lite_vm
            ;;
        h)
            showUsage
            exit 0
            ;;
       \?)
       >&2 echo
       >&2 echo "Invalid option: -$OPTARG" >&2
       >&2 echo
       showUsage
       exit 1
       ;;
    esac
done

