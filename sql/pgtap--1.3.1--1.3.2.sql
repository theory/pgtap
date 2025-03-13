DROP FUNCTION parse_type(type text, OUT typid oid, OUT typmod int4);

CREATE OR REPLACE FUNCTION format_type_string ( TEXT )
RETURNS TEXT AS $$
DECLARE
    want_type TEXT := $1;
    typmodin_arg cstring[];
    typmodin_func regproc;
    typmod int;
BEGIN
    IF want_type::regtype = 'interval'::regtype THEN
        -- RAISE NOTICE 'cannot resolve: %', want_type;  -- TODO
        RETURN want_type;
    END IF;

    -- Extract type modifier from type declaration and format as cstring[] literal.
    typmodin_arg := translate(substring(want_type FROM '[(][^")]+[)]'), '()', '{}');

    -- Find typmodin function for want_type.
    SELECT typmodin INTO typmodin_func
      FROM pg_catalog.pg_type
     WHERE oid = want_type::regtype;

    IF typmodin_func = 0 THEN
        -- Easy: types without typemods.
        RETURN format_type(want_type::regtype, null);
    END IF;

    -- Get typemod via type-specific typmodin function.
    EXECUTE format('SELECT %I(%L)', typmodin_func, typmodin_arg) INTO typmod;
    RETURN format_type(want_type::regtype, typmod);
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE PLPGSQL STABLE;

--added a three columns: "args", "returns", "langname" used in mock_func function
CREATE OR REPLACE VIEW tap_funky
AS 
SELECT p.oid,
	n.nspname AS schema,
	p.proname AS name,
	pg_get_userbyid(p.proowner) AS owner,
	arg._types as args,
	proc_return."returns",
	p.prolang AS langoid,
	p.proisstrict AS is_strict,
	tap._prokind(p.oid) AS kind,
	p.prosecdef AS is_definer,
	p.proretset AS returns_set,
	p.provolatile::character(1) AS volatility,
	pg_function_is_visible(p.oid) AS is_visible,
	l.lanname AS langname
FROM 
	pg_proc p
JOIN 
	pg_namespace n 
ON 
	p.pronamespace = n.oid
LEFT JOIN 
	pg_language l 
ON 
	l.oid = p.prolang
left join lateral (
	select string_agg(nullif(_type, '')::regtype::text, ', ') as _types
	from unnest(regexp_split_to_array(p.proargtypes::text, ' ')) as _type
) as arg on true
 LEFT JOIN LATERAL (
	SELECT  (n.nspname::text || '.'::text) || p.proname::text AS qualified
) proc_name ON true
left join lateral (
	select 
		case 
			when n.nspname != 'pg_catalog' 
				then pg_get_function_result((concat(proc_name.qualified, '(', arg._types, ')')::regprocedure)::oid) 
			else null 
		end AS "returns"
) as proc_return on true;
			
--this procedure creates a mock in place of a real function
create or replace procedure mock_func(
    in _func_schema text
    , in _func_name text
    , in _func_args text
    , in _return_value anyelement
)
--creates mock in place of a real function
 LANGUAGE plpgsql
AS $procedure$
declare 
    _mock_ddl text;
    _func_result_type text;
    _func_qualified_name text;
    _func_language text;
begin
    select 
        "returns"
        , langname
    into 
        _func_result_type
        , _func_language
    from
        tap_funky
    where
        "schema" = _func_schema
        and "name" = _func_name;
    
    _mock_ddl = '
        create or replace function ' || quote_ident(_func_schema) || '.' || quote_ident(_func_name) || _func_args || '
             RETURNS ' || _func_result_type || '
             LANGUAGE ' || _func_language || '
        AS $function$
            select ' || quote_nullable(_return_value) || '::' || pg_typeof(_return_value) || ';
        $function$;';    
    execute _mock_ddl;
end $procedure$;

CREATE OR REPLACE PROCEDURE fake_table(
    IN _table_schema text[], 
    IN _table_name text[], 
    in _make_table_empty boolean default false,
    IN _drop_not_null boolean DEFAULT false, 
    IN _drop_collation boolean DEFAULT false
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
            quote_ident(table_schema) table_schema,
            quote_ident(table_name) table_name,
            table_schema table_schema_l,
            table_name table_name_l
        from 
            unnest(_table_schema, _table_name) as t(table_schema, table_name)
        loop
            for _fk_table in 
                -- collect all table's relations including primary key and unique constraint
                select distinct * 
                from (
                    select 
                        fk_schema_name table_schema, fk_table_name table_name, fk_constraint_name constraint_name, 1 as ord
                    from 
                        pg_all_foreign_keys 
                    where 
                        fk_schema_name = _table.table_schema_l and fk_table_name = _table.table_name_l
                    union all
                    select 
                        fk_schema_name table_schema, fk_table_name table_name, fk_constraint_name constraint_name, 1 as ord
                    from 
                        pg_all_foreign_keys 
                    where 
                        pk_schema_name = _table.table_schema_l and pk_table_name = _table.table_name_l
                    union all
                    select 
                        table_schema, table_name, constraint_name, 2 as ord
                    from 
                        information_schema.table_constraints
                    where 
                        table_schema = _table.table_schema_l
                        and table_name = _table.table_name_l
                        and constraint_type in ('PRIMARY KEY', 'UNIQUE')
                ) as t
                order by ord
            loop
                _fake_ddl = 'alter table ' || _fk_table.table_schema || '.' || _fk_table.table_name || '
                    drop constraint ' || _fk_table.constraint_name || ';';
                execute _fake_ddl;
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

CREATE OR REPLACE FUNCTION _runner(text[], text[], text[], text[], text[])
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
    startup  ALIAS FOR $1;
    shutdown ALIAS FOR $2;
    setup    ALIAS FOR $3;
    teardown ALIAS FOR $4;
    tests    ALIAS FOR $5;
    tap      TEXT;
    tfaild   INTEGER := 0;
    ffaild   INTEGER := 0;
    tnumb    INTEGER := 0;
    fnumb    INTEGER := 0;
    tok      BOOLEAN := TRUE;
BEGIN
    BEGIN
        -- No plan support.
        PERFORM * FROM no_plan();
        FOR tap IN SELECT * FROM _runem(startup, false) LOOP RETURN NEXT tap; END LOOP;
    EXCEPTION
        -- Catch all exceptions and simply rethrow custom exceptions. This
        -- will roll back everything in the above block.
        WHEN raise_exception THEN RAISE EXCEPTION '%', SQLERRM;
    END;

    -- Record how startup tests have failed.
    tfaild := num_failed();

    FOR i IN 1..COALESCE(array_upper(tests, 1), 0) LOOP

        -- What subtest are we running?
        RETURN NEXT diag_test_name('Subtest: ' || tests[i]);

        -- Reset the results.
        tok := TRUE;
        tnumb := COALESCE(_get('curr_test'), 0);

        IF tnumb > 0 THEN
            EXECUTE 'ALTER SEQUENCE __tresults___numb_seq RESTART WITH 1';
            PERFORM _set('curr_test', 0);
            PERFORM _set('failed', 0);
        END IF;

        DECLARE
            errstate text;
            errmsg   text;
            detail   text;
            hint     text;
            context  text;
            schname  text;
            tabname  text;
            colname  text;
            chkname  text;
            typname  text;
        BEGIN
            BEGIN
                -- Run the setup functions.
                FOR tap IN SELECT * FROM _runem(setup, false) LOOP
                    RETURN NEXT regexp_replace(tap, '^', '    ', 'gn');
                END LOOP;
            
                -- Run the actual test function.
                FOR tap IN EXECUTE 'SELECT * FROM ' || tests[i] || '()' LOOP
                    RETURN NEXT regexp_replace(tap, '^', '    ', 'gn');
                END LOOP;

                -- Run the teardown functions.
                FOR tap IN SELECT * FROM _runem(teardown, false) LOOP
                    RETURN NEXT regexp_replace(tap, '^', '    ', 'gn');
                END LOOP;

                -- Emit the plan.
                fnumb := COALESCE(_get('curr_test'), 0);
                RETURN NEXT '    1..' || fnumb;

                -- Emit any error messages.
                IF fnumb = 0 THEN
                    RETURN NEXT '    # No tests run!';
                    tok = false;
                ELSE
                    -- Report failures.
                    ffaild := num_failed();
                    IF ffaild > 0 THEN
                        tok := FALSE;
                        RETURN NEXT '    ' || diag(
                            'Looks like you failed ' || ffaild || ' test' ||
                             CASE ffaild WHEN 1 THEN '' ELSE 's' END
                             || ' of ' || fnumb
                        );
                    END IF;
                END IF;

            EXCEPTION WHEN OTHERS THEN
                -- Something went wrong. Record that fact.
                errstate := SQLSTATE;
                errmsg := SQLERRM;
                GET STACKED DIAGNOSTICS
                    detail  = PG_EXCEPTION_DETAIL,
                    hint    = PG_EXCEPTION_HINT,
                    context = PG_EXCEPTION_CONTEXT,
                    schname = SCHEMA_NAME,
                    tabname = TABLE_NAME,
                    colname = COLUMN_NAME,
                    chkname = CONSTRAINT_NAME,
                    typname = PG_DATATYPE_NAME;
            END;

            -- Always raise an exception to rollback any changes.
            RAISE EXCEPTION '__TAP_ROLLBACK__';

        EXCEPTION WHEN raise_exception THEN
            IF errmsg IS NOT NULL THEN
                -- Something went wrong. Emit the error message.
                tok := FALSE;
               RETURN NEXT regexp_replace( diag('Test died: ' || _error_diag(
                   errstate, errmsg, detail, hint, context, schname, tabname, colname, chkname, typname
               )), '^', '    ', 'gn');
                errmsg := NULL;
            END IF;
        END;

        -- Restore the sequence.
        EXECUTE 'ALTER SEQUENCE __tresults___numb_seq RESTART WITH ' || tnumb + 1;
        PERFORM _set('curr_test', tnumb);
        PERFORM _set('failed', tfaild);

        -- Record this test.
        RETURN NEXT ok(tok, tests[i]);
        IF NOT tok THEN tfaild := tfaild + 1; END IF;

    END LOOP;

    -- Run the shutdown functions.
    FOR tap IN SELECT * FROM _runem(shutdown, false) LOOP RETURN NEXT tap; END LOOP;

    -- Finish up.
    FOR tap IN SELECT * FROM _finish( COALESCE(_get('curr_test'), 0), 0, tfaild ) LOOP
        RETURN NEXT tap;
    END LOOP;

    -- Clean up and return.
    PERFORM _cleanup();
    RETURN;
END;
$function$;

create or replace function drop_prepared_statement(_statement_name text)
returns bool as $$
begin
    if exists(select * from pg_prepared_statements where "name" = _statement_name) then
        EXECUTE format('deallocate %I;', _statement_name);
        return true;
    end if;
    return false;
end
$$
language plpgsql;

create or replace procedure print_table_as_json(in _table_schema text, in _table_name text)
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