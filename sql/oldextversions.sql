-- test old extension version entry points

CREATE EXTENSION pg_stat_statements WITH VERSION '1.4';
-- Execution of pg_stat_statements_reset() is granted only to
-- superusers in 1.4, so this fails.
SET SESSION AUTHORIZATION pg_read_all_stats;
SELECT pg_stat_statements_reset();
RESET SESSION AUTHORIZATION;

AlTER EXTENSION pg_stat_statements UPDATE TO '1.5';
-- Execution of pg_stat_statements_reset() should be granted to
-- pg_read_all_stats now, so this works.
SET SESSION AUTHORIZATION pg_read_all_stats;
SELECT pg_stat_statements_reset();
RESET SESSION AUTHORIZATION;

-- In 1.6, it got restricted back to superusers.
AlTER EXTENSION pg_stat_statements UPDATE TO '1.6';
SET SESSION AUTHORIZATION pg_read_all_stats;
SELECT pg_stat_statements_reset();
RESET SESSION AUTHORIZATION;
SELECT pg_get_functiondef('pg_stat_statements_reset'::regproc);

-- New function for pg_stat_statements_reset introduced, still
-- restricted for non-superusers.
AlTER EXTENSION pg_stat_statements UPDATE TO '1.7';
SET SESSION AUTHORIZATION pg_read_all_stats;
SELECT pg_stat_statements_reset();
RESET SESSION AUTHORIZATION;
SELECT pg_get_functiondef('pg_stat_statements_reset'::regproc);
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- New functions and views for pg_stat_statements in 1.8
AlTER EXTENSION pg_stat_statements UPDATE TO '1.8';
\d pg_stat_statements
SELECT pg_get_functiondef('pg_stat_statements_reset'::regproc);

-- New function pg_stat_statement_info, and new function
-- and view for pg_stat_statements introduced in 1.9
AlTER EXTENSION pg_stat_statements UPDATE TO '1.9';
SELECT pg_get_functiondef('pg_stat_statements_info'::regproc);
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- New functions and views for pg_stat_statements in 1.10
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- eXperDB 1.10e2: stats_last and stats_since appended to pg_stat_statements
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;
-- stats_last is set once the counters have been updated and never precedes stats_since
SELECT count(*) > 0 AS has_stats_last FROM pg_stat_statements
  WHERE stats_last IS NOT NULL AND stats_last >= stats_since;
-- the scripts keep the extension comment in step with the installed version
SELECT obj_description(oid, 'pg_extension') FROM pg_extension WHERE extname = 'pg_stat_statements';
-- functions using the view's row type (or its array type) survive 1.10e2 -> 1.10e1 -> 1.10e2
-- with definition, owner, privileges and comment; ALTER DEFAULT PRIVILEGES does not leak in
CREATE ROLE regress_pgss_dep;
CREATE ROLE regress_pgss_dflt;
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
COMMENT ON FUNCTION pgss_dep_test() IS 'dependent';
REVOKE EXECUTE ON FUNCTION pgss_dep_test() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgss_dep_test() TO regress_pgss_dep WITH GRANT OPTION;
CREATE FUNCTION pgss_dep_arr(pg_stat_statements[]) RETURNS int
  AS 'SELECT array_length($1, 1)' LANGUAGE sql;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO regress_pgss_dflt;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e1';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT obj_description(oid, 'pg_extension') FROM pg_extension WHERE extname = 'pg_stat_statements';
-- the legacy 1.10e1 definition is served with bind_types always NULL
SELECT count(bind_types) = 0 AS bind_types_null FROM pg_stat_statements;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT pgss_dep_arr(ARRAY(SELECT s FROM pg_stat_statements s LIMIT 1)) = 1 AS arr_dep_kept;
SELECT obj_description('pgss_dep_test()'::regprocedure, 'pg_proc') = 'dependent' AS comment_kept;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
-- privileges reproduced exactly and not recorded as extension initial privileges (pg_dump keeps them)
SELECT has_function_privilege('regress_pgss_dep', 'pgss_dep_test()', 'EXECUTE WITH GRANT OPTION') AS grant_kept,
       NOT has_function_privilege('regress_pgss_dflt', 'pgss_dep_test()', 'EXECUTE') AS no_default_leak,
       NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                   WHERE p.oid = 'pgss_dep_test()'::regprocedure AND a.grantee = 0) AS public_revoked,
       NOT EXISTS (SELECT 1 FROM pg_init_privs
                   WHERE objoid IN ('pgss_dep_test()'::regprocedure,
                                    'pgss_dep_arr(pg_stat_statements[])'::regprocedure)) AS no_init_privs;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM regress_pgss_dflt;
DROP FUNCTION pgss_dep_test();
DROP FUNCTION pgss_dep_arr(pg_stat_statements[]);
DROP OWNED BY regress_pgss_dep, regress_pgss_dflt;
DROP ROLE regress_pgss_dep;
DROP ROLE regress_pgss_dflt;

DROP EXTENSION pg_stat_statements;
-- eXperDB: direct update paths from older versions (pg_upgrade'd clusters) while a function
-- using the row type exists; the upstream chain would stop at its first DROP VIEW
CREATE EXTENSION pg_stat_statements VERSION '1.8';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 45 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.9';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 45 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
