Drupal development with Docker
==============================

Quick and easy to use Docker container for your *local Drupal development*. It contains a LAMP stack and an SSH server, along with an up to date version of Drush. It is based on [Debian Wheezy](https://wiki.debian.org/DebianWheezy).

Summary
-------

This image contains:

* Apache 2.2
* MySQL 5.6
* PostgreSQL 9.4
* SQLite 3.7
* PHP 5.6
* Drupal 7.x, [Web Experience Toolkit distribution](https://www.drupal.org/project/wetkit) 4.0, development edition (optionally supports current Drupal)
* Drush 7.0
* Apache Solr 4.10.4
* [Composer](https://getcomposer.org/)
* [Adminer](http://www.adminer.org/) 4.2
* [Supervisor](http://supervisord.org/)
* nano, vim, git and mercurial (hg)

When launched, the container will contain a ready-to-install Drupal distribution, with no database configured. You need to first create a database by using Adminer off the web root at `/adminer.php`, then select one of PostgreSQL, MySQL or SQLite as a database, when kicking off a Drupal install.

### Passwords

* Drupal: `admin:admin`
* MySQL: `root:` (no password)
* PostgreSQL: `postgres:postgres`
* SSH: `root:root`
* Supervisor `supervisor:supervisor`

### Exposed ports

* 80 (Apache)
* 22 (SSH)
* 3306 (MySQL)
* 5432 (PostgreSQL)
* 8983 (Solr)
* 9001 (Supervisor)

Tutorial
--------

You can read more about the original container this is based on [here](http://wadmiraal.net/lore/2015/03/27/use-docker-to-kickstart-your-drupal-development/).

Installation
------------

### Github

https://github.com/jmdeleon/docker-drupal

Clone the repository locally and build it:

	git clone https://github.com/jmdeleon/docker-drupal.git
	cd docker-drupal
	docker build -t yourname/drupal .

### Docker repository

https://registry.hub.docker.com/u/jmdeleon/docker-drupal-wxt/

Get the image:

	docker pull jmdeleon/docker-drupal-wxt

Running the container
---------------------

For optimum usage, map some local directories to the container for easier development. I personally create at least a `modules/` directory which will contain my custom modules. You can do the same for your themes.

The container exposes its `80` port (Apache), its `3306` port (MySQL), its `5432` port (PostgreSQL), its `8983` port (Apache Solr), its `9001` port (Supervisor) and its `22` port (SSH). Make good use of this by forwarding your local ports. You should at least forward to port `80` (using `-p local_port:80`, like `-p 8080:80`). A good idea is to also forward port `22`, so you can use Drush from your local machine using aliases, and directly execute commands inside the container, without attaching to it.

Here's an example just running the container and forwarding `localhost:8080`, `localhost:2222`, `localhost:8984`, `localhost:9291` to the container:

	docker run -d --name youralias -p 8080:80 -p 2222:22 -p 8984:8983 -p 9291:9001 -t yourname/drupal

### MySQL, PostgreSQL, SQLite and Adminer

Adminer can be used to administer MySQL, PostgreSQL and SQLite databases. Adminer is aliased to the web root at `/adminer.php`.

The MySQL port `3306` is exposed. The root account for MySQL is `root` (no password).

The PostgreSQL port `5432` is exposed. The root account for PostgreSQL is `postgres` (password `postgres`).

### Supervisor

Supervisor provides a rudimentary web UI over the port `9001` to manage several of the server processes (Apache, MySQL, PostgreSQL, sshd, Solr). It can be found over http `localhost:9291` in the above example, logging in with the id `supervisor` and the password also `supervisor`.

### Apache Solr

Apache Solr 4.x is installed across port `8983`. If port `8983` is mapped as above, Solr is accessible via http `localhost:8984/solr`.

Developing in this container
----------------------------

### Writing code locally

Here's an example running the container, forwarding port `8080` like before, but also mounting Drupal's `sites/all/modules/custom/` folder to my local `modules/` folder. I can then start writing code on my local machine, directly in this folder, and it will be available inside the container:

	docker run -d -p 8080:80 -v `pwd`/modules:/var/www/sites/all/modules/custom -t yourname/drupal

### Using Drush

Using Drush aliases, I can directly execute Drush commands locally and have them be executed inside the container. Create a new aliases file in your home directory and add the following:

	# ~/.drush/docker.aliases.drushrc.php
	<?php
	$aliases['wadmiraal_drupal'] = array(
	  'root' => '/var/www',
	  'remote-user' => 'root',
	  'remote-host' => 'localhost',
	  'ssh-options' => '-p 8022', // Or any other port you specify when running the container
	);

Next, if you do not wish to type the root password everytime you run a Drush command, copy the content of your local SSH public key (usually `~/.ssh/id_rsa.pub`; read [here](https://help.github.com/articles/generating-ssh-keys/) on how to generate one if you don't have it). SSH into the running container:

	# If you forwarded another port than 8022, change accordingly.
	# Password is "root".
	ssh root@localhost -p 8022

Once you're logged in, add the contents of your `id_rsa.pub` file to `/root/.ssh/authorized_keys`. Exit.

You should now be able to call:

	drush @docker.wadmiraal_drupal cc all

This will clear the cache of your Drupal site. All other commands will function as well.
