\unset ECHO
\i test/setup.sql

SELECT plan(57);

-- This will be rolled back. :-)
SET client_min_messages = warning;
CREATE TABLE public.sometab(
    id    INT NOT NULL,
    name  TEXT DEFAULT '',
    CONSTRAINT sometab_pkey     PRIMARY KEY (id),
    CONSTRAINT sometab_name_chk CHECK (name IN ('foo', 'bar', 'baz'))
);
RESET client_min_messages;

/****************************************************************************/
-- Test has_constraint().

SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'sometab_pkey', 'p', 'public.sometab should have sometab_pkey' ),
    true,
    'has_constraint( schema, table, constraint, type, desc )',
    'public.sometab should have sometab_pkey',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'sometab_pkey', 'p' ),
    true,
    'has_constraint( schema, table, constraint, type )',
    'Constraint sometab_pkey should exist on public.sometab',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'sometab', 'sometab_pkey', 'p', 'sometab should have sometab_pkey' ),
    true,
    'has_constraint( table, constraint, type, desc )',
    'sometab should have sometab_pkey',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'sometab', 'sometab_pkey', 'p' ),
    true,
    'has_constraint( table, constraint, type )',
    'Constraint sometab_pkey should exist on sometab',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'sometab_name_chk', 'c', 'public.sometab should have sometab_name_chk' ),
    true,
    'has_constraint( schema, table, constraint, type, desc ) check constraint',
    'public.sometab should have sometab_name_chk',
    ''
);

-- Fail: constraint name does not exist.
SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'nonexistent_constraint', 'c', 'public.sometab should have nonexistent_constraint' ),
    false,
    'has_constraint( schema, table, constraint, type, desc ) fail nonexistent',
    'public.sometab should have nonexistent_constraint',
    ''
);

-- Fail: constraint exists but wrong type ('p' is pk, not 'u' unique).
SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'sometab_pkey', 'u', 'public.sometab sometab_pkey should be unique constraint' ),
    false,
    'has_constraint( schema, table, constraint, type, desc ) fail wrong type',
    'public.sometab sometab_pkey should be unique constraint',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'public', 'sometab', 'nonexistent_constraint', 'c' ),
    false,
    'has_constraint( schema, table, constraint, type ) fail',
    'Constraint nonexistent_constraint should exist on public.sometab',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'sometab', 'nonexistent_constraint', 'c', 'sometab should have nonexistent_constraint' ),
    false,
    'has_constraint( table, constraint, type, desc ) fail',
    'sometab should have nonexistent_constraint',
    ''
);

SELECT * FROM check_test(
    has_constraint( 'sometab', 'nonexistent_constraint', 'c' ),
    false,
    'has_constraint( table, constraint, type ) fail',
    'Constraint nonexistent_constraint should exist on sometab',
    ''
);

/****************************************************************************/
-- Test hasnt_constraint().

SELECT * FROM check_test(
    hasnt_constraint( 'public', 'sometab', 'nonexistent_constraint', 'c', 'public.sometab should not have nonexistent_constraint' ),
    true,
    'hasnt_constraint( schema, table, constraint, type, desc )',
    'public.sometab should not have nonexistent_constraint',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'public', 'sometab', 'nonexistent_constraint', 'c' ),
    true,
    'hasnt_constraint( schema, table, constraint, type )',
    'Constraint nonexistent_constraint should not exist on public.sometab',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'sometab', 'nonexistent_constraint', 'c', 'sometab should not have nonexistent_constraint' ),
    true,
    'hasnt_constraint( table, constraint, type, desc )',
    'sometab should not have nonexistent_constraint',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'sometab', 'nonexistent_constraint', 'c' ),
    true,
    'hasnt_constraint( table, constraint, type )',
    'Constraint nonexistent_constraint should not exist on sometab',
    ''
);

-- Pass: name exists but type is wrong, so the typed constraint is absent.
SELECT * FROM check_test(
    hasnt_constraint( 'public', 'sometab', 'sometab_pkey', 'u', 'sometab_pkey is not a unique constraint' ),
    true,
    'hasnt_constraint( schema, table, constraint, type, desc ) pass wrong type',
    'sometab_pkey is not a unique constraint',
    ''
);

-- Fail: constraint exists with matching name and type.
SELECT * FROM check_test(
    hasnt_constraint( 'public', 'sometab', 'sometab_pkey', 'p', 'public.sometab should not have sometab_pkey' ),
    false,
    'hasnt_constraint( schema, table, constraint, type, desc ) fail',
    'public.sometab should not have sometab_pkey',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'public', 'sometab', 'sometab_pkey', 'p' ),
    false,
    'hasnt_constraint( schema, table, constraint, type ) fail',
    'Constraint sometab_pkey should not exist on public.sometab',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'sometab', 'sometab_pkey', 'p', 'sometab should not have sometab_pkey' ),
    false,
    'hasnt_constraint( table, constraint, type, desc ) fail',
    'sometab should not have sometab_pkey',
    ''
);

SELECT * FROM check_test(
    hasnt_constraint( 'sometab', 'sometab_pkey', 'p' ),
    false,
    'hasnt_constraint( table, constraint, type ) fail',
    'Constraint sometab_pkey should not exist on sometab',
    ''
);

/****************************************************************************/
-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
