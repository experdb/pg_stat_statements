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

-- New functions and views for pg_stat_statements in 1.12
AlTER EXTENSION pg_stat_statements UPDATE TO '1.12';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- New functions and views for pg_stat_statements in 1.13
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

-- eXperDB 1.13e1: stats_last appended to pg_stat_statements
-- functions using the view's row type (or its array type) survive the upstream -> 1.13e1 update
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
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;
-- stats_last is set once the counters have been updated and never precedes stats_since
SELECT count(*) > 0 AS has_stats_last FROM pg_stat_statements
  WHERE stats_last IS NOT NULL AND stats_last >= stats_since;
-- the scripts keep the extension comment in step with the installed version
SELECT obj_description(oid, 'pg_extension') FROM pg_extension WHERE extname = 'pg_stat_statements';
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
SELECT path FROM pg_extension_update_paths('pg_stat_statements') WHERE source = '1.8' AND target = '1.13e1';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
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
SELECT path FROM pg_extension_update_paths('pg_stat_statements') WHERE source = '1.9' AND target = '1.13e1';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
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
SELECT path FROM pg_extension_update_paths('pg_stat_statements') WHERE source = '1.10' AND target = '1.13e1';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.11';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
SELECT path FROM pg_extension_update_paths('pg_stat_statements') WHERE source = '1.11' AND target = '1.13e1';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.12';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
SELECT path FROM pg_extension_update_paths('pg_stat_statements') WHERE source = '1.12' AND target = '1.13e1';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT count(*) = 1 AS info_ok FROM pg_stat_statements_info;
SELECT pg_get_function_result('pg_stat_statements_reset(oid,oid,bigint,boolean)'::regprocedure) AS reset_result;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
-- eXperDB: definitions kept by pg_upgrade from PostgreSQL 15/16/17/18 are served by this library:
-- 1.12e2 (53, pg_stat_statements_1_12e2), 1.12e1 (53, pg_stat_statements_1_12), 1.11e2 (50, pg_stat_statements_1_11e2),
-- 1.11e1 (51, pg_stat_statements_1_11), 1.10e2 (45, pg_stat_statements_1_10e2), 1.10e1 (46, pg_stat_statements_1_10)
-- and the 45-column "1.10" of the 1.10e1 package (pg_stat_statements_1_10)
CREATE EXTENSION pg_stat_statements;
SELECT 1 AS x;
CREATE FUNCTION pgss_1_12e2_probe(IN showtext boolean,
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
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records int8,
    OUT wal_fpi int8,
    OUT wal_bytes numeric,
    OUT wal_buffers_full int8,
    OUT jit_functions int8,
    OUT jit_generation_time float8,
    OUT jit_inlining_count int8,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count int8,
    OUT jit_optimization_time float8,
    OUT jit_emission_count int8,
    OUT jit_emission_time float8,
    OUT jit_deform_count int8,
    OUT jit_deform_time float8,
    OUT parallel_workers_to_launch int8,
    OUT parallel_workers_launched int8,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone,
    OUT stats_last timestamp with time zone
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_12e2'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(*) = count(stats_since) AND count(stats_last) > 0 AS ok FROM pgss_1_12e2_probe(true);
DROP FUNCTION pgss_1_12e2_probe(boolean);
CREATE FUNCTION pgss_1_12e1_probe(IN showtext boolean,
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
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records int8,
    OUT wal_fpi int8,
    OUT wal_bytes numeric,
    OUT wal_buffers_full int8,
    OUT jit_functions int8,
    OUT jit_generation_time float8,
    OUT jit_inlining_count int8,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count int8,
    OUT jit_optimization_time float8,
    OUT jit_emission_count int8,
    OUT jit_emission_time float8,
    OUT jit_deform_count int8,
    OUT jit_deform_time float8,
    OUT parallel_workers_to_launch int8,
    OUT parallel_workers_launched int8,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone,
    OUT stats_last timestamp with time zone
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_12'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(*) = count(stats_since) AND count(stats_last) > 0 AS ok FROM pgss_1_12e1_probe(true);
DROP FUNCTION pgss_1_12e1_probe(boolean);
CREATE FUNCTION pgss_1_11e2_probe(IN showtext boolean,
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
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
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
    OUT jit_deform_count int8,
    OUT jit_deform_time float8,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone,
    OUT stats_last timestamp with time zone
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_11e2'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(*) = count(stats_since) AS stats_since_set FROM pgss_1_11e2_probe(true);
DROP FUNCTION pgss_1_11e2_probe(boolean);
CREATE FUNCTION pgss_1_11e1_probe(IN showtext boolean,
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
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
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
    OUT jit_deform_count int8,
    OUT jit_deform_time float8,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone,
    OUT stats_last timestamp with time zone,
    OUT bind_types text
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_11'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(bind_types) = 0 AS bind_types_null FROM pgss_1_11e1_probe(true);
DROP FUNCTION pgss_1_11e1_probe(boolean);
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
DROP FUNCTION pgss_1_10e2_probe(boolean);
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
DROP FUNCTION pgss_1_10e1_probe(boolean);
CREATE FUNCTION pgss_1_10e1_45_probe(IN showtext boolean,
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
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_10'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) > 0 AS has_data, count(*) = count(stats_since) AS stats_since_set FROM pgss_1_10e1_45_probe(true);
DROP FUNCTION pgss_1_10e1_45_probe(boolean);
-- the 1.13 columns of the 1.12e2 layout are not shifted: stats_last is the 53rd output column
CREATE FUNCTION pgss_1_12e2_probe(IN showtext boolean,
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
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records int8,
    OUT wal_fpi int8,
    OUT wal_bytes numeric,
    OUT wal_buffers_full int8,
    OUT jit_functions int8,
    OUT jit_generation_time float8,
    OUT jit_inlining_count int8,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count int8,
    OUT jit_optimization_time float8,
    OUT jit_emission_count int8,
    OUT jit_emission_time float8,
    OUT jit_deform_count int8,
    OUT jit_deform_time float8,
    OUT parallel_workers_to_launch int8,
    OUT parallel_workers_launched int8,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone,
    OUT stats_last timestamp with time zone
)
RETURNS SETOF record
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_12e2'
LANGUAGE C STRICT VOLATILE;
SELECT count(*) = 0 AS no_mismatch FROM pgss_1_12e2_probe(true) p
  WHERE p.stats_last IS NOT NULL AND p.stats_last < p.stats_since;
DROP FUNCTION pgss_1_12e2_probe(boolean);
-- stats_last is NULL (not 2000-01-01) for an entry whose counters were never updated
SELECT count(*) = 0 AS no_epoch FROM pg_stat_statements WHERE stats_last = '2000-01-01 00:00:00+00';
DROP EXTENSION pg_stat_statements;
-- eXperDB: scripts that rebuild the view keep helpers and the view's table and column privileges, and
-- leave its initial privileges as after CREATE EXTENSION (pg_dump keeps dumping the site's grants)
CREATE ROLE regress_pgss_mon;
CREATE ROLE regress_pgss_col;
CREATE EXTENSION pg_stat_statements VERSION '1.13';
SELECT NOT EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
                   WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                     AND a.grantee NOT IN (0, (SELECT relowner FROM pg_class
                                               WHERE oid = 'pg_stat_statements'::regclass))) AS init_owner_public,
       EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
               WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                 AND i.objsubid = 0 AND a.grantee = 0 AND a.privilege_type = 'SELECT') AS init_public_select,
       NOT EXISTS (SELECT 1 FROM pg_init_privs
                   WHERE objoid = 'pg_stat_statements'::regclass AND classoid = 'pg_class'::regclass
                     AND objsubid <> 0) AS no_column_init,
       NOT EXISTS (SELECT 1 FROM pg_shdepend
                   WHERE objid = 'pg_stat_statements'::regclass AND classid = 'pg_class'::regclass
                     AND deptype = 'i') AS no_initacl_deps;
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.13';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
REVOKE SELECT ON pg_stat_statements FROM PUBLIC;
GRANT SELECT ON pg_stat_statements TO regress_pgss_mon WITH GRANT OPTION;
GRANT SELECT (queryid, calls) ON pg_stat_statements TO regress_pgss_col;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT has_table_privilege('regress_pgss_mon', 'pg_stat_statements', 'SELECT WITH GRANT OPTION') AS view_grant_kept,
       NOT EXISTS (SELECT 1 FROM pg_class c, aclexplode(c.relacl) a
                   WHERE c.oid = 'pg_stat_statements'::regclass AND a.grantee = 0) AS public_revoked,
       has_column_privilege('regress_pgss_col', 'pg_stat_statements', 'calls', 'SELECT')
         AND NOT has_column_privilege('regress_pgss_col', 'pg_stat_statements', 'query', 'SELECT') AS column_grant_kept;
SELECT NOT EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
                   WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                     AND a.grantee NOT IN (0, (SELECT relowner FROM pg_class
                                               WHERE oid = 'pg_stat_statements'::regclass))) AS init_owner_public,
       EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
               WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                 AND i.objsubid = 0 AND a.grantee = 0 AND a.privilege_type = 'SELECT') AS init_public_select,
       NOT EXISTS (SELECT 1 FROM pg_init_privs
                   WHERE objoid = 'pg_stat_statements'::regclass AND classoid = 'pg_class'::regclass
                     AND objsubid <> 0) AS no_column_init,
       NOT EXISTS (SELECT 1 FROM pg_shdepend
                   WHERE objid = 'pg_stat_statements'::regclass AND classid = 'pg_class'::regclass
                     AND deptype = 'i') AS no_initacl_deps;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements VERSION '1.12';
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
REVOKE SELECT ON pg_stat_statements FROM PUBLIC;
GRANT SELECT ON pg_stat_statements TO regress_pgss_mon WITH GRANT OPTION;
GRANT SELECT (queryid, calls) ON pg_stat_statements TO regress_pgss_col;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT has_table_privilege('regress_pgss_mon', 'pg_stat_statements', 'SELECT WITH GRANT OPTION') AS view_grant_kept,
       NOT EXISTS (SELECT 1 FROM pg_class c, aclexplode(c.relacl) a
                   WHERE c.oid = 'pg_stat_statements'::regclass AND a.grantee = 0) AS public_revoked,
       has_column_privilege('regress_pgss_col', 'pg_stat_statements', 'calls', 'SELECT')
         AND NOT has_column_privilege('regress_pgss_col', 'pg_stat_statements', 'query', 'SELECT') AS column_grant_kept;
SELECT NOT EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
                   WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                     AND a.grantee NOT IN (0, (SELECT relowner FROM pg_class
                                               WHERE oid = 'pg_stat_statements'::regclass))) AS init_owner_public,
       EXISTS (SELECT 1 FROM pg_init_privs i, aclexplode(i.initprivs) a
               WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_class'::regclass
                 AND i.objsubid = 0 AND a.grantee = 0 AND a.privilege_type = 'SELECT') AS init_public_select,
       NOT EXISTS (SELECT 1 FROM pg_init_privs
                   WHERE objoid = 'pg_stat_statements'::regclass AND classoid = 'pg_class'::regclass
                     AND objsubid <> 0) AS no_column_init,
       NOT EXISTS (SELECT 1 FROM pg_shdepend
                   WHERE objid = 'pg_stat_statements'::regclass AND classid = 'pg_class'::regclass
                     AND deptype = 'i') AS no_initacl_deps;
DROP FUNCTION pgss_dep_test();
DROP EXTENSION pg_stat_statements;
-- the same with an extension owned by a superuser that is not the bootstrap superuser (its INITACL
-- dependencies are recorded): only the owner's table-level one is left
CREATE ROLE regress_pgss_su SUPERUSER;
SET ROLE regress_pgss_su;
CREATE EXTENSION pg_stat_statements VERSION '1.13';
GRANT SELECT ON pg_stat_statements TO regress_pgss_mon;
GRANT SELECT (queryid, calls) ON pg_stat_statements TO regress_pgss_col;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT NOT EXISTS (SELECT 1 FROM pg_shdepend
                   WHERE objid = 'pg_stat_statements'::regclass AND classid = 'pg_class'::regclass
                     AND deptype = 'i' AND (objsubid <> 0 OR refobjid <> 'regress_pgss_su'::regrole)) AS initacl_owner_only,
       has_table_privilege('regress_pgss_mon', 'pg_stat_statements', 'SELECT') AS view_grant_kept,
       has_column_privilege('regress_pgss_col', 'pg_stat_statements', 'calls', 'SELECT') AS column_grant_kept;
DROP EXTENSION pg_stat_statements;
RESET ROLE;
DROP ROLE regress_pgss_su;
-- eXperDB: a fresh CREATE EXTENSION ends at 1.13e1 (55 columns, C function pg_stat_statements_1_13e1)
CREATE EXTENSION pg_stat_statements;
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT prosrc FROM pg_proc WHERE oid = 'pg_stat_statements(boolean)'::regprocedure;
SELECT count(*) = 55 AS cols_ok FROM pg_attribute
  WHERE attrelid = 'pg_stat_statements'::regclass AND attnum > 0 AND NOT attisdropped;
DROP EXTENSION pg_stat_statements;
-- eXperDB 1.13e1: the scripts call catalog functions schema-qualified, so a function in the extension schema
-- schema with a better-matching signature cannot capture them (it would run as the updating superuser)
CREATE SCHEMA pgss_hostile;
CREATE FUNCTION pgss_hostile.quote_ident(name) RETURNS text
  AS $$ BEGIN RAISE EXCEPTION 'captured'; END $$ LANGUAGE plpgsql;
CREATE EXTENSION pg_stat_statements SCHEMA pgss_hostile VERSION '1.13';
GRANT SELECT ON pgss_hostile.pg_stat_statements TO regress_pgss_mon;
CREATE FUNCTION pgss_hostile.pgss_dep_h() RETURNS SETOF pgss_hostile.pg_stat_statements
  AS 'SELECT * FROM pgss_hostile.pg_stat_statements' LANGUAGE sql;
REVOKE EXECUTE ON FUNCTION pgss_hostile.pgss_dep_h() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgss_hostile.pgss_dep_h() TO regress_pgss_mon;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT has_function_privilege('regress_pgss_mon', 'pgss_hostile.pgss_dep_h()', 'EXECUTE') AS func_grant_kept,
       has_table_privilege('regress_pgss_mon', 'pgss_hostile.pg_stat_statements', 'SELECT') AS view_grant_kept;
DROP FUNCTION pgss_hostile.pgss_dep_h();
DROP EXTENSION pg_stat_statements;
DROP FUNCTION pgss_hostile.quote_ident(name);
DROP SCHEMA pgss_hostile;
-- no initial-privilege dependency is left behind: the roles can be dropped
DROP ROLE regress_pgss_mon;
DROP ROLE regress_pgss_col;
