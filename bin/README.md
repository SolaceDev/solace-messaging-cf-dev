
To support testing a bosh release directly by developers and users of PCFDev.

Requires a [bosh-lite] (https://github.com/cloudfoundry/bosh-lite) 
- Assumes installation with default networking options. 
- Scripts need to be able to target bosh.


- The files in [templates](../templates/) are used to generate a bosh deployment manifest
- The [templates](../templates) contain parameters that assume you a locally accessible [PCF Dev](https://pivotal.io/pcf-dev)

## Scripts

All these scripts are independent of one another and are useable if adequate prerequirements are met.

Most of these scripts are accompanied by help messages that are retrievable using an `-h` option. Please consult those for more detailed information on their operations and usages.

### BOSH Deployment Scripts

#### High-Level BOSH Deployment Scripts

* deploy.sh
  * Depending on if the input is:
    1. A Config File  
      Pass it through `parser/converter.py` to convert it to a BOSH manifest saved to `$MANIFEST`.
    2. No Input  
      Uses a default Config file from templates.
  * Run `optimizeManifest.py`.
  * Run `deployBoshManifest.sh`.
  
* cleanup.sh
  * Runs `cleanupBoshDeployment.sh`.

* getBoshInfo.sh
  * Prints a basic summary of the live deployment or a provided BOSH manifest.

#### Modular BOSH Deployment Component Scripts

* optimizeManifest.py
  * Modifies the provided manifest file against the live deployment to maintain the following conditions:
    * If the given manifest contains VMR(s) that are already deployed, the manifest's VMR job(s) will reuse them.
    * If the given manifest does not contain VMR(s) that are deployed, modify the manifest's VMR job(s) such that they do not use the IPs of these to-be-deleted VMRs.

* deployBoshManifest.sh
  * Shutdowns all running VMRs if a deployment was already done.
  * Run `bosh_prepare.sh`.
  * Uploads/Upgrades the release to bosh.
  * Deploys the release according to the provided manifest.

* bosh_prepare.sh
  * prepares bosh-lite to use the solace bosh release, adds docker-bosh and stemcell.

* cleanupBoshDeployment.sh 
  * Shutdowns all running VMRs.
  * Deletes a recent deployment to bosh lite.
  * Deletes the release.
  * Deletes orphaned disks.

### Service Broker Scripts

* getServiceBrokerInfo.sh
  * Finds the service broker.
  * Queries and displays discovered information about the inventory under management by the service broker.
  
### Utility Scripts

* extract_tile.sh
  * Extracts the contents of a Solace Tile and keeps the necessary parts in `~/workspace/releases`.
