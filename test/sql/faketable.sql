\unset ECHO
\i test/setup.sql
-- \i sql/pgtap.sql

SELECT plan(21);
--SELECT * FROM no_plan();

-- This will be rolled back. :-)
SET track_functions = 'all';
SET client_min_messages = warning;

create or replace function public.scalar_function()
returns time
language plpgsql
as $$
begin
    return now()::time;
end;
$$;

create or replace function public.set_sql_function()
returns table(id int, f text)
language sql
as $$
    select * from (values(1, 'a'), (2, 'b'), (3, 'c')) as t(id, f);
$$;

create or replace function public.set_sql_function(_whatever text)
returns table(id int, f text)
language sql
as $$
    select * from (values(1, 'a' || _whatever), (2, 'b' || _whatever)) as t(id, f);
$$;

CREATE TABLE public.parent(
	id int NOT NULL, col text NOT NULL,
	CONSTRAINT parent_pk PRIMARY KEY (id)
);

CREATE TABLE public.child(
	id int NOT NULL,
	parent_id int NOT NULL,
	col text NOT NULL,
	CONSTRAINT child_pk PRIMARY KEY (id),
	CONSTRAINT child_fk FOREIGN KEY (parent_id) REFERENCES parent(id)
);

INSERT INTO public.parent(id, col) values(1, 'a');

INSERT INTO public.child(id, parent_id, col) values(1, 1, 'b');

RESET client_min_messages;

CREATE FUNCTION test_faking_functionality() RETURNS SETOF TEXT AS $$
BEGIN
	perform fake_table(
		'{public.parent}'::text[],
		_make_table_empty => TRUE,
		_leave_primary_key => TRUE,
		_drop_not_null => FALSE);

	perform fake_table(
		'{public.child}'::text[],
		_make_table_empty => TRUE,
		_leave_primary_key => FALSE,
		_drop_not_null => TRUE);

	RETURN query SELECT * FROM check_test(
		col_is_pk('public', 'parent', '{id}'::name[]),
		TRUE,
		'public.parent.id is primary key');

	RETURN query SELECT * FROM check_test(
		col_isnt_pk('public', 'child', 'id'),
		TRUE,
		'public.child.id is not primary key');

	RETURN query SELECT * FROM check_test(
		col_isnt_fk('public', 'child', 'parent_id'),
		TRUE,
		'public.child.parent_id is not foreign key');

	RETURN query SELECT * FROM check_test(
		col_not_null('public', 'parent', 'id', ''),
		TRUE,
		'public.parent.id is not null');
	
	RETURN query SELECT * FROM check_test(
		col_not_null('public', 'parent', 'col', ''),
		TRUE,
		'public.parent.col is null');
	
	RETURN query SELECT * FROM check_test(
		col_is_null('public', 'child', 'id', ''),
		TRUE,
		'public.child.id is null');
	
	RETURN query SELECT * FROM check_test(
		col_is_null('public', 'child', 'parent_id', ''),
		TRUE,
		'public.child.parent_id is null');

	RETURN query SELECT * FROM check_test(
		col_is_null('public', 'child', 'col', ''),
		TRUE,
		'public.child.col is null');

	PREPARE parent_all AS SELECT * FROM public.parent;
	PREPARE child_all AS SELECT * FROM public.child;

	RETURN query SELECT * FROM check_test(
		is_empty('parent_all'),
		TRUE,
		'table public.parent is empty');

	RETURN query SELECT * FROM check_test(
		is_empty('child_all'),
		TRUE,
		'table public.child is empty');

	RETURN query SELECT * FROM check_test(
		lives_ok('INSERT INTO child(id, parent_id, col) values(1, 108, ''z'')'),
		TRUE,
		'We can do insert into foreign key column');
END;
$$ LANGUAGE plpgsql;

CREATE TABLE public.pk_plus_not_null(
	id int NOT NULL,
	num varchar(10) not null,
	tale text not null,
    comments text,
	CONSTRAINT pk_plus_not_null_pk PRIMARY KEY (id, num)
);

CREATE FUNCTION test_faking_functionality_pk_not_null() RETURNS SETOF TEXT AS $$
BEGIN
	perform fake_table(
		'{public.pk_plus_not_null}'::text[],
		_leave_primary_key => TRUE,
		_make_table_empty => TRUE,
		_drop_not_null => TRUE);

	RETURN query SELECT * FROM check_test(
		col_is_pk('public', 'pk_plus_not_null', '{id, num}'::name[]),
		TRUE,
		'public.pk_plus_not_null primary key is (id, num)');

	RETURN query SELECT * FROM check_test(
		col_isnt_pk('public', 'pk_plus_not_null', '{tale, comments}'::name[], 'no pk'),
		TRUE,
		'Columns tale and comments of public.pk_plus_not_null are not part of primary key');

	RETURN query SELECT * FROM check_test(
		col_not_null('public', 'pk_plus_not_null', 'id', ''),
		TRUE,
		'public.pk_plus_not_null.id is not null');

	RETURN query SELECT * FROM check_test(
		col_not_null('public', 'pk_plus_not_null', 'num', ''),
		TRUE,
		'public.pk_plus_not_null.num is not null');

	RETURN query SELECT * FROM check_test(
		col_is_null('public', 'pk_plus_not_null', 'tale', ''),
		TRUE,
		'public.pk_plus_not_null.tale is null');

	RETURN query SELECT * FROM check_test(
		col_is_null('public', 'pk_plus_not_null', 'comments', ''),
		TRUE,
		'public.pk_plus_not_null.comments is null');
END;
$$ LANGUAGE plpgsql;

create table public.parts(
	id int,
	tale text,
	date_key date
)
partition by range(date_key);

create table public.part_202509 partition of public.parts
	for values from ('2025-09-01') to ('2025-10-01');

create table public.part_202510 partition of public.parts
	for values from ('2025-10-01') to ('2025-11-01');

create or replace FUNCTION test_faking_functionality_no_partitions() RETURNS SETOF TEXT AS $$
BEGIN
	perform fake_table(
		'{public.parts}'::text[],
		_drop_partitions => TRUE);

	RETURN query SELECT * FROM check_test(
		partitions_are('public', 'parts', '{}'::name[], 'No partitions we expect'),
		TRUE,
		'public.parts should have no any partition');
END;
$$ LANGUAGE plpgsql;

SELECT * FROM test_faking_functionality();
SELECT * FROM test_faking_functionality_pk_not_null();
SELECT * FROM test_faking_functionality_no_partitions();

CREATE FUNCTION test_call_count_functionality() RETURNS SETOF TEXT AS $$
BEGIN
	perform public.scalar_function();
	perform public.set_sql_function();
	perform public.set_sql_function();
	perform public.set_sql_function('whatever');

	RETURN query SELECT * FROM check_test(
		call_count(1, 'public', 'scalar_function', '{}'::name[]),
		TRUE,
		'public.scalar_function called once');

	RETURN query SELECT * FROM check_test(
		call_count(2, 'public', 'set_sql_function', '{}'::name[]),
		TRUE,
		'public.set_sql_function called twice');

	RETURN query SELECT * FROM check_test(
		call_count(1, 'public', 'set_sql_function', '{text}'::name[]),
		TRUE,
		'public.set_sql_function(text) called once');
END;
$$ LANGUAGE plpgsql;

SELECT * FROM test_call_count_functionality();

RESET track_functions;

-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
