#!/usr/bin/env bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

JAVA_BUILD_PACK_VERSION=${JAVA_BUILD_PACK_VERSION:-"4.8"}
TRUSTED_CERT_FILE="$WORKSPACE/trusted.crt"

cf target -o system
if [ ! -e $TRUSTED_CERT_FILE ]; then
	echo "Will generate $TRUSTED_CERT_FILE"
	CERTS_OPS_FILE="$SCRIPTPATH/../cf-solace-messaging-deployment/operations/example-vars-files/certs.yml"
	sed -n 'N; /solace_vmr_cert:\n  certificate:/,/-----END CERTIFICATE-----/ p' "$CERTS_OPS_FILE" > $TRUSTED_CERT_FILE
	sed -i '/cert_pem/d' $TRUSTED_CERT_FILE 
	sed -i '/certificate/d' $TRUSTED_CERT_FILE 
	sed -i 's/^[ \t]*//' $TRUSTED_CERT_FILE
fi

if [ ! -e $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip ]; then
	echo "Creating custom buildpack required for pcfdev"
	(
	 cd $WORKSPACE
	 rm -rf $WORKSPACE/java-buildpack-${JAVA_BUILD_PACK_VERSION}
	 rm -rf $WORKSPACE/java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz
	 wget -O java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz https://github.com/cloudfoundry/java-buildpack/archive/v${JAVA_BUILD_PACK_VERSION}.tar.gz
	 tar -xzf java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz
	 cd java-buildpack-${JAVA_BUILD_PACK_VERSION}

	 if [ -f $TRUSTED_CERT_FILE ]; then
		 echo "Will add the CA trusted certificate to the JVM: $TRUSTED_CERT_FILE"
		 mkdir -p resources/open_jdk_jre/lib/security
		 keytool -keystore resources/open_jdk_jre/lib/security/cacerts -storepass changeit --importcert -noprompt -alias SolaceDevTrustedCert -file $TRUSTED_CERT_FILE
	 fi
	 bundle install
	 bundle exec rake clean package OFFLINE=true PINNED=true
	 cp build/java-buildpack-offline-v${JAVA_BUILD_PACK_VERSION}.zip $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip
	 echo "Buildpack created: $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip"
	 echo "Cleaning unneeded buildpack working files"
	 rm -rf $WORKSPACE/java-buildpack-${JAVA_BUILD_PACK_VERSION}
	 rm -rf $WORKSPACE/java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz
	 )
	else
	echo "Will use buildpack: $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip" 
fi

cf buildpacks
FOUND_CF_BUILDPACK=$( cf buildpacks | grep java_buildpack | wc -l )
if [ "$FOUND_CF_BUILDPACK" -eq "0" ]; then
	echo "cf doesn't have the required buildpack, will create it"
	cf create-buildpack java_buildpack $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip 0 --enable
	else 
	echo "cf has a java-buildpack will update it"
	cf update-buildpack java_buildpack -p $WORKSPACE/java-buildpack-offline-custom-v${JAVA_BUILD_PACK_VERSION}.zip -i 0 --enable
fi
cf buildpacks

