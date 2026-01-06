\unset ECHO
\i test/setup.sql
-- \i sql/pgtap.sql

SELECT plan(3);
--SELECT * FROM no_plan();

-- This will be rolled back. :-)
--SET track_functions = 'all';

-- This will be rolled back. :-)
SET client_min_messages = warning;

create or replace function public.scalar_function()
returns time
language sql
as $$
    select now()::time;
$$;

create or replace function public.set_sql_function()
returns table(id int, col text)
language sql
as $$
    select * FROM (VALUES(1, 'a'), (2, 'b')) AS t(id, col);
$$;

create or replace function public.set_plpgsql_function()
returns table(id int, col text)
language plpgsql
as $$
begin
    RETURN query select * FROM (VALUES(1, 'a'), (2, 'b')) AS t(id, col);
END;
$$;

RESET client_min_messages;

CREATE FUNCTION test_mocking_functionality() RETURNS SETOF TEXT AS $$
DECLARE
	_hour_before time;
	_mock_result time;
BEGIN
	_hour_before = now() - INTERVAL '01:00'; 
	perform mock_func('public', 'scalar_function', '()'
        , _return_scalar_value => _hour_before::time);
	_mock_result = scalar_function();

	RETURN query SELECT * FROM check_test(
		is(_mock_result, _hour_before),
		TRUE,
		'mock scalar_function');

	PREPARE mock_set_sql_function AS SELECT * FROM (VALUES(1, 'x'), (2, 'z')) AS t(id, col) ORDER BY id;
	perform mock_func('public', 'set_sql_function', '()'
        , _return_set_value => 'mock_set_sql_function');
	PREPARE returned_set_sql_function AS SELECT * FROM set_sql_function() ORDER BY id;

	RETURN query SELECT * FROM check_test(
		results_eq('returned_set_sql_function', 'mock_set_sql_function'),
		TRUE,
		'mock sql function returning a set');

	PREPARE mock_set_plpgsql_function AS SELECT * FROM (VALUES(1, 'w'), (2, 'q')) AS t(id, col) ORDER BY id;
	perform mock_func('public', 'set_plpgsql_function', '()'
        , _return_set_value => 'mock_set_plpgsql_function');
	PREPARE returned_set_plpgsql_function AS SELECT * FROM set_plpgsql_function() ORDER BY id;

	RETURN query SELECT * FROM check_test(
		results_eq('returned_set_plpgsql_function', 'mock_set_plpgsql_function'),
		TRUE,
		'mock plpgsql function returning a set');
END;
$$ LANGUAGE plpgsql;

SELECT * FROM test_mocking_functionality();

-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
