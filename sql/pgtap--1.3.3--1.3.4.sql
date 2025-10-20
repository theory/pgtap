-- has_composite( schema, type )
CREATE OR REPLACE FUNCTION has_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_composite(
        $1, $2,
        'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should exist'
    );
$$ LANGUAGE SQL;

-- hasnt_composite( schema, type )
CREATE OR REPLACE FUNCTION hasnt_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_composite(
        $1, $2,
        'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should not exist'
    );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_routine_signature(
	_routine_schema name
	, _routine_name name)
 RETURNS TABLE (routine_schema TEXT, routine_name TEXT, routine_params TEXT)
 LANGUAGE SQL STABLE
AS $function$
	SELECT
		"schema", "name", args_with_defs
	FROM tap_funky
	WHERE
		"schema" = _func_schema and
		"name" = _func_name;
$function$;

CREATE OR REPLACE FUNCTION get_routine_signature(
	_routine_name name)
 RETURNS TABLE (routine_schema TEXT, routine_name TEXT, routine_params TEXT)
 LANGUAGE SQL STABLE
AS $function$
	SELECT
		"schema", "name", args_with_defs
	FROM tap_funky
	WHERE
		"name" = _func_name;
$function$;

--this function creates a mock in place of a real function
create or replace function mock_func(
    _func_schema text
    , _func_name text
    , _func_args text
    , _return_set_value text default null
    , _return_scalar_value anyelement default null::text
)
returns void
--creates a mock in place of a real function
 LANGUAGE plpgsql
AS $function$
declare
    _mock_ddl text;
    _func_result_type text;
    _func_qualified_name text;
    _func_language text;
	_returns_set bool;
	_variants text;
	_ex_msg text;
begin
	--First of all, we have to identify which function we must mock. If there is no such function, throw an error.
	begin
	    select "returns", langname, returns_set
	    into strict _func_result_type, _func_language, _returns_set
	    from tap_funky
	    where "schema" = _func_schema
	        and "name" = _func_name
	        and args_with_defs = _func_args;
		exception when NO_DATA_FOUND or TOO_MANY_ROWS then
			select string_agg(E'\t - ' || format('%I.%I %s', "schema", "name", args_with_defs), E'\n')::text
			into _variants
			from tap_funky
			where "name" = _func_name;
			_ex_msg = format('Routine %I.%I %s does not exist.',
				_func_schema, _func_name, _func_args) || E'\n' || 'Possible variants are:' || E'\n' || _variants;
            raise exception '%', _ex_msg;
	end;

	--This is the case when we need to mock a function written in SQL.
	--But in order to be able to execute the mocking functionality, we need to have a function written in plpgsql.
	--That is why we create a hidden function which name starts with "__".
	if _func_language = 'sql' and _returns_set then
		_mock_ddl = format('
	        create or replace function %1$I.__%2$I(_name text)
	             returns %3$s
	             language plpgsql
	        AS %5$sfunction%5$s
			begin
	            return query execute _query(%4$L);
			end;
	        %5$sfunction%5$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_result_type/*3*/, _return_set_value/*4*/, '$'/*5*/);
	    execute _mock_ddl;
		_mock_ddl = format('
	        create or replace function %1$I.%2$I %3$s
	             returns %4$s
	             language %5$s
	        AS %7$sfunction%7$s
	            select * from %1$I.__%2$I ( %6$s );
	        %7$sfunction%7$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
			_func_language/*5*/, _return_set_value/*6*/, '$'/*7*/);
	    execute _mock_ddl;
	end if;

	if _func_language = 'plpgsql' and _returns_set then
		_mock_ddl = format('
	        create or replace function %1$I.%2$I %3$s
	             returns %4$s
	             language plpgsql
	        AS %6$sfunction%6$s
			begin
	            return query execute _query( %5$s );
			end;
	        %6$sfunction%6$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
			_return_set_value/*5*/, '$'/*6*/);
	    execute _mock_ddl;
	end if;

	if not _returns_set then
		_mock_ddl = format('
	        create or replace function %1$I.%2$I %3$s
	             RETURNS %4$s
	             LANGUAGE %5$s
	        AS %8$sfunction%8$s
	            select %6$L::%7$s;
	        %8$sfunction%8$s;',
			_func_schema/*1*/,  _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
			_func_language/*5*/, _return_scalar_value/*6*/, pg_typeof(_return_scalar_value)/*7*/, '$'/*8*/);
	    execute _mock_ddl;
	end if;
end $function$;

create or replace function fake_table(
    _table_ident text[],
    _make_table_empty boolean default false,
    _leave_primary_key boolean default false,
    _drop_not_null boolean DEFAULT false,
    _drop_collation boolean DEFAULT false
)
returns void
--It frees a table from any constraint (we call such a table as a fake)
--faked table is a full copy of _table_name, but has no any constraint
--without foreign and primary things you can do whatever you want in testing context
 LANGUAGE plpgsql
AS $function$
declare
    _table record;
    _fk_table record;
    _fake_ddl text;
    _not_null_ddl text;
begin
    for _table in
        select
            quote_ident(coalesce((parse_ident(table_ident))[1], '')) table_schema,
            quote_ident(coalesce((parse_ident(table_ident))[2], '')) table_name,
            coalesce((parse_ident(table_ident))[1], '') table_schema_l,
            coalesce((parse_ident(table_ident))[2], '') table_name_l
        from
            unnest(_table_ident) as t(table_ident)
        loop
            for _fk_table in
                -- collect all table's relations including primary key and unique constraint
                select distinct *
                from (
                    select
                        fk_schema_name table_schema, fk_table_name table_name
						, fk_constraint_name constraint_name, false as is_pk, 1 as ord
                    from
                        pg_all_foreign_keys
                    where
                        fk_schema_name = _table.table_schema_l and fk_table_name = _table.table_name_l
                    union all
                    select
                        fk_schema_name table_schema, fk_table_name table_name
						, fk_constraint_name constraint_name, false as is_pk, 1 as ord
                    from
                        pg_all_foreign_keys
                    where
                        pk_schema_name = _table.table_schema_l and pk_table_name = _table.table_name_l
                    union all
                    select
                        table_schema, table_name
						, constraint_name
						, case when constraint_type = 'PRIMARY KEY' then true else false end as is_pk, 2 as ord
                    from
                        information_schema.table_constraints
                    where
                        table_schema = _table.table_schema_l
                        and table_name = _table.table_name_l
                        and constraint_type in ('PRIMARY KEY', 'UNIQUE')
                ) as t
                order by ord
            loop
				if not(_leave_primary_key and _fk_table.is_pk) then
	                _fake_ddl = format('alter table %1$I.%2$I drop constraint %3$I;',
	                	_fk_table.table_schema/*1*/, _fk_table.table_name/*2*/, _fk_table.constraint_name/*3*/
	                );
	                execute _fake_ddl;
				end if;
            end loop;

            if _make_table_empty then
                _fake_ddl = format('truncate table %1$s.%2$s;', _table.table_schema, _table.table_name);
                execute _fake_ddl;
            end if;

            --Free table from not null constraints
            _fake_ddl = format('alter table %1$s.%2$s ', _table.table_schema, _table.table_name);
            if _drop_not_null then
                select
                    string_agg(format('alter column %1$I drop not null', t.attname), ', ')
                into
                    _not_null_ddl
                from
                    pg_catalog.pg_attribute t
                where t.attrelid = (_table.table_schema || '.' || _table.table_name)::regclass
                    and t.attnum > 0 and attnotnull;

                _fake_ddl = _fake_ddl || _not_null_ddl || ';';
            else
                _fake_ddl = null;
            end if;

            if _fake_ddl is not null then
                execute _fake_ddl;
            end if;
        end loop;
end $function$;

create or replace function call_count(
	_call_count int
	, _func_schema name
	, _func_name name
	, _func_args name[])
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
    _actual_call_count int;
	_track_functions_setting text;
begin
	select current_setting('track_functions') into _track_functions_setting;

	if _track_functions_setting != 'all' then
	    return fail('track_functions setting is not set. Must be all');
	end if;

	select calls into _actual_call_count
	from pg_stat_xact_user_functions
	where funcid = _get_func_oid(_func_schema, _func_name, _func_args);

    return ok(
        _actual_call_count = _call_count
        , format('routine %I.%I must has been called %L times, actual call count is %L'
        	, _func_schema, _func_name, _call_count, _actual_call_count)
    );
end $function$;

create or replace function drop_prepared_statement(_statements text[])
returns setof bool as $$
declare
    _statement record;
begin
	for _statement in select _name from unnest(_statements) as t(_name) loop
	    if exists(select * from pg_prepared_statements where "name" = _statement._name) then
	        EXECUTE format('deallocate %I;', _statement._name);
	        return next true;
		else
			return next false;
	    end if;
	end loop;
end
$$
language plpgsql;


create or replace function print_table_as_json(in _table_schema text, in _table_name text)
returns void
 language plpgsql
AS $function$
declare
    _ddl text;
    _json text;
    _columns text;
--returns a query which you can execute and see your table as normal dataset
--you can find the returned query in the output window in DBeaver, where we see raise notice command output
--note! the returned dataset is limited to 1000 records. that's why you didn't get any jdbc error in dbeaver in case of huge amount of rows
begin
    _ddl = format('
        select json_agg(
            array(select %1$I from %2$I.%1$I limit 1000
        )) as j;', _table_name, _table_schema);
    execute _ddl into _json;
    _json = '[' || ltrim(rtrim(_json::text, ']'), '[') || ']';

    select string_agg(concat(quote_ident(c.column_name), ' ', case when lower(c.data_type) = 'array' then e.data_type || '[]' else c.data_type end), ', ')
    into _columns
    from information_schema."columns" c
    left join information_schema.element_types e
     on ((c.table_catalog, c.table_schema, c.table_name, 'TABLE', c.dtd_identifier)
       = (e.object_catalog, e.object_schema, e.object_name, e.object_type, e.collection_type_identifier))
    where c.table_schema = _table_schema
        and c.table_name = _table_name;

    _json = format('select * from /*%1$I.%2$I*/ json_to_recordset(%3$L) as t(%4$s)',
		_table_schema/*1*/, _table_name/*2*/, _json/*3*/, _columns/*4*/);
    raise notice '%', _json;
end $function$;

create or replace function print_query_as_json(in _prepared_statement_name text)
returns void
 language plpgsql
as $function$
declare
    _ddl text;
	_table_name text;
--returns a query which you can execute and see your table as normal dataset
--you can find the returned query in the output window in DBeaver, where we see raise notice command output
--note! the returned dataset is limited to 1000 records. that's why you didn't get any jdbc error in dbeaver in case of huge amount of rows
begin
	_table_name = _prepared_statement_name || '_' || gen_random_uuid();
    _ddl = format('create table public.%1$I as execute %2$s', _table_name, _prepared_statement_name);
	execute _ddl;
	perform print_table_as_json('public', _table_name::text);
end;
$function$;


CREATE OR REPLACE FUNCTION _get_func_oid(name, name, name[])
 RETURNS oid
 LANGUAGE sql
AS $function$
    SELECT oid
      FROM tap_funky
     WHERE "schema" = $1
	   and "name" = $2
       AND args = _funkargs($3)
       AND is_visible
$function$
;


-- index_is_partial( schema, table, index, description )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME, NAME, text )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ct    ON ct.oid = x.indrelid
      JOIN pg_catalog.pg_class ci    ON ci.oid = x.indexrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = ct.relnamespace
     WHERE ct.relname = $2
       AND ci.relname = $3
       AND n.nspname  = $1
      INTO res;

      RETURN ok( COALESCE(res, false), $4 );
END;
$$ LANGUAGE plpgsql;

-- index_is_partial( schema, table, index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT index_is_partial(
        $1, $2, $3,
        'Index ' || quote_ident($3) || ' should be partial'
    );
$$ LANGUAGE sql;

-- index_is_partial( table, index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ct ON ct.oid = x.indrelid
      JOIN pg_catalog.pg_class ci ON ci.oid = x.indexrelid
     WHERE ct.relname = $1
       AND ci.relname = $2
       AND pg_catalog.pg_table_is_visible(ct.oid)
     INTO res;

      RETURN ok(
          COALESCE(res, false),
          'Index ' || quote_ident($2) || ' should be partial'
      );
END;
$$ LANGUAGE plpgsql;

-- index_is_partial( index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ci ON ci.oid = x.indexrelid
      JOIN pg_catalog.pg_class ct ON ct.oid = x.indrelid
     WHERE ci.relname = $1
       AND pg_catalog.pg_table_is_visible(ct.oid)
      INTO res;

      RETURN ok(
          COALESCE(res, false),
          'Index ' || quote_ident($1) || ' should be partial'
      );
END;
$$ LANGUAGE plpgsql;