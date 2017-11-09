# Found on stackoverflow
# https://stackoverflow.com/questions/6432605/any-yaml-libraries-in-python-that-support-dumping-of-long-strings-as-block-liter
# Fixes the yaml dumps not being formatted correctly and having weird newline issues

import yaml

class folded_unicode(str): pass
class literal_unicode(str): pass

def _folded_unicode_representer(dumper, data: str):
    return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='>')
def _literal_unicode_representer(dumper, data: str):
    return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')

yaml.add_representer(literal_unicode, _literal_unicode_representer)
yaml.add_representer(folded_unicode, _folded_unicode_representer)
