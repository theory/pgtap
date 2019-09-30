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

PGPORT=$1
OLD_PATH="$2"
NEW_PATH="$3"

DBNAME=test_pgtap_upgrade

check_bin() {
    for f in pg_ctl psql initdb; do
        if ! [ -x "$1/$f" ]; then
            echo "$1/$f does not exist or is not executable" >&2
            exit 1
        fi
    done
}

check_bin "$OLD_PATH"
check_bin "$NEW_PATH"

export PATH="$OLD_PATH:$PATH"

export TMPDIR=${TMPDIR-:${TEMP-:${TMP-:/tmp}}}
upgrade_dir=$(mktemp -p '' -d test_pgtap_upgrade.upgrade.XXXXXX)
old_dir=$(mktemp -p '' -d test_pgtap_upgrade.old.XXXXXX)
new_dir=$(mktemp -p '' -d test_pgtap_upgrade.new.XXXXXX)
if [ -n "$keep" ]; then
    trap "rm -rf '$upgrade_dir' '$old_dir' '$new_dir'" EXIT
fi
export PGDATA=$old_dir

export PGPORT

echo "Creating old version temporary installation at $old_dir on port $PGPORT"
initdb --no-sync
echo "port = $PGPORT" >> $PGDATA/postgresql.conf
echo "synchronous_commit = off" >> $PGDATA/postgresql.conf

echo "Installing pgtap"
( cd $(dirname $0)/.. && make clean install )

echo "Starting postgres"
pg_ctl start --wait

echo "Creating database"
createdb

echo "Loading extension"
psql -c 'CREATE EXTENSION pgtap'

echo "Stopping database"
pg_ctl stop --wait

export PGDATA=$new_dir
export PATH="$NEW_PATH:$PATH"

echo "Creating new version temporary installation at $new_dir on port $PGPORT"
initdb --no-sync
echo "port = $PGPORT" >> $PGDATA/postgresql.conf
echo "synchronous_commit = off" >> $PGDATA/postgresql.conf

echo "Running pg_upgrade"
cd $upgrade_dir
pg_upgrade -d "$old_dir" -D "$new_dir" -b "$OLD_PATH" -B "$NEW_PATH"
