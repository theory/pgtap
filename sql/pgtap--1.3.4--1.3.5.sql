-- Changes between pgTAP v1.3.4 and v1.3.5.

-- _has_constraint( schema, table, constraint_name, constraint_type )
CREATE OR REPLACE FUNCTION _has_constraint ( NAME, NAME, NAME, CHAR )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_namespace n
          JOIN pg_catalog.pg_class c      ON c.relnamespace = n.oid
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE n.nspname = $1
           AND c.relname = $2
           AND x.conname = $3
           AND x.contype = $4
    );
$$ LANGUAGE sql;

-- _has_constraint( table, constraint_name, constraint_type )
CREATE OR REPLACE FUNCTION _has_constraint ( NAME, NAME, CHAR )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT true
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_constraint x ON c.oid = x.conrelid
         WHERE pg_catalog.pg_table_is_visible(c.oid)
           AND c.relname = $1
           AND x.conname = $2
           AND x.contype = $3
    );
$$ LANGUAGE sql;

-- has_constraint( schema, table, constraint, type, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, NAME, CHAR, TEXT )
RETURNS TEXT AS $$
    SELECT ok( _has_constraint($1, $2, $3, $4), $5 );
$$ LANGUAGE sql;

-- has_constraint( schema, table, constraint, type ) or has_constraint( table, constraint, type, description )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT CASE WHEN _is_schema($1)
           THEN ok(
               _has_constraint($1, $2, $3, $4::char),
               'Constraint ' || quote_ident($3) || ' should exist on ' || quote_ident($1) || '.' || quote_ident($2)
           )
           ELSE ok( _has_constraint($1, $2, $3::char), $4 )
           END;
$$ LANGUAGE sql;

-- has_constraint( table, constraint, type )
CREATE OR REPLACE FUNCTION has_constraint ( NAME, NAME, CHAR )
RETURNS TEXT AS $$
    SELECT ok(
        _has_constraint($1, $2, $3),
        'Constraint ' || quote_ident($2) || ' should exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;

-- hasnt_constraint( schema, table, constraint, type, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, NAME, CHAR, TEXT )
RETURNS TEXT AS $$
    SELECT ok( NOT _has_constraint($1, $2, $3, $4), $5 );
$$ LANGUAGE sql;

-- hasnt_constraint( schema, table, constraint, type ) or hasnt_constraint( table, constraint, type, description )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT CASE WHEN _is_schema($1)
           THEN ok(
               NOT _has_constraint($1, $2, $3, $4::char),
               'Constraint ' || quote_ident($3) || ' should not exist on ' || quote_ident($1) || '.' || quote_ident($2)
           )
           ELSE ok( NOT _has_constraint($1, $2, $3::char), $4 )
           END;
$$ LANGUAGE sql;

-- hasnt_constraint( table, constraint, type )
CREATE OR REPLACE FUNCTION hasnt_constraint ( NAME, NAME, CHAR )
RETURNS TEXT AS $$
    SELECT ok(
        NOT _has_constraint($1, $2, $3),
        'Constraint ' || quote_ident($2) || ' should not exist on ' || quote_ident($1)
    );
$$ LANGUAGE sql;
