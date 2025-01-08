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

--added a column "langname" used in mock_func function
CREATE OR REPLACE VIEW tap_funky
 AS SELECT p.oid         AS oid,
           n.nspname     AS schema,
           p.proname     AS name,
           pg_catalog.pg_get_userbyid(p.proowner) AS owner,
           array_to_string(p.proargtypes::regtype[], ',') AS args,
           CASE p.proretset WHEN TRUE THEN 'setof ' ELSE '' END
             || p.prorettype::regtype AS returns,
           p.prolang     AS langoid,
           p.proisstrict AS is_strict,
           _prokind(p.oid) AS kind,
           p.prosecdef   AS is_definer,
           p.proretset   AS returns_set,
           p.provolatile::char AS volatility,
           pg_catalog.pg_function_is_visible(p.oid) AS is_visible,
		   l.lanname AS langname
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
	  LEFT JOIN pg_language l ON l.oid = p.prolang
;
			
--this procedure creates a mock in place of a real function
create or replace procedure mock_func(
    _func_schema text
    , _func_name text
    , _func_args text
    , _return_set_value text default null
    , _return_scalar_value anyelement default null::text
)
--creates a mock in place of a real function
 LANGUAGE plpgsql
AS $procedure$
declare 
    _mock_ddl text;
    _func_result_type text;
    _func_qualified_name text;
    _func_language text;
	_returns_set bool;
begin
    select "returns", langname, returns_set
    into _func_result_type, _func_language, _returns_set
    from tap_funky
    where "schema" = _func_schema
        and "name" = _func_name;

	if _func_language = 'sql' and _returns_set then
		_mock_ddl = '
	        create or replace function ' || quote_ident(_func_schema) || '.__' || quote_ident(_func_name) || '(_name text)
	             returns ' || _func_result_type || '
	             language plpgsql
	        AS $function$
			begin
	            return query execute _query(' || quote_literal(_return_set_value) || ');
			end;
	        $function$;';   
	    execute _mock_ddl;
		_mock_ddl = '
	        create or replace function ' || quote_ident(_func_schema) || '.' || quote_ident(_func_name) || _func_args || '
	             returns ' || _func_result_type || '
	             language ' || _func_language || '
	        AS $function$
	            select * from ' || quote_ident(_func_schema) || '.__' || quote_ident(_func_name) || 
					'(' || quote_literal(_return_set_value) || ');
	        $function$;';    
	    execute _mock_ddl;
	end if;
    
	if _func_language = 'plpgsql' and _returns_set then
		_mock_ddl = '
	        create or replace function ' || quote_ident(_func_schema) || '.' || quote_ident(_func_name) || _func_args || '
	             returns ' || _func_result_type || '
	             language plpgsql
	        AS $function$
			begin
	            return query execute _query(' || quote_literal(_return_set_value) || ');
			end;
	        $function$;';   
	    execute _mock_ddl;
	end if;

	if not _returns_set then
		_mock_ddl = '
	        create or replace function ' || quote_ident(_func_schema) || '.' || quote_ident(_func_name) || _func_args || '
	             RETURNS ' || _func_result_type || '
	             LANGUAGE ' || _func_language || '
	        AS $function$
	            select ' || quote_nullable(_return_scalar_value) || '::' || pg_typeof(_return_scalar_value) || ';
	        $function$;';
	    execute _mock_ddl;
	end if;
end $procedure$;


CREATE OR REPLACE PROCEDURE fake_table(
    _table_ident text[], 
    _make_table_empty boolean default false,
    _leave_primary_key boolean default false,
    _drop_not_null boolean DEFAULT false, 
    _drop_collation boolean DEFAULT false
)
--It frees a table from any constraint (we call such a table as a fake)
--faked table is a full copy of _table_name, but has no any constraint
--without foreign and primary things you can do whatever you want in testing context
 LANGUAGE plpgsql
AS $procedure$
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
	                _fake_ddl = 'alter table ' || _fk_table.table_schema || '.' || _fk_table.table_name || '
	                    drop constraint ' || _fk_table.constraint_name || ';';
	                execute _fake_ddl;
				end if;
            end loop;
        
            if _make_table_empty then
                _fake_ddl = 'truncate table ' || _table.table_schema || '.' || _table.table_name || ';';
                execute _fake_ddl;
            end if;
            
            --Free table from not null constraints
            _fake_ddl = 'alter table ' || _table.table_schema || '.' || _table.table_name || ' ';
            if _drop_not_null then
                select 
                    string_agg('alter column ' || t.attname || ' drop not null', ', ')
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
end $procedure$;

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
        , format('routine %I.%I must have been called %L times, actual call count is %L'
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


create or replace procedure print_table_as_json(_table_schema text, _table_name text)
 language plpgsql
AS $procedure$
declare 
    _ddl text;
    _json text;
    _columns text;
--returns a query which you can execute and see your table as normal dataset
--note! the returned dataset is limited to 1000 records. that's why you didn't get any jdbc error in dbeaver in case of huge amount of rows 
begin
    _ddl = '  
        select json_agg(
            array(select ' || quote_ident(_table_name) || ' from ' || quote_ident(_table_schema) || '.' || quote_ident(_table_name) || ' limit 1000
        )) as j;';
    execute _ddl into _json;
    _json = '[' || ltrim(rtrim(_json::text, ']'), '[') || ']';

    select string_agg(concat(c.column_name, ' ', case when lower(c.data_type) = 'array' then e.data_type || '[]' else c.data_type end), ', ')
    into _columns
    from information_schema."columns" c
    left join information_schema.element_types e
     on ((c.table_catalog, c.table_schema, c.table_name, 'TABLE', c.dtd_identifier)
       = (e.object_catalog, e.object_schema, e.object_name, e.object_type, e.collection_type_identifier))
    where c.table_schema = _table_schema
        and c.table_name = _table_name;

    _json = $$select * from /*$$ || quote_ident(_table_schema) || '.' || quote_ident(_table_name) || $$*/ json_to_recordset('$$ || _json || $$') as t($$ || _columns || $$)$$;
    raise notice '%', _json;
end $procedure$;

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

CREATE OR REPLACE VIEW tap_funky
 AS 
 SELECT 
	p.oid                                    AS oid,
	n.nspname                                AS schema,
	p.proname                                AS name,
	pg_catalog.pg_get_userbyid(p.proowner)   AS owner,
	proc_name.args                           AS args,
	lower(coalesce(
		proc_return."returns", 
		proc_return.sys_returns))            AS "returns",
	p.prolang                                AS langoid,
	p.proisstrict                            AS is_strict,
	_prokind(p.oid)                          AS kind,
	p.prosecdef                              AS is_definer,
	p.proretset                              AS returns_set,
	p.provolatile::char                      AS volatility,
	pg_catalog.pg_function_is_visible(p.oid) AS is_visible,
	l.lanname                                AS langname
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
LEFT JOIN pg_language l ON l.oid = p.prolang
LEFT JOIN LATERAL (
	SELECT  
		(n.nspname::text || '.'::text) || p.proname::text AS qualified,
		array_to_string(p.proargtypes::regtype[], ',') AS args
) proc_name ON true
LEFT JOIN LATERAL (
	SELECT 
		CASE 
			WHEN n.nspname != 'pg_catalog' 
				THEN pg_get_function_result((concat(proc_name.qualified, '(', proc_name.args, ')')::regprocedure)::oid) 
			ELSE NULL 
		END AS "returns",
		CASE p.proretset WHEN TRUE THEN 'setof ' ELSE '' END || p.prorettype::regtype AS sys_returns
) AS proc_return ON TRUE;
