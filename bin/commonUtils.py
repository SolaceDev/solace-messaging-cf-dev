from collections import namedtuple
import sys
import yaml

PoolType = namedtuple("PoolType", ["listName", "solaceDockerImageName", "haEnabled"])
POOL_TYPES = {
        "Shared-VMR": PoolType("shared", "latest-evaluation", False),
        "Medium-HA-VMR": PoolType("medium_ha", "latest-evaluation", True),
        "Large-VMR": PoolType("large", "latest-evaluation", False),
        "Large-HA-VMR": PoolType("large_ha", "latest-evaluation", True),
        "Community-VMR": PoolType("community", "latest-community", False)
}

def getPoolNames():
    print(" ".join(list(POOL_TYPES.keys())))

# Meant to be used with bash scripts
def isValidPoolName(poolName):
    print(int(poolName in POOL_TYPES))

def getSolaceDockerImageName(poolName):
    if poolName in POOL_TYPES:
        print(POOL_TYPES[poolName].solaceDockerImageName)
        sys.exit(0)
    raise ValueError("{} not a valid pool type".format(poolName))

def getHaEnabled(poolName):
    if poolName in POOL_TYPES:
        print(int(POOL_TYPES[poolName].haEnabled))
    else:
        raise ValueError("{} not a valid pool type".format(poolName))
        sys.exit(1)

def getManifestJobByName(manifestFile, jobName):
    with open(manifestFile, 'r') as f:
        jobs = yaml.load(f)["jobs"]
        job = next((j for j in jobs if j["name"] == jobName), None)

        if job != None:
            print(yaml.dump(job, default_flow_style=True))

def getManifestJobNames(manifestFile, vmrFilter=True):
    with open(manifestFile, 'r') as f:
        jobs = yaml.load(f)["jobs"]

        if vmrFilter:
            jobs = [j for j in jobs if "pool_name" in j["properties"]]

        jobNames = [j["name"] for j in jobs]
        print(" ".join(jobNames))

