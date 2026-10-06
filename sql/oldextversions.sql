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
SELECT pg_stat_statements_reset();
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- New functions and views for pg_stat_statements in 1.8
AlTER EXTENSION pg_stat_statements UPDATE TO '1.8';
SELECT pg_get_functiondef('pg_stat_statements_reset'::regproc);
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

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

-- New functions and views for pg_stat_statements in 1.11
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;
-- New parameter minmax_only of pg_stat_statements_reset function
SELECT pg_get_functiondef('pg_stat_statements_reset'::regproc);
SELECT pg_stat_statements_reset() IS NOT NULL AS t;

-- eXperDB 1.11e2: stats_last appended to pg_stat_statements
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;
-- stats_last is set once the counters have been updated and never precedes stats_since
SELECT count(*) > 0 AS has_stats_last FROM pg_stat_statements
  WHERE stats_last IS NOT NULL AND stats_last >= stats_since;
-- the scripts keep the extension comment in step with the installed version
SELECT obj_description(oid, 'pg_extension') FROM pg_extension WHERE extname = 'pg_stat_statements';
-- functions using the view's row type (or its array type) survive 1.11e2 -> 1.11e1 -> 1.11e2
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
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e1';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT obj_description(oid, 'pg_extension') FROM pg_extension WHERE extname = 'pg_stat_statements';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
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
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 50 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.9';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 50 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.10';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 50 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
-- eXperDB: the PostgreSQL 15/16 definitions kept by pg_upgrade are served by this library:
-- 1.10e2 = 45 columns bound to pg_stat_statements_1_10e2, 1.10e1 = 46 columns bound to pg_stat_statements_1_10
CREATE FUNCTION pgss_1_10e2_probe(IN showtext boolean,
    OUT userid oid,
    OUT dbid oid,
    OUT toplevel bool,
    OUT queryid bigint,
    OUT query text,
    OUT plans int8,
    OUT total_plan_time float8,
    OUT min_plan_time float8,
    OUT max_plan_time float8,
    OUT mean_plan_time float8,
    OUT stddev_plan_time float8,
    OUT calls int8,
    OUT total_exec_time float8,
    OUT min_exec_time float8,
    OUT max_exec_time float8,
    OUT mean_exec_time float8,
    OUT stddev_exec_time float8,
    OUT rows int8,
    OUT shared_blks_hit int8,
    OUT shared_blks_read int8,
    OUT shared_blks_dirtied int8,
    OUT shared_blks_written int8,
    OUT local_blks_hit int8,
    OUT local_blks_read int8,
    OUT local_blks_dirtied int8,
    OUT local_blks_written int8,
    OUT temp_blks_read int8,
    OUT temp_blks_written int8,
    OUT blk_read_time float8,
    OUT blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records int8,
    OUT wal_fpi int8,
    OUT wal_bytes numeric,
    OUT jit_functions int8,
    OUT jit_generation_time float8,
    OUT jit_inlining_count int8,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count int8,
    OUT jit_optimization_time float8,
    OUT jit_emission_count int8,
    OUT jit_emission_time float8,
    OUT stats_last timestamp with time zone,
    OUT stats_since timestamp with time zone
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_10e2'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(*) = count(stats_since) AS stats_since_set FROM pgss_1_10e2_probe(true);
CREATE FUNCTION pgss_1_10e1_probe(IN showtext boolean,
    OUT userid oid,
    OUT dbid oid,
    OUT toplevel bool,
    OUT queryid bigint,
    OUT query text,
    OUT plans int8,
    OUT total_plan_time float8,
    OUT min_plan_time float8,
    OUT max_plan_time float8,
    OUT mean_plan_time float8,
    OUT stddev_plan_time float8,
    OUT calls int8,
    OUT total_exec_time float8,
    OUT min_exec_time float8,
    OUT max_exec_time float8,
    OUT mean_exec_time float8,
    OUT stddev_exec_time float8,
    OUT rows int8,
    OUT shared_blks_hit int8,
    OUT shared_blks_read int8,
    OUT shared_blks_dirtied int8,
    OUT shared_blks_written int8,
    OUT local_blks_hit int8,
    OUT local_blks_read int8,
    OUT local_blks_dirtied int8,
    OUT local_blks_written int8,
    OUT temp_blks_read int8,
    OUT temp_blks_written int8,
    OUT blk_read_time float8,
    OUT blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records int8,
    OUT wal_fpi int8,
    OUT wal_bytes numeric,
    OUT jit_functions int8,
    OUT jit_generation_time float8,
    OUT jit_inlining_count int8,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count int8,
    OUT jit_optimization_time float8,
    OUT jit_emission_count int8,
    OUT jit_emission_time float8,
    OUT stats_last timestamp with time zone,
    OUT stats_since timestamp with time zone,
    OUT bind_types text
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_10'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(bind_types) = 0 AS bind_types_null FROM pgss_1_10e1_probe(true);
DROP FUNCTION pgss_1_10e2_probe(boolean);
DROP FUNCTION pgss_1_10e1_probe(boolean);
