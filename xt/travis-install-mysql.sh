#!/bin/bash

set -ex

if [ x"$MYSQL_VERSION" != "x" ]
then
    sudo service mysql stop;
    sudo aptitude purge -y mysql-server libmysqlclient-dev mysql-server-5.6 mysql-common-5.6 mysql-client-5.6 libmysqlclient18 mysql-client-core-5.6 mysql-server-core-5.6 libdbd-mysql-perl mysql-common
    sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5
    . /etc/lsb-release  # sets the env var DISTRIB_CODENAME
    sudo add-apt-repository "deb http://repo.mysql.com/apt/ubuntu/ $DISTRIB_CODENAME mysql-$MYSQL_VERSION"
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -q --yes --fix-broken --allow-unauthenticated --option DPkg::Options::=--force-confnew install mysql-server libmysqlclient-dev
    sudo mysql_upgrade -u root --password='' --force
    sudo service mysql restart
fi

# vim: expandtab shiftwidth=4
