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

-- These are now obsolete
DROP FUNCTION col_not_null ( NAME, NAME );
DROP FUNCTION col_is_null ( NAME, NAME, NAME );
DROP FUNCTION col_is_null ( NAME, NAME );

-- _col_is_null( schema, table, column, desc, null )
CREATE OR REPLACE FUNCTION _col_is_null ( NAME, NAME, NAME, TEXT, bool )
RETURNS TEXT AS $$
DECLARE
    qcol CONSTANT text := quote_ident($1) || '.' || quote_ident($2) || '.' || quote_ident($3);
    c_desc CONSTANT text := coalesce(
        $4,
        'Column ' || qcol || ' should '
            || CASE WHEN $5 THEN 'be NOT' ELSE 'allow' END || ' NULL'
    );
BEGIN
    IF NOT _cexists( $1, $2, $3 ) THEN
        RETURN fail( c_desc ) || E'\n'
            || diag ('    Column ' || qcol || ' does not exist' );
    END IF;
    RETURN ok(
        EXISTS(
            SELECT true
              FROM pg_catalog.pg_namespace n
              JOIN pg_catalog.pg_class c ON n.oid = c.relnamespace
              JOIN pg_catalog.pg_attribute a ON c.oid = a.attrelid
             WHERE n.nspname = $1
               AND c.relname = $2
               AND a.attnum  > 0
               AND NOT a.attisdropped
               AND a.attname    = $3
               AND a.attnotnull = $5
        ), c_desc
    );
END;
$$ LANGUAGE plpgsql;

-- _col_is_null( table, column, desc, null )
CREATE OR REPLACE FUNCTION _col_is_null ( NAME, NAME, TEXT, bool )
RETURNS TEXT AS $$
DECLARE
    qcol CONSTANT text := quote_ident($1) || '.' || quote_ident($2);
    c_desc CONSTANT text := coalesce(
        $3,
        'Column ' || qcol || ' should '
            || CASE WHEN $4 THEN 'be NOT' ELSE 'allow' END || ' NULL'
    );
BEGIN
    IF NOT _cexists( $1, $2 ) THEN
        RETURN fail( c_desc ) || E'\n'
            || diag ('    Column ' || qcol || ' does not exist' );
    END IF;
    RETURN ok(
        EXISTS(
            SELECT true
              FROM pg_catalog.pg_class c
              JOIN pg_catalog.pg_attribute a ON c.oid = a.attrelid
             WHERE pg_catalog.pg_table_is_visible(c.oid)
               AND c.relname = $1
               AND a.attnum > 0
               AND NOT a.attisdropped
               AND a.attname    = $2
               AND a.attnotnull = $4
        ), c_desc
    );
END;
$$ LANGUAGE plpgsql;

-- col_not_null( schema, table, column, description )
-- col_not_null( schema, table, column )
CREATE OR REPLACE FUNCTION col_not_null (
    schema_name NAME, table_name NAME, column_name NAME, description TEXT DEFAULT NULL
) RETURNS TEXT AS $$
    SELECT _col_is_null( $1, $2, $3, $4, true );
$$ LANGUAGE SQL;

-- col_not_null( table, column, description )
-- col_not_null( table, column )
CREATE OR REPLACE FUNCTION col_not_null (
    table_name NAME, column_name NAME, description TEXT DEFAULT NULL
) RETURNS TEXT AS $$
    SELECT _col_is_null( $1, $2, $3, true );
$$ LANGUAGE SQL;

-- col_is_null( schema, table, column, description )
-- col_is_null( schema, table, column )
CREATE OR REPLACE FUNCTION col_is_null (
    schema_name NAME, table_name NAME, column_name NAME, description TEXT DEFAULT NULL
) RETURNS TEXT AS $$
    SELECT _col_is_null( $1, $2, $3, $4, false );
$$ LANGUAGE SQL;

-- col_is_null( table, column, description )
-- col_is_null( table, column )
CREATE OR REPLACE FUNCTION col_is_null (
    table_name NAME, column_name NAME, description TEXT DEFAULT NULL
) RETURNS TEXT AS $$
    SELECT _col_is_null( $1, $2, $3, false );
$$ LANGUAGE SQL;

