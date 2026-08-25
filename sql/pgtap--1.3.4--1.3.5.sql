-- Changes between pgTAP v1.3.4 and v1.3.5.

-- hasnt_pk( schema, table )
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_pk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a primary key' );
$$ LANGUAGE sql;

-- has_fk( schema, table )
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_fk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a foreign key constraint' );
$$ LANGUAGE sql;

-- hasnt_fk( schema, table )
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_fk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a foreign key constraint' );
$$ LANGUAGE sql;

-- Replace has_unique(TEXT...) with has_unique(NAME...) so (schema, table) can be overloaded.
DROP FUNCTION has_unique ( TEXT, TEXT, TEXT );
DROP FUNCTION has_unique ( TEXT, TEXT );
DROP FUNCTION has_unique ( TEXT );

-- has_unique( schema, table, description )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'u' ), $3 );
$$ LANGUAGE sql;

-- has_unique( schema, table )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_unique( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a unique constraint' );
$$ LANGUAGE sql;

-- has_unique( table, description )
CREATE OR REPLACE FUNCTION has_unique ( NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'u' ), $2 );
$$ LANGUAGE sql;

-- has_unique( table )
CREATE OR REPLACE FUNCTION has_unique ( NAME )
RETURNS TEXT AS $$
    SELECT has_unique( $1, 'Table ' || quote_ident($1) || ' should have a unique constraint' );
$$ LANGUAGE sql;

-- hasnt_unique( schema, table, description )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'u' ), $3 );
$$ LANGUAGE sql;

-- hasnt_unique( schema, table )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_unique( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a unique constraint' );
$$ LANGUAGE sql;

-- hasnt_unique( table, description )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'u' ), $2 );
$$ LANGUAGE sql;

-- hasnt_unique( table )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME )
RETURNS TEXT AS $$
    SELECT hasnt_unique( $1, 'Table ' || quote_ident($1) || ' should not have a unique constraint' );
$$ LANGUAGE sql;

-- has_check( schema, table )
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_check( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a check constraint' );
$$ LANGUAGE sql;

-- hasnt_check( schema, table, description )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'c' ), $3 );
$$ LANGUAGE sql;

-- hasnt_check( schema, table )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_check( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a check constraint' );
$$ LANGUAGE sql;

-- hasnt_check( table, description )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'c' ), $2 );
$$ LANGUAGE sql;

-- hasnt_check( table )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME )
RETURNS TEXT AS $$
    SELECT hasnt_check( $1, 'Table ' || quote_ident($1) || ' should not have a check constraint' );
$$ LANGUAGE sql;

DROP FUNCTION plan( integer );
CREATE OR REPLACE FUNCTION plan( bigint )
RETURNS TEXT AS $$
DECLARE
    rcount INTEGER;
BEGIN
    BEGIN
        EXECUTE '
            CREATE TEMP SEQUENCE __tcache___id_seq;
            CREATE TEMP TABLE __tcache__ (
                id    INTEGER NOT NULL DEFAULT nextval(''__tcache___id_seq''),
                label TEXT    NOT NULL,
                value INTEGER NOT NULL,
                note  TEXT    NOT NULL DEFAULT ''''
            );
            CREATE UNIQUE INDEX __tcache___key ON __tcache__(id);
            GRANT ALL ON TABLE __tcache__ TO PUBLIC;
            GRANT ALL ON TABLE __tcache___id_seq TO PUBLIC;

            CREATE TEMP SEQUENCE __tresults___numb_seq;
            GRANT ALL ON TABLE __tresults___numb_seq TO PUBLIC;
        ';

    EXCEPTION WHEN duplicate_table THEN
        -- Raise an exception if there's already a plan.
        EXECUTE 'SELECT TRUE FROM __tcache__ WHERE label = ''plan''';
      GET DIAGNOSTICS rcount = ROW_COUNT;
        IF rcount > 0 THEN
           RAISE EXCEPTION 'You tried to plan twice!';
        END IF;
    END;

    -- Save the plan and return.
    PERFORM _set('plan', $1::int );
    PERFORM _set('failed', 0 );
    RETURN '1..' || $1;
END;
$$ LANGUAGE plpgsql strict;

-- is_definer() / isnt_definer() / is_strict() / isnt_strict(): report missing
-- functions instead of a NULL test result.

-- is_definer( schema, function, args[] )
CREATE OR REPLACE FUNCTION is_definer( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, $3, _definer($1, $2, $3),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '(' ||
        array_to_string($3, ', ') || ') should be security definer'
    );
$$ LANGUAGE sql;

-- is_definer( schema, function )
CREATE OR REPLACE FUNCTION is_definer( NAME, NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, _definer($1, $2),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '() should be security definer'
    );
$$ LANGUAGE sql;

-- is_definer( function, args[] )
CREATE OR REPLACE FUNCTION is_definer( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, $2, _definer($1, $2),
        'Function ' || quote_ident($1) || '(' ||
        array_to_string($2, ', ') || ') should be security definer'
    );
$$ LANGUAGE sql;

-- is_definer( function )
CREATE OR REPLACE FUNCTION is_definer( NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, _definer($1),
        'Function ' || quote_ident($1) || '() should be security definer'
    );
$$ LANGUAGE sql;

-- isnt_definer( schema, function, args[] )
CREATE OR REPLACE FUNCTION isnt_definer( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, $3, NOT _definer($1, $2, $3),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '(' ||
        array_to_string($3, ', ') || ') should not be security definer'
    );
$$ LANGUAGE sql;

-- isnt_definer( schema, function )
CREATE OR REPLACE FUNCTION isnt_definer( NAME, NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, NOT _definer($1, $2),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '() should not be security definer'
    );
$$ LANGUAGE sql;

-- isnt_definer( function, args[] )
CREATE OR REPLACE FUNCTION isnt_definer( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, $2, NOT _definer($1, $2),
        'Function ' || quote_ident($1) || '(' ||
        array_to_string($2, ', ') || ') should not be security definer'
    );
$$ LANGUAGE sql;

-- isnt_definer( function )
CREATE OR REPLACE FUNCTION isnt_definer( NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, NOT _definer($1),
        'Function ' || quote_ident($1) || '() should not be security definer'
    );
$$ LANGUAGE sql;

-- is_strict( schema, function, args[] )
CREATE OR REPLACE FUNCTION is_strict( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, $3, _strict($1, $2, $3),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '(' ||
        array_to_string($3, ', ') || ') should be strict'
    );
$$ LANGUAGE sql;

-- is_strict( schema, function )
CREATE OR REPLACE FUNCTION is_strict( NAME, NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, _strict($1, $2),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '() should be strict'
    );
$$ LANGUAGE sql;

-- is_strict( function, args[] )
CREATE OR REPLACE FUNCTION is_strict( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, $2, _strict($1, $2),
        'Function ' || quote_ident($1) || '(' ||
        array_to_string($2, ', ') || ') should be strict'
    );
$$ LANGUAGE sql;

-- is_strict( function )
CREATE OR REPLACE FUNCTION is_strict( NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, _strict($1),
        'Function ' || quote_ident($1) || '() should be strict'
    );
$$ LANGUAGE sql;

-- isnt_strict( schema, function, args[] )
CREATE OR REPLACE FUNCTION isnt_strict( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, $3, NOT _strict($1, $2, $3),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '(' ||
        array_to_string($3, ', ') || ') should not be strict'
    );
$$ LANGUAGE sql;

-- isnt_strict( schema, function )
CREATE OR REPLACE FUNCTION isnt_strict( NAME, NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        $1, $2, NOT _strict($1, $2),
        'Function ' || quote_ident($1) || '.' || quote_ident($2) || '() should not be strict'
    );
$$ LANGUAGE sql;

-- isnt_strict( function, args[] )
CREATE OR REPLACE FUNCTION isnt_strict( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, $2, NOT _strict($1, $2),
        'Function ' || quote_ident($1) || '(' ||
        array_to_string($2, ', ') || ') should not be strict'
    );
$$ LANGUAGE sql;

-- isnt_strict( function )
CREATE OR REPLACE FUNCTION isnt_strict( NAME )
RETURNS TEXT AS $$
    SELECT _func_compare(
        NULL, $1, NOT _strict($1),
        'Function ' || quote_ident($1) || '() should not be strict'
    );
$$ LANGUAGE sql;
