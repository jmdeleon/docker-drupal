FROM debian:jessie
MAINTAINER Jose de Leon <jose_de_leon@hotmail.com>
ENV DEBIAN_FRONTEND noninteractive
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install base packages
RUN apt-get update && apt-get install -y \
	build-essential \
	vim \
	curl \
	wget \
	nano \
	zip unzip \
	openssh-server \
	openjdk-7-jdk \
	ruby ruby-dev ri \
	python-pip \
	python-virtualenv \
	golang \
	lua5.2 \
	open-cobol \
	git \
	mercurial \
	supervisor

# Install Node.js
RUN curl --silent --location https://deb.nodesource.com/setup_4.x | bash -
RUN apt-get install --yes nodejs
RUN curl -L --insecure https://www.npmjs.org/install.sh | bash

# Install MongoDB
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen' | tee /etc/apt/sources.list.d/mongodb.list
RUN apt-get update
RUN mkdir -p /data/db
RUN apt-get install -y libkrb5-dev libreadline-dev adduser mongodb-org

# Install updated PHP 5.6 and Apache from dotdeb.org repository
RUN echo -e '\n\ndeb http://packages.dotdeb.org jessie all\ndeb-src http://packages.dotdeb.org jessie all\n\n' >>  /etc/apt/sources.list
RUN wget --quiet -O - https://www.dotdeb.org/dotdeb.gpg | apt-key add -
RUN apt-get update && apt-get upgrade && apt-get install -y \
	apache2 \
	apache2-dev \
	sqlite3 \
	libapache2-mod-php5 \
	mysql-server \
	mysql-client \
	php5-fpm \
	php5-dev \
	php-pear \
	php5-cli \
	php5-mysql \
	php5-gd \
	php5-curl \
	php5-sqlite

# Install PostgreSQL 9.4 from PostgreSQL repository 
RUN echo -e '\n\ndeb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main\n\n' >>  /etc/apt/sources.list
RUN apt-get -y install ca-certificates
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update && apt-get upgrade && apt-get install -y postgresql-9.4 postgresql-client php5-pgsql

# Install Phusion Passenger + Apache module through Phusion's APT repository.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
RUN apt-get install -y apt-transport-https ca-certificates
RUN sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger jessie main > /etc/apt/sources.list.d/passenger.list'
RUN apt-get update && apt-get install -y libapache2-mod-passenger

RUN apt-get autoremove && apt-get clean

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Install Drush dev-master
RUN composer global require drush/drush:dev-master
RUN composer global update
# Unfortunately, adding the composer vendor dir to the PATH doesn't seem to work. So:
RUN ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush

# Setup PHP
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/cli/php.ini
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/apache2/php.ini
RUN sed -i 's/memory_limit = 128M/memory_limit = 384M/' /etc/php5/apache2/php.ini
RUN sed -i 's/max_execution_time = 30/max_execution_time = 600/' /etc/php5/apache2/php.ini
RUN sed -i 's/max_input_time = 60/max_input_time = 120/' /etc/php5/apache2/php.ini
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 300M/' /etc/php5/apache2/php.ini
RUN sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/' /etc/php5/apache2/php.ini
RUN sed -i 's/;date.timezone =/date.timezone = "UTC"/' /etc/php5/apache2/php.ini

# Setup Apache
# In order to run our Simpletest tests, we need to make Apache
# listen on the same port as the one we forwarded. Because we use
# 8080 by default, we set it up for that port.
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN echo "Listen 8080" >> /etc/apache2/ports.conf
RUN sed -i 's/VirtualHost *:80/VirtualHost */' /etc/apache2/sites-available/000-default.conf

# Setup MySQL, bind on all addresses
RUN sed -i -e 's/^bind-address\s*=\s*127.0.0.1/#bind-address = 127.0.0.1/' /etc/mysql/my.cnf

# Configure PostgreSQL
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf

# there might be a docker bug that postgresql could access /etc/ssl/private/ssl-cert-snakeoil.key
RUN sed -i "s/ssl = true/ssl = false/g" /etc/postgresql/9.4/main/postgresql.conf

# start postgresql and reset postgres user's password
USER postgres
RUN /etc/init.d/postgresql start && \
    psql -e --command "ALTER USER postgres WITH PASSWORD 'postgres'" && \
    /etc/init.d/postgresql stop
# Go back to root
USER root

# Setup SSH.
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd
RUN mkdir -p /root/.ssh/ && touch /root/.ssh/authorized_keys
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Setup PHP support for MongoDB
RUN echo -e '\n' | pecl install mongo
RUN echo -e '\nextension = mongo.so\n\n' >> /etc/php5/apache2/php.ini

# Setup PHP support for uploadprogress
RUN echo -e '\n' | pecl install uploadprogress
RUN echo -e '\nextension = uploadprogress.so\n\n' >> /etc/php5/apache2/php.ini

# Setup Supervisor
RUN echo -e '\n[inet_http_server]\nport = *:9001\nusername = supervisor\npassword = supervisor\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:apache2]\ncommand=/usr/bin/pidproxy /var/run/apache2/apache2.pid /bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND"\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:mysql]\ncommand=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/sbin/mysqld\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:sshd]\ncommand=/usr/sbin/sshd -D\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
# Setup Supervisor PostgreSQL
RUN echo -e '[program:postgresql]\nuser=postgres\nautorestart=true\ncommand=/usr/lib/postgresql/9.4/bin/postgres -D /var/lib/postgresql/9.4/main -c config_file=/etc/postgresql/9.4/main/postgresql.conf\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
# Setup Supervisor Solr
RUN echo -e '[program:solr]\ncommand=/usr/bin/java -Xmx512M -server -jar start.jar\ndirectory=/usr/share/solr/example\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
# Setup Supervisor MongoDB
RUN echo -e '[program:mongod]\ncommand=/usr/bin/mongod --smallfiles\nautostart=true\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf

# Download Drupal
RUN rm -rf /var/www/html
RUN cd /var && \
# Download the Web Experience Toolkit Drupal distribution
	drush dl wetkit-7.x-4.x-dev && mv /var/wetkit* /var/www/html
# Replace the line above with the line below to download the stock Drupal core distribution
#	drush dl drupal && mv /var/drupal* /var/www/html
RUN mkdir -p /var/www/html/sites/default/files && \
	chmod a+w /var/www/html/sites -R && \
	mkdir /var/www/html/sites/all/modules/contrib -p && \
	mkdir /var/www/html/sites/all/modules/custom && \
	mkdir /var/www/html/sites/all/modules/features && \
	mkdir /var/www/html/sites/all/themes/contrib -p && \
	mkdir /var/www/html/sites/all/themes/custom && \
	chown -R www-data:www-data /var/www/html

# Setup Node.js build tools
RUN npm install -g grunt grunt-cli yo bower coffee-script cobol nativescript express mongodb pg mysql node-gyp sqlite3 consolidate swig mongoose

# Setup Ruby Rake, Bundle, SASS, and Compass gems
RUN gem install rake bundler sass compass rails

# Setup Adminer
RUN mkdir /usr/share/adminer
RUN wget --quiet -c http://www.adminer.org/latest.php -O /usr/share/adminer/adminer.php
RUN echo -e '<?php phpinfo(); ?>' >> /usr/share/adminer/php-info.php
RUN echo -e 'Alias /php-info.php /usr/share/adminer/php-info.php' > /etc/apache2/mods-available/adminer.load
RUN echo -e 'Alias /adminer.php /usr/share/adminer/adminer.php' >> /etc/apache2/mods-available/adminer.load

RUN a2enmod alias auth_basic auth_digest authn_file authz_groupfile authz_host authz_user autoindex cgi dav dav_fs dbd deflate dir env expires headers include mime negotiation php5 proxy proxy_html proxy_http passenger reqtimeout rewrite setenvif speling ssl status suexec xml2enc adminer

# Setup Solr
RUN wget -nv -c http://archive.apache.org/dist/lucene/solr/4.10.4/solr-4.10.4.tgz -O /tmp/solr-4.10.4.tgz
RUN cd /tmp && tar xzf solr-4.10.4.tgz && mv solr-4.10.4 /usr/share/solr && rm /tmp/solr-4.10.4.tgz

# Install Drupal
# RUN cd /var/www/html && drush si -y minimal --db-url=mysql://root:@localhost/drupal --account-pass=admin

# Expose application ports and start Supervisor to manage service applications
EXPOSE 80 3306 22 5432 8983 9001 27017 28017
CMD exec supervisord -n -c /etc/supervisor/supervisord.conf

