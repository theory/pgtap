\unset ECHO
\i test/setup.sql

SELECT plan(72);
--SELECT * FROM no_plan();

-- This will be rolled back. :-)

/****************************************************************************/
-- Test extensions_are().
CREATE SCHEMA someschema;
CREATE SCHEMA ci_schema;
CREATE SCHEMA "empty schema";
CREATE EXTENSION IF NOT EXISTS citext SCHEMA ci_schema;
CREATE EXTENSION IF NOT EXISTS isn SCHEMA someschema;
CREATE EXTENSION IF NOT EXISTS ltree SCHEMA someschema;

SELECT * FROM check_test(
    extensions_are( 'someschema', ARRAY['isn', 'ltree'], 'Got em' ),
    true,
    'extensions_are(sch, exts, desc)',
    'Got em',
    ''
);

SELECT * FROM check_test(
    extensions_are( 'someschema', ARRAY['isn', 'ltree'] ),
    true,
    'extensions_are(sch, exts)',
    'Schema someschema should have the correct extensions',
    ''
);

SELECT* FROM check_test(
    extensions_are( ARRAY['citext', 'isn', 'ltree', 'plpgsql', 'pgtap'], 'Got em' ),
    true,
    'extensions_are(exts, desc)',
    'Got em',
    ''
);

SELECT* FROM check_test(
    extensions_are( ARRAY['citext', 'isn', 'ltree', 'plpgsql', 'pgtap'] ),
    true,
    'extensions_are(exts)',
    'Should have the correct extensions',
    ''
);

SELECT* FROM check_test(
    extensions_are( 'ci_schema', ARRAY['citext'], 'Got em' ),
    true,
    'extensions_are(ci_schema, exts, desc)',
    'Got em',
    ''
);

SELECT* FROM check_test(
    extensions_are( 'empty schema', '{}'::name[] ),
    true,
    'extensions_are(non-sch, exts)',
    'Schema "empty schema" should have the correct extensions',
    ''
);

/********************************************************************/
-- Test failures and diagnostics.
SELECT* FROM check_test(
    extensions_are( 'someschema', ARRAY['ltree', 'nonesuch'], 'Got em' ),
    false,
    'extensions_are(sch, good/bad, desc)',
    'Got em',
    '    Extra extensions:
        isn
    Missing extensions:
        nonesuch'
);

SELECT* FROM check_test(
    extensions_are( ARRAY['citext', 'isn', 'ltree', 'pgtap', 'nonesuch'] ),
    false,
    'extensions_are(someexts)',
    'Should have the correct extensions',
    '    Extra extensions:
        plpgsql
    Missing extensions:
        nonesuch'
);

/********************************************************************/
-- Test has_extension().
-- 8 tests

SELECT * FROM check_test(
    has_extension( 'ci_schema', 'citext', 'desc' ),
    true,
    'has_extension( schema, name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    has_extension( 'ci_schema', 'citext'::name ),
    true,
    'has_extension( schema, name )',
    'Extension citext should exist in schema ci_schema',
    ''
);

SELECT * FROM check_test(
    has_extension( 'citext'::name, 'desc' ),
    true,
    'has_extension( name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    has_extension( 'citext' ),
    true,
    'has_extension( name )',
    'Extension citext should exist',
    ''
);

SELECT * FROM check_test(
    has_extension( 'public'::name, '__NON_EXISTS__'::name, 'desc' ),
    false,
    'has_extension( schema, name, desc ) fail',
    'desc',
    ''
);

SELECT * FROM check_test(
    has_extension( 'public'::name, '__NON_EXISTS__'::name ),
    false,
    'has_extension( schema, name ) fail',
    'Extension "__NON_EXISTS__" should exist in schema public',
    ''
);

SELECT * FROM check_test(
    has_extension( '__NON_EXISTS__'::name, 'desc' ),
    false,
    'has_extension( name, desc ) fail',
    'desc',
    ''
);

SELECT * FROM check_test(
    has_extension( '__NON_EXISTS__'::name ),
    false,
    'has_extension( name ) fail',
    'Extension "__NON_EXISTS__" should exist',
    ''
);

/********************************************************************/
-- Test hasnt_extension().
-- 8 tests

SELECT * FROM check_test(
    hasnt_extension( 'public', '__NON_EXISTS__', 'desc' ),
    true,
    'hasnt_extension( schema, name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( 'public', '__NON_EXISTS__'::name ),
    true,
    'hasnt_extension( schema, name )',
    'Extension "__NON_EXISTS__" should not exist in schema public',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( '__NON_EXISTS__'::name, 'desc' ),
    true,
    'hasnt_extension( name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( '__NON_EXISTS__' ),
    true,
    'hasnt_extension( name )',
    'Extension "__NON_EXISTS__" should not exist',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( 'ci_schema', 'citext', 'desc' ),
    false,
    'hasnt_extension( schema, name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( 'ci_schema', 'citext'::name ),
    false,
    'hasnt_extension( schema, name )',
    'Extension citext should not exist in schema ci_schema',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( 'citext', 'desc' ),
    false,
    'hasnt_extension( name, desc )',
    'desc',
    ''
);

SELECT * FROM check_test(
    hasnt_extension( 'citext' ),
    false,
    'hasnt_extension( name )',
    'Extension citext should not exist',
    ''
);

/****************************************************************************/
-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
