BEGIN;
SELECT plan( 20 );
\set domain_id 1
\set source_id 1

SET client_min_messages = warning;
CREATE TABLE domains (
    id serial primary key,
    domain text
);
CREATE TABLE sources (
    id serial primary key,
    name text
);
CREATE TABLE stuff (
    id serial primary key,
    name text
);

CREATE TABLE domain_stuff (
    domain_id int REFERENCES domains(id),
    source_id int REFERENCES sources(id),
    stuff_id  int REFERENCES stuff(id),
    primary key (domain_id, source_id, stuff_id)
);

CREATE OR REPLACE FUNCTION insert_stuff (
    url  text,
    ints int[],
    did  int,
    sid  int
) RETURNS BOOL LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO domains VALUES (did, url);
    INSERT INTO sources VALUES (sid, url);

    FOR i IN array_lower(ints, 1)..array_upper(ints, 1) LOOP
        INSERT INTO stuff VALUES (ints[i], url);
        INSERT INTO domain_stuff (domain_id, source_id, stuff_id)
        VALUES (did, sid, ints[i]);
    END LOOP;
    RETURN true;
END;
$$;

-- Insert stuff.
SELECT ok(
   insert_stuff( 'www.foo.com', '{1,2,3}', :domain_id, :source_id ),
    'insert_stuff() should return true'
);

-- Check for domain stuff records.
SELECT is(
    ARRAY(
        SELECT stuff_id
          FROM domain_stuff
         WHERE domain_id = :domain_id
           AND source_id = :source_id
         ORDER BY stuff_id
    ),
    ARRAY[ 1, 2, 3 ],
    'The stuff should have been associated with the domain'
);

SELECT has_table( 'domains' );
SELECT has_table( 'stuff' );
SELECT has_table( 'sources' );
SELECT has_table( 'domain_stuff' );

SELECT has_column( 'domains', 'id' );
SELECT col_is_pk(  'domains', 'id' );
SELECT has_column( 'domains', 'domain' );

SELECT has_column( 'stuff',   'id' );
SELECT col_is_pk(  'stuff', 'id' );
SELECT has_column( 'stuff',   'name' );

SELECT has_column( 'sources', 'id' );
SELECT col_is_pk(  'sources', 'id' );
SELECT has_column( 'sources', 'name' );

SELECT has_column( 'domain_stuff', 'domain_id' );
SELECT has_column( 'domain_stuff', 'source_id' );
SELECT has_column( 'domain_stuff', 'stuff_id' );
SELECT col_is_pk(
    'domain_stuff',
    ARRAY['domain_id', 'source_id', 'stuff_id']
);

SELECT can_ok(
    'insert_stuff',
    ARRAY[ 'text', 'integer[]', 'integer', 'integer' ]
);

SELECT * FROM finish();
ROLLBACK;
