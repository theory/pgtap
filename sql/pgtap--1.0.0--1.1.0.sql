CREATE OR REPLACE FUNCTION pgtap_version()
RETURNS NUMERIC AS 'SELECT 1.1;'
LANGUAGE SQL IMMUTABLE;

/*
 * PR #178: Add col_is_pk variants
 * https://github.com/theory/pgtap/pull/178
 */
-- col_is_pk( schema, table, column, description )
-- col_is_pk( schema, table, column )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME, NAME[], TEXT DEFAULT NULL )
RETURNS TEXT AS $$
    SELECT is( _ckeys( $1, $2, 'p' ), $3,
               coalesce( $4,
               'Columns ' || quote_ident( $1 ) || '.' || quote_ident( $2 )
                          || '(' || _ident_array_to_string( $3, ', ' ) || ') should be a primary key' ) );
$$ LANGUAGE sql;


-- col_is_pk( schema, table, column, description )
-- col_is_pk( schema, table, column )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME, NAME, TEXT DEFAULT NULL )
RETURNS TEXT AS $$
        SELECT is( _ckeys( $1, $2, 'p' ), ARRAY[ $3 ]::NAME[],
                   coalesce( $4,
                            'Column ' || quote_ident( $1 ) || '.' || quote_ident( $2 )
                            || '(' || quote_ident( $3 ) || ') should be a primary key' ) );
$$ LANGUAGE sql;

-- col_is_pk( table, column, description )
-- col_is_pk( table, column )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME[], TEXT DEFAULT NULL )
RETURNS TEXT AS $$
    SELECT is( _ckeys( $1, 'p' ), $2,
               coalesce( $3,  'Columns '  || quote_ident( $1 )
                             || '(' || _ident_array_to_string( $2, ', ' ) || ') should be a primary key' ) );
$$ LANGUAGE sql;


-- col_is_pk( table, column, description )
CREATE OR REPLACE FUNCTION col_is_pk ( NAME, NAME, TEXT DEFAULT NULL )
RETURNS TEXT AS $$
    SELECT col_is_pk( $1, ARRAY[$2]::name[],
                      coalesce( $3, 'Column ' || quote_ident( $1 ) || '(' || quote_ident( $2 ) || ') should be a primary key' ) );
$$ LANGUAGE sql;
