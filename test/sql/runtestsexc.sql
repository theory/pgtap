\unset ECHO
\i test/setup.sql
SET client_min_messages = warning;

CREATE SCHEMA whatever;
CREATE TABLE whatever.foo ( id serial primary key );

-- Make sure we get test function names.
SET client_min_messages = notice;

CREATE OR REPLACE FUNCTION whatever.test1this() RETURNS SETOF TEXT AS $$
    SELECT pass('simple pass') AS foo
    UNION SELECT pass('another simple pass')
    ORDER BY foo ASC;
$$ LANGUAGE SQL;

-- Make sure we have tests after the test with exception
CREATE OR REPLACE FUNCTION whatever.test2unexpectedexception() RETURNS SETOF TEXT AS $$
BEGIN
    RAISE EXCEPTION 'Runner should continue after exception in test';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION whatever.test3plpgsql() RETURNS SETOF TEXT AS $$
BEGIN
    RETURN NEXT pass( 'plpgsql simple' );
    RETURN NEXT pass( 'plpgsql simple 2' );
    INSERT INTO whatever.foo VALUES(1);
    RETURN NEXT is( MAX(id), 1, 'Should be a 1 in the test table') FROM whatever.foo;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION whatever.testunexpectedexception() RETURNS SETOF TEXT AS $$
BEGIN
    RAISE EXCEPTION 'Runner should continue after exception in test';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION whatever.teardownunexpectedexception() RETURNS SETOF TEXT AS $$
BEGIN
    RAISE EXCEPTION 'Runner should continue after exception in teardown';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION whatever.shutdownunexpectedexception() RETURNS SETOF TEXT AS $$
BEGIN
    RAISE EXCEPTION 'Runner should continue after exception in shutdown';
END;
$$ LANGUAGE plpgsql;

-- Run the actual tests. Yes, it's a one-liner!
SELECT * FROM runtests('whatever'::name);

ROLLBACK;
