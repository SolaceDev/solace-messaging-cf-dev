import ipaddress
from solyaml import literal_unicode
from typing import Dict, Any, Optional, List
from schema import root
import yaml


class Errand:
    SSH_PORT = 2222 #const
    def __init__(self, name : str) -> None:
        self.name = name

    def generateBoshLiteManifestJob(self, properties : Dict[str, Any], inputFile : Dict[str, Any], inputMetaFile : Dict[str, Any], outFile: List[Dict[str, Any]]) -> None:

        ## Look for solace_messaging app_manifest to be used as starter
        for job_type in inputMetaFile["job_types"]:
           if job_type["name"] == self.name:
              errand_manifest_str = job_type["manifest"];
              errandManifest = yaml.load(errand_manifest_str)
              # print("Found my errand manifest " , errand_manifest_str  )


        output = {}
        output["name"] = self.name
        output["instances"] = 1
        output["lifecycle"] = "errand"
        output["templates"] = []
        output["templates"].append({"name": self.name, "release": "solace-messaging"})
        output["resource_pool"] = "common-resource-pool"
        output["networks"] = []
        output["networks"].append({})
        output["networks"][0]["name"] = "test-network"

        output["properties"] = {}
        output["properties"]["cf"] = {}
        output["properties"]["cf"]["admin_user"] = "admin"
        output["properties"]["cf"]["admin_password" ] = "admin"

        output["properties"]["domain"] = "local.pcfdev.io"
        output["properties"]["app_domains"] = []
        output["properties"]["app_domains"].append( "local.pcfdev.io" )

        output["properties"]["org"] = "solace"
        output["properties"]["space"] = "solace-messaging"

        output["properties"]["ssl"] = {}
        output["properties"]["ssl"]["skip_cert_verify"] = True

        output["properties"]["security"] = {}
        output["properties"]["security"]["user"] = "solacedemo"
        output["properties"]["security"]["password"] = "solacedemo"


        output["properties"]["solace_messaging"] = {}

        output["properties"]["solace_messaging"]["user"] = "solacedemo"
        output["properties"]["solace_messaging"]["password"] = "solacedemo"
        output["properties"]["solace_messaging"]["enable_global_access_to_plans"] = True


        # Test specific settings
        output["properties"]["solace_messaging"]["auto_services"] = []
        output["properties"]["solace_messaging"]["auto_services"].append({ "name": "p-mysql", "plan" : "1gb" } )

        ## Start with app_manifest of tile
        output["properties"]["solace_messaging"]["app_manifest"] = errandManifest["solace_messaging"]["app_manifest"]

        # Using 1GB
        output["properties"]["solace_messaging"]["app_manifest"]["memory"] = "1024M"


        ## TODO: See about adding generic manifest processing

        ## TODO: FIX ME, get these from the inputFile tcp routes cf credentials 
        output["properties"]["solace_messaging"]["app_manifest"]["env"]["SOLACE_ROUTER_CLIENT_ID"] = "solace_router"
        output["properties"]["solace_messaging"]["app_manifest"]["env"]["SOLACE_ROUTER_CLIENT_SECRET"] = "1234"


        output["properties"]["solace_vmr"] = {}

# Defaults for hosts
        output["properties"]["solace_vmr"]["shared_vmr"] = {}
        output["properties"]["solace_vmr"]["shared_vmr"]["host"] = []
        output["properties"]["solace_vmr"]["shared_vmr"]["hosts"] = []

        output["properties"]["solace_vmr"]["community_vmr"] = {}
        output["properties"]["solace_vmr"]["community_vmr"]["host"] = []
        output["properties"]["solace_vmr"]["community_vmr"]["hosts"] = []

        output["properties"]["solace_vmr"]["large_vmr"] = {}
        output["properties"]["solace_vmr"]["large_vmr"]["host"] = []
        output["properties"]["solace_vmr"]["large_vmr"]["hosts"] = []

        output["properties"]["solace_vmr"]["large_ha_vmr"] = {}
        output["properties"]["solace_vmr"]["large_ha_vmr"]["host"] = []
        output["properties"]["solace_vmr"]["large_ha_vmr"]["hosts"] = []

        output["properties"]["solace_vmr"]["medium_ha_vmr"] = {}
        output["properties"]["solace_vmr"]["medium_ha_vmr"]["host"] = []
        output["properties"]["solace_vmr"]["medium_ha_vmr"]["hosts"] = []

# Make VMR host and hosts list per
        for job in outFile["jobs"]:
           job_name = job["name"].lower().replace("-","_")
           # Skip Errands
           if job_name == self.name:
             continue
           if 'lifecycle' in job.keys() and job["lifecycle"] == "errand":
             continue
           host_list = []
           hosts_list = []
           output["properties"]["solace_vmr"][job_name] = {}
           output["properties"]["solace_vmr"][job_name]["host"] = []
           output["properties"]["solace_vmr"][job_name]["hosts"] = []
           for network in job["networks"]:
              for static_ip in network["static_ips"]:
                  hosts_list.append(static_ip)
                  if( len(host_list) < 1 ):
                    host_list.append(static_ip)
           if( len(host_list) > 0 ):           
             output["properties"]["solace_vmr"][job_name]["host"] = host_list
             output["properties"]["solace_vmr"][job_name]["hosts"] = hosts_list

# Simple/Flat properties
        output["properties"]["starting_port"] = properties["starting_port"]
        output["properties"]["vmr_admin_password"] = properties["admin_password"]

# Handle special structured properties ( tls_config, tcp_routes_config, ... )

## Custom generate
        customProperties = root.generateSelectorPropertiesFromCiFile(inputFile)
        output["properties"].update(customProperties)




## Add the job
        outFile["jobs"].append(output)

# Define the errands
deploy_all = Errand("deploy-all")
delete_all = Errand("delete-all")
