CREATE OR REPLACE FUNCTION _runner( text[], text[], text[], text[], text[] )
RETURNS SETOF TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- col_is_pk( schema, table, column[] )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_is_pk( $1, $2, $3, 'Columns ' || quote_ident($1) || '.' || quote_ident($2) || '(' || _ident_array_to_string($3, ', ') || ') should be a primary key' );
$$ LANGUAGE sql;

-- col_is_pk( schema, table, column )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_is_pk( $1, $2, $3, 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '(' || quote_ident($3) || ') should be a primary key' );
$$ LANGUAGE sql;

-- col_has_exclusion(schema, table, columns, description)
CREATE OR REPLACE FUNCTION col_has_exclusion(TEXT, TEXT, TEXT[], TEXT)
RETURNS TEXT AS $$
    SELECT ok(array_agg(attr.attname)::TEXT[] @> $3 AND $3 @> array_agg(attr.attname)::TEXT[])
    FROM pg_constraint AS con
    JOIN LATERAL unnest(con.conkey) AS attnums (num) ON TRUE
    JOIN pg_attribute AS attr ON attr.attrelid = con.conrelid
        AND attr.attnum = attnums.num
    WHERE conrelid = format('%1$I.%2$I', $1, $2)::regclass
        AND contype = 'x';
$$ LANGUAGE sql;

-- set_eq( array, array, description )
CREATE OR REPLACE FUNCTION set_eq(anyarray, anyarray, TEXT)
RETURNS TEXT AS $$
    SELECT ok($1 @> $2 AND $2 @> $1, $3);
$$ LANGUAGE sql;

-- set_eq( array, array )
CREATE OR REPLACE FUNCTION set_eq(anyarray, anyarray)
RETURNS TEXT AS $$
    SELECT set_eq($1, $2, 'arrays have identical contents')
$$ LANGUAGE sql;

-- table_comment_has(schema, table, comment, description)
CREATE OR REPLACE FUNCTION table_comment_has(TEXT, TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT ok(COUNT(*) >= 1, $4)
    FROM pg_description
    JOIN LATERAL regexp_split_to_table(description, '\n') AS lines (line) ON TRUE
    WHERE objoid = format('%1$I.%2$I', $1, $2)::regclass
        AND objsubid = 0
        AND trim(line) ILIKE $3
$$ LANGUAGE sql;

-- table_comment_has(schema, table, comment)
CREATE OR REPLACE FUNCTION table_comment_has(TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT table_comment_has($1, $2, $3, 'table comment contains expected line');
$$ LANGUAGE sql;

-- column_comment_has(schema, table, column, comment, description)
CREATE OR REPLACE FUNCTION column_comment_has(TEXT, TEXT, TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT ok(COUNT(*) >= 1, $5)
    FROM pg_description
    JOIN pg_attribute AS attr
        ON attr.attrelid = pg_description.objoid
        AND attr.attnum = pg_description.objsubid
    JOIN LATERAL regexp_split_to_table(description, '\n') AS lines (line) ON TRUE
    WHERE objoid = format('%1$I.%2$I', $1, $2)::regclass
        AND attr.attname = $3::name
        AND trim(line) ILIKE $4
$$ LANGUAGE sql;

-- column_comment_has(schema, table, column, comment)
CREATE OR REPLACE FUNCTION column_comment_has(TEXT, TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT column_comment_has($1, $2, $3, $4, 'column comment contains expected line');
$$ LANGUAGE sql;

-- function_comment_has(schema, function, comment, description)
CREATE OR REPLACE FUNCTION function_comment_has(TEXT, TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT ok(COUNT(*) >= 1, $4)
    FROM pg_description
    JOIN LATERAL regexp_split_to_table(description, '\n') AS lines (line) ON TRUE
    WHERE objoid = format('%1$I.%2$I', $1, $2)::regproc
        AND objsubid = 0
        AND trim(line) ILIKE $3
$$ LANGUAGE sql;

-- function_comment_has(schema, function, comment)
CREATE OR REPLACE FUNCTION function_comment_has(TEXT, TEXT, TEXT)
RETURNS TEXT AS $$
    SELECT function_comment_has($1, $2, $3, 'function comment contains expected line');
$$ LANGUAGE sql;

-- rls_is_enabled(schema, table, desired_value)
CREATE OR REPLACE FUNCTION rls_is_enabled(TEXT, TEXT, BOOLEAN)
RETURNS TEXT AS $$
    SELECT ok(relrowsecurity IS NOT DISTINCT FROM $3)
    FROM pg_class
    WHERE oid = format('%1$I.%2$I', $1, $2)::regclass
$$ LANGUAGE sql;
