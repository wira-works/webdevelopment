FROM php:8-apache

ENV ACCEPT_EULA=Y

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        wget \ 
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libaio1 \
        #libldap2-dev \
    && docker-php-ext-install -j$(nproc) iconv gettext \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql mysqli bcmath

# Install XDebug - Required for code coverage in PHPUnit
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostartvg=off" >> /usr/local/etc/php/conf.d/xdebug.ini

# Copy over the php conf
COPY docker-php.conf /etc/apache2/conf-enabled/docker-php.conf

# Copy over the php ini
COPY docker-php.ini $PHP_INI_DIR/conf.d/

RUN cd /usr/local/etc/php/conf.d/ && \
  echo 'memory_limit = -1' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini

# Set the timezone
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN printf "log_errors = On \nerror_log = /dev/stderr\n" > /usr/local/etc/php/conf.d/php-logs.ini

# Enable mod_rewrite
RUN a2enmod rewrite

# Install Oracle instantclient
ADD instantclient-basiclite-linux.x64-19.5.0.0.0dbru.zip /tmp/
ADD instantclient-sdk-linux.x64-19.5.0.0.0dbru.zip /tmp/
ADD instantclient-sqlplus-linux.x64-19.5.0.0.0dbru.zip /tmp/

RUN unzip /tmp/instantclient-basiclite-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/
RUN unzip /tmp/instantclient-sdk-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/
RUN unzip /tmp/instantclient-sqlplus-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/

ENV LD_LIBRARY_PATH /usr/local/instantclient_19_5/

RUN ln -s /usr/local/instantclient_19_5 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus

RUN echo 'export LD_LIBRARY_PATH="/usr/local/instantclient"' >> /root/.bashrc
RUN echo 'umask 002' >> /root/.bashrc

RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8
RUN echo "extension=oci8.so" > /usr/local/etc/php/conf.d/php-oci8.ini

# Install git
RUN apt-get -y install git unixodbc-dev unixodbc
    
# Install MS ODBC Driver for SQL Server
RUN wget https://packages.microsoft.com/debian/10/prod/pool/main/m/msodbcsql17/msodbcsql17_17.7.1.1-1_amd64.deb
COPY msodbcsql17_17.7.1.1-1_amd64.deb /tmp/
RUN dpkg -i /tmp/msodbcsql17_17.7.1.1-1_amd64.deb

# RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
#     && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
#     apt-get update \
#     && apt-get -y install msodbcsql17 unixodbc-dev libgssapi-krb5-2 
#RUN apt-get update
#RUN apt-get install msodbcsql17 -y
RUN pecl install sqlsrv \
    && pecl install pdo_sqlsrv \ 
    && echo "extension=sqlsrv.so" >> /usr/local/etc/php/conf.d/sqlsrv.ini \
    && echo "extension=pdo_sqlsrv.so" >> /usr/local/etc/php/conf.d/pdo_sqlsrv.ini \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* 


# Install Composer
ENV COMPOSER_HOME /composer
ENV PATH ./vendor/bin:/composer/vendor/bin:$PATH
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer --version

# Add the files and set permissions

WORKDIR /var/www/html
ADD . /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
