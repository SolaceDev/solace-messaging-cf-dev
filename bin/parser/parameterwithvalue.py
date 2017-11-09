from baseparameter import BaseParameter
from typing import Any, Optional, Union

class ParameterWithValue:
    def __init__(self, parameter : BaseParameter, value : Union[str, int, bool]) -> None:
        assert issubclass(type(parameter), BaseParameter)
        self.parameter : BaseParameter = parameter
        if value is not None:
            self.value = value
        else:
            if parameter.defaultValue is not None:
                self.value = parameter.defaultValue
            else:
                raise ValueError("No value provided for parameter name '" + parameter.name + "'")

    def setParent(self, parent: Optional[BaseParameter]) -> None:
        self.parameter.parent = parent

