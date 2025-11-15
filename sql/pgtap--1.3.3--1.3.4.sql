-- has_composite( schema, type )
CREATE OR REPLACE FUNCTION has_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_composite(
        $1, $2,
        'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should exist'
    );
$$ LANGUAGE SQL;

-- hasnt_composite( schema, type )
CREATE OR REPLACE FUNCTION hasnt_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_composite(
        $1, $2,
        'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should not exist'
    );
$$ LANGUAGE SQL;

-- index_is_partial( schema, table, index, description )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME, NAME, text )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ct    ON ct.oid = x.indrelid
      JOIN pg_catalog.pg_class ci    ON ci.oid = x.indexrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = ct.relnamespace
     WHERE ct.relname = $2
       AND ci.relname = $3
       AND n.nspname  = $1
      INTO res;

      RETURN ok( COALESCE(res, false), $4 );
END;
$$ LANGUAGE plpgsql;

-- index_is_partial( schema, table, index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME, NAME )
RETURNS TEXT AS $$
    SELECT index_is_partial(
        $1, $2, $3,
        'Index ' || quote_ident($3) || ' should be partial'
    );
$$ LANGUAGE sql;

-- index_is_partial( table, index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME, NAME )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ct ON ct.oid = x.indrelid
      JOIN pg_catalog.pg_class ci ON ci.oid = x.indexrelid
     WHERE ct.relname = $1
       AND ci.relname = $2
       AND pg_catalog.pg_table_is_visible(ct.oid)
     INTO res;

      RETURN ok(
          COALESCE(res, false),
          'Index ' || quote_ident($2) || ' should be partial'
      );
END;
$$ LANGUAGE plpgsql;

-- index_is_partial( index )
CREATE OR REPLACE FUNCTION index_is_partial ( NAME )
RETURNS TEXT AS $$
DECLARE
    res boolean;
BEGIN
    SELECT x.indpred IS NOT NULL
      FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class ci ON ci.oid = x.indexrelid
      JOIN pg_catalog.pg_class ct ON ct.oid = x.indrelid
     WHERE ci.relname = $1
       AND pg_catalog.pg_table_is_visible(ct.oid)
      INTO res;

      RETURN ok(
          COALESCE(res, false),
          'Index ' || quote_ident($1) || ' should be partial'
      );
END;
$$ LANGUAGE plpgsql;