-- has_composite( schema, type )
CREATE OR REPLACE FUNCTION has_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT has_composite($1, $2,
           'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should exist' );
$$ LANGUAGE SQL;

-- hasnt_composite( schema, type )
CREATE OR REPLACE FUNCTION hasnt_composite ( NAME, NAME )
RETURNS TEXT AS $$
    SELECT hasnt_composite($1, $2,
        'Composite type ' || quote_ident($1) || '.' || quote_ident($2) || ' should not exist' );
$$ LANGUAGE SQL;
