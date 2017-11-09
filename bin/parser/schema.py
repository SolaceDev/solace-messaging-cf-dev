from selector import Selector
from parameter import Parameter
from root import Root
import parametertypes
import tileform
from option import Option

root = Root("root",
    parameters = [
        Parameter("starting_port", tileForm=tileform.msgRouterForm, defaultValue=7000, parameterType=parametertypes.Port, label="Starting Port"),
        Selector("tls_config", tileForm=tileform.tlsForm, defaultValue="disabled", label="Choose whether TLS is enabled or not", enumValues=[Option("disabled", "TLS Disabled"), Option("enabled", "TLS Enabled")],
            parameters={
                "enabled": [
                    Parameter("cert_pem", pcfFormName="rsa_server_cert", parameterType=parametertypes.CertPem, placeholder="Message Router's Server Certificate"),
                    Parameter("private_key_pem", pcfFormName="rsa_server_cert", parameterType=parametertypes.PrivateKeyPem),
                    Parameter("broker_validate_cert_disabled", parameterType=parametertypes.Boolean,visibleInBoshManifest=False),
                    Parameter("trusted_root_certificates", optional=True, parameterType=parametertypes.Text),
                ],
            }
        ),
        Selector("application_access_auth_scheme", tileForm=tileform.appAccessForm, defaultValue="vmr_internal", enumValues=[Option("vmr_internal", "VMR Internal"), Option("ldap_server", "LDAP Server")]),
        Parameter("vmr_admin_password", tileForm=tileform.mgmtAccessForm, parameterType=parametertypes.Password, placeholder="admin password"),
        Selector("management_access_auth_scheme", tileForm=tileform.mgmtAccessForm, defaultValue="vmr_internal", enumValues=[Option("vmr_internal", "VMR Internal"), Option("ldap_server", "LDAP Server")],
            parameters={
                "ldap_server": [
                    Parameter("ldap_mgmt_read_only_groups", optional=True, placeholder="'cn=readonly,cn=groups,dc=example,dc=com'"),
                    Parameter("ldap_mgmt_read_write_groups", optional=True, placeholder="'cn=readwrite,cn=groups,dc=example,dc=com'"),
                    Parameter("ldap_mgmt_admin_groups", optional=True, placeholder="'cn=admin,cn=groups,dc=example,dc=com'")
                ]
            }
        ),
        Selector("ldap_config", tileForm=tileform.ldapForm, defaultValue="disabled", enumValues=[Option("disabled", "Disabled"), Option("enabled", "LDAP Enabled")],
            parameters={
                "enabled": [
                    Parameter("ldap_server_url", parameterType=parametertypes.LdapURL, placeholder="'ldap://ldap.domain.com'"),
                    Parameter("ldap_start_tls", defaultValue = "disabled", parameterType=parametertypes.Dropdown, enumValues=[Option("disabled", "Disable startTLS"), Option("enabled", "Enable startTLS")]),
                    Parameter("ldap_admin_password", pcfFormName="ldap_credentials", parameterType=parametertypes.CredentialsPassword),
                    Parameter("ldap_admin_username", pcfFormName="ldap_credentials", parameterType=parametertypes.CredentialsIdentity),
                    Parameter("ldap_user_search_base", placeholder="'cn=users,dc=example,dc=com'"),
                    Parameter("ldap_user_search_filter", defaultValue="(cn=$CLIENT_USERNAME)"),
                    Parameter("ldap_group_membership_attribute_name", defaultValue="memberOf"),
                ]
            }
        ),
        Selector("syslog_config", tileForm=tileform.syslogForm, defaultValue="disabled", enumValues=[Option("disabled", "System Logging Disabled"), Option("enabled", "System Logging Enabled")],
            parameters={
                "enabled": [
                    Parameter("syslog_hostname"),
                    Parameter("syslog_port", parameterType=parametertypes.Port, placeholder=514),
                    Parameter("syslog_protocol", optional=True, defaultValue="tcp", parameterType=parametertypes.Dropdown, enumValues=[Option("udp", "UDP Protocol"), Option("tcp", "TCP Protocol")]),
                    Parameter("syslog_vmr_command_logs", optional=True, parameterType=parametertypes.Boolean),
                    Parameter("syslog_vmr_event_logs", optional=True, parameterType=parametertypes.Boolean),
                    Parameter("syslog_vmr_system_logs", optional=True, parameterType=parametertypes.Boolean),
                    Parameter("syslog_broker_and_agent_logs", optional=True, parameterType=parametertypes.Boolean)
                ]
            }
        ),
        Selector("tcp_routes_config", tileForm=tileform.tcpRouteForm, defaultValue="disabled", boshJobFieldName="tcp_routes_enabled", enumValues=[Option("disabled", "TCP Routes Disabled"), Option("enabled", "TCP Routes Enabled")],
            parameters={
                "disabled" : [
                    Parameter("tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[Option("not_allowed", "Not Allowed")],visibleInBoshManifest=False),
                ],
                "enabled": [
                    Parameter("cf_client_id", pcfFormName="cf_credentials", parameterType=parametertypes.CredentialsIdentity, optional=True, alternateName="identity"),
                    Parameter("cf_client_secret", pcfFormName="cf_credentials", parameterType=parametertypes.CredentialsPassword, optional=True, alternateName="password"),
                    Parameter("smf_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("smf_tls_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("smf_zip_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("web_messaging_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("web_messaging_tls_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("mqtt_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("mqtt_tls_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("mqtt_ws_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("mqtt_wss_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("rest_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("rest_tls_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("amqp_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                    Parameter("amqp_tls_tcp_route_enabled", defaultValue="not_allowed", parameterType=parametertypes.Dropdown, enumValues=[
                        Option("not_allowed", "Not Allowed"),
                        Option("disabled_by_default", "Disabled by default"),
                        Option("enabled_by_default", "Enabled by default")],
                    visibleInBoshManifest=False),
                ]
            }
        )
    ]
)
