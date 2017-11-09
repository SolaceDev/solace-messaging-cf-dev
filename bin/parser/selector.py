from baseparameter import BaseParameter
import parametertypes
from typing import Dict, List, Any

class Selector(BaseParameter):
    def __init__(self,
            name,
            *,
            pcfFormName = None,
            defaultValue = None,
            tileForm=None,
            label: str=None,
            enumValues=[],
            parameters: Dict[str, List[BaseParameter]] = {},
            boshJobFieldName: str=None
        )-> None:
        super().__init__(name, pcfFormName=pcfFormName, defaultValue=defaultValue, tileForm=tileForm, label=label, enumValues=enumValues, parameterType=parametertypes.Selector)
        if parameters is not None:
            enumValueNames = set([x.name for x in enumValues])
            for parameterName in parameters.keys():
                if parameterName not in enumValueNames:
                    raise ValueError("Unexpected parameter '" + parameterName + "' in selector '" + self.name + "'")
        self.parameters = parameters
        for parameterList in self.parameters.values():
            for parameter in parameterList:
                parameter.setParent(self)
        self.boshJobFieldName=boshJobFieldName

    def generateTileTemplate(self, prefix, propertyListOutput, formOutput) -> None:
        fullName = prefix + "." + self.name + "." + self.parameterType.pcfManifestType 
        if self.name not in propertyListOutput:
            propertyListOutput[self.name] = []
        propertyListOutput[self.name].append(fullName)

        formRepresentation = self.getFormRepresentation()

        # 'parameters' is a dictionary of lists, the key is the selected option in a selector
        # the entries in the list are other parameters/selectors
        for selectedOptionName, listOfParameters in self.parameters.items():
            for parameter in listOfParameters:
#                assert issubclass(type(parameter), BaseParameter)
                for option in formRepresentation["option_templates"]:
                    if option["name"] == selectedOptionName:
                        break
                else:
                    raise ValueError("Option name '" + option["name"] + "' not in option_templates for selector '" + self.name + "'. How can this happen?")
                if "property_blueprints" not in option:
                    option["property_blueprints"] = []
                parameter.generateTileTemplate(prefix + "." + self.name + "." + selectedOptionName, propertyListOutput, option["property_blueprints"])
        formOutput.append(formRepresentation)

    def prettyPrint(self, indent : int = 0) -> None:
        print(" "*4*indent + self.name)
        for key, parameterList in self.parameters.items():
            print(" "*4*indent + "  " + key + ":")
            for parameter in parameterList:
                parameter.prettyPrint(indent + 1)

    def getFormRepresentation(self) -> Dict[str, Any]:
        output = super().getFormRepresentation()
        if self.defaultValue is not None:
            output["default"] = self.defaultValue
        if self.enumValues:
            output["option_templates"] = []
            for value in self.enumValues:
                output["option_templates"].append(value.getTileOptionTemplateRepresentation())
        return output

    def convertToBoshLiteManifest(self, fullPropertyName: str, relativePropertyName: str, propertyValue, outputProperties) -> None:
        if "." in relativePropertyName:
            optionName, parameterName = relativePropertyName.split(".", 1)
            enumValueNames = set([x.name for x in self.enumValues])
            if optionName not in enumValueNames:
                raise ValueError("property '" + fullPropertyName + "' enum option '" + optionName + "' not found in schema")
            else:
                matchingParameters = [parameter for parameter in self.parameters[optionName] if parameter.getPcfFormName() == parameterName]
                if len(matchingParameters) == 0:
                    raise ValueError("property '" + fullPropertyName + "' parameter '" + parameterName + "' not found in schema")
                # Only one matching parameter, just call it directly
                elif len(matchingParameters) == 1:
                    matchingParameters[0].convertToBoshLiteManifest(fullPropertyName, parameterName, propertyValue, outputProperties)
                else:
                    for parameter in matchingParameters:
                        parameter.convertToBoshLiteManifest(fullPropertyName, relativePropertyName, propertyValue, outputProperties)
                return
        else:
            self.parameterType.validate(propertyValue)
            fieldNameToUse = self.name
            if self.boshJobFieldName is not None:
                fieldNameToUse = self.boshJobFieldName
            # Only add if its unique
            if fieldNameToUse not in outputProperties:
                outputProperties[fieldNameToUse] = propertyValue
            else:
                raise ValueError("property '" + fieldNameToUse + "' already found in outputProperties")

    def convertToBoshLiteManifestErrand(self, fullPropertyName: str, relativePropertyName: str, propertyValue, outputProperties) -> None:
        if "." in relativePropertyName:
            optionName, parameterName = relativePropertyName.split(".", 1)
            enumValueNames = set([x.name for x in self.enumValues])
            if optionName not in enumValueNames:
                raise ValueError("property '" + fullPropertyName + "' enum option '" + optionName + "' not found in schema")
            else:
                matchingParameters = [parameter for parameter in self.parameters[optionName] if parameter.getPcfFormName() == parameterName]
                if len(matchingParameters) == 0:
                    raise ValueError("property '" + fullPropertyName + "' parameter '" + parameterName + "' not found in schema")
                # Only one matching parameter, just call it directly
                elif len(matchingParameters) == 1:
                    matchingParameters[0].convertToBoshLiteManifestErrand(self, fullPropertyName, parameterName, propertyValue, outputProperties)
                else:
                    for parameter in matchingParameters:
                        parameter.convertToBoshLiteManifestErrand(self, fullPropertyName, relativePropertyName, propertyValue, outputProperties)
                return
        else:
            self.parameterType.validate(propertyValue)
            # Create only if missing
            if self.name not in outputProperties:
                outputProperties[self.name] = {}
            outputProperties[self.name]["value"] = propertyValue
