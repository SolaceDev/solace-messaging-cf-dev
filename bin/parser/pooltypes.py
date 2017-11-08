import ipaddress
from solyaml import literal_unicode
from typing import Dict, Any, Optional, List
from schema import root

class PoolType:
    freeIpAddress = ipaddress.IPv4Address('10.244.0.3')
    SSH_PORT = 2222 #const
    def __init__(self, name : str, isHA : bool, solaceDockerImageName: str) -> None:
        self.name = name
        # HA is 3, non-HA is 1
        self.isHA = isHA
        self.solaceDockerImageName = solaceDockerImageName

    @classmethod
    def _allocateIpAddress(cls) -> ipaddress.IPv4Address:
        ipAddress = cls.freeIpAddress
        cls.freeIpAddress = cls.freeIpAddress + 1
        # The route for bosh-lite is only added for this subnet
        # All generated VMR IPs have to be on this subnet
        assert ipAddress in ipaddress.ip_network('10.244.0.0/16')
        return ipAddress

    def getNumInstances(self, commandLineArgs: Optional[int], numInstances : str) -> int:
        if commandLineArgs is not None:
            return int(commandLineArgs)
        returnValue = numInstances
        if numInstances == "automatic":
            returnValue = 1 if not self.isHA else 3
        return int(returnValue)


    def generateBoshLiteManifestJob(self, properties : Dict[str, Any], numInstances: int, inputFile : Dict[str, Any], inputMetaFile : Dict[str, Any], outFile: List[Dict[str, Any]]) -> None:
        if numInstances == 0:
            return
        output = {}
        output["name"] = self.name
        output["instances"] = numInstances 
        output["persistent_disk"] = 20480
        output["memory"] = 6144
        output["templates"] = []
        output["templates"].append({"name": "docker", "release": "docker"})
        output["templates"].append({"name": "prepare_vmr", "release": "solace-vmr"})
        output["templates"].append({"name": "containers", "release": "solace-vmr"})
        output["templates"].append({"name": "vmr_agent", "release": "solace-vmr"})
        output["properties"] = {}
        output["resource_pool"] = "common-resource-pool"
        output["networks"] = []
        output["networks"].append({})
        output["networks"][0]["name"] = "test-network"
        output["networks"][0]["static_ips"] = []
        for x in range(numInstances):
            output["networks"][0]["static_ips"].append(str(PoolType._allocateIpAddress()))
        output["properties"]["containers"] = []
        output["properties"]["containers"].append({})
        output["properties"]["containers"][0]["name"] = "solace"
        output["properties"]["containers"][0]["image"] = "solace-bosh"
        output["properties"]["containers"][0]["memory"] = "6G"
        output["properties"]["containers"][0]["uts"] = "host"
        output["properties"]["containers"][0]["privileged"] = True
        output["properties"]["containers"][0]["shm_size"] = "2G"
        output["properties"]["containers"][0]["net"] = "host"
        output["properties"]["containers"][0]["dockerfile"] = literal_unicode( \
"""          FROM solace-app:{}

          RUN \\
            echo '#!/bin/bash' > /sbin/dhclient && \\
            echo 'exit 0' >> /sbin/dhclient && \\
            echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
            chmod +x /sbin/dhclient""".format(self.solaceDockerImageName))
        output["properties"]["containers"][0]["env_vars"] = [
            "NODE_TYPE=MESSAGE_ROUTING_NODE",
            "SERVICE_SSH_PORT=" + str(self.SSH_PORT),
            "ALWAYS_DIE_ON_FAILURE=1",
            "USERNAME_ADMIN_PASSWORD=" + properties["admin_password"],
            "USERNAME_ADMIN_GLOBALACCESSLEVEL=admin"
        ]
        output["properties"]["containers"][0]["encrypted_vars"] = [
            "DEBUG_USERNAME_ROOT_ENCRYPTEDPASSWORD=solace1"
        ]
        output["properties"]["containers"][0]["volumes"] = [
            "/var/vcap/store/prepare_vmr/volumes/jail:/usr/sw/jail",
            "/var/vcap/store/prepare_vmr/volumes/var:/usr/sw/var",
            "/var/vcap/store/prepare_vmr/volumes/internalSpool:/usr/sw/internalSpool",
            "/var/vcap/store/prepare_vmr/volumes/adbBackup:/usr/sw/adb",
            "/var/vcap/store/prepare_vmr/volumes/adb:/usr/sw/internalSpool/softAdb"
        ]
        output["properties"].update(properties)
        output["properties"]["pool_name"] = self.name
        output["properties"]["admin_user"] = "admin"
        output["properties"]["vmr_agent_port"] = 18080
        output["properties"]["semp_port"] = 8080
        output["properties"]["semp_ssl_port"] = 943
        output["properties"]["ssh_port"] = self.SSH_PORT
        output["properties"]["heartbeat_rate"] = 15000
        output["properties"]["broker_user"] = "solacedemo"
        output["properties"]["broker_password"] = "solacedemo"
        output["properties"]["broker_hostname"] = "solace-messaging.local.pcfdev.io"
        output["properties"]["system_domain"] = "local.pcfdev.io"
        output["properties"]["cf_api_host"] = "api.local.pcfdev.io"
        output["properties"]["cf_client_id"] = "solace_router"
        output["properties"]["cf_client_secret"] = "1234"
        output["properties"]["cf_organization"] = "solace"
        output["properties"]["cf_space"] = "solace-messaging"
        output["properties"]["tls_cacert"] = """-----BEGIN CERTIFICATE-----
MIIDnzCCAoegAwIBAgIJAKEsd5V3+exFMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNV
BAYTAkNBMQswCQYDVQQIDAJPTjEPMA0GA1UEBwwGS2FuYXRhMQ8wDQYDVQQKDAZT
b2xhY2UxGTAXBgNVBAsMEENsb3VkSW50ZWdyYXRpb24xDDAKBgNVBAMMA1BvQzAg
Fw0xNjEwMjcxNzA3MDRaGA8yMTE2MTAwMzE3MDcwNFowZTELMAkGA1UEBhMCQ0Ex
CzAJBgNVBAgMAk9OMQ8wDQYDVQQHDAZLYW5hdGExDzANBgNVBAoMBlNvbGFjZTEZ
MBcGA1UECwwQQ2xvdWRJbnRlZ3JhdGlvbjEMMAoGA1UEAwwDUG9DMIIBIjANBgkq
hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4U3oyVABZuRGJoMzUX4y+KA6ImOucCQQ
pLK4X3ZQj4cBf3OGp0Z8eNePgHua2LId7qs4K3R2qWxQy3Mgl23FxO+XKzaEpCP+
RjRJAuN51rbrw5eqSbuNuOFyx6f8VWvxQK44EqqqhDMDPai+RwPZpVvEQ+kR7HTm
Krfp/goetgb94DmMqEJmBHvKWHIJZFC+ulyriX874X0ZIU3+w+3A1YDbv17SKCnU
/Oe8OJjMYJWdUEYCIaxWHzqbiXg5JluiEKx/gJNIJvhtry+kJMHCHR3lPAsG9EWP
UzvrjpkyUXbnnv+xDWFInEeuncpend5dMZlXhx+BXyptRoGjkSNTAQIDAQABo1Aw
TjAdBgNVHQ4EFgQUl58rrahDoyB48RKuOPzwggwdm40wHwYDVR0jBBgwFoAUl58r
rahDoyB48RKuOPzwggwdm40wDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOC
AQEAFsjDBYpiCNz462duzQdf5ZWXlDfcQ3BDuJe4OD+GlS1abOrwyyhxIcPmiewx
mV6jxfPWAcgr+4RuZ8bpschbKMdOLaBVrt5hMsnFXP32EmDIdZGygUy5ndlvEdtd
3J/Ct6S/BzhOiJ09DEzaLS4cg0AXIylCnF+gjglxfrn68ci+/dYpQ2IXqxrWpkpc
5I3CyDMVn5SAHw4WiVol3ZsmnL1IUsBT1NBSXFaCPL+ys5FRjkZbr7uygBaKPu7r
q8cMA/GaUHCCyf4F0DQcOs8HSmNDYVHkgsP1HKUra2dWjZcXwRkzAuoLJgspG1GK
3PVkdvOXQ9ROEMS+OQw0ubc0mQ==
-----END CERTIFICATE-----
"""
        output["properties"]["tls_cert"] = """-----BEGIN CERTIFICATE-----
MIIDnzCCAoegAwIBAgIJAKEsd5V3+exFMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNV
BAYTAkNBMQswCQYDVQQIDAJPTjEPMA0GA1UEBwwGS2FuYXRhMQ8wDQYDVQQKDAZT
b2xhY2UxGTAXBgNVBAsMEENsb3VkSW50ZWdyYXRpb24xDDAKBgNVBAMMA1BvQzAg
Fw0xNjEwMjcxNzA3MDRaGA8yMTE2MTAwMzE3MDcwNFowZTELMAkGA1UEBhMCQ0Ex
CzAJBgNVBAgMAk9OMQ8wDQYDVQQHDAZLYW5hdGExDzANBgNVBAoMBlNvbGFjZTEZ
MBcGA1UECwwQQ2xvdWRJbnRlZ3JhdGlvbjEMMAoGA1UEAwwDUG9DMIIBIjANBgkq
hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4U3oyVABZuRGJoMzUX4y+KA6ImOucCQQ
pLK4X3ZQj4cBf3OGp0Z8eNePgHua2LId7qs4K3R2qWxQy3Mgl23FxO+XKzaEpCP+
RjRJAuN51rbrw5eqSbuNuOFyx6f8VWvxQK44EqqqhDMDPai+RwPZpVvEQ+kR7HTm
Krfp/goetgb94DmMqEJmBHvKWHIJZFC+ulyriX874X0ZIU3+w+3A1YDbv17SKCnU
/Oe8OJjMYJWdUEYCIaxWHzqbiXg5JluiEKx/gJNIJvhtry+kJMHCHR3lPAsG9EWP
UzvrjpkyUXbnnv+xDWFInEeuncpend5dMZlXhx+BXyptRoGjkSNTAQIDAQABo1Aw
TjAdBgNVHQ4EFgQUl58rrahDoyB48RKuOPzwggwdm40wHwYDVR0jBBgwFoAUl58r
rahDoyB48RKuOPzwggwdm40wDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOC
AQEAFsjDBYpiCNz462duzQdf5ZWXlDfcQ3BDuJe4OD+GlS1abOrwyyhxIcPmiewx
mV6jxfPWAcgr+4RuZ8bpschbKMdOLaBVrt5hMsnFXP32EmDIdZGygUy5ndlvEdtd
3J/Ct6S/BzhOiJ09DEzaLS4cg0AXIylCnF+gjglxfrn68ci+/dYpQ2IXqxrWpkpc
5I3CyDMVn5SAHw4WiVol3ZsmnL1IUsBT1NBSXFaCPL+ys5FRjkZbr7uygBaKPu7r
q8cMA/GaUHCCyf4F0DQcOs8HSmNDYVHkgsP1HKUra2dWjZcXwRkzAuoLJgspG1GK
3PVkdvOXQ9ROEMS+OQw0ubc0mQ==
-----END CERTIFICATE-----
"""
        output["properties"]["tls_key"] = """-----BEGIN PRIVATE KEY-----
MIIEpQIBAAKCAQEA4U3oyVABZuRGJoMzUX4y+KA6ImOucCQQpLK4X3ZQj4cBf3OG
p0Z8eNePgHua2LId7qs4K3R2qWxQy3Mgl23FxO+XKzaEpCP+RjRJAuN51rbrw5eq
SbuNuOFyx6f8VWvxQK44EqqqhDMDPai+RwPZpVvEQ+kR7HTmKrfp/goetgb94DmM
qEJmBHvKWHIJZFC+ulyriX874X0ZIU3+w+3A1YDbv17SKCnU/Oe8OJjMYJWdUEYC
IaxWHzqbiXg5JluiEKx/gJNIJvhtry+kJMHCHR3lPAsG9EWPUzvrjpkyUXbnnv+x
DWFInEeuncpend5dMZlXhx+BXyptRoGjkSNTAQIDAQABAoIBACOGw3Qq922gBSfB
fHAXNDZcHY6apUDtjupJfCUhZOac5TGRp+Psi2gKpYge9XXB8FJYEU1Y2fUxLTRH
fRYjqxG4rd+UgynWuxua1wBrmiSvR1HaMnHZ7yj987lj1bgqgyotzo2y95xM5u/s
EcTk6IbYh4Ql1juw2zJVOcJjGiCdgdvgAcIvjSRT+sbBL4biw4BRajsX8t+xD73f
jOfK6RhroZgRgtYMYNsG4gtPoGErYyqNdsOccr81VDpo2HEcOxk1ymy/bea6hEBd
m3gNA/P23GUxycRcXd4Ki9GfW/XdnHDoGzLVonEJa7xz6uSuw6PhlxVH4+il7PJk
hDzsJqECgYEA9fak4D+0G7mEKDAec052etqPcjzZsPYUWdj2SLeVD/mF6IJDW+KI
efCxbzW53gBR91ugmwPxQ4Ti9CBpRNZlKcAPFEU7/S2Njfdc+i/QuQoZQW5Q1FHT
M70z9WHQFdmWy0D45gndAt9l93ZRRhn32oEsY/OjS6J69ghGOT/ELJ0CgYEA6n91
UgiBOhg0i/FubstUVbu1xn2XxRgzGpI7ZsrNfxU8jDEwZa9twbhWrUXQhWtq7eWR
mgWfK3usCxoOiXHJFNeN0jkQxiPErNAz4CrvDbUPboqKHXmeP8f2YGVJl5t1oW7P
DVTZaLM5Ss1PMlzqtr7DYkm84u8HBa15biWQaLUCgYEAmmWIG+iBM8IhjmSeSL1h
LD9UOl6uPCJMphXGi+EJpix4/Xn/tIcgKoOHrgqosQ28ZizTRVuVMFATczGBQx/e
AvY3wP6w6H2W1R4I9FfdironHmaUQKNYk6raGdebmouq183iL+zTGoGHbW6NGBcm
+beKWPfQcqL80sJg6oD3sRUCgYEAovjAJaoJfcGSy2uYj2G6k/boBzIEB5Og+KeG
pxLtLJQqx1fsRc9dHVQq0TODDyavYvS4c23SyFqkH/cVAUrWMCj6xI6qbLoxFtWA
KBxOlZ0vQ2j/Qiri43rqbOYX9kixwOcM+Tvt+QkOGUGE+ACBk04S5j1PC/yJSdXd
XcK3kT0CgYEAzle+WKkSCsQPMRcP+pWPBK4YGs/pi3fLYlNFN8dCZctLCVXIgXao
1CzB8vsEva40zy06xHaqbNNpnH0zI0dcsnRFWUqNilZnEYDYjVb0G8oEcNY9AEXm
P5Z/XHQfurMSM19OUK5EQrSvb7TZKcxV2m3ZBMXg7ccUjh+ZcR3X7rM=
-----END PRIVATE KEY-----
"""

        ## Custom generate
        customProperties = root.generateSelectorPropertiesFromCiFile(inputFile)
        output["properties"].update(customProperties)


        outFile["jobs"].append(output)

Shared = PoolType("Shared-VMR", False, "latest")
Community = PoolType("Community-VMR", False, "latest")
Large = PoolType("Large-VMR", False, "latest")
MediumHA = PoolType("Medium-HA-VMR", True, "latest")
LargeHA = PoolType("Large-HA-VMR", True, "latest")
