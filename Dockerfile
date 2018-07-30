FROM php:5.6-fpm-alpine

MAINTAINER mars@mozilla.com
# These are unlikely to change from version to version of the container
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh", "start"]

# Git commit SHAs for the build artifacts we want to grab.
# From https://github.com/phacility/phabricator/commits/stable
# Promote 2018 Week 30
# plus the following:
# (stable) Remove the execution time limit (if any) before sinking HTTP responses
ENV PHABRICATOR_GIT_SHA 58e8d3c134790e2c58e34568dc65f1951561dcb2
# From https://github.com/phacility/arcanist/commits/stable
# Promote 2018 Week 29
ENV ARCANIST_GIT_SHA 830661f62833e4601e31854532321bb30be74440
# From https://github.com/phacility/libphutil/commits/stable
# Promote 2018 Week 29
ENV LIBPHUTIL_GIT_SHA 340445cf69474ce4246c49bfaaa694851b9b0a48
# Should match the phabricator 'repository.default-local-path' setting.
ENV REPOSITORY_LOCAL_PATH /repo
# Explicitly set TMPDIR
ENV TMPDIR /tmp

# Runtime dependencies
RUN apk --no-cache --update add \
    curl \
    freetype \
    g++ \
    git \
    libjpeg-turbo \
    libmcrypt \
    libpng \
    make \
    mariadb-client \
    mariadb-client-libs \
    ncurses \
    py-pygments

# Install mercurial from source b/c it's wicked out of date on main
COPY mercurial_requirements.txt requirements.txt
RUN apk add python-dev py-pip && \
      pip install --require-hashes -r requirements.txt

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
    && pecl install https://s3.amazonaws.com/net-mozaws-dev-mozphab-pecl-mirror/apcu-4.0.11.tgz \
    && docker-php-ext-enable apcu \
    && apk del build-dependencies

RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64 && if test -f /usr/local/bin/dumb-init; then chmod 755 /usr/local/bin/dumb-init; fi

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
        echo 'post_max_size="32M"'; \
    } | tee /usr/local/etc/php/conf.d/phabricator.ini

# add a non-privileged user for installing and running the application
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app -h /app -s /bin/sh app

COPY . /app
WORKDIR /app

# Install Phabricator code
RUN git clone https://secure.phabricator.com/source/phabricator.git phabricator --branch stable --depth 1 \
    && git clone https://secure.phabricator.com/diffusion/ARC/arcanist.git arcanist --branch stable --depth 1 \
    && git clone https://secure.phabricator.com/source/libphutil.git libphutil --branch stable --depth 1 \
    && cd phabricator && git reset --hard ${PHABRICATOR_GIT_SHA} && cd .. \
    && cd arcanist && git reset --hard ${ARCANIST_GIT_SHA} && cd .. \
    && cd libphutil && git reset --hard ${LIBPHUTIL_GIT_SHA} && cd .. \
    && ./libphutil/scripts/build_xhpast.php

# Create version.json
RUN /app/merge_versions.py

RUN chmod +x /app/entrypoint.sh /app/wait-for-mysql.php \
    && mkdir $REPOSITORY_LOCAL_PATH \
    && chown -R app:app /app $REPOSITORY_LOCAL_PATH

USER app
VOLUME ["$REPOSITORY_LOCAL_PATH"]
