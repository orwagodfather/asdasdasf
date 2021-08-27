ARG PHP_VERSION=7.3
ARG NGINX_VERSION=1.17
ARG VARNISH_VERSION=6.2

FROM php:${PHP_VERSION}-fpm AS base_php

ARG APCU_VERSION=5.1.17
RUN set -eux; \
    apt-get update ; \
    apt-get install -y gnupg2 ; \
    echo 'deb http://s3-eu-west-1.amazonaws.com/tideways/packages debian main' > /etc/apt/sources.list.d/tideways.list ; \
    curl -sS 'https://s3-eu-west-1.amazonaws.com/tideways/packages/EEB5E8F4.gpg' | apt-key add - ; \
    apt-get update ; \
	apt-get install -y \
	    tideways-php \
	    acl \
        gettext \
		$PHPIZE_DEPS \
		libicu-dev \
		libzip-dev \
        libmemcached-dev \
		zlib1g-dev \
		libpng-dev \
		msmtp msmtp-mta \
	; \
	\
	docker-php-ext-configure zip --with-libzip; \
	docker-php-ext-install -j$(nproc) \
		intl \
		pdo_mysql \
		mysqli \
		zip \
		gd \
	; \
	pecl install \
		apcu-${APCU_VERSION} \
		memcached \
	; \
	pecl clear-cache; \
	docker-php-ext-enable \
		apcu \
		opcache \
		memcached \
		mysqli \
	; \
	apt-get autoremove --assume-yes && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker/msmtprc /etc/msmtprc
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY docker/php/conf.d/api.ini $PHP_INI_DIR/conf.d/api.ini
COPY docker/php/php-fpm.d/www.conf $PHP_INI_DIR/../php-fpm.d/www.conf

##########
FROM base_php AS api
ARG APP_NAME

WORKDIR /srv/api

COPY docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

# "nginx" stage
# depends on the "php" stage above
FROM nginx:${NGINX_VERSION}-alpine AS nginx

COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /srv/api
