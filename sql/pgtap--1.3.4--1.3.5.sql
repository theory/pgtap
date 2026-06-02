-- Changes between pgTAP v1.3.4 and v1.3.5.

-- -----------------------------------------------------------------------------
-- Private helpers
-- -----------------------------------------------------------------------------

-- _hasc( schema, table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME, CHAR, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_namespace n
          JOIN pg_catalog.pg_class c      ON c.relnamespace = n.oid
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
          JOIN pg_catalog.pg_index i      ON c.oid = i.indrelid
         WHERE i.indisprimary = true
           AND n.nspname = $1
           AND c.relname = $2
           AND x.contype = $3
           AND x.conname = $4
    );
$$ LANGUAGE sql;

-- _hasc( table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, CHAR, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
          JOIN pg_catalog.pg_index i      ON c.oid = i.indrelid
         WHERE i.indisprimary = true
           AND pg_catalog.pg_table_is_visible(c.oid)
           AND c.relname = $1
           AND x.contype = $2
           AND x.conname = $3
    );
$$ LANGUAGE sql;

-- _hasc( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_namespace n
          JOIN pg_catalog.pg_class c      ON c.relnamespace = n.oid
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
          JOIN pg_catalog.pg_index i      ON c.oid = i.indrelid
         WHERE i.indisprimary = true
           AND n.nspname = $1
           AND c.relname = $2
           AND x.conname = $3
    );
$$ LANGUAGE sql;

-- _hasc( table, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
          JOIN pg_catalog.pg_index i      ON c.oid = i.indrelid
         WHERE i.indisprimary = true
           AND pg_catalog.pg_table_is_visible(c.oid)
           AND c.relname = $1
           AND x.conname = $2
    );
$$ LANGUAGE sql;

-- _hasc( schema, table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME, CHAR, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_namespace n
          JOIN pg_catalog.pg_class c      ON c.relnamespace = n.oid
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE n.nspname = $1
           AND c.relname = $2
           AND x.contype = $3
           AND x.conname = $4
    );
$$ LANGUAGE sql;

-- _hasc( table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, CHAR, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE pg_catalog.pg_table_is_visible(c.oid)
           AND c.relname = $1
           AND x.contype = $2
           AND x.conname = $3
    );
$$ LANGUAGE sql;

-- _hasc( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_namespace n
          JOIN pg_catalog.pg_class c      ON c.relnamespace = n.oid
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE n.nspname = $1
           AND c.relname = $2
           AND x.conname = $3
    );
$$ LANGUAGE sql;

-- _hasc( table, constraint_name )
CREATE OR REPLACE FUNCTION _hasc ( NAME, NAME )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE pg_catalog.pg_table_is_visible(c.oid)
           AND c.relname = $1
           AND x.conname = $2
    );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Has constraint
-- -----------------------------------------------------------------------------

-- has_constraint( schema, table, constraint_type, constraint_name, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, CHAR, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc($1, $2, $3, $4), $5 );
$$ LANGUAGE sql;

-- has_constraint( schema, table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, CHAR, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        _hasc($1, $2, $3, $4),
        'Constraint ' || quote_ident($4) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2)
    );
$$ LANGUAGE sql;

-- has_constraint( table, constraint_type, constraint_name, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, CHAR, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc($1, $2, $3), $4 );
$$ LANGUAGE sql;

-- has_constraint( table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, CHAR, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        _hasc($1, $2, $3),
        'Constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;

-- has_constraint( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc($1, $2, $3), $4 );
$$ LANGUAGE sql;

-- has_constraint( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        _hasc($1, $2, $3),
        'Constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2)
    );
$$ LANGUAGE sql;

-- has_constraint( table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc($1, $2), $3 );
$$ LANGUAGE sql;

-- has_constraint( table, constraint_name )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        _hasc($1, $2),
        'Constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt constraint
-- -----------------------------------------------------------------------------

-- hasnt_constraint( schema, table, constraint_type, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, CHAR, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc($1, $2, $3, $4), $5 );
$$ LANGUAGE sql;

-- hasnt_constraint( schema, table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, CHAR, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        NOT _hasc($1, $2, $3, $4),
        'Constraint ' || quote_ident($4) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2)
    );
$$ LANGUAGE sql;

-- hasnt_constraint( table, constraint_type, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, CHAR, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc($1, $2, $3), $4 );
$$ LANGUAGE sql;

-- hasnt_constraint( table, constraint_type, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, CHAR, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        NOT _hasc($1, $2, $3),
        'Constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;

-- hasnt_constraint( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc($1, $2, $3), $4 );
$$ LANGUAGE sql;

-- hasnt_constraint( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        NOT _hasc($1, $2, $3),
        'Constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2)
    );
$$ LANGUAGE sql;

-- hasnt_constraint( table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc($1, $2), $3 );
$$ LANGUAGE sql;

-- hasnt_constraint( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok(
        NOT _hasc($1, $2),
        'Constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Reminder for constraitns
-- - has_X( schema, table, description )
-- - has_X( schema, table )
-- - has_X( table, description )
-- - has_X( table )
-- - has_X( schema, table, constraint_name, description )
-- - has_X( schema, table, constraint_name )
-- - has_X( table, constraint_name, description )
-- - has_X( table, constraint_name )
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- Has check
-- -----------------------------------------------------------------------------

-- has_check( schema, table )
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_check( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a check constraint' );
$$ LANGUAGE sql;

-- has_check( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'c', $3 ), $4 );
$$ LANGUAGE sql;

-- has_check( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_check( $1, $2, $3, 'Check constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- has_check( table, constraint_name, description ) * Overlap problem
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'c', $2 ), $3 );
$$ LANGUAGE sql;

-- has_check( table, constraint_name )
CREATE OR REPLACE FUNCTION has_check ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_check( $1, $2, 'Check constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt check
-- -----------------------------------------------------------------------------

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

-- hasnt_check( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'c', $3 ), $4 );
$$ LANGUAGE sql;

-- hasnt_check( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_check( $1, $2, $3, 'Check constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- hasnt_check( table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'c', $2 ), $3 );
$$ LANGUAGE sql;

-- hasnt_check( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_check ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_check( $1, $2, 'Check constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Has exclude
-- -----------------------------------------------------------------------------

-- has_exclude( schema, table, description )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'x' ), $3 );
$$ LANGUAGE sql;

-- has_exclude( schema, table )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_exclude( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a exclude constraint' );
$$ LANGUAGE sql;

-- has_exclude( table, description )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'x' ), $2 );
$$ LANGUAGE sql;

-- has_exclude( table )
CREATE OR REPLACE FUNCTION has_exclude ( NAME )
RETURNS TEXT AS $$
    SELECT has_exclude( $1, 'Table ' || quote_ident($1) || ' should have a exclude constraint' );
$$ LANGUAGE sql;

-- has_exclude( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_exclude( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'x', $3 ), $4 );
$$ LANGUAGE sql;

-- has_exclude( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_exclude( $1, $2, $3, 'Exclude constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- has_exclude( table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'x', $2 ), $3 );
$$ LANGUAGE sql;

-- has_exclude( table, constraint_name )
CREATE OR REPLACE FUNCTION has_exclude ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_exclude( $1, $2, 'Exclude constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt exclude
-- -----------------------------------------------------------------------------

-- hasnt_exclude( schema, table, description )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'x' ), $3 );
$$ LANGUAGE sql;

-- hasnt_exclude( schema, table )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_exclude( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a exclude constraint' );
$$ LANGUAGE sql;

-- hasnt_exclude( table, description )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'x' ), $2 );
$$ LANGUAGE sql;

-- hasnt_exclude( table )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME )
RETURNS TEXT AS $$
    SELECT hasnt_exclude( $1, 'Table ' || quote_ident($1) || ' should not have a exclude constraint' );
$$ LANGUAGE sql;

-- hasnt_exclude( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'x', $3 ), $4 );
$$ LANGUAGE sql;

-- hasnt_exclude( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_exclude( $1, $2, $3, 'Exclude constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- hasnt_exclude( table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'x', $2 ), $3 );
$$ LANGUAGE sql;

-- hasnt_exclude( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_exclude ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_exclude( $1, $2, 'Exclude constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Has foreign key
-- -----------------------------------------------------------------------------

-- has_fk( schema, table )
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_fk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a foreign key constraint' );
$$ LANGUAGE sql;

-- has_fk( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'f', $3 ), $4 );
$$ LANGUAGE sql;

-- has_fk( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_fk( $1, $2, $3, 'Foreign key constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- has_fk( table, constraint_name, description ) * Overlap problem
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'f', $2 ), $3 );
$$ LANGUAGE sql;

-- has_fk( table, constraint_name )
CREATE OR REPLACE FUNCTION has_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_fk( $1, $2, 'Foreign key constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt foreign key
-- -----------------------------------------------------------------------------

-- hasnt_fk( schema, table )
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_fk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a foreign key constraint' );
$$ LANGUAGE sql;

-- hasnt_fk( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'f', $3 ), $4 );
$$ LANGUAGE sql;

-- hasnt_fk( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_fk( $1, $2, $3, 'Foreign key constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- hasnt_fk( table, constraint_name, description ) * Overlap problem
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'f', $2 ), $3 );
$$ LANGUAGE sql;

-- hasnt_fk( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_fk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_fk( $1, $2, 'Foreign key constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Has primary key
-- -----------------------------------------------------------------------------

-- has_pk( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_pk ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'p', $3 ), $4 );
$$ LANGUAGE sql;

-- has_pk( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_pk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_pk( $1, $2, $3, 'Primary key constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- has_pk( table, constraint_name, description ) * Overlap problem
CREATE OR REPLACE FUNCTION has_pk ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'p', $2 ), $3 );
$$ LANGUAGE sql;

-- has_pk( table, constraint_name ) * Overlap problem
CREATE OR REPLACE FUNCTION has_pk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_pk( $1, $2, 'Primary key constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt primary key
-- -----------------------------------------------------------------------------

-- hasnt_pk( schema, table )
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_pk( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should not have a primary key' );
$$ LANGUAGE sql;

-- hasnt_pk( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'p', $3 ), $4 );
$$ LANGUAGE sql;

-- hasnt_pk( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_pk( $1, $2, $3, 'Primary key constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- hasnt_pk( table, constraint_name, description ) * Overlap problem
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'p', $2 ), $3 );
$$ LANGUAGE sql;

-- hasnt_pk( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_pk ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_pk( $1, $2, 'Primary key constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Has unique
-- -----------------------------------------------------------------------------

-- has_unique( schema, table )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_unique( $1, $2, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have a unique constraint' );
$$ LANGUAGE sql;

-- has_unique( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, $2, 'u', $3 ), $4 );
$$ LANGUAGE sql;

-- has_unique( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_unique( $1, $2, $3, 'Unique constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- has_unique( table, constraint_name, description )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _hasc( $1, 'u', $2 ), $3 );
$$ LANGUAGE sql;

-- has_unique( table, constraint_name )
CREATE OR REPLACE FUNCTION has_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_unique( $1, $2, 'Unique constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

-- -----------------------------------------------------------------------------
-- Hasnt unique
-- -----------------------------------------------------------------------------

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

-- hasnt_unique( schema, table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, $2, 'u', $3 ), $4 );
$$ LANGUAGE sql;

-- hasnt_unique( schema, table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_unique( $1, $2, $3, 'Unique constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2) );
$$ LANGUAGE sql;

-- hasnt_unique( table, constraint_name, description )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _hasc( $1, 'u', $2 ), $3 );
$$ LANGUAGE sql;

-- hasnt_unique( table, constraint_name )
CREATE OR REPLACE FUNCTION hasnt_unique ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_unique( $1, $2, 'Unique constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1) );
$$ LANGUAGE sql;

