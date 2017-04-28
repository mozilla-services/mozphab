#!/usr/bin/env python
import json
import os
import sys

try:
    infile = open('/app/circle.json', 'r')
    circle_data = json.load(infile)
except IOError:
    circle_data = json.loads("{}")

app_data = dict()
app_data['arcanist_source'] = 'https://github.com/phacility/arcanist'
app_data['arcanist_version'] = os.getenv('ARCANIST_GIT_SHA', None)
app_data['libphutil_source'] = 'https://github.com/phacility/libphutil'
app_data['libphutil_version'] = os.getenv('LIBPHUTIL_GIT_SHA', None)
app_data['phabricator_source'] = 'https://github.com/phacility/phabricator'
app_data['phabricator_version'] = os.getenv('PHABRICATOR_GIT_SHA', None)
version_info = {**circle_data, **app_data}
try:
    OUTFILE = open('/app/version.json', 'w')
    json.dump(version_info, OUTFILE)
except IOError:
    sys.exit()
