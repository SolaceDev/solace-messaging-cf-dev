import abc
from option import Option
from typing import Dict, Any, Optional, List
from tileform import TileForm
from parametertypes import AbstractParameter

class BaseParameter(metaclass=abc.ABCMeta):
    def __init__(self,
            name : str,
            *,
            pcfFormName: Optional[str]=None,
            defaultValue: Any=None,
            enumValues: Optional[List[Option]]=None,
            parameterType: AbstractParameter=None,
            label: str=None,
            tileForm:Optional[TileForm]=None,
            visibleInBoshManifest: Optional[bool]=True
        ) -> None:
        if " " in name:
            raise ValueError("Spaces not allowed in parameter names for parameter '" + name + "'")
        self.name = name
        self.pcfFormName = pcfFormName
        self.defaultValue = defaultValue
        self.label = label
        self.parent = None
        if parameterType.multiType and pcfFormName is None:
            raise ValueError("Have to specify a pcfFormName for parameter '" + self.name + "' because it has a multi type")
        self.parameterType = parameterType
        self.tileForm = tileForm
        if defaultValue is not None and enumValues is not None and defaultValue not in [x.name for x in enumValues]:
            raise ValueError("default value '" + defaultValue + "' not in enumValues '" + str(enumValues) + "' for parameter: " + name)
        if parameterType.requireEnumValues is True and not enumValues:
            raise ValueError("Parameter type '" + parameterType.tileTemplateValue + "' requires enumValues, for parameter: " + name)
        self.enumValues = enumValues
        self.visibleInBoshManifest = visibleInBoshManifest

    def getPcfFormName(self) -> str:
        if self.pcfFormName is not None:
            return self.pcfFormName
        return self.name

    def setParent(self, parent : Optional['BaseParameter']) -> None:
        self.parent = parent

    def prettyPrint(self, indent: int=0) -> None:
        print(" "*4*indent + self.name)

    @abc.abstractmethod
    def generateTileTemplate(self, prefix: str, propertyListOutput, formOutput) -> dict:
        raise NotImplementedError("generateTileTemplate is an abstract method for BaseParameter")

    def getFormRepresentation(self) -> Dict[str, Any]:
        output = {}
        output["name"] = self.getPcfFormName()
        output["type"] = self.parameterType.getTileTemplateType()
        output["configurable"] = True
        if self.label is not None:
            output["label"] = self.label
        return output

    @abc.abstractmethod
    def convertToBoshLiteManifest(self, fullPropertyName, relativePropertyName, propertyValue, outputProperties) -> None:
        raise NotImplementedError("convertToBoshLiteManifest is an abstract method for BaseParameter")
