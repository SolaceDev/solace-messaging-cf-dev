#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}
export CF_SOLACE_MESSAGING_DEPLOYMENT_HOME=${CF_SOLACE_MESSAGING_DEPLOYMENT_HOME:-"$( cd $SCRIPTPATH/../cf-solace-messaging-deployment && pwd )"}

export CF_DEPLOYMENT=${CF_DEPLOYMENT:="cf"}
export CF_MYSQL_DEPLOYMENT=${CF_MYSQL_DEPLOYMENT:="cf-mysql"}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}
export VMR_EDITION=${VMR_EDITION:-"evaluation"}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

source $SCRIPTPATH/bosh-common.sh

function check_cf_deployment() {

 ## Check CF is deployed

 CF_FOUND=$( bosh deployments --json | jq '.Tables[].Rows[] | .name' | sed 's/\"//g' | grep "^$CF_DEPLOYMENT$" )

 if [ "$CF_FOUND" != "$CF_DEPLOYMENT" ]; then
    echo "The Cloud Foundry \"$CF_DEPLOYMENT\" deployment is not found, please deploy Cloud Foundry,  run \"$SCRIPTPATH/cf_deploy.sh\" "
    exit 1
 fi

}

function update_cloud_config() { 

 ## Upload Cloud Config to BOSH if windows deployment
 bosh update-cloud-config $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/iaas-support/bosh-lite/cloud-config.yml

}

function check_cf_mysql_deployment() {

 if [ -n "$USE_MYSQL_FOR_PCF" ]; then 
   ## Check CF-MYSQL is deployed

   CF_MYSQL_FOUND=$( bosh deployments --json | jq '.Tables[].Rows[] | .name' | sed 's/\"//g' | grep "^$CF_MYSQL_DEPLOYMENT$" )

   if [ "$CF_MYSQL_FOUND" != "$CF_MYSQL_DEPLOYMENT" ]; then
      echo "The Mysql Cloud Foundry \"$CF_MYSQL_DEPLOYMENT\" deployment is not found, please deploy Mysql for Cloud Foundry,  run \"$SCRIPTPATH/cf_mysql_deploy.sh\" "
      exit 1
   fi
 fi
}

function check_cf_marketplace_access() {

 if [ -n "$USE_MYSQL_FOR_PCF" ]; then
   ## Check that mysql deployment is present in CF Marketplace

   CF_MARKETPLACE_MYSQL_FOUND=$( cf target -o system > /dev/null; cf m | grep "p-mysql"  | wc -l )
   if [[ $CF_MARKETPLACE_MYSQL_FOUND -eq "0" ]]; then 
     echo "p-mysql service was not found in CF Marketplace, please check CF Marketplace and make sure MySQL deployment was successful."
     exit 1
   fi
 fi 

}

function checkDeploymentRequirements() {

 ## Check only when the deployment is on BOSH-Lite by setup_bosh_lite_vm.sh
 if [ -f $WORKSPACE/.boshvm ]; then
    check_cf_deployment
    check_cf_mysql_deployment
 else 
    update_cloud_config
 fi

 ## Check CF Access and CF marketplace for p-mysql

 check_cf_marketplace_access

 ## Check BOSH Stemcell is uploaded
 loadStemcells

}

function checkSolaceReleases() {

 SOLACE_PUBSUB_RELEASE_FOUND_COUNT=`bosh releases | grep -v solace-pubsub-broker | grep solace-pubsub | wc -l`

 if [ "$SOLACE_PUBSUB_RELEASE_FOUND_COUNT" -eq "0" ]; then
   echo "solace-pubsub release seem to be missing from bosh, please upload-release to bosh"
   echo 
   echo "TIP: To upload solace bosh releases use \"$SCRIPTPATH/solace_upload_releases.sh\" "
   exit 1
 fi

 SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-pubsub-broker | wc -l`

 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -eq "0" ]; then
   echo "solace-pubsub-broker release seem to be missing from bosh, please upload-release to bosh"
   echo 
   echo "TIP: To upload solace bosh releases use \"$SCRIPTPATH/solace_upload_releases.sh\" "
   exit 1
 fi

}

function showUsage() {
    echo
    echo "Usage: $CMD_NAME [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -h                        Show Command options "
    echo "  -e                        Is Enterprise mode"
    echo "  -s <starting_port>        Provide Starting Port "
    echo "  -p <vmr_admin_password>   Provide VMR Admin Password "
    echo "  -v <vars.yml>             Provide vars.yml file path "
    echo "  -t <tls_config.yml>       Provide TLS Config file path"
    echo "  -n                        Disable Service Broker TLS Certificate Validation"
    echo "  -a <syslog_config.yml>    Provide Syslog Config file path"
    echo "  -r <tcp_config.yml>       Provide TCP Routes Config file path" 
    echo "  -l <ldap_config.yml>      Provide LDAP Config file path"   
    echo "  -b                        Enable LDAP Management Authorization access" 
    echo "  -c                        Enable LDAP Application Authorization access" 
    echo "  -k                        Keep Errand(s) Alive" 
    echo "  -m                        Use MySQL For PCF"
    echo "  -y                        Deploy highly available internal mysql database"
    echo "  -z                        Use external mysql database"
    echo "  -x extra bosh params      Additional parameters to be passed to bosh"
}


while getopts "t:a:nbcr:l:s:p:v:x:ekmyzh" arg; do
    case "${arg}" in
        t) 
            TLS_PATH=$( echo $(cd $(dirname "$OPTARG") && pwd -P)/$(basename "$OPTARG") )
	    if [ ! -f $TLS_PATH ]; then
		       >&2 echo
       		       >&2 echo "File not found: $OPTARG" >&2
		       >&2 echo
		       exit 1
            fi
            ;;
        a)
            SYSLOG_PATH=$( echo $(cd $(dirname "$OPTARG") && pwd -P)/$(basename "$OPTARG") )
	    if [ ! -f $SYSLOG_PATH ]; then
		       >&2 echo
       		       >&2 echo "File not found: $OPTARG" >&2
		       >&2 echo
		       exit 1
            fi
            ;;
        n) 
            disablebrokertls=true
            ;; 
        b) 
            mldap=true
            ;;
        c) 
            aldap=true
            ;;
        r) 
            TCP_PATH=$( echo $(cd $(dirname "$OPTARG") && pwd -P)/$(basename "$OPTARG") )
	    if [ ! -f $TCP_PATH ]; then
		       >&2 echo
       		       >&2 echo "File not found: $OPTARG" >&2
		       >&2 echo
		       exit 1
            fi
            ;;
        l) 
            LDAP_PATH=$( echo $(cd $(dirname "$OPTARG") && pwd -P)/$(basename "$OPTARG") )
	    if [ ! -f $LDAP_PATH ]; then
		       >&2 echo
       		       >&2 echo "File not found: $OPTARG" >&2
		       >&2 echo
		       exit 1
            fi
            ;; 
        s)
            starting_port="$OPTARG"
	    ;;
        p)
            vmr_admin_password="${OPTARG}"
            ;;
        v)
            VARS_FILE=$( echo $(cd $(dirname "$OPTARG") && pwd -P)/$(basename "$OPTARG") )
	    if [ ! -f $VARS_FILE ]; then
		       >&2 echo
       		       >&2 echo "File not found: $OPTARG" >&2
		       >&2 echo
		       exit 1
            fi
            ;; 
        e) 
	    VMR_EDITION="enterprise"
            ;;
        x)
            EXTRA_BOSH_PARAMS="$OPTARG"
            ;; 
        k)  KEEP_ERRAND_ALIVE=true
            ;;
        m)  USE_MYSQL_FOR_PCF=true
            ;;
        y)  DEPLOY_HA_INTERNAL_MYSQL=true
            ;;
        z)  USE_EXTERNAL_MYSQL=true
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

if [ -z "$VARS_FILE" ]; then
   if [ ! -f $WORKSPACE/vars.yml ]; then
     cp $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/vars.yml $WORKSPACE
   fi
   VARS_FILE=$WORKSPACE/vars.yml
fi

if [ -n "$vmr_admin_password" ]; then
   grep -q 'vmr_admin_password' $VARS_FILE && sed -i "s/vmr_admin_password.*/vmr_admin_password: $vmr_admin_password/" $VARS_FILE || echo "vmr_admin_password: $vmr_admin_password" >> $VARS_FILE
fi

if [ -n "$starting_port" ]; then
   grep -q 'starting_port' $VARS_FILE && sed -i "s/starting_port.*/starting_port: $starting_port/" $VARS_FILE || echo "starting_port: $starting_port" >> $VARS_FILE
fi

if [ -n "$SYSLOG_PATH" ]; then
   ENABLE_SYSLOG_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/enable_syslog.yml"
   SYSLOG_VARS="-l $SYSLOG_PATH" 
fi

if [[ $KEEP_ERRAND_ALIVE == true ]]; then
   export ERRAND_PARAMS=" --keep-alive"
fi

if [ -n "$LDAP_PATH" ]; then 
   ENABLE_LDAP_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/enable_ldap.yml" 
   LDAP_VARS="-l $LDAP_PATH"
fi 

if [[ $mldap == true ]]; then 
   ENABLE_MANAGEMENT_ACCESS_LDAP_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/set_management_access_ldap.yml"
fi 

if [[ $disablebrokertls == true ]]; then 
   DISABLE_SERVICE_BROKER_CERTIFICATE_VALIDATION_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/disable_service_broker_certificate_validation.yml"
fi

if [ -n "$TLS_PATH" ]; then 
   SET_SOLACE_VMR_CERT_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/set_solace_vmr_cert.yml"
   TLS_VARS="-l $TLS_PATH" 
fi 

if [[ $aldap == true ]]; then
   ENABLE_APPLICATION_ACCESS_LDAP_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/set_application_access_ldap.yml" 
fi 

if [ -n "$TCP_PATH" ]; then
    ENABLE_TCP_ROUTES_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/enable_tcp_routes.yml"
    TCP_ROUTES_VARS="-l $TCP_PATH"
fi

# Solace deployment defaults to internal MySQL (non ha) if no MySQL option is specified
if [[ "$DEPLOY_HA_INTERNAL_MYSQL" == true ]]; then
    MYSQL_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/internal_mysql_ha.yml"
elif [[ "$USE_MYSQL_FOR_PCF" == true ]]; then
    MYSQL_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/mysql_for_pcf.yml"
elif [[ "$USE_EXTERNAL_MYSQL" == true ]]; then
    MYSQL_OPS="-o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/external_mysql.yml "
fi

checkSolaceReleases

export SOLACE_PUBSUB_RELEASES_LIST=$( bosh releases --json | jq -r '.Tables[].Rows[] | select((.name | contains("solace-pubsub")) and (.name | contains("solace-pubsub-broker") | not)) | .version' )
export SOLACE_PUBSUB_RELEASES=$( echo "$SOLACE_PUBSUB_RELEASES_LIST" | sort | sed 's/\*//g' | awk -vRS="" -vOFS=',' '$1=$1' )
export SOLACE_PUBSUB_RELEASE=$( echo "$SOLACE_PUBSUB_RELEASES_LIST" | sed 's/\*//g' | sort | tail -1 )
export TEMPLATE_VERSION=$( echo "$SOLACE_PUBSUB_RELEASE" | awk -F\- '{ print $1 }' )
export TEMPLATE_DIR=${TEMPLATE_DIR:-$SCRIPTPATH/../templates/$TEMPLATE_VERSION}

if [ ! -d "$TEMPLATE_DIR" ]; then
   echo "WARN: Unable to find template directory [$TEMPLATE_DIR] for Solace PubSub+ Release [$SOLACE_PUBSUB_RELEASE] from found release(s) [ $SOLACE_PUBSUB_RELEASES ], TEMPLATE VERSION [ $TEMPLATE_VERSION ]"
   exit 1
else
   echo "Deployment using Solace PubSub+ Release [$SOLACE_PUBSUB_RELEASE] from found release(s) [ $SOLACE_PUBSUB_RELEASES ] , TEMPLATE VERSION [ $TEMPLATE_VERSION ], template directory [$TEMPLATE_DIR]"
fi

OPS_BASE=${OPS_BASE:-" -o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/set_plan_inventory.yml -o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/bosh_lite.yml -o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/enable_global_access_to_plans.yml"}

FEATURES_OPS=${FEATURES_OPS:-"$ENABLE_LDAP_OPS $ENABLE_SYSLOG_OPS $ENABLE_MANAGEMENT_ACCESS_LDAP_OPS $ENABLE_APPLICATION_ACCESS_LDAP_OPS $SET_SOLACE_VMR_CERT_OPS $DISABLE_SERVICE_BROKER_CERTIFICATE_VALIDATION_OPS $ENABLE_TCP_ROUTES_OPS "}
FEATURES_VARS=${FEATURES_VARS:-"$TLS_VARS $TCP_ROUTES_VARS $SYSLOG_VARS $LDAP_VARS "}

VARS_STORE=${VARS_STORE:-"--vars-store $WORKSPACE/deployment-vars.yml "}

CMD_VARS=${CMD_VARS:="-v system_domain=$SYSTEM_DOMAIN -v app_domain=$SYSTEM_DOMAIN -v cf_deployment=$CF_DEPLOYMENT "}

MISC_VARS=${MISC_VARS:-""}

## If not defined and found in templates
if [ -z "$RELEASE_VARS" ] && [ -f "$TEMPLATE_DIR/release-vars.yml" ]; then
   RELEASE_VARS_FILE=$TEMPLATE_DIR/release-vars.yml
   RELEASE_VARS=" -l $TEMPLATE_DIR/release-vars.yml"
fi

if [ ! -z "$DEPLOYMENT_NAME" ]; then
   MISC_VARS="-v deployment_name=$DEPLOYMENT_NAME $MISC_VARS"
fi

if [ -z "$RELEASE_VARS" ]; then
  RELEASE_VARS_FILE=$CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/release-vars.yml
  RELEASE_VARS=" -l $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/release-vars.yml"
fi
# Accept if defined or default to the version from $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME

## 
# Handle stemcell loading based on release-vars contents
##
if [ -f "$RELEASE_VARS_FILE" ]; then
   # Find it or accept the default
   RELEASE_STEMCELL=$(bosh int $RELEASE_VARS_FILE --path /bosh_stemcell)
   RELEASE_STEMCELL_VERSION=$(bosh int $RELEASE_VARS_FILE --path /bosh_stemcell_version)

   ## Accept the default
   RELEASE_STEMCELL=${RELEASE_STEMCELL:-$STEMCELL}
   RELEASE_STEMCELL_VERSION=${RELEASE_STEMCELL_VERSION:-$STEMCELL_VERSION}

   if [ ! "$RELEASE_STEMCELL" == "$STEMCELL" ] || [ ! "$RELEASE_STEMCELL_VERSION" == "$STEMCELL_VERSION" ]; then
      export REQUIRED_STEMCELLS="$REQUIRED_STEMCELLS $RELEASE_STEMCELL:$RELEASE_STEMCELL_VERSION"
   fi
fi

BOSH_PARAMS=" $OPS_BASE $MYSQL_OPS $FEATURES_OPS -o $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/operations/is_${VMR_EDITION}.yml $VARS_STORE $CMD_VARS -l $VARS_FILE $FEATURES_VARS $RELEASE_VARS $MISC_VARS $EXTRA_BOSH_PARAMS"

