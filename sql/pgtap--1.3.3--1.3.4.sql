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

