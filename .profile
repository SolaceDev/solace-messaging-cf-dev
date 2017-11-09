##

export SOLACE_MESSAGING_CF_DEV=$HOME/solace-messaging-cf-dev

export PATH=$SOLACE_MESSAGING_CF_DEV/bin:$PATH

## Just in case
chmod +x $SOLACE_MESSAGING_CF_DEV/bin/*.sh

echo
echo
cat $SOLACE_MESSAGING_CF_DEV/.banner
echo
echo

printf "SOLACE_MESSAGING_CF_DEV\t\t%s\n" "$SOLACE_MESSAGING_CF_DEV"

# Used by most scripts
export WORKSPACE=$HOME/workspace

printf "WORKSPACE\t\t\t%s\n" "$WORKSPACE"

## Test PCF Dev access

CF_API_FOUND=$( cf api | grep "api endpoint" | grep http | wc -l )

if [ "$CF_API_FOUND" -eq "0" ]; then

   printf  "PCFDev \t\t\t\t%s\n" "Access attempt (may take some time)"

   ping -q -c 5 -w 10 api.local.pcfdev.io > /dev/null
   if [ $? -eq "0" ]; then
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
   else
     export PCFDEV=0
   fi

   if [ $PCFDEV -eq "1" ]; then
    printf  "PCFDev \t\t\t\t%s\n" "OK"
   else
    printf  "PCFDev \t\t\t\t%s\n" "WARN: PCFDev is not accessible. Is it installed? running? is routing enabled?"
   fi

else
  CF_API=$( cf api | grep "api endpoint" | grep http )
  printf  "PCFDev \t\t\t\t%s\n" "You seem to have CF setup to access ( $CF_API )"
  export PCFDEV=1
fi




## Test BOSH-Lite access

export BOSH_CMD="/usr/local/bin/bosh"
export BOSH_CLIENT=${BOSH_CLIENT:-admin}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET:-admin}

function targetBosh() {
  
  if [ ! -d $HOME/bosh-lite ]; then
     (cd $HOME; git clone https://github.com/cloudfoundry/bosh-lite.git)
  fi

 # bosh target 192.168.50.4 alias as 'lite'
 BOSH_TARGET_LOG=$( $BOSH_CMD alias-env lite -e 192.168.50.4 --ca-cert=~/bosh-lite/ca/certs/ca.crt --client=admin --client-secret=admin  )
  if [ $? -eq 0 ]; then
    BOSH_LOGIN_LOG=$( BOSH_CLIENT=$BOSH_CLIENT BOSH_CLIENT_SECRET=$BOSH_CLIENT_SECRET $BOSH_CMD -e lite log-in )
    if [ $? -eq 0 ]; then
       export BOSHLITE=1
    else
       export BOSHLITE=0
       echo $BOSH_LOGIN_LOG
    fi
  else
     export BOSHLITE=0
     echo $BOSH_TARGET_LOG
  fi

}

export BOSHLITE=0
printf "BOSH-lite\t\t\t%s\n" "Access attempt (may take some time)"

ping -q -c 5 -w 10 192.168.50.4 > /dev/null
if [ $? -eq "0" ]; then
  targetBosh
else
  export BOSHLITE=0
fi

if [ $BOSHLITE -eq "1" ]; then
    printf "BOSH-lite\t\t\t%s\n" "OK"
else
    printf "BOSH-lite\t\t\t%s\n" "WARN: BOSH-lite is not accessible. Is it installed ? running? is routing enabled?"
fi

echo

