from collections import OrderedDict
from typing import Dict, Any, Union, List 
from soltypes import TileFormRepresentation

class TileForm():
    allTileForms = OrderedDict()

    def __init__(self, name : str, label : str, description : str) -> None:
        if " " in name:
            raise ValueError("Spaces not allowed in tile form names for tile form '" + name + "'")
        self.name = name
        self.label = label
        self.description = description
        self.allTileForms[name] = self.getFormRepresentation()

    def getFormRepresentation(self) -> TileFormRepresentation:
        output = {}
        output["name"] = self.name
        output["label"] = self.label
        output["description"] = self.description
        output["properties"] = []
        return output

# Order matters here, they show up as they are declared here
msgRouterForm = TileForm("message_router_config", "Message Router Config", "Message Router Config")
tlsForm = TileForm("tls_settings", "TLS Config", "TLS Config")
appAccessForm = TileForm("application_access_config", "Application Access", "Configure how applications will be authenticated to their bound service instances.")
mgmtAccessForm = TileForm("management_access_config", "Management Access", "Configure how VMR Administrators will be authenticated when they login to the management interface.")
ldapForm = TileForm("ldap_settings", "LDAP Settings", "Configure external LDAP user store (Optional)")
syslogForm = TileForm("system_logging", "System Logging", "Configure system logging.")
tcpRouteForm = TileForm("tcp_routes_settings", "TCP Routes", "Supports exposing VMR service ports to the internet (Optional)")
