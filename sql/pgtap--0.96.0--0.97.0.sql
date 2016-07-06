CREATE OR REPLACE FUNCTION _is_indexed( NAME, NAME, NAME[])
RETURNS BOOLEAN AS $$
    WITH cols AS (
       SELECT x.indexrelid, x.indrelid, unnest(x.indkey) as colid
         FROM pg_catalog.pg_index x
         JOIN pg_catalog.pg_class r ON r.oid = x.indrelid
         JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
       WHERE n.nspname = $1
         AND r.relname = $2),
    colsdef AS (
       SELECT cols.indexrelid, cols.indrelid, array_agg(a.attname) as cols
         FROM cols
         JOIN pg_catalog.pg_attribute a ON (a.attrelid = cols.indrelid
                                            AND a.attnum = cols.colid)
       GROUP BY 1, 2)
    SELECT EXISTS (
    SELECT TRUE
      FROM colsdef
    WHERE colsdef.cols::NAME[] = $3
    );
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION _is_indexed( NAME, NAME[])
RETURNS BOOLEAN AS $$
    WITH cols AS (
       SELECT x.indexrelid, x.indrelid, unnest(x.indkey) as colid
         FROM pg_catalog.pg_index x
         JOIN pg_catalog.pg_class r ON r.oid = x.indrelid
       WHERE r.relname = $1),
    colsdef AS (
       SELECT cols.indexrelid, cols.indrelid, array_agg(a.attname) as cols
         FROM cols
         JOIN pg_catalog.pg_attribute a ON (a.attrelid = cols.indrelid
                                            AND a.attnum = cols.colid)
       GROUP BY 1, 2)
    SELECT EXISTS (
    SELECT TRUE
      FROM colsdef
    WHERE colsdef.cols::NAME[] = $2
    );
$$ LANGUAGE sql;

-- is_indexed( schema, table, columns[], description )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME, NAME[], TEXT )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, $2, $3), $4);
$$ LANGUAGE sql;

-- is_indexed( schema, table, columns[] )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, $2, $3), 'An index on ' || quote_ident($1) || '.' || quote_ident($2) || ' with ' || $3::text || ' should exist');
$$ LANGUAGE sql;

-- is_indexed( table, columns[], description )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME[], TEXT )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, $2), $3);
$$ LANGUAGE sql;

-- is_indexed( table, columns[] )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME[] )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, $2), 'An index on ' || quote_ident($1) || ' with ' || $2::text || ' should exist');
$$ LANGUAGE sql;

-- is_indexed( schema, table, column, description )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, $2, ARRAY[$3]::NAME[]), $4);
$$ LANGUAGE sql;

-- is_indexed( schema, table, column )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT CASE WHEN _is_schema( $1 ) THEN
        -- Looking for schema.table index.
            ok ( _is_indexed( $1, $2, ARRAY[$3]::NAME[]),
                'An index on ' || quote_ident($1) || '.' || quote_ident($2)
                    || ' on column ' || quote_ident($3) || ' should exist')
        ELSE
        -- Looking for particular columns.
            ok ( _is_indexed( $1, ARRAY[$2]::NAME[]), $3)
        END;
$$ LANGUAGE sql;

-- is_indexed( table, column )
CREATE OR REPLACE FUNCTION is_indexed ( NAME, NAME )
RETURNS TEXT AS $$
   SELECT ok ( _is_indexed( $1, ARRAY[$2]::NAME[]),
              'An index on ' || quote_ident($1) || ' on column '
                  || $2::text || ' should exist');
$$ LANGUAGE sql;

-- has_column( schema, table, column )
CREATE OR REPLACE FUNCTION has_column ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok( _cexists( $1, $2, $3 ),
       'Column ' || quote_ident($1) || '.' || quote_ident($2)
                 || '.' || quote_ident($3) || ' should exist' );
$$ LANGUAGE SQL;

-- hasnt_column( schema, table, column )
CREATE OR REPLACE FUNCTION hasnt_column ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT ok( NOT _cexists( $1, $2, $3 ),
       'Column ' || quote_ident($1) || '.' || quote_ident($2)
                 || '.' || quote_ident($3) || ' should not exist' );
$$ LANGUAGE SQL;

-- col_has_default( schema, table, column )
CREATE OR REPLACE FUNCTION col_has_default ( NAME, NAME, NAME )
RETURNS TEXT AS $$
BEGIN
    IF NOT _cexists( $1, $2, $3 ) THEN
        RETURN fail( $4 ) || E'\n'
            || diag ('    Column ' || quote_ident($1) || '.' || quote_ident($2) || '.' || quote_ident($3) || ' does not exist' );
    END IF;
    RETURN ok( _has_def( $1, $2, $3 ), 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '.' || quote_ident($3) || ' should have a default' );
END
$$ LANGUAGE plpgsql;

-- col_hasnt_default( schema, table, column )
CREATE OR REPLACE FUNCTION col_hasnt_default ( NAME, NAME, NAME )
RETURNS TEXT AS $$
BEGIN
    IF NOT _cexists( $1, $2, $3 ) THEN
        RETURN fail( $4 ) || E'\n'
            || diag ('    Column ' || quote_ident($1) || '.' || quote_ident($2) || '.' || quote_ident($3) || ' does not exist' );
    END IF;
    RETURN ok( NOT _has_def( $1, $2, $3 ), 'Column ' || quote_ident($1) || '.' || quote_ident($2) || '.' || quote_ident($3) || ' should not have a default' );
END;
$$ LANGUAGE plpgsql;
