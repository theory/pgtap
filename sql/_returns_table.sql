
CREATE OR REPLACE FUNCTION public._returns_table(name, name, name[])
 RETURNS table(t_args text,t_types text)
 LANGUAGE sql
AS $function$
     SELECT table_args, table_types
     FROM tap_funky
     WHERE schema = $1
       AND name   = $2
       AND args   = array_to_string($3, ',')
$function$;

CREATE OR REPLACE FUNCTION public._returns_table(name, name)
 RETURNS table(t_args text,t_types text)
 LANGUAGE sql
AS $function$
    SELECT table_args, table_types
    FROM tap_funky WHERE schema = $1 AND name = $2
$function$;

CREATE OR REPLACE FUNCTION public._returns_table(name, name[])
 RETURNS table(t_args text,t_types text)
 LANGUAGE sql
AS $function$
    SELECT table_args, table_types
      FROM tap_funky
     WHERE name = $1
       AND args = array_to_string($2, ',')
       AND is_visible;
$function$;

CREATE OR REPLACE FUNCTION public._returns_table(name)
 RETURNS table(t_args text,t_types text)
 LANGUAGE sql
AS $function$
   SELECT table_args, table_types
   FROM tap_funky WHERE name = $1 AND is_visible;
$function$;
