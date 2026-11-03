/* contrib/pg_stat_statements/pg_stat_statements--1.11--1.12e2.sql */

-- complain if script is sourced in psql, rather than via ALTER EXTENSION
\echo Use "ALTER EXTENSION pg_stat_statements UPDATE TO '1.12e2'" to load this file. \quit

/*
 * eXperDB: objects that use the view's row type (for example eXperDB helper
 * functions declared "RETURNS SETOF pg_stat_statements") would block
 * DROP VIEW below.  Save those functions (definition, owner, privileges,
 * comment) and the view's privileges, drop the functions, and restore
 * everything unchanged once the view has been rebuilt.
 */
DO $pgss$
DECLARE
  saved jsonb;
  r     jsonb;
BEGIN
  SELECT jsonb_build_object(
           'view_acl', (SELECT relacl::text[] FROM pg_class WHERE oid = 'pg_stat_statements'::regclass),
           'col_acl', (SELECT coalesce(jsonb_agg(jsonb_build_object('att', a.attname, 'acl', a.attacl::text[])), '[]'::jsonb)
                       FROM pg_attribute a
                       WHERE a.attrelid = 'pg_stat_statements'::regclass AND a.attnum > 0
                         AND NOT a.attisdropped AND a.attacl IS NOT NULL),
           'funcs', coalesce(jsonb_agg(jsonb_build_object(
                      'nsp',   n.nspname,
                      'name',  p.proname,
                      'sig',   format('%I.%I(%s)', n.nspname, p.proname,
                                      pg_get_function_identity_arguments(p.oid)),
                      'def',   pg_get_functiondef(p.oid),
                      'owner', pg_get_userbyid(p.proowner),
                      'acl',   p.proacl::text[],
                      'cmt',   obj_description(p.oid, 'pg_proc'))), '[]'::jsonb))
    INTO saved
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.oid IN (SELECT d.objid FROM pg_depend d
                  WHERE d.classid = 'pg_proc'::regclass
                    AND d.refclassid = 'pg_type'::regclass
                    AND d.refobjid IN (SELECT t.oid FROM pg_class c
                                       JOIN pg_type t ON t.oid IN (c.reltype, (SELECT typarray FROM pg_type
                                                                                WHERE oid = c.reltype))
                                       WHERE c.oid = 'pg_stat_statements'::regclass)
                    AND d.deptype = 'n');

  PERFORM set_config('experdb_pgss.saved', saved::text, true);

  FOR r IN SELECT * FROM jsonb_array_elements(saved->'funcs') LOOP
    EXECUTE 'DROP FUNCTION ' || (r->>'sig');
  END LOOP;
END
$pgss$;

/* Drop the 1.11 definitions (pg_stat_statements_reset is unchanged) */
DROP VIEW pg_stat_statements;
DROP FUNCTION pg_stat_statements(boolean);

/* Now redefine: upstream 1.12 columns + stats_last (eXperDB), direct from 1.11 */
CREATE FUNCTION pg_stat_statements(IN showtext boolean,
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
AS 'MODULE_PATHNAME', 'pg_stat_statements_1_12e2'
LANGUAGE C STRICT VOLATILE PARALLEL SAFE;

CREATE VIEW pg_stat_statements AS
  SELECT * FROM pg_stat_statements(true);

GRANT SELECT ON pg_stat_statements TO PUBLIC;

/* eXperDB: ALTER EXTENSION UPDATE keeps the comment the extension was created
 * with; set the one of this version so that \dx shows what is installed */
COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed (eXperDB 1.12e2: +stats_last)';

/* eXperDB: restore the saved functions and the view's privileges */
DO $pgss$
DECLARE
  saved jsonb := current_setting('experdb_pgss.saved')::jsonb;
  r     jsonb;
  g     record;
  cur   aclitem[];
  own   oid;
  init  aclitem[];
BEGIN
  /* what the script's own GRANT SELECT ... TO PUBLIC recorded as the view's initial privileges */
  SELECT i.initprivs INTO init FROM pg_catalog.pg_init_privs i
  WHERE i.objoid = 'pg_stat_statements'::regclass AND i.classoid = 'pg_catalog.pg_class'::regclass
    AND i.objsubid = 0;

  IF jsonb_typeof(saved->'view_acl') = 'array' THEN
    /* start from the owner alone (drop PUBLIC and anything ALTER DEFAULT PRIVILEGES added) */
    SELECT c.relacl, c.relowner INTO cur, own FROM pg_class c WHERE c.oid = 'pg_stat_statements'::regclass;
    REVOKE ALL ON pg_stat_statements FROM PUBLIC;
    FOR g IN SELECT DISTINCT a.grantee FROM aclexplode(cur) a WHERE a.grantee NOT IN (0, own) LOOP
      EXECUTE format('REVOKE ALL ON pg_stat_statements FROM %I', pg_get_userbyid(g.grantee));
    END LOOP;
    FOR g IN SELECT a.grantee, a.privilege_type, a.is_grantable
             FROM aclexplode(ARRAY(SELECT jsonb_array_elements_text(saved->'view_acl'))::aclitem[]) a
    LOOP
      EXECUTE format('GRANT %s ON pg_stat_statements TO %s%s', g.privilege_type,
                     CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(g.grantee)) END,
                     CASE WHEN g.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
  END IF;

  /* column privileges, for the columns that still exist */
  FOR g IN SELECT c->>'att' AS att, a.grantee, a.privilege_type, a.is_grantable
           FROM jsonb_array_elements(coalesce(saved->'col_acl', '[]'::jsonb)) c,
                aclexplode(ARRAY(SELECT jsonb_array_elements_text(c->'acl'))::aclitem[]) a
           WHERE EXISTS (SELECT 1 FROM pg_attribute t
                         WHERE t.attrelid = 'pg_stat_statements'::regclass AND t.attname = c->>'att'
                           AND t.attnum > 0 AND NOT t.attisdropped)
  LOOP
    EXECUTE format('GRANT %s (%I) ON pg_stat_statements TO %s%s', g.privilege_type, g.att,
                   CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(g.grantee)) END,
                   CASE WHEN g.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
  END LOOP;

  /*
   * The GRANT/REVOKE statements above ran inside the extension script, so
   * PostgreSQL recorded the site's privileges as the view's initial
   * privileges; pg_dump would stop dumping them.  Put back the initial
   * privileges recorded by this script itself (owner + PUBLIC SELECT, as
   * after CREATE EXTENSION), drop the column-level records, and the INITACL
   * dependencies (pg_shdepend deptype 'i') that only the dropped records
   * carried: every column-level one, and table-level ones of roles that are
   * not in the restored initial privileges (the owner keeps its row unless
   * it is a pinned role; PUBLIC never has one).
   */
  IF init IS NOT NULL THEN
    UPDATE pg_catalog.pg_init_privs SET initprivs = init
    WHERE objoid = 'pg_stat_statements'::regclass AND classoid = 'pg_catalog.pg_class'::regclass
      AND objsubid = 0;
    DELETE FROM pg_catalog.pg_init_privs
    WHERE objoid = 'pg_stat_statements'::regclass AND classoid = 'pg_catalog.pg_class'::regclass
      AND objsubid <> 0;
    DELETE FROM pg_catalog.pg_shdepend
    WHERE dbid = (SELECT oid FROM pg_catalog.pg_database WHERE datname = current_database())
      AND classid = 'pg_catalog.pg_class'::regclass AND objid = 'pg_stat_statements'::regclass
      AND deptype = 'i'
      AND (objsubid <> 0
           OR refobjid NOT IN (SELECT a.grantee FROM aclexplode(init) a
                               UNION SELECT a.grantor FROM aclexplode(init) a));
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(saved->'funcs') LOOP
    EXECUTE r->>'def';
    EXECUTE format('ALTER FUNCTION %s OWNER TO %I', r->>'sig', r->>'owner');

    SELECT p.proacl, p.proowner INTO cur, own
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = r->>'nsp' AND p.proname = r->>'name'
      AND format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)) = r->>'sig';
    IF cur IS NOT NULL OR jsonb_typeof(r->'acl') = 'array' THEN
      /* start from the owner alone (drop PUBLIC and anything ALTER DEFAULT PRIVILEGES added) */
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r->>'sig');
      FOR g IN SELECT DISTINCT a.grantee FROM aclexplode(cur) a WHERE a.grantee NOT IN (0, own) LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %I', r->>'sig', pg_get_userbyid(g.grantee));
      END LOOP;
      IF jsonb_typeof(r->'acl') = 'array' THEN
        FOR g IN SELECT a.grantee, a.is_grantable
                 FROM aclexplode(ARRAY(SELECT jsonb_array_elements_text(r->'acl'))::aclitem[]) a
                 WHERE a.privilege_type = 'EXECUTE'
        LOOP
          EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %s%s', r->>'sig',
                         CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(g.grantee)) END,
                         CASE WHEN g.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
        END LOOP;
      ELSE
        /* the function had the default privileges */
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO PUBLIC', r->>'sig');
      END IF;
    END IF;

    IF r->>'cmt' IS NOT NULL THEN
      EXECUTE format('COMMENT ON FUNCTION %s IS %L', r->>'sig', r->>'cmt');
    END IF;

    /*
     * The function was created inside this script, so it became an extension
     * member, and every GRANT/REVOKE above was recorded in pg_init_privs.
     * "ALTER EXTENSION ... DROP" undoes both; it must stay the last step, or
     * pg_dump would treat the site's privileges as extension defaults and
     * stop dumping them.
     */
    EXECUTE 'ALTER EXTENSION pg_stat_statements DROP FUNCTION ' || (r->>'sig');
  END LOOP;
END
$pgss$;
