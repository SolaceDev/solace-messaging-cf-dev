This directory contains all the source code for converting a tile configuration file to its equivalent BOSH manifest.

## General Usage
```
./converter.py --in-file="~/workspace/some-tile-config.yml" --out-file="~/workspace/bosh_manifest_file.yml"
```

If `--out-file` is not provided, this script will output the file to `./output/manifest.out.yml` by default.

## Modifying The Converter

These core files are those which can be modified to manipulate conversion process and output:

* converter.py
  * The call-able converter script itself.
  * Contains the non-job-specific static properties for the BOSH manifest file.
  * Also sets the global static IPs for the test-network.
  
* pooltypes.py
  * Contains the BOSH manifest structure of the job for each of the solace-messaging pools.
  * Manages pool-specific data such as its name, whether or not its HA, and the docker image name for this pool.
  
* root.py
  * Contains the high-level function for extracting data from the tile config file and creating the necessary data structure needed to generate the BOSH manifest.
  
* schema.py
  * The validation file used for validating the properties given to the converter.
  * Don't know if this is actually used. If not, we should consider removing it...
  
## Proposed Changes
Removing the capability to change the number of VMR instances for each pool at execution-time, thereby making this converter much more purer and simpler.
