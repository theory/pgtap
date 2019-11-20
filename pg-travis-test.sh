#!/bin/bash

# Based on https://gist.github.com/petere/6023944

set -E -e -u -o pipefail 

export DEBUG=1
set -x

export UPGRADE_TO=${UPGRADE_TO:-}
failed=''

sudo apt-get update

get_packages() {
    echo "libtap-parser-sourcehandler-pgtap-perl postgresql-$1 postgresql-server-dev-$1"
}
get_path() {
    # See also test/test_MVU.sh
    echo "/usr/lib/postgresql/$1/bin/"
}

# Do NOT use () here; we depend on being able to set failed
test_cmd() (
#local status rc
if [ "$1" == '-s' ]; then
    status="$2"
    shift 2
else
    status="$1"
fi

echo
echo #############################################################################
echo "PG-TRAVIS: running $@"
echo #############################################################################
# Use || so as not to trip up -e, and a sub-shell to be safe.
rc=0
( "$@" ) || rc=$?
if [ $rc -ne 0 ]; then
    error test
    echo
    echo '!!!!!!!!!!!!!!!! FAILURE !!!!!!!!!!!!!!!!'
    echo "$@" returned $rc
    echo '!!!!!!!!!!!!!!!! FAILURE !!!!!!!!!!!!!!!!'
    echo
    failed="$failed '$status'"
fi
)

# Ensure test_cmd sets failed properly
test_cmd fail > /dev/null 2>&1
[ -n "$failed" ] || die 91 "test_cmd did not set \$failed"
failed=''

test_make() {
    # Many tests depend on install, so just use sudo for all of them
    test_cmd -s "$*" sudo make "$@"
}

########################################################
# Install packages
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

# Need to explicitly set which pg_config we want to use
export PG_CONFIG="$(get_path $PGVERSION)pg_config"
[ "$PG_CONFIG" != 'pg_config' ]

# Make life easier for test_MVU.sh
sudo usermod -a -G postgres $USER


# Setup cluster
export PGPORT=55435
export PGUSER=postgres
sudo pg_createcluster --start $PGVERSION test -p $PGPORT -- -A trust

sudo easy_install pgxnclient

set +x
test_make clean regress

# pg_regress --launcher not supported prior to 9.1
# There are some other failures in 9.1 and 9.2 (see https://travis-ci.org/decibel/pgtap/builds/358206497).
echo $PGVERSION | grep -qE "8[.]|9[.][012]" || test_make clean updatecheck

# Explicitly test these other targets

# TODO: install software necessary to allow testing 'html' target
for t in all install test ; do
    # Test from a clean slate...
    test_make uninstall clean $t
    # And then test again
    test_make $t
done

if [ -n "$UPGRADE_TO" ]; then
    # We need to tell test_MVU.sh to run some steps via sudo since we're
    # actually installing from pgxn into a system directory.  We also use a
    # different port number to avoid conflicting with existing clusters.
    test_cmd test/test_MVU.sh -s 55667 55778 $PGVERSION $UPGRADE_TO "$(get_path $PGVERSION)" "$(get_path $UPGRADE_TO)"
fi

if [ -n "$failed" ]; then
    # $failed will have a leading space if it's not empty
    echo "These test targets failed:$failed"
    exit 1
fi
