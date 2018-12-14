FROM php:7.1-apache-jessie

LABEL vendor="Mautic"
LABEL maintainer="MotaWord <it@motaword.com>"

# Create manual files for software installations. openjdk is giving an error otherwise.
RUN for i in {1..8}; do mkdir -p "/usr/share/man/man$i" && chmod 777 -R "/usr/share/man/man$i"; done

# Install Java 8 for zanata-cli tool in MauticMotaWordBundle
RUN echo deb http://http.debian.net/debian jessie-backports main >> /etc/apt/sources.list
RUN apt-get -y update && apt-get install --no-install-recommends -y -t jessie-backports ca-certificates-java && apt-get -y --no-install-recommends install openjdk-8-jdk && update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Install PHP extensions and helper software
RUN apt-get update && apt-get install --no-install-recommends -y \
    cron \
    git \
    wget \
    libc-client-dev \
    libicu-dev \
    libkrb5-dev \
    libmcrypt-dev \
    libssl-dev \
    libz-dev \
    unzip \
    zip \
    supervisor \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/cron.daily/*

RUN apt-get install $PHPIZE_DEPS
RUN docker-php-ext-configure imap --with-imap --with-imap-ssl --with-kerberos
RUN pecl install xdebug
RUN docker-php-ext-install imap intl bcmath mbstring mcrypt mysqli pdo_mysql sockets zip opcache
RUN docker-php-ext-enable imap intl bcmath mbstring mcrypt mysqli pdo_mysql sockets zip opcache

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# By default enable cron jobs
# MotaWord uses different host structures for web serving and background workers (queue + microservice)
# MAUTIC_RUN_CRON_JOBS should be false for hosts that only server web.
ENV MAUTIC_RUN_CRON_JOBS true

# Copy init scripts and custom .htaccess
COPY docker/docker-entrypoint.sh /entrypoint.sh
COPY docker/makeconfig.php /makeconfig.php
COPY docker/makedb.php /makedb.php
COPY docker/mautic.crontab /etc/cron.d/mautic
COPY docker/mautic-php.ini /usr/local/etc/php/conf.d/mautic-php.ini
COPY docker/init.sql /init.sql
COPY docker/supervisord.conf /etc/supervisord.conf
ADD . /var/www/html

RUN mkdir /var/log/mautic && chmod 777 -R /var/log/mautic && chmod o+t -R /var/log/mautic && \
    chmod 777 -R /tmp && chmod o+t -R /tmp && chown -R www-data:www-data /tmp && \
    chown -R www-data:www-data /var/www/html/app/cache && chown -R www-data:www-data /var/www/html/app/logs && \
    chown -R www-data:www-data /var/www/html/media

# Enable Apache Rewrite Module
RUN a2enmod rewrite

# Apply necessary permissions
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

# By default, this container serves the web dashboard and runs cron jobs.
# However, MotaWord runs queue and microservice workers in different hosts with the same container.
# CMD of those workers should be this:
# /usr/bin/supervisord -c /etc/supervisord.conf;

CMD ["apache2-foreground"]
