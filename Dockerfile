R# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

FROM php:5.6-fpm-alpine

MAINTAINER mars@mozilla.com

# Git commit SHAs for the build artifact we want to grab.
# Default is SHAs for 2017 Week 14
# From https://github.com/phacility/phabricator/commits/stable
ENV PHABRICATOR_GIT_SHA 699ab153e3751e5389c69db4387d261e358de290
# From https://github.com/phacility/arcanist/commits/stable
ENV ARCANIST_GIT_SHA 3512c4ab86d66a103a6733a0589177f93b6d6811
# From https://github.com/phacility/libphutil/commits/stable
ENV LIBPHUTIL_GIT_SHA f568eb7b9542259cd3c0dcb3405cc9a83c90a2f5

# Should match the phabricator 'repository.default-local-path' setting.
ENV REPOSITORY_LOCAL_PATH /repo

# Runtime dependencies
RUN apk --no-cache --update add \
    curl \
    freetype \
    libjpeg-turbo \
    libmcrypt \
    libpng \
    mariadb-client-libs

# Build PHP extensions
RUN apk --no-cache add --virtual build-dependencies \
        $PHPIZE_DEPS \
        curl-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        mariadb-dev \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include \
        --with-jpeg-dir=/usr/include \
        --with-png-dir=/usr/include \
    && docker-php-ext-install -j "$(nproc)" \
        curl \
        gd \
        iconv \
        mbstring \
        mcrypt \
        mysqli \
        opcache \
        pcntl \
    && pecl install apcu-4.0.11 \
    && docker-php-ext-enable apcu \
    && apk del build-dependencies

# Install opcache recommended settings from
# https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.validate_timestamps=0'; \
    } | tee /usr/local/etc/php/conf.d/opcache.ini

# The container does not log errors by default, so turn them on
RUN { \
        echo 'php_admin_flag[log_errors] = on'; \
        echo 'php_flag[display_errors] = off'; \
    } | tee /usr/local/etc/php-fpm.d/zz-log.conf

# Phabricator recommended settings (skipping these will result in setup warnings
# in the application).
RUN { \
        echo 'always_populate_raw_post_data=-1'; \
    } | tee /usr/local/etc/php/conf.d/phabricator.ini

WORKDIR /var/www/html

RUN curl -fsSL https://github.com/phacility/phabricator/archive/${PHABRICATOR_GIT_SHA}.tar.gz -o phabricator.tar.gz \
    && curl -fsSL https://github.com/phacility/arcanist/archive/${ARCANIST_GIT_SHA}.tar.gz -o arcanist.tar.gz \
    && curl -fsSL https://github.com/phacility/libphutil/archive/${LIBPHUTIL_GIT_SHA}.tar.gz -o libphutil.tar.gz \
    && tar xzf phabricator.tar.gz \
    && tar xzf arcanist.tar.gz \
    && tar xzf libphutil.tar.gz \
    && mv phabricator-${PHABRICATOR_GIT_SHA} phabricator \
    && mv arcanist-${ARCANIST_GIT_SHA} arcanist \
    && mv libphutil-${LIBPHUTIL_GIT_SHA} libphutil \
    && rm phabricator.tar.gz arcanist.tar.gz libphutil.tar.gz \
    && chown -R www-data:www-data phabricator arcanist libphutil

VOLUME ["/repo"]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000

CMD "/entrypoint.sh"
