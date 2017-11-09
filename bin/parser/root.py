from baseparameter import BaseParameter
from tileform import TileForm
from collections import OrderedDict
from typing import List, Dict
from selector import Selector

keywordsToIgnore = [
    "jobs"
]

class Root(BaseParameter):
    def __init__(self,
            name : str, 
            parameters : List[BaseParameter] = []
        )-> None:
        self.name = name
        self.parameters = OrderedDict()
        for parameter in parameters:
            parameter.setParent(self)
            self.parameters[parameter.name] = parameter

    def generateTileTemplate(self, prefix : str, propertyListOutput, formOutput) -> dict:
        tileDict = {}
        for parameter in self.parameters.values():
            # Skip any parameters that dont have a tile form
            if parameter.tileForm is None:
                continue
            tileOutput = []
            if parameter.tileForm.name not in tileDict:
                tileDict[parameter.tileForm.name] = [] 
            parameter.generateTileTemplate(prefix, propertyListOutput, tileOutput)
            tileDict[parameter.tileForm.name] = tileDict[parameter.tileForm.name] + tileOutput

        # Iterate over all forms and add the results to the output
        for currentFormName, currentForm in TileForm.allTileForms.items():
            if currentFormName in tileDict:
                currentForm["properties"] = currentForm["properties"] + tileDict[currentFormName]
            formOutput.append(currentForm)
        return formOutput

    def prettyPrint(self, indent: int=0) -> None:
        print(" "*4*indent + self.name)
        for parameter in self.parameters.values():
            parameter.prettyPrint(indent + 1)

    def getFormRepresentation(self) -> None:
        raise NotImplementedError("getFormRepresentation is an abstract method for Root")

    def convertToBoshLiteManifest(self, fullPropertyName, relativePropertyName, propertyValue, outputProperties) -> None:
        raise NotImplementedError("convertToBoshLiteManifest is an abstract method for Root")


    def generateSelectorPropertiesFromCiFile(self, inputFile) -> dict:
        outputProperties = {}
        for propertyName, propertyValue in inputFile.items():
            if propertyName not in keywordsToIgnore:
                name = propertyName.split(".")[0]
                if name not in self.parameters:
                    raise ValueError("property '" + name + "' not found in schema")
                else:
                    parameter = self.parameters[name]
                    if "." in propertyName:
                        relativeName = propertyName.split(".", 1)[1]
                    else:
                        relativeName = "" 

                    if isinstance(parameter,Selector):
                       parameter.convertToBoshLiteManifestErrand(propertyName, relativeName, propertyValue, outputProperties)
                       # parameter.convertToBoshLiteManifest(propertyName, relativeName, propertyValue, outputProperties)
                       #if "." not in propertyName:
                       #    print("Done" , propertyName, "x" , relativeName, "x" , propertyValue )
                       #    outputProperties[propertyName] = {}
                       #    outputProperties[propertyName]["value"] = propertyValue
                       #else:
                       #   print(parameter.name)
                       #   print(propertyName, "x" , relativeName, "x" , propertyValue )

                           
        return outputProperties 


    def generatePropertiesFromCiFile(self, inputFile) -> dict:
        outputProperties = {}
        for propertyName, propertyValue in inputFile.items():
            if propertyName not in keywordsToIgnore:
                name = propertyName.split(".")[0]
                if name not in self.parameters:
                    raise ValueError("property '" + name + "' not found in schema")
                else:
                    parameter = self.parameters[name]
                    if "." in propertyName:
                        relativeName = propertyName.split(".", 1)[1]
                    else:
                        relativeName = "" 
                    parameter.convertToBoshLiteManifest(propertyName, relativeName, propertyValue, outputProperties)
        return outputProperties 


