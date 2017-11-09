from baseparameter import BaseParameter
import parametertypes
from solyaml import literal_unicode
from typing import Any, Dict, List, Optional, Union
from tileform import TileForm
from option import Option

class Parameter(BaseParameter):
    def __init__(self,
            name: str,
            *,
            pcfFormName: Optional[str]=None,
            defaultValue: Union[str, bool, int]=None,
            placeholder: Union[str, bool, int]=None,
            pcfType: Optional[str]=None,
            enumValues: Optional[List[Option]]=None,
            optional: Optional[bool]=None,
            tileForm: Optional[TileForm]=None,
            label: Optional[str]=None,
            parameterType: parametertypes.AbstractParameter=parametertypes.String,
            visibleInBoshManifest: Optional[bool]=True,
            alternateName: Optional[str]=None
        )-> None:
        super().__init__(name, pcfFormName=pcfFormName, defaultValue=defaultValue, tileForm=tileForm, enumValues=enumValues, label=label, parameterType=parameterType)
        self.optional = optional
        self.placeholder = placeholder
        self.visibleInBoshManifest = visibleInBoshManifest
        self.alternateName = alternateName

    def generateTileTemplate(self, prefix: str, propertyListOutput, formOutput) -> None:
        fullName = prefix + "." + self.getPcfFormName() + "." + self.parameterType.pcfManifestType
        if self.name not in propertyListOutput:
            propertyListOutput[self.name] = []
        propertyListOutput[self.name].append(fullName)
        if formOutput and formOutput[-1]["name"] == self.getPcfFormName():
            if not self.parameterType.multiType:
                raise ValueError("parameter '" + self.getPcfFormName() + "' already seen in form output")
        else:
            formOutput.append(self.getFormRepresentation())

    def getFormRepresentation(self) -> Dict[str, Any]:
        output = super().getFormRepresentation()
        # if we have enum values then we store the default value in the option information
        if self.defaultValue is not None and self.enumValues is None:
            output["default"] = self.defaultValue
        if self.optional is not None:
            output["optional"] = self.optional
        if self.placeholder is not None:
            output["placeholder"] = self.placeholder
        if self.enumValues:
            output["options"] = []
            for value in self.enumValues:
                output["options"].append(value.getTileOptionRepresentation(self.defaultValue))
        return output

    def convertToBoshLiteManifest(self, fullPropertyName: str, relativePropertyName: str, propertyValue, outputProperties) -> None:
        self.parameterType.validate(propertyValue)
        if self.name not in outputProperties:
            assignValue = propertyValue
            if isinstance(propertyValue, dict):
                if self.parameterType.pcfManifestType in propertyValue:
                    assignValue = propertyValue[self.parameterType.pcfManifestType]
                else:
                    raise ValueError("property '" + fullPropertyName + "' expected type '" + self.parameterType.pcfManifestType + "' does not match described type(s) '" + str(propertyValue.keys()) + "'")
            if isinstance(assignValue, str):
                # Need to fix the newline issue when dumping yaml
                # long strings with newlines have to be marked as a literal block
                if "\n" in assignValue:
                    assignValue = literal_unicode(assignValue)
            if self.visibleInBoshManifest:
               outputProperties[self.name] = assignValue
        else:
            raise ValueError("property '" + self.name + "' already found in outputProperties")

    def convertToBoshLiteManifestErrand(self, parent, fullPropertyName: str, relativePropertyName: str, propertyValue, outputProperties ) -> None:
        self.parameterType.validate(propertyValue)

        if parent.name not in outputProperties:
           outputProperties[parent.name] = {}

        if parent.name not in outputProperties:
            raise ValueError("parent of property '" + self.name + "' not present in outputProperties")

        if "selected_option" not in outputProperties[parent.name]:
           outputProperties[parent.name]["selected_option"] = {}

        ## Value handling
        assignValue = propertyValue
        if isinstance(propertyValue, dict):
           if self.parameterType.pcfManifestType in propertyValue:
               assignValue = propertyValue[self.parameterType.pcfManifestType]
           else:
               raise ValueError("property '" + fullPropertyName + "' expected type '" + self.parameterType.pcfManifestType + "' does not match described type(s) '" + str(propertyValue.keys()) + "'")

        if isinstance(assignValue, str):
            # Need to fix the newline issue when dumping yaml
            # long strings with newlines have to be marked as a literal block
            if "\n" in assignValue:
                assignValue = literal_unicode(assignValue)

        myFieldName = self.name
        if self.alternateName is not None:
           myFieldName = self.alternateName

        if myFieldName not in outputProperties[parent.name]["selected_option"]:
            if self.pcfFormName is not None:
               if self.pcfFormName not in outputProperties[parent.name]["selected_option"]:
                  outputProperties[parent.name]["selected_option"][self.pcfFormName] = {}
               outputProperties[parent.name]["selected_option"][self.pcfFormName][myFieldName] = assignValue
            else:
               outputProperties[parent.name]["selected_option"][myFieldName] = assignValue
        else:
            raise ValueError("property '" + myFieldName + "' already found in outputProperties")


