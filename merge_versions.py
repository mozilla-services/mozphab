#!/usr/bin/env python2
import json
import os
import sys

try:
    with open('/app/mozphab.json', 'r') as f:
        circle_data = json.load(f)
except IOError:
    circle_data = {}

app_data = dict()
app_data = {
    'arcanist_source': 'https://github.com/phacility/arcanist',
    'arcanist_version': os.getenv('ARCANIST_GIT_SHA', None),
    'libphutil_source': 'https://github.com/phacility/libphutil',
    'libphutil_version': os.getenv('LIBPHUTIL_GIT_SHA', None),
    'phabricator_source': 'https://github.com/phacility/phabricator',
    'phabricator_version': os.getenv('PHABRICATOR_GIT_SHA', None),
}
app_data.update(circle_data)
try:
    with open('/app/mozphab.json', 'w') as f:
        json.dump(app_data, f)
except IOError:
    sys.exit()
