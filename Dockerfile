# -------- Copy stuff from base images
ARG PHP_VER=7.2.29
ARG OS_VER=3.10

FROM jwilder/dockerize:0.6.0 AS dockerize
FROM bashitup/alpine-tools:latest AS tools
FROM php:$PHP_VER-fpm-alpine$OS_VER

COPY --from=dockerize /usr/local/bin/dockerize /usr/bin/

COPY --from=tools     /bin/yaml2json        /usr/bin/
COPY --from=tools     /bin/modd             /usr/bin/
COPY --from=tools     /bin/jq               /usr/bin/

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/
# -------- Add packages and build/install tools

ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN apk --no-cache add \
		--repository http://dl-3.alpinelinux.org/alpine/edge/community \
		gnu-libiconv \
	&& \
	apk --update add \
		bash nginx nginx-mod-http-lua nginx-mod-http-lua-upstream \
		supervisor ncurses certbot git wget curl openssh-client ca-certificates \
		dialog \
	&& \
	install-php-extensions mcrypt pdo_mysql mysqli gd exif intl zip opcache

# -------- Setup composer and runtime environment

ADD https://getcomposer.org/download/1.10.1/composer.phar /usr/bin/composer
RUN chmod ugo+rx /usr/bin/composer && \
    chmod ugo+r /etc/supervisord.conf && \
	mkdir -p /run/nginx /etc/nginx/sites-enabled && \
	ln -s ../sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# -------- Add our stuff, process build args, and initialize composer globals

ENV CODE_BASE /var/www/html
ENV GIT_SSH /usr/bin/git-ssh
ENV COMPOSER_OPTIONS --no-dev

VOLUME /etc/letsencrypt
EXPOSE 443 80
CMD ["/usr/bin/start-container"]

COPY scripts/install-extras /usr/bin/

ARG EXTRA_APKS
ARG EXTRA_EXTS
ARG EXTRA_PECL
RUN /usr/bin/install-extras

COPY scripts/ /usr/bin/
COPY tpl /tpl

ARG GLOBAL_REQUIRE=hirak/prestissimo:^0.3.7
ENV COMPOSER_HOME /composer
RUN { [[ -z "$GLOBAL_REQUIRE" ]] || composer-global $GLOBAL_REQUIRE; } \
    && mkdir -p /var/www/html \
    && echo '<?php echo phpinfo();' >/var/www/html/index.php
