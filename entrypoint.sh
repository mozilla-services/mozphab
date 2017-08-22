#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Configure Phabricator on startup from environment variables.

set -ex

cd phabricator

test -n "${MYSQL_HOST}" \
  && /app/wait-for-mysql.php \
  && ./bin/config set mysql.host ${MYSQL_HOST}
test -n "${MYSQL_PORT}" \
  && ./bin/config set mysql.port ${MYSQL_PORT}
test -n "${MYSQL_USER}" \
  && ./bin/config set mysql.user ${MYSQL_USER}
set +x
test -n "${MYSQL_USER}" \
  && ./bin/config set mysql.pass ${MYSQL_PASS}
set -x
test -n "${1}" \
  && ARG=$(echo ${1:-start}  | tr [A-Z] [a-z])

case "$ARG" in
  "start")
      set +e

      # Create database if one does not exist
      ./bin/storage upgrade --force

      # Set the local repository
      if [ -n "${REPOSITORY_LOCAL_PATH}" ]; then
        if [ -d "${REPOSITORY_LOCAL_PATH}" ]; then
          :
        else
          mkdir -p "${REPOSITORY_LOCAL_PATH}"
        fi
        ./bin/config set repository.default-local-path "${REPOSITORY_LOCAL_PATH}"
      else
        echo "No REPOSITORY_LOCAL_PATH set"
        exit
      fi

      # You should set the base URI to the URI you will use to access Phabricator,
      # like "http://phabricator.example.com/".

      # Include the protocol (http or https), domain name, and port number if you are
      # using a port other than 80 (http) or 443 (https).
      test -n "${PHABRICATOR_URI}" \
       && ./bin/config set phabricator.base-uri "${PHABRICATOR_URI}"
      test -n "${PHABRICATOR_CDN_URI}" \
       && ./bin/config set security.alternate-file-domain "${PHABRICATOR_CDN_URI}"

      # Set recommended runtime configuration values to silence setup warnings.
      ./bin/config set storage.mysql-engine.max-size 8388608
      ./bin/config set pygments.enabled true
      ./bin/config set phabricator.timezone UTC

      # Ensure that we have an updated static resources map
      # Required so extension resources are accounted for and available
      ./bin/celerity map

      # Start phd and php-fpm running in the foreground
      ./bin/phd start && /usr/local/sbin/php-fpm -F
      ;;
  "docs")
      # Create database if one does not exist
      set +e
      ./bin/storage status > /dev/null 2>&1
      if [ $? -gt 0 ]; then
        set -e
        ./bin/storage upgrade --force
      fi

      # Build diviner docs
      ./bin/diviner generate
      ;;
  "data")
      # Allows the container to be used as a data-volume only container
      /bin/true && exit
      ;;
  "shell"|"admin")
      /bin/sh
      ;;
  "dump")
      ./bin/storage dump
      exit
      ;;
  *)
      exec $ARG
      ;;
esac
