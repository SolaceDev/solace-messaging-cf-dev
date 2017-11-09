#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BUILD_PACK_VERSION=3.13

export TEMP_DIR=$(mktemp -d)

function cleanupTemp() {
if [ -d $TEMP_DIR ]; then
   rm -rf $TEMP_DIR
   fi
}
trap cleanupTemp EXIT INT TERM HUP

source $SCRIPTPATH/cf-common.sh

pcfdev_login


function addBuildPack() {

   cf target -o system
   FOUND_BUILDPACK=$( cf buildpacks | grep java_buildpack_offline | grep java-buildpack-offline-v${BUILD_PACK_VERSION}.zip | wc -l )
   if [ "$FOUND_BUILDPACK" -eq "0" ]; then
      echo "Will make a new buildpack and add to pcfdev"
      ( 
        cd $WORKSPACE
        wget -O java-buildpack-${BUILD_PACK_VERSION}.tgz https://github.com/cloudfoundry/java-buildpack/archive/v${BUILD_PACK_VERSION}.tar.gz
	tar -xzf java-buildpack-${BUILD_PACK_VERSION}.tgz
	cd java-buildpack-${BUILD_PACK_VERSION}
	if [ -f $WORKSPACE/trusted.crt ]; then
		echo "Will add a CA trusted certificate to the JVM"
		mkdir -p resources/open_jdk_jre/lib/security
		keytool -keystore resources/open_jdk_jre/lib/security/cacerts -storepass changeit --importcert -noprompt -alias SolaceDevTrustedCert -file $WORKSPACE/trusted.crt
	fi
	bundle install
	bundle exec rake clean package OFFLINE=true PINNED=true
	cf create-buildpack  java_buildpack_offline build/java-buildpack-offline-v${BUILD_PACK_VERSION}.zip 0 --enable
      )
   else
	echo "Found java build pack there already :"
   	cf buildpacks | grep java_buildpack_offline | grep java-buildpack-offline-v${BUILD_PACK_VERSION}.zip 
   fi

}


function enableTcpRoutingForSolaceRouter() {

	TARGET=${1:-"uaa.local.pcfdev.io"}
	uaac target $TARGET --skip-ssl-validation
	uaac token client get admin -s admin-client-secret
        FOUND_CLIENT=$( uaac clients | grep name | grep solace_router | wc -l )

	if [ "$FOUND_CLIENT" -eq "0" ]; then

		echo "Adding solace_router client"

		uaac client add solace_router \
		  --name solace_router \
		  --scope uaa.none \
		  --authorized_grant_types "refresh_token,client_credentials" \
		  --authorities "routing.routes.read,routing.routes.write,routing.router_groups.read,cloud_controller.read,cloud_controller.write,cloud_controller.admin" \
		  -s "1234"
	else

		echo "Found solace_router in clients list ( uaac clients ) : "
		uaac clients | grep name | grep solace_router

	fi

	## Create tcp domain if needed
        TCP_DOMAIN=$( cf target | grep "api endpoint" | sed 's/https\:\/\/api/tcp/g' | sed 's/http\:\/\/api/tcp/g' | awk '{ print $3 }' )

	cf target -o system > /dev/null

	FOUND_COUNT=$(cf domains | grep "$TCP_DOMAIN" | wc -l )

	if [ $FOUND_COUNT -eq "0" ]; then
	  echo "Will create tcp domain: $TCP_DOMAIN"
	  cf create-shared-domain $TCP_DOMAIN --router-group default-tcp
	else
	  echo "tcp domain found : $TCP_DOMAIN"
	  cf domains | grep $TCP_DOMAIN 
	fi

}


addBuildPack
enableTcpRoutingForSolaceRouter

