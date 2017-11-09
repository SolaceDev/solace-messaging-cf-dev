#!/usr/bin/env bash

####################################### GLOBALS ###########################################

SHARED_PLAN="af308299-102f-47a3-acb0-7de72be192bf"
SHARED_POOL_NAME="Shared-VMR"
LARGE_PLAN="9bd51219-9cee-4570-99ab-ebe80d82c854"
LARGE_POOL_NAME="Large-VMR"
COMMUNITY_PLAN="c1589346-ca21-4d64-8c31-330d5fb07a58"
COMMUNITY_POOL_NAME="Community-VMR"
MEDIUM_HA_PLAN="9f57fa1c-7bb1-4a48-a651-d0c560fb5730"
MEDIUM_HA_POOL_NAME="Medium-HA-VMR"
LARGE_HA_PLAN="6a833e3f-3a24-419d-94d9-4bb38dc51f04"
LARGE_HA_POOL_NAME="Large-HA-VMR"

export PAIRS_PARAM="includeMonitor=false"
export MONITOR_PARAM="includeBackup=false&includePrimary=false"
export PRIMARY_PARAM="includeMonitor=false&includeBackup=false"
export BACKUP_PARAM="includeMonitor=false&includePrimary=false"

export SB_ORG=${SB_ORG:-"solace"}
export SB_SPACE=${SB_SPACE:-"solace-messaging"}

export TEST_ORG=${TEST_ORG:-"solace-test"}
export TEST_SPACE=${TEST_SPACE:-"test"}

####################################### FUNCTIONS ###########################################

function log() {
 echo ""
 echo `date` $1
}


function confirmServiceBrokerRunning() {

    getServiceBrokerDetails

    ## Lookup again to confirm and use for message
    SB_RUNNING=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep started | wc -l`
    if [ "$SB_RUNNING" -eq "1" ]; then
      log "confirmServiceBrokerRunning : Service Broker is running"
    else
      log "confirmServiceBrokerRunning : Service Broker is NOT running"
    fi
    ## Will cause an exit in testing ( set -e )
    cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | grep started
    export SB_APP=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | grep started | awk '{ print $1}'`
}

function getServiceBrokerDetails() {
 
 switchToServiceBrokerTarget

 SB_FOUND=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | wc -l`
 SB_RUNNING=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep started | wc -l`

 if [ "$SB_FOUND" -eq "1" ]; then
  ## Capture a few details from the service broker
   export SB_APP=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | awk '{ print $1}'`
   export SB_URL=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep $SB_APP | awk '{ print $6}'`
   export SECURITY_USER_NAME=`cf env $SB_APP | grep SECURITY_USER_NAME | awk '{ print $2}'`
   export SECURITY_USER_PASSWORD=`cf env $SB_APP | grep SECURITY_USER_PASSWORD | awk '{ print $2}'`
   export VMR_SUPPORT_PASSWORD=`cf env $SB_APP | grep VMR_SUPPORT_PASSWORD | awk '{ print $2}'`
   export VMR_SUPPORT_USER=`cf env $SB_APP | grep VMR_SUPPORT_USER | awk '{ print $2}'`
   export VMR_ADMIN_PASSWORD=`cf env $SB_APP  | grep VMR_ADMIN_PASSWORD | awk '{print $2}'`
   export VMR_ADMIN_USER=`cf env $SB_APP  | grep VMR_ADMIN_USER | awk '{print $2}'`
   export STARTING_PORT=`cf env $SB_APP | grep STARTING_PORT | awk '{print $2}'`
   export SB_BASE=$SECURITY_USER_NAME:$SECURITY_USER_PASSWORD@$SB_URL
 fi

 if [ "$SB_RUNNING" -eq "1" ]; then
    lookupServiceBrokerVMRs
 fi


}

function lookupServiceBrokerDetails() {

 getServiceBrokerDetails

 if [ "$SB_FOUND" -eq "1" ]; then
 log "ServiceBroker $SB_APP: http://${SB_URL}"
 log "Servicebroker URL BASE: ${SB_BASE} "

 if [ "$SB_RUNNING" -eq "1" ]; then
    lookupServiceBrokerVMRs
    log "Servicebroker LARGE_VMR_LIST: ${LARGE_VMR_LIST} "
    log "Servicebroker SHARED_VMR_LIST: ${SHARED_VMR_LIST} "
    log "Servicebroker COMMUNITY_VMR_LIST: ${COMMUNITY_VMR_LIST} "
    log "Servicebroker LARGE_HA_VMR_LIST: ${LARGE_HA_VMR_LIST} "
    log "Servicebroker LARGE_HA_VMR_PAIRS_LIST: ${LARGE_HA_VMR_PAIRS_LIST} "
    log "Servicebroker LARGE_HA_VMR_PRIMARY_LIST: ${LARGE_HA_VMR_PRIMARY_LIST} "
    log "Servicebroker LARGE_HA_VMR_BACKUP_LIST: ${LARGE_HA_VMR_BACKUP_LIST} "
    log "Servicebroker LARGE_HA_VMR_MONITOR_LIST: ${LARGE_HA_VMR_MONITOR_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_LIST: ${MEDIUM_HA_VMR_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_PAIRS_LIST: ${MEDIUM_HA_VMR_PAIRS_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_PRIMARY_LIST: ${MEDIUM_HA_VMR_PRIMARY_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_BACKUP_LIST: ${MEDIUM_HA_VMR_BACKUP_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_MONITOR_LIST: ${MEDIUM_HA_VMR_MONITOR_LIST} "
    log "Servicebroker ALL_VMR_LIST: ${ALL_VMR_LIST} "
    getServiceBrokerRouterInventory
    log "Servicebroker AvailabilityZones ${AVAILABILITY_ZONE_COUNT} : ${AVAILABILITY_ZONES} "
 else
    log "Servicebroker $SB_APP is not running"
 fi

 else
   log "Could not find solace-messaging in the current cloud-foundry environment"
 fi

}

function lookupServiceBrokerVMRs() {
 
 INFO_DATA=`curl -sX GET $SB_BASE/info` 

 # Pre 1.1.0 backwards compatibility
 if [ "$(echo $INFO_DATA | jq length)" == "0" ]; then
  deprecated_lookupServiceBrokerVMRs
  return
 fi

 ROUTERS_DATA=`echo $INFO_DATA | jq -c ".messageRouters"`
  
 export ALL_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA       | jq -c '.[] | .sshLink'))
 export SHARED_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA    | jq -c 'map(select(.poolName == "Shared-VMR"))'    | jq -c '.[] | .sshLink'))
 export LARGE_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA     | jq -c 'map(select(.poolName == "Large-VMR"))'     | jq -c '.[] | .sshLink'))
 export COMMUNITY_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Community-VMR"))' | jq -c '.[] | .sshLink'))
 
 export MEDIUM_HA_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Medium-HA-VMR"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_VMR_PAIRS_LIST=$(formatVMRList $(echo $ROUTERS_DATA   | jq -c 'map(select(.poolName == "Medium-HA-VMR" and .role != "monitor"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_VMR_PRIMARY_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Medium-HA-VMR" and .role == "primary"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_VMR_BACKUP_LIST=$(formatVMRList $(echo $ROUTERS_DATA  | jq -c 'map(select(.poolName == "Medium-HA-VMR" and .role == "backup"))'  | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_VMR_MONITOR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Medium-HA-VMR" and .role == "monitor"))' | jq -c '.[] | .sshLink'))
 
 export LARGE_HA_VMR_LIST=$(formatVMRList $(echo $ROUTERS_DATA         | jq -c 'map(select(.poolName == "Large-HA-VMR"))'                        | jq -c '.[] | .sshLink'))
 export LARGE_HA_VMR_PAIRS_LIST=$(formatVMRList $(echo $ROUTERS_DATA   | jq -c 'map(select(.poolName == "Large-HA-VMR" and .role != "monitor"))' | jq -c '.[] | .sshLink'))
 export LARGE_HA_VMR_PRIMARY_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Large-HA-VMR" and .role == "primary"))' | jq -c '.[] | .sshLink'))
 export LARGE_HA_VMR_BACKUP_LIST=$(formatVMRList $(echo $ROUTERS_DATA  | jq -c 'map(select(.poolName == "Large-HA-VMR" and .role == "backup"))'  | jq -c '.[] | .sshLink'))
 export LARGE_HA_VMR_MONITOR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "Large-HA-VMR" and .role == "monitor"))' | jq -c '.[] | .sshLink'))
}

#Deprecated 1.1.0
function deprecated_lookupServiceBrokerVMRs() {

 export ALL_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links`
 export SHARED_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$SHARED_PLAN`
 export LARGE_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_PLAN`
 export COMMUNITY_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$COMMUNITY_PLAN`
 export MEDIUM_HA_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN`
 export MEDIUM_HA_VMR_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PAIRS_PARAM`
 export MEDIUM_HA_VMR_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PRIMARY_PARAM`
 export MEDIUM_HA_VMR_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$BACKUP_PARAM`
 export MEDIUM_HA_VMR_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$MONITOR_PARAM`
 export LARGE_HA_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN`
 export LARGE_HA_VMR_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PAIRS_PARAM`
 export LARGE_HA_VMR_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PRIMARY_PARAM`
 export LARGE_HA_VMR_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$BACKUP_PARAM`
 export LARGE_HA_VMR_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$MONITOR_PARAM`

}

function formatVMRList() {
  # Echos formatted results from jq
  echo `echo "$@" | tr -d "\"\n\r" | tr " " ","`
}

function showServiceBrokerVMRs() {

 log "ServiceBroker: VMR Lists "
 echo "ALL_VMR_LIST=${ALL_VMR_LIST}"
 echo "SHARED_VMR_LIST=${SHARED_VMR_LIST}"
 echo "LARGE_VMR_LIST=${LARGE_VMR_LIST}"
 echo "COMMUNITY_VMR_LIST=${COMMUNITY_VMR_LIST}"
 echo "MEDIUM_HA_VMR_LIST=${MEDIUM_HA_VMR_LIST}"
 echo "MEDIUM_HA_VMR_PAIRS_LIST=${MEDIUM_HA_VMR_PAIRS_LIST}"
 echo "MEDIUM_HA_VMR_PRIMARY_LIST=${MEDIUM_HA_VMR_PRIMARY_LIST}"
 echo "MEDIUM_HA_VMR_BACKUP_LIST=${MEDIUM_HA_VMR_BACKUP_LIST}"
 echo "MEDIUM_HA_VMR_MONITOR_LIST=${MEDIUM_HA_VMR_MONITOR_LIST}"
 echo "LARGE_HA_VMR_LIST=${LARGE_HA_VMR_LIST}"
 echo "LARGE_HA_VMR_PAIRS_LIST=${LARGE_HA_VMR_PAIRS_LIST}"
 echo "LARGE_HA_VMR_PRIMARY_LIST=${LARGE_HA_VMR_PRIMARY_LIST}"
 echo "LARGE_HA_VMR_BACKUP_LIST=${LARGE_HA_VMR_BACKUP_LIST}"
 echo "LARGE_HA_VMR_MONITOR_LIST=${LARGE_HA_VMR_MONITOR_LIST}"

}

function checkServiceBrokerRepoStats() {

 log "ServiceBroker: Repo stats $1"
 curl -sX GET $SB_BASE/solace/status/repositories -H "Content-Type: application/json;charset=UTF-8"

 # TODO: Add some parameter driven assertions later

}

function checkServiceBrokerServicePlanStats() {

 # Just output for logging for now
 log "ServiceBroker: service plan stats $1"
 curl -sX GET $SB_BASE/solace/status -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: shared plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$SHARED_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$LARGE_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: community plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$COMMUNITY_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: medium-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$MEDIUM_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$LARGE_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"

 getServiceBrokerMessageRoutersSummary $1

 # TODO: Add some parameter driven assertions later

}

function getServiceBrokerRouterInventory() {

  export INVENTORY_RESPONSE=$(curl -sX GET $SB_BASE/solace/resources/solace_message_routers/inventory -H "Content-Type: application/json;charset=UTF-8")
  export AVAILABILITY_ZONES=$( echo $INVENTORY_RESPONSE | jq ".routerInventory[].haGroups[].availabilityZones"  | grep -v "\[" | grep -v "\]" | sort | uniq )
  export AVAILABILITY_ZONE_COUNT=$( echo $AVAILABILITY_ZONES | tr ',' '\n' | wc -l )

}

function showServiceBrokerRouterInventory() {

  getServiceBrokerRouterInventory

  log "ServiceBroker inventory view"
  echo
  echo $INVENTORY_RESPONSE
  echo 
  echo "Availability Zones: $AVAILABILITY_ZONE_COUNT"
  echo $AVAILABILITY_ZONES
  echo
}

function getServiceBrokerMessageRoutersSummary() {

 log "ServiceBroker: Message Routers Summary $1"
 echo
 curl -sX GET $SB_BASE/solace/resources/solace_message_routers/summary -H "Content-Type: application/json;charset=UTF-8"
 echo

}

function getServiceBrokerRouters() {

 log "ServiceBroker: Message Routers Details"
 echo
 export SERVICE_BROKER_DETAILS=`curl -sX GET $SB_BASE/solace/resources/solace_message_routers/details -H "Content-Type: application/json;charset=UTF-8"`
 echo
 
 # Show summary after the details
 getServiceBrokerMessageRoutersSummary

}

####################################### TEST FUNCTIONS ###########################################

function switchToOrgAndSpace() {

 FOUND_ORG=0
 for ORG in $(cf orgs | grep -v "Getting" | grep -v "^name"); do
    if [ "$ORG" == "$1" ]; then
       FOUND_ORG=1
    fi
 done

 if [ "$FOUND_ORG" -eq "0" ]; then
   log "Will create and target org: $1"
   cf create-org $1 > /dev/null
 fi

 cf target -o $1 > /dev/null

 FOUND_SPACE=0
 for SPACE in $(cf spaces | grep -v "Getting" | grep -v "^name"); do
    if [ "$SPACE" == "$2" ]; then
       FOUND_SPACE=1
    fi
 done

 if [ "$FOUND_SPACE" -eq "0" ]; then
   log "Will create and target space: $2"
   cf create-space $2 > /dev/null
 fi

 cf target -o $1 -s $2 > /dev/null
 if [ $? -ne 0 ]; then
    log "FAILED: cf target -o $1 -s $2"
 fi

}

function switchToTestOrgAndSpace() {

 switchToOrgAndSpace $TEST_ORG $TEST_SPACE

}

function enableAndShowInMarketPlace() {

 ## Checking Marketplace
 log "Enabling access to the Solace Service Broker provided service: solace-messaging"
 cf enable-service-access solace-messaging

 log "Marketplace:"
 cf m

 #todo: Need to install tile for this check to work (enable_global_access_to_plans)
 # Rely on grep's non-0 exit code to fail script

 log "Checking marketplace for solace service: solace-messaging"
 cf m | grep solace-messaging
 log "Checking marketplace for solace service plan: shared"
 cf m | grep shared 
 log "Checking marketplace for solace service plan: large"
 cf m | grep large
 log "Checking marketplace for solace service plan: community"
 cf m | grep community
 log "Checking marketplace for solace service plan: medium-ha"
 cf m | grep medium-ha
 log "Checking marketplace for solace service plan: large-ha"
 cf m | grep large-ha

 log "Checking marketplace for solace service plan: shared, free"
 cf m -s solace-messaging | grep shared | grep free
 log "Checking marketplace for solace service plan: large, free"
 cf m -s solace-messaging | grep -v large-ha | grep large | grep free
 log "Checking marketplace for solace service plan: community, free"
 cf m -s solace-messaging | grep community | grep free
 log "Checking marketplace for solace service plan: medium-ha, free"
 cf m -s solace-messaging | grep medium-ha | grep free
 log "Checking marketplace for solace service plan: large-ha, free"
 cf m -s solace-messaging | grep large-ha | grep free

}

function switchToServiceBrokerTarget() {
        switchToOrgAndSpace $SB_ORG $SB_SPACE
}

function restartServiceBroker() {
 	switchToServiceBrokerTarget
	cf restart $SB_APP
}


function pcfdev_login() {
 export PCFDEV=0 
 cf api https://api.local.pcfdev.io --skip-ssl-validation > /dev/null
 if [ $? -eq 0 ]; then
    cf auth admin admin > /dev/null
    if [ $? -eq 0 ]; then
       export PCFDEV=1 
    else
       export PCFDEV=0 
    fi
 else
   export PCFDEV=0 
 fi

}

