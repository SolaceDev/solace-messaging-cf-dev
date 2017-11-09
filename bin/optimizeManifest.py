#!/usr/bin/python3

import argparse
import ipaddress
import os
import subprocess
import yaml

import commonUtils

def getTestSubnets(manifest):
    foundNetworks = [s for s in manifest["networks"] if s["name"] == "test-network"]
    foundNetwork = foundNetworks[0]
    return foundNetwork["subnets"]

def getTestSubnet(manifest):
    return getTestSubnets(manifest)[0]

def getTestNetworkIps(manifest):
    testSubnets = getTestSubnets(manifest)
    testSubnet = testSubnets[0]
    otherSubnets = testSubnets[1:]

    testIpSubnet = ipaddress.ip_network(testSubnet["range"])
    otherIpSubnets = [ipaddress.ip_network(s["range"]) for s in otherSubnets]
    subnetGateway = testSubnet["gateway"]

    overlapOtherIpSubnets = [s for s in otherIpSubnets if testIpSubnet.overlaps(s)]
    for otherIpSubnet in overlapOtherIpSubnets:
        testIpSubnet = testIpSubnet.address_exclude(otherIpSubnet)

    testHosts = [h.exploded for h in testIpSubnet.hosts()]
    testHosts.remove(subnetGateway)
    return testHosts

def getDeployedIps(deploymentName):
    deploymentCount = subprocess.check_output("bosh -e lite deployments | grep {} | wc -l".format(deploymentName),
        shell=True, stderr=subprocess.DEVNULL)

    if int(deploymentCount) == 0:
        return None

    deployedManifest = yaml.load(
            subprocess.check_output("bosh -e lite -d {} manifest".format(deploymentName),
            shell=True, stderr=subprocess.DEVNULL))

    deployedIpConfig = {}
    deployedIpConfig["global"] = getTestSubnet(deployedManifest)["static"]
    deployedJobs = [j for j in deployedManifest["jobs"] if j["name"] in commonUtils.POOL_TYPES]

    for job in deployedJobs:
        jobIps = job["networks"][0]["static_ips"]
        deployedIpConfig[job["name"]] = jobIps

    return deployedIpConfig

def main(args):
    print("Optimizing manifest against active deployment...")
    manifestFile = args["manifest-file"]

    with open(manifestFile, 'r') as f:
        manifest = yaml.load(f)

    testSubnet = getTestSubnet(manifest)
    testSubnet["static"] = []

    freeIps = getTestNetworkIps(manifest)
    deployedIpConfig = getDeployedIps(manifest["name"])

    if deployedIpConfig is None:
        print("No active deployment found. No optimization to do...")
        return

    # Pre 1.1.0 Compatibility
    if len([j for j in manifest["jobs"] if j["name"] == "UpdateServiceBroker"]) > 0:
        testSubnet["static"] += [freeIps.pop(0)]

    print("Detected IPs that are already in use: {}".format(deployedIpConfig["global"]))
    print("Adjusting static network IPs to maximize VMR reuse and to resolve IP conflicts...\n")
    freeIps = list(set(freeIps) - set(deployedIpConfig["global"]))
    freeIps.sort()

    for job in manifest["jobs"]:
        if 'lifecycle' in job.keys() and job["lifecycle"] == "errand":
            continue

        poolName = job["name"]
        if poolName not in commonUtils.POOL_TYPES:
            continue

        numInstancesToAllocate = job["instances"]
        vmrIpList = []
        if poolName in deployedIpConfig:
            numToDelete = len(deployedIpConfig[poolName]) - job["instances"]
            if numToDelete > 0:
                del deployedIpConfig[poolName][-numToDelete]

            vmrIpList = deployedIpConfig[poolName]
            numInstancesToAllocate -= len(vmrIpList)
            print("Reusing {} deployed instance(s) of {}.".format(len(vmrIpList), poolName))

        newJobIps = freeIps[:numInstancesToAllocate]
        print("Allocating new static IPs to job {}: {}".format(poolName, newJobIps))
        vmrIpList += newJobIps
        del freeIps[:numInstancesToAllocate]

        job["networks"][0]["static_ips"] = vmrIpList
        testSubnet["static"] += vmrIpList

        # Update the errands with the ips
        for errand in manifest["jobs"]:
            if 'lifecycle' in errand.keys() and errand["lifecycle"] == "errand":
                errandName = errand["name"]
                jobName = job["name"].lower().replace("-","_")

                host_list = []
                host_list.append(vmrIpList[0])
                hosts_list = []
                hosts_list.extend(vmrIpList)

                print("Updating errand {}: {} host {}".format(errandName, jobName, host_list))
                print("Updating errand {}: {} hosts {}\n".format(errandName, jobName, hosts_list))
                errand["properties"]["solace_vmr"][jobName]["host"] = []
                errand["properties"]["solace_vmr"][jobName]["hosts"] = []
                errand["properties"]["solace_vmr"][jobName]["host"] = host_list 
                errand["properties"]["solace_vmr"][jobName]["hosts"] = hosts_list

    with open(manifestFile, 'w') as f:
        print(yaml.dump(manifest, default_flow_style=False), file=f)

    print("Finished optimizing manifest file.")
    print("{} was overwritten with the new manifest.".format(manifestFile))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Optimizes a bosh-lite manifest against the current deployed.')
    parser.add_argument(dest='manifest-file', help="Manifest file to optimize and overwrite")
    main(vars(parser.parse_args()))
