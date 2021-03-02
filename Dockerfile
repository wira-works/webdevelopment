FROM alpine:latest

ADD /instantclient/instantclient_21_1.zip /tmp/
RUN unzip /tmp/instantclient_21_1.zip -d /opt/oracle/

RUN rm /tmp/instantclient_21_1.zip

RUN ln -s /opt/oracle/instantclient_21_1 /usr/local/instantclient


ENV LD_LIBRARY_PATH /opt/oracle/instantclient_21_1
#ENV ORACLE_BASE /opt/oracle/instantclient_21_1
#ENV TNS_ADMIN /opt/oracle/instantclient_21_1/network
#ENV ORACLE_HOME /usr/lib/instantclient_21_1

RUN apk update \
    && apk add --no-cache nginx php7-fpm php7-pear php7-dev php7-mcrypt \
    php7-soap php7-openssl php7-gmp \
    php7-pdo_odbc php7-json php7-dom \
    php7-pdo php7-zip php7-mysqli \
    php7-apcu php7-pdo_pgsql \
    php7-bcmath php7-gd php7-odbc \
    php7-pdo_mysql \
    php7-gettext php7-xmlreader php7-xmlrpc \
    php7-bz2 php7-iconv php7-pdo_dblib php7-curl php7-ctype \
    make gcc g++ \
    supervisor \
    && pecl channel-update pecl.php.net \
    && echo 'instantclient,/usr/local/instantclient' | pear install pecl/oci8-2.2.0 \
    && echo 'extension=oci8.so' > /etc/php7/conf.d/oracle.ini \
    && php -m

# Install Composer
ENV COMPOSER_HOME /composer
ENV PATH ./vendor/bin:/composer/vendor/bin:$PATH
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY nginx.conf /etc/nginx/nginx.conf
COPY configure.sh /configure.sh
COPY supervisord.conf /etc/supervisord.conf
VOLUME ["/var/lib/nginx/html/"]
EXPOSE 80/tcp
RUN sh /configure.sh
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]