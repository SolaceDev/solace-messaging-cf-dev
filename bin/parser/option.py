from typing import Optional, Dict, Union

class Option:
    def __init__(self,
            name: str, 
            label: str, 
            *, 
            select_value: Optional[str]=None, 
            defaultValue: Optional[str]=None
        )-> None:
        self.name = name
        self.select_value = select_value
        self.label = label
        self.defaultValue = defaultValue

    def getTileOptionTemplateRepresentation(self) -> Dict[str, str]:
        output = {}
        output["name"] = self.name
        output["label"] = self.label
        output["select_value"] = self.select_value or self.name
        return output

    def getTileOptionRepresentation(self, defaultValue: str) -> Dict[str, Union[bool, str]]:
        output = {}
        output["name"] = self.name
        output["label"] = self.label
        output["select_value"] = self.select_value or self.name
        if self.name == defaultValue:
            output["default"] = True
        return output
