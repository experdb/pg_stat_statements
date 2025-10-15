-- test old extension version entry points

CREATE EXTENSION pg_stat_statements WITH VERSION '1.4';
-- New functions and views for pg_stat_statements in 1.10e1
AlTER EXTENSION pg_stat_statements UPDATE TO '1.10e1';
\d pg_stat_statements
SELECT count(*) > 0 AS has_data FROM pg_stat_statements;

DROP EXTENSION pg_stat_statements;

