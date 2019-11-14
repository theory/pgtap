#!/usr/bin/env bash

# Test performing a Major Version Upgrade via pg_upgrade.
#
# MVU can be problematic due to catalog changes. For example, if the extension
# contains a view that references a catalog column that no longer exists,
# pg_upgrade itself will break.

set -E -e -u -o pipefail 

keep=''
if [ "$1" == "-k" ]; then
    keep=1
    shift
fi

sudo=''
if [ "$1" == '-s' ]; then
    # Useful error if we can't find sudo
    which sudo > /dev/null
    sudo=$(which sudo)
    shift
fi

PGPORT=$1
OLD_PATH="$2"
NEW_PATH="$3"

DBNAME=test_pgtap_upgrade

# ###########
# TODO: break these functions into a library shell script so they can be used elsewhere

error() {
    echo "$@" >&2
}

die() {
    rc=$1
    shift
    error "$@"
    exit $rc
}

DEBUG=${DEBUG:-0}
debug() {
    local level
    level=$1
    shift
    [ $level -gt $DEBUG ] || error "$@"
}

byte_len() (
[ $# -eq 1 ] || die 99 "Expected 1 argument, not $# ($@)"
LANG=C LC_ALL=C
debug 99 "byte_len($@) = ${#1}"
echo ${#1}
)

check_bin() {
    for f in pg_ctl psql initdb; do
        [ -x "$1/$f" ] || die 1 "$1/$f does not exist or is not executable"
    done
}

# mktemp on OS X results is a super-long path name that can cause problems, ie:
#   connection to database failed: Unix-domain socket path "/private/var/folders/rp/mv0457r17cg0xqyw5j7701892tlc0h/T/test_pgtap_upgrade.upgrade.7W4BLF/.s.PGSQL.50432" is too long (maximum 103 bytes)
#
# This function looks for that condition and replaces the output with something more sane
short_tmpdir() (
[ $# -eq 1 ] || die 99 "Expected 1 argument, not $# ($@)"
[ "$TMPDIR" != "" ] || die 99 '$TMPDIR not set'
out=$(mktemp -p '' -d $1.XXXXXX)
if echo "$out" | egrep -q '^(/private)?/var/folders'; then
    newout=$(echo "$out" | sed -e "s#.*/$TMPDIR#$TMPDIR#")
    debug 19 "replacing '$out' with '$newout'"
fi

debug 9 "$0($@) = $out"
# Postgres blows up if this is too long. Technically the limit is 103 bytes,
# but need to account for the socket name, plus the fact that OS X might
# prepend '/private' to what we return. :(
[ $(byte_len "$out") -lt 75 ] || die 9 "short_tmpdir($@) returning a value >= 75 bytes ('$out')"
echo "$out"
)

banner() {
    echo
    echo '###################################'
    echo "$@"
    echo '###################################'
    echo
}

check_bin "$OLD_PATH"
check_bin "$NEW_PATH"

export PATH="$OLD_PATH:$PATH"

export TMPDIR=${TMPDIR:-${TEMP:-${TMP:-/tmp}}}
debug 9 "\$TMPDIR=$TMPDIR"
[ $(byte_len "$TMPDIR") -lt 50 ] || die 9 "\$TMPDIR ('$TMPDIR') is too long; please set it" '(or $TEMP, or $TMP) to a value less than 50 bytes'
upgrade_dir=$(short_tmpdir test_pgtap_upgrade.upgrade)
old_dir=$(short_tmpdir test_pgtap_upgrade.old)
new_dir=$(short_tmpdir test_pgtap_upgrade.new)
if [ -n "$keep" ]; then
    trap "rm -rf '$upgrade_dir' '$old_dir' '$new_dir'" EXIT
fi
export PGDATA=$old_dir

export PGPORT

banner "Creating old version temporary installation at $old_dir on port $PGPORT"
initdb #TODO9.2: Add this back in when dropping 9.2 support: --no-sync
echo "port = $PGPORT" >> $PGDATA/postgresql.conf
echo "synchronous_commit = off" >> $PGDATA/postgresql.conf

echo "Installing pgtap"
# If user requested sudo then we need to use it for the install step. TODO:
# it'd be nice to move this into the Makefile, if the PGXS make stuff allows
# it...
( cd $(dirname $0)/.. && $sudo make clean install )

banner "Starting OLD postgres via" `which pg_ctl`
pg_ctl start -w # older versions don't support --wait

echo "Creating database"
createdb

banner "Loading extension"
psql -c 'CREATE EXTENSION pgtap'

echo "Stopping OLD postgres via" `which pg_ctl`
pg_ctl sotp -w # older versions don't support --wait

export PGDATA=$new_dir
export PATH="$NEW_PATH:$PATH"

banner "Creating new version temporary installation at $new_dir on port $PGPORT"
initdb #TODO9.2: Add this back in when dropping 9.2 support: --no-sync
echo "port = $PGPORT" >> $PGDATA/postgresql.conf
echo "synchronous_commit = off" >> $PGDATA/postgresql.conf

echo "Running pg_upgrade"
cd $upgrade_dir
pg_upgrade -d "$old_dir" -D "$new_dir" -b "$OLD_PATH" -B "$NEW_PATH"
