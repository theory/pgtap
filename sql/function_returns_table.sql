-- Functions covered so far
/*
SELECT function_returns_table( :schema, :function, :args, :return_args, :return_types, :description );
SELECT function_returns_table( :schema, :function, :return_args, :return_types, :description );
SELECT function_returns_table( :function, :args, :return_args, :return_types, :description );
SELECT function_returns_table( :function, :return_args, :return_types, :description );

SELECT function_returns_table( :schema, :function, :args, :return_args, :description );
SELECT function_returns_table( :schema, :function, :return_args, :description );
SELECT function_returns_table( :function, :args, :return_args, :description );
SELECT function_returns_table( :function, :return_args, :description );

SELECT function_returns_table( :schema, :function, :args, :return_types, :description );
SELECT function_returns_table( :schema, :function, :return_types, :description );
SELECT function_returns_table( :function, :args, :return_types, :description );
SELECT function_returns_table( :function, :return_types, :description );
*/
---------------------------------------------------------------------------------
--- Both table args and table types --------------------------------------------
---------------------------------------------------------------------------------
--- with schema, with args                        sch    fx    args   t_arg   t_type   desc
CREATE OR REPLACE FUNCTION function_returns_table(name, name, name[], text[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare($1, $2, $3, t.t_args||t.t_types, array_to_string($4, ',')||array_to_string($5, ','), $6)
    from _returns_table($1, $2, $3) t;
$function$;
-- with schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, name, text[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT _func_compare($1, $2, t.t_args||t.t_types, array_to_string($3, ',')||array_to_string($4, ','), $5)
    from _returns_table($1, $2) t;
$function$;
-- without schema, with args
CREATE OR REPLACE FUNCTION function_returns_table(name, name[], text[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare(NULL, $1, $2, t.t_args||t.t_types, array_to_string($3, ',')||array_to_string($4, ','), $5)
    from _returns_table($1, $2) t;
$function$;
-- without schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, text[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare(null, $1, t.t_args||t.t_types, array_to_string($2, ',')||array_to_string($3, ','), $4)
    from _returns_table($1) t;
$function$;
---------------------------------------------------------------------------------
-- Only table args --------------------------------------------------------------
---------------------------------------------------------------------------------
-- with schema, with args
CREATE OR REPLACE FUNCTION function_returns_table(name, name, name[], text[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare($1, $2, $3, t.t_args, array_to_string($4, ','), $5)
    from _returns_table($1, $2, $3) t;
$function$;
-- with schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, name, text[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT _func_compare($1, $2, t.t_args, array_to_string($3, ','), $4)
    from _returns_table($1, $2) t;
$function$;
-- without schema, with args
CREATE OR REPLACE FUNCTION function_returns_table(name, name[], text[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare(null, $1, $2, t.t_args, array_to_string($3, ','), $4)
    from _returns_table($1, $2) t;
$function$;
-- without schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, text[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT _func_compare(null, $1, t.t_args, array_to_string($2, ','), $3)
    from _returns_table($1) t;
$function$;
---------------------------------------------------------------------------------
-- Only table types -------------------------------------------------------------
---------------------------------------------------------------------------------
-- with schema, with args
CREATE OR REPLACE FUNCTION function_returns_table(name, name, name[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare($1, $2, $3, t.t_types, array_to_string($4, ','), $5)
    from _returns_table($1, $2, $3) t;
$function$;
-- with schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, name, name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT _func_compare($1, $2, t.t_types, array_to_string($3, ','), $4)
    from _returns_table($1, $2) t;
$function$;
-- without schema, with args
CREATE OR REPLACE FUNCTION function_returns_table(name, name[], name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    select _func_compare(null, $1, $2, t.t_types, array_to_string($3, ','), $4)
    from _returns_table($1, $2) t;
$function$;
-- without schema, without args
CREATE OR REPLACE FUNCTION function_returns_table(name, name[], text)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT _func_compare(null, $1, t.t_types, array_to_string($2, ','), $3)
    from _returns_table($1) t;
$function$;
