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
-- functions using the view's row type survive 1.10e2 -> 1.10e1 -> 1.10e2
CREATE FUNCTION pgss_dep_test() RETURNS SETOF pg_stat_statements
  AS 'SELECT * FROM pg_stat_statements' LANGUAGE sql;
COMMENT ON FUNCTION pgss_dep_test() IS 'dependent';
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e1';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
-- the legacy 1.10e1 definition is served with bind_types always NULL
SELECT count(bind_types) = 0 AS bind_types_null FROM pg_stat_statements;
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';
SELECT count(*) > 0 AS has_data FROM pgss_dep_test();
SELECT obj_description('pgss_dep_test()'::regprocedure, 'pg_proc') = 'dependent' AS comment_kept;
SELECT NOT EXISTS (SELECT 1 FROM pg_depend
                   WHERE objid = 'pgss_dep_test()'::regprocedure AND deptype = 'e') AS not_ext_member;
DROP FUNCTION pgss_dep_test();

DROP EXTENSION pg_stat_statements;
