-- procedures_are( schema, procedures[], description )
CREATE OR REPLACE FUNCTION procedures_are ( NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'procedures',
        ARRAY(
            SELECT name FROM tap_funky WHERE schema = $1 and prokind = 'p'
            EXCEPT
            SELECT $2[i]
              FROM generate_series(1, array_upper($2, 1)) s(i)
        ),
        ARRAY(
            SELECT $2[i]
               FROM generate_series(1, array_upper($2, 1)) s(i)
            EXCEPT
            SELECT name FROM tap_funky WHERE schema = $1 and prokind = 'p'
        ),
        $3
    );
$$ LANGUAGE SQL;

-- procedures_are( schema, procedures[] )
CREATE OR REPLACE FUNCTION procedures_are ( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT procedures_are( $1, $2, 'Schema ' || quote_ident($1) || ' should have the correct procedures' );
$$ LANGUAGE SQL;

-- procedures_are( procedures[], description )
CREATE OR REPLACE FUNCTION procedures_are ( NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'procedures',
        ARRAY(
            SELECT name FROM tap_funky WHERE is_visible and prokind = 'p'
            AND schema NOT IN ('pg_catalog', 'information_schema')
            EXCEPT
            SELECT $1[i]
              FROM generate_series(1, array_upper($1, 1)) s(i)
        ),
        ARRAY(
            SELECT $1[i]
               FROM generate_series(1, array_upper($1, 1)) s(i)
            EXCEPT
            SELECT name FROM tap_funky WHERE is_visible and prokind = 'p'
            AND schema NOT IN ('pg_catalog', 'information_schema')
        ),
        $2
    );
$$ LANGUAGE SQL;

-- procedures_are( procedures[] )
CREATE OR REPLACE FUNCTION procedures_are ( NAME[] )
RETURNS TEXT AS $$
    SELECT procedures_are( $1, 'Search path ' || pg_catalog.current_setting('search_path') || ' should have the correct procedures' );
$$ LANGUAGE SQL;
