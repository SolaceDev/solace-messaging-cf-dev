from typing import List, Dict, Union
from solyaml import literal_unicode

Property = List[Dict[str, Union[str, int, bool, literal_unicode]]]
TileFormRepresentation = Dict[str, Union[str, Property]] 
