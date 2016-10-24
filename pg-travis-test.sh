#!/bin/bash

# Based on https://gist.github.com/petere/6023944

set -eux
failed=''

sudo apt-get update

packages="python-setuptools postgresql-$PGVERSION postgresql-server-dev-$PGVERSION postgresql-common"

# bug: http://www.postgresql.org/message-id/20130508192711.GA9243@msgid.df7cb.de
sudo update-alternatives --remove-all postmaster.1.gz

# stop all existing instances (because of https://github.com/travis-ci/travis-cookbooks/pull/221)
sudo service postgresql stop
# and make sure they don't come back
echo 'exit 0' | sudo tee /etc/init.d/postgresql
sudo chmod a+x /etc/init.d/postgresql

sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install $packages

export PGPORT=55435
export PGUSER=postgres
export PG_CONFIG=/usr/lib/postgresql/$PGVERSION/bin/pg_config
sudo pg_createcluster --start $PGVERSION test -p $PGPORT -- -A trust

make all

sudo easy_install pgxnclient

sudo make regress || failed=true # Don't exit yet if this failed

# pg_regress --launcher not supported prior to 9.1
echo $PGVERSION | grep -qE "8[.]|9[.][0]" || sudo make updatecheck # updatecheck depends on install, so must be sudo

[ -z "$failed" ]
