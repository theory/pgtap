#!/bin/bash

# Based on https://gist.github.com/petere/6023944

set -eux
failed=''

sudo apt-get update

get_packages() {
    echo "postgresql-$1 postgresql-server-dev-$1"
}
get_path() {
    echo "/usr/lib/postgresql/$1/bin/"
}

packages="python-setuptools postgresql-common $(get_packages $PGVERSION)"

if [ -n "$UPGRADE_TO" ]; then
    packages="$packages $(get_packages $UPGRADE_TO)"
fi

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
export PG_CONFIG="$(get_path $PGVERSION)pg_config"
[ "$PG_CONFIG" != 'pg_config' ]
sudo pg_createcluster --start $PGVERSION test -p $PGPORT -- -A trust

sudo easy_install pgxnclient

test_make() {
    set +ux
    # Many tests depend on install, so just use sudo for all of them
    if ! sudo make "$@"; then
        echo
        echo '!!!!!!!!!!!!!!!!'
        echo "make $@ failed"
        echo '!!!!!!!!!!!!!!!!'
        echo
        failed="$failed '$@'"
    fi
    set -ux
}

test_make clean regress

# pg_regress --launcher not supported prior to 9.1
# There are some other failures in 9.1 and 9.2 (see https://travis-ci.org/decibel/pgtap/builds/358206497).
echo $PGVERSION | grep -qE "8[.]|9[.][012]" || test_make clean updatecheck

# Explicitly test these other targets

# TODO: install software necessary to allow testing the 'test' and 'html' targets
for t in all install ; do
    test_make clean $t
    test_make $t
done

if [ -n "$UPGRADE_TO" ]; then
    # Note that we shouldn't need to run this as root since it's creating a
    # temporary install. We also use a different port number to avoid
    # conflicting with existing clusters.
    set +ux
    test/test_MVU.sh 55667 "$(get_path $PGVERSION)" "$(get_path $UPGRADE_TO)"
    rc=$?
    set -ux
    if [ $rc -ne 0 ]; then
        echo
        echo '!!!!!!!!!!!!!!!!'
        echo test/test_MVU.sh 55667 "$(get_path $PGVERSION)" "$(get_path $UPGRADE_TO)" returned $0
        echo '!!!!!!!!!!!!!!!!'
        echo
        failed="$failed 'test/test_MVU.sh'"
    fi
fi

if [ -n "$failed" ]; then
    set +ux
    # $failed will have a leading space if it's not empty
    echo "These test targets failed:$failed"
    exit 1
fi
