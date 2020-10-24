CREATE OR REPLACE FUNCTION pgtap_version()
RETURNS NUMERIC AS 'SELECT 1.2;'
LANGUAGE SQL IMMUTABLE;

-- has_view( schema, view )
CREATE OR REPLACE FUNCTION has_view ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_view ($1, $2, 
    'View ' || quote_ident($1) || '.' || quote_ident($2) || ' should exist'
    );    
$$ LANGUAGE SQL;

-- hasnt_view( schema, table )
CREATE OR REPLACE FUNCTION hasnt_view ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_view( $1, $2,
        'View ' || quote_ident($1) || '.' || quote_ident($2) || ' should not exist'
    );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION _def_is( TEXT, TEXT, anyelement, TEXT )
RETURNS TEXT AS $$
DECLARE
    thing text;
BEGIN
    -- Function, cast, or special SQL syntax.
    IF $1 ~ '^[^'']+[(]' OR $1 ~ '[)]::[^'']+$' OR $1 = ANY('{CURRENT_CATALOG,CURRENT_ROLE,CURRENT_SCHEMA,CURRENT_USER,SESSION_USER,USER,CURRENT_DATE,CURRENT_TIME,CURRENT_TIMESTAMP,LOCALTIME,LOCALTIMESTAMP}') THEN
        RETURN is( $1, $3, $4 );
    END IF;

    EXECUTE 'SELECT is('
             || COALESCE($1, 'NULL' || '::' || $2) || '::' || $2 || ', '
             || COALESCE(quote_literal($3), 'NULL') || '::' || $2 || ', '
             || COALESCE(quote_literal($4), 'NULL')
    || ')' INTO thing;
    RETURN thing;
END;
$$ LANGUAGE plpgsql;

-- hasnt_operator( left_type, schema, name, right_type, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists($1, $2, $3, $4, $5 ), $6 );
$$ LANGUAGE SQL;

-- hasnt_operator( left_type, schema, name, right_type, return_type )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, $3, $4, $5 ),
        'Operator ' || quote_ident($2) || '.' || $3 || '(' || $1 || ',' || $4
        || ') RETURNS ' || $5 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_operator( left_type, name, right_type, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists($1, $2, $3, $4 ), $5 );
$$ LANGUAGE SQL;

-- hasnt_operator( left_type, name, right_type, return_type )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, $3, $4 ),
        'Operator ' ||  $2 || '(' || $1 || ',' || $3
        || ') RETURNS ' || $4 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_operator( left_type, name, right_type, description )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists($1, $2, $3 ), $4 );
$$ LANGUAGE SQL;

-- hasnt_operator( left_type, name, right_type )
CREATE OR REPLACE FUNCTION hasnt_operator ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, $3 ),
        'Operator ' ||  $2 || '(' || $1 || ',' || $3
        || ') should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_leftop( schema, name, right_type, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists(NULL, $1, $2, $3, $4), $5 );
$$ LANGUAGE SQL;

-- hasnt_leftop( schema, name, right_type, return_type )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists(NULL, $1, $2, $3, $4 ),
        'Left operator ' || quote_ident($1) || '.' || $2 || '(NONE,'
        || $3 || ') RETURNS ' || $4 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_leftop( name, right_type, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists(NULL, $1, $2, $3), $4 );
$$ LANGUAGE SQL;

-- hasnt_leftop( name, right_type, return_type )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists(NULL, $1, $2, $3 ),
        'Left operator ' || $1 || '(NONE,' || $2 || ') RETURNS ' || $3 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_leftop( name, right_type, description )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists(NULL, $1, $2), $3 );
$$ LANGUAGE SQL;

-- hasnt_leftop( name, right_type )
CREATE OR REPLACE FUNCTION hasnt_leftop ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists(NULL, $1, $2 ),
        'Left operator ' || $1 || '(NONE,' || $2 || ') should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, schema, name, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists( $1, $2, $3, NULL, $4), $5 );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, schema, name, return_type )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, $3, NULL, $4 ),
        'Right operator ' || quote_ident($2) || '.' || $3 || '('
        || $1 || ',NONE) RETURNS ' || $4 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, name, return_type, description )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists( $1, $2, NULL, $3), $4 );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, name, return_type )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, NULL, $3 ),
        'Right operator ' || $2 || '('
        || $1 || ',NONE) RETURNS ' || $3 || ' should not exist'
    );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, name, description )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _op_exists( $1, $2, NULL), $3 );
$$ LANGUAGE SQL;

-- hasnt_rightop( left_type, name )
CREATE OR REPLACE FUNCTION hasnt_rightop ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
         NOT _op_exists($1, $2, NULL ),
        'Right operator ' || $2 || '(' || $1 || ',NONE) should not exist'
    );
$$ LANGUAGE SQL;
