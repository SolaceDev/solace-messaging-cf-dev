import abc
from typing import Optional, Any, Union, Dict

class AbstractParameter:
    def __init__(self,
            tileTemplateValue : str,
            *,
            pcfManifestType: str="value",
            requireEnumValues: bool=False,
            multiType: bool=False
        ) -> None:
        self.tileTemplateValue = tileTemplateValue
        # Parameter must define enum values in order to be allowed to use this type
        self.requireEnumValues = requireEnumValues
        self.pcfManifestType = pcfManifestType
        # multiType means we expect this type to contain more than one property (eg username/password combo)
        self.multiType = multiType

    def getTileTemplateType(self) -> str:
        return self.tileTemplateValue

    @abc.abstractmethod
    def validate(self, param: Any) -> None:
        return

    # Sometimes values are hidden in a dictionary, at which point we have to read them out
    def _getValue(self, value: Union[Dict[str, Any], str, int, bool]) -> Union[str, int, bool]:
        if isinstance(value, dict):
            if self.pcfManifestType not in value:
                raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' does not contain a value for pcf manifest type '" + self.pcfManifestType + "'")
            return value[self.pcfManifestType]
        return value

class StringParameter(AbstractParameter):
    def __init__(self,
            tileTemplateValue: str,
            *,
            pcfManifestType: str="value",
            requireEnumValues: bool=False,
            multiType: bool=False,
            minLength: Optional[int]=None,
            maxLength: Optional[int]=None
        ) -> None:
        super().__init__(tileTemplateValue, pcfManifestType=pcfManifestType, requireEnumValues=requireEnumValues, multiType=multiType)
        self.minLength = minLength
        self.maxLength = maxLength

    def validate(self, param: str) -> None:
        value = self._getValue(param)
        if not isinstance(value, str):
            raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' is not a string")
        valueLength = len(value)
        if self.minLength is not None and valueLength < self.minLength:
            raise ValueError("value '" + value + "' of type '" + self.tileTemplateValue + "' is less than min string length " + str(self.minLength))
        if self.maxLength is not None and valueLength > self.maxLength:
            raise ValueError("value '" + value + "' of type '" + self.tileTemplateValue + "' is great than max string length " + str(self.maxLength))
        return

class IntParameter(AbstractParameter):
    def __init__(self,
            tileTemplateValue: str,
            *,
            pcfManifestType: str="value",
            minValue: Optional[int]=None,
            maxValue: Optional[int]=None,
            requireEnumValues: bool=False,
            multiType: bool=False
        ) -> None:
        super().__init__(tileTemplateValue, pcfManifestType=pcfManifestType, requireEnumValues=requireEnumValues, multiType=multiType)
        self.minValue = minValue
        self.maxValue = maxValue

    def validate(self, param: Union[int, str]) -> None:
        tempValue = self._getValue(param)
        value = 0
        if isinstance(tempValue, int):
            value = tempValue
        elif isinstance(tempValue, str) and tempValue.isdigit():
            value = int(tempValue)
        else:
            raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' is not an integer")
        if self.minValue is not None and value < self.minValue:
            raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' is less than min value " + str(self.minValue))
        if self.maxValue is not None and value > self.maxValue:
            raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' is greater than max value " + str(self.maxValue))

class BoolParameter(AbstractParameter):
    def __init__(self,
            tileTemplateValue: str,
            *,
            pcfManifestType: str="value",
            requireEnumValues: bool=False,
            multiType: bool=False
        )-> None:
        super().__init__(tileTemplateValue, pcfManifestType=pcfManifestType, requireEnumValues=requireEnumValues, multiType=multiType)

    def validate(self, param: bool) -> None:
        value = self._getValue(param)
        if not isinstance(value, bool):
            raise ValueError("value '" + str(value) + "' of type '" + self.tileTemplateValue + "' is not a boolean")

Boolean = BoolParameter("boolean")
Port = IntParameter("port")
Selector = StringParameter("selector", requireEnumValues=True)
String = StringParameter("string")
Text = StringParameter("text") # Textbox (ie a very large string)
LdapURL = StringParameter("ldap_url")
Dropdown = StringParameter("dropdown_select", requireEnumValues=True)
Password = StringParameter("secret", pcfManifestType="secret")
CredentialsIdentity = StringParameter("simple_credentials", pcfManifestType="identity", multiType=True)
CredentialsPassword = StringParameter("simple_credentials", pcfManifestType="password", multiType=True)
CertPem= StringParameter("rsa_cert_credentials", pcfManifestType="cert_pem", multiType=True)
PrivateKeyPem = StringParameter("rsa_cert_credentials", pcfManifestType="private_key_pem", multiType=True)
