FROM php:8.2-apache

ENV ACCEPT_EULA=Y

ENV APACHE_DOCUMENT_ROOT /var/www/html

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf


# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        wget \ 
        unzip \
        apt-utils \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libaio1 \
        libxml2-dev \
        libmagickwand-dev \
        #libldap2-dev \
    && docker-php-ext-install -j$(nproc) iconv gettext \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install soap \
    && docker-php-ext-install pdo pdo_mysql mysqli bcmath

# Install XDebug - Required for code coverage in PHPUnit
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
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
RUN a2enmod rewrite && a2enmod headers && service apache2 restart

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

RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8-3.0.1
RUN echo "extension=oci8.so" > /usr/local/etc/php/conf.d/php-oci8.ini

# Install git
RUN apt-get -y install git unixodbc-dev unixodbc
    
# Install MS ODBC Driver for SQL Server
RUN curl -sSL -O https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
# Install the package
RUN dpkg -i packages-microsoft-prod.deb
# Delete the file
RUN rm packages-microsoft-prod.deb
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y msodbcsql18
# optional: for bcp and sqlcmd
RUN ACCEPT_EULA=Y apt-get install -y mssql-tools18
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
#RUN source ~/.bashrc
# optional: for unixODBC development headers
RUN apt-get install -y unixodbc-dev
# optional: kerberos library for debian-slim distributions
RUN apt-get install -y libgssapi-krb5-2

RUN pecl install sqlsrv \
    && pecl install pdo_sqlsrv \ 
    && echo "extension=sqlsrv.so" >> /usr/local/etc/php/conf.d/sqlsrv.ini \
    && echo "extension=pdo_sqlsrv.so" >> /usr/local/etc/php/conf.d/pdo_sqlsrv.ini 

#mongodb
RUN pecl install mongodb \
    && echo "extension=mongodb.so" >> /usr/local/etc/php/conf.d/mongodb.ini

# Install Composer
ENV COMPOSER_HOME /composer
ENV PATH ./vendor/bin:/composer/vendor/bin:$PATH
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer --version

RUN docker-php-ext-install sockets && apt-get install -y libicu-dev zlib1g-dev libzip-dev \ 
&& docker-php-ext-configure intl \
&& docker-php-ext-install intl \ 
&& docker-php-ext-configure zip \
&& docker-php-ext-install zip

#RUN apt-get install -y nodejs npm

#clean
RUN apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* 

# Add the files and set permissions
WORKDIR /var/www/html
ADD phpinfo.php /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
