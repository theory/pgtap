\unset ECHO
SET client_min_messages = warning;
CREATE ROLE tap_testman LOGIN NOSUPERUSER;
CREATE DATABASE tap_testdb WITH OWNER = tap_testman;
\c tap_testdb;
CREATE LANGUAGE plpgsql;

\i test/setup.sql

SELECT plan(3);

-- This will be rolled back. :-)
--RESET client_min_messages;
/****************************************************************************/
SELECT  * From check_test( 
	db_owner_is('blob','should end up with an error, because user is unknown'), 
	false
);
SELECT  * From check_test( 
	db_owner_is('tap_testman','user tap_testman should own current database'), 
	true, 
	'CHECK_TEST: user tap_testman should own current database'
);
SELECT  * From check_test( 
	db_owner_is('tap_testman','tap_testdb','user tap_testman should own db tap_testdb'), 
	true, 
	'CHECK_TEST: user tap_testman should own db tap_testdb'
);


/****************************************************************************/
-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
\c template1;
DROP DATABASE tap_testdb;
DROP ROLE tap_testman;
