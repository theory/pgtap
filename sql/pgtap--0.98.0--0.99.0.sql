CREATE OR REPLACE FUNCTION pgtap_version()
RETURNS NUMERIC AS 'SELECT 0.99;'
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION pg_version_num()
RETURNS integer AS $$
    SELECT current_setting('server_version_num')::integer;
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION _ident_array_to_sorted_string( name[], text )
RETURNS text AS $$
    SELECT array_to_string(ARRAY(
        SELECT quote_ident($1[i])
          FROM generate_series(1, array_upper($1, 1)) s(i)
         ORDER BY $1[i]
    ), $2);
$$ LANGUAGE SQL immutable;

CREATE OR REPLACE FUNCTION _array_to_sorted_string( name[], text )
RETURNS text AS $$
    SELECT array_to_string(ARRAY(
        SELECT $1[i]
          FROM generate_series(1, array_upper($1, 1)) s(i)
         ORDER BY $1[i]
    ), $2);
$$ LANGUAGE SQL immutable;

CREATE OR REPLACE FUNCTION _are ( text, name[], name[], TEXT )
RETURNS TEXT AS $$
DECLARE
    what    ALIAS FOR $1;
    extras  ALIAS FOR $2;
    missing ALIAS FOR $3;
    descr   ALIAS FOR $4;
    msg     TEXT    := '';
    res     BOOLEAN := TRUE;
BEGIN
    IF extras[1] IS NOT NULL THEN
        res = FALSE;
        msg := E'\n' || diag(
            '    Extra ' || what || E':\n        '
            ||  _ident_array_to_sorted_string( extras, E'\n        ' )
        );
    END IF;
    IF missing[1] IS NOT NULL THEN
        res = FALSE;
        msg := msg || E'\n' || diag(
            '    Missing ' || what || E':\n        '
            ||  _ident_array_to_sorted_string( missing, E'\n        ' )
        );
    END IF;

    RETURN ok(res, descr) || msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _areni ( text, text[], text[], TEXT )
RETURNS TEXT AS $$
DECLARE
    what    ALIAS FOR $1;
    extras  ALIAS FOR $2;
    missing ALIAS FOR $3;
    descr   ALIAS FOR $4;
    msg     TEXT    := '';
    res     BOOLEAN := TRUE;
BEGIN
    IF extras[1] IS NOT NULL THEN
        res = FALSE;
        msg := E'\n' || diag(
            '    Extra ' || what || E':\n        '
            ||  _array_to_sorted_string( extras, E'\n        ' )
        );
    END IF;
    IF missing[1] IS NOT NULL THEN
        res = FALSE;
        msg := msg || E'\n' || diag(
            '    Missing ' || what || E':\n        '
            ||  _array_to_sorted_string( missing, E'\n        ' )
        );
    END IF;

    RETURN ok(res, descr) || msg;
END;
$$ LANGUAGE plpgsql;

-- Note: this fixes a bug in the 97->98 upgrade script
-- table_owner_is ( table, user, description )
CREATE OR REPLACE FUNCTION table_owner_is ( NAME, NAME, TEXT )
RETURNS TEXT AS $$
DECLARE
    owner NAME := _get_rel_owner('{r,p}'::char[], $1);
BEGIN
    -- Make sure the table exists.
    IF owner IS NULL THEN
        RETURN ok(FALSE, $3) || E'\n' || diag(
            E'    Table ' || quote_ident($1) || ' does not exist'
        );
    END IF;

    RETURN is(owner, $2, $3);
END;
$$ LANGUAGE plpgsql;
