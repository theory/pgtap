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

-- col_isnt_pk( schema, table, columns[] )
CREATE OR REPLACE FUNCTION col_isnt_pk ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_isnt_pk( $1, $2, $3, 'Columns ' || quote_ident($1) || '.' || quote_ident($2) || '(' || _ident_array_to_string($3, ', ') || ') should not be a primary key' );
$$ LANGUAGE sql;

-- col_isnt_pk( schema, table, column )
CREATE OR REPLACE FUNCTION col_isnt_pk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_isnt_pk( $1, $2, $3, 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '(' || quote_ident($3) || ') should not be a primary key' );
$$ LANGUAGE sql;

-- col_is_fk( schema, table, columns[] )
CREATE OR REPLACE FUNCTION col_is_fk ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_is_fk( $1, $2, $3, 'Columns ' || quote_ident($1) || '.' || quote_ident($2) || '(' || _ident_array_to_string($3, ', ') || ') should be a foreign key' );
$$ LANGUAGE sql;

-- col_is_fk( schema, table, column )
CREATE OR REPLACE FUNCTION col_is_fk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_is_fk( $1, $2, $3, 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '(' || quote_ident($3) || ') should be a foreign key' );
$$ LANGUAGE sql;

-- col_isnt_fk( schema, table, columns[] )
CREATE OR REPLACE FUNCTION col_isnt_fk ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_isnt_fk( $1, $2, $3, 'Columns ' || quote_ident($1) || '.' || quote_ident($2) || '(' || _ident_array_to_string($3, ', ') || ') should not be a foreign key' );
$$ LANGUAGE sql;

-- col_isnt_fk( schema, table, column )
CREATE OR REPLACE FUNCTION col_isnt_fk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_isnt_fk( $1, $2, $3, 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '(' || quote_ident($3) || ') should not be a foreign key' );
$$ LANGUAGE sql;

-- col_isnt_unique( schema, table, columns[], description )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT ok(
        NOT EXISTS (
            SELECT 1
              FROM _keys($1, $2, 'u') AS keys(key_columns)
             WHERE key_columns = $3
        ),
        $4
    );
$$ LANGUAGE sql;

-- col_isnt_unique( schema, table, column, description )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, $2, ARRAY[$3], $4 );
$$ LANGUAGE sql;

-- col_isnt_unique( schema, table, columns[] )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, $2, $3, 'Columns ' || quote_ident($2) || '(' || _ident_array_to_string($3, ', ') || ') should not have a unique constraint' );
$$ LANGUAGE sql;

-- col_isnt_unique( schema, table, column )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, $2, ARRAY[$3], 'Column ' || quote_ident($2) || '(' || quote_ident($3) || ') should not have a unique constraint' );
$$ LANGUAGE sql;

-- col_isnt_unique( table, columns[], description )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT ok(
        NOT EXISTS (
            SELECT 1
              FROM _keys($1, 'u') AS keys(key_columns)
             WHERE key_columns = $2
        ),
        $3
    );
$$ LANGUAGE sql;

-- col_isnt_unique( table, column, description )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, ARRAY[$2], $3 );
$$ LANGUAGE sql;

-- col_isnt_unique( table, columns[] )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, $2, 'Columns ' || quote_ident($1) || '(' || _ident_array_to_string($2, ', ') || ') should not have a unique constraint' );
$$ LANGUAGE sql;

-- col_isnt_unique( table, column )
CREATE OR REPLACE FUNCTION col_isnt_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT col_isnt_unique( $1, $2, 'Column ' || quote_ident($1) || '(' || quote_ident($2) || ') should not have a unique constraint' );
$$ LANGUAGE sql;
