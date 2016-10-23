#!/bin/bash

set -eux

sudo apt-get update

packages="postgresql-$PGVERSION postgresql-server-dev-$PGVERSION postgresql-common"

# bug: http://www.postgresql.org/message-id/20130508192711.GA9243@msgid.df7cb.de
sudo update-alternatives --remove-all postmaster.1.gz

# stop all existing instances (because of https://github.com/travis-ci/travis-cookbooks/pull/221)
sudo service postgresql stop
# and make sure they don't come back
echo 'exit 0' | sudo tee /etc/init.d/postgresql
sudo chmod a+x /etc/init.d/postgresql

sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install $packages

status=0
sudo pg_createcluster --start $PGVERSION test -p 55435 -- -A trust

make all
sudo make install
export PGPORT=55435
export PGUSER=postgres
export PG_CONFIG=/usr/lib/postgresql/$PGVERSION/bin/pg_config

make regress || failed=true # Don't exit yet if this failed

sudo make uninstall updatecheck # updatecheck depends on install, so must be sudo

[ -n "$failed" ]
