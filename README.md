# pg_stat_statements 1.13e1 (eXperDB) — PostgreSQL 19

업스트림 PostgreSQL 19.0 `contrib/pg_stat_statements`(1.13)에 **`stats_last` 컬럼 하나만** 추가한 버전입니다.
뷰는 55컬럼(업스트림 54개 + `stats_last`)입니다. 1.13에서 업스트림이 추가한 `generic_plan_calls`, `custom_plan_calls`도 그대로 있습니다.

PostgreSQL 19용 eXperDB 버전은 이것이 처음입니다. 1.12e2(PostgreSQL 18)와 같은 방식으로 만들었습니다.
- 업데이트 스크립트가 eXperDB 헬퍼 함수(`get_stat_statements()`, `get_stat_statements_r1()`, `get_pgss_r1()` 등)와 뷰 권한을 보존합니다.
- PostgreSQL 15/16/17/18 클러스터를 pg_upgrade로 19에 올릴 수 있습니다. 라이브러리가 옛 eXperDB 정의(1.12e2, 1.12e1, 1.11e2, 1.11e1, 1.10e2, 1.10e1)를 모두 처리합니다.
- 크래시 결함이 있던 `bind_types` 코드는 없습니다.

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_13e1`), `PGSS_FILE_HEADER` 변경, 옛 eXperDB SQL 정의 호환 출력(아래 표). 쿼리 파싱·정규화 코드는 업스트림 19.0과 같습니다 |
| `pg_stat_statements--1.13--1.13e1.sql` | 업스트림 1.13 → 1.13e1 |
| `pg_stat_statements--1.8/1.9/1.10/1.10e1/1.10e2/1.11/1.11e1/1.11e2/1.12/1.12e1/1.12e2--1.13e1.sql` | pg_upgrade로 올라온 서버용 직접 경로. 1.9의 `pg_stat_statements_info`, 1.11의 `pg_stat_statements_reset(minmax_only)`, 1.12/1.13의 새 컬럼을 함께 적용 |
| `pg_stat_statements.control` | `default_version = '1.13e1'`, 코멘트에 1.13e1 표시 |
| `Makefile`, `meson.build` | 새 SQL 스크립트를 설치 목록에 추가 |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.13e1 업그레이드, 의존 함수·뷰 권한·초기 권한 보존, 직접 경로, 옛 정의 호환 출력 회귀 테스트 |

`stats_last`는 해당 항목의 카운터가 마지막으로 갱신된 시각입니다(계획 또는 실행 종료 시점).
- 동시 갱신 시에도 뒤로 가지 않습니다(단조 증가). 시각은 스핀락 밖에서 구하고 스핀락 안에서 비교·기록합니다.
- 재시작 후에도 통계 파일로 저장·복원됩니다.
- 한 번도 갱신되지 않은 항목은 NULL입니다.

### 이 라이브러리가 처리하는 SQL 정의

| 정의(어디서 왔나) | 컬럼 수 | C 함수 |
|---|---|---|
| 1.13e1 | 55 | `pg_stat_statements_1_13e1` |
| 업스트림 1.13 / 1.12 / 1.11 / 1.10 … | 54 / 52 / 49 / 43 … | 업스트림 그대로 |
| 1.12e2 (PG18에서 pg_upgrade) | 53 | `pg_stat_statements_1_12e2` |
| 1.12e1 (PG18에서 pg_upgrade) | 53 | `pg_stat_statements_1_12` |
| 1.11e2 (PG17에서 pg_upgrade) | 50 | `pg_stat_statements_1_11e2` |
| 1.11e1 (PG17에서 pg_upgrade) | 51 (`bind_types`는 NULL) | `pg_stat_statements_1_11` |
| 1.10e2 (PG15/16에서 pg_upgrade) | 45 | `pg_stat_statements_1_10e2` |
| 1.10e1 (PG15/16에서 pg_upgrade) | 46 (`bind_types`는 NULL) | `pg_stat_statements_1_10` |

### 업데이트 스크립트가 의존 객체와 권한을 보존함
1.13e1로 가는 모든 경로는 컬럼 구성이 바뀌므로 뷰를 다시 만듭니다. 이때 다음을 처리합니다.
1. 뷰의 행 타입(또는 그 배열 타입)을 쓰는 함수의 **정의, 소유자, 권한, 코멘트**를 저장합니다. 뷰의 **테이블·컬럼 권한**도 저장합니다.
2. 함수를 지우고 뷰를 다시 만든 뒤, 저장해 둔 것을 그대로 복원합니다. 함수가 확장 멤버로 들어가지 않게 하고, 그 함수의 `pg_init_privs` 기록도 남기지 않습니다.
3. 뷰의 초기 권한(`pg_init_privs`)은 `CREATE EXTENSION` 직후와 같게(소유자 + PUBLIC SELECT) 되돌립니다. 그래서 `pg_dump`가 사이트에서 준 뷰 권한(예: 모니터링 롤 GRANT)을 계속 덤프합니다.

`CASCADE`로 조용히 지우는 일은 없습니다. 함수가 아닌 객체(사용자 뷰 등)가 이 뷰에 의존하면 업스트림과 마찬가지로 오류가 나고 아무것도 바뀌지 않습니다. 그 경우 해당 객체를 먼저 정리합니다.

## 빌드 / 설치
```bash
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config install
```

## 신규 설치
`shared_preload_libraries`에 `pg_stat_statements`를 넣고 재기동한 뒤 `CREATE EXTENSION pg_stat_statements;`만 실행하면 1.13e1(55컬럼)이 됩니다.

## 업스트림 1.13 → 1.13e1 적용 (primary / standby)
1. **모든 노드**에 빌드·설치합니다. 실행 중인 서버는 재기동 전까지 옛 .so를 계속 씁니다.
2. **standby 먼저, 그다음 primary**를 재기동합니다. ALTER 전에도 뷰는 그대로 동작합니다(새 .so가 1.13 정의를 처리).
3. **primary에서만**, 확장이 설치된 각 DB에서 실행합니다.
   ```sql
   SET lock_timeout = '10s';
   ALTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';
   ```
   standby는 복제로 따라옵니다.

주의
- `ALTER EXTENSION`은 **모든 노드를 재기동한 뒤에** 실행합니다. 재기동 전 노드에서는 `could not find function "pg_stat_statements_1_13e1"` 오류가 납니다.
- 재기동 전에 `DROP EXTENSION` / `CREATE EXTENSION`을 하지 마세요.
- `PGSS_FILE_HEADER`가 바뀌었으므로 이전 통계 파일은 첫 기동 때 `LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"`와 함께 버려집니다(통계 한 번 초기화).
- ALTER 직후 `SELECT *`로 뷰를 읽던 prepared statement가 한 번 `cached plan must not change result type` 오류를 받을 수 있습니다(뷰를 다시 만들기 때문).
- ALTER 순간에 뷰나 헬퍼를 읽고 있던 쿼리 몇 건이 `cache lookup failed for type ...` 오류를 한 번 받을 수 있습니다(1.10e2/1.11e2와 같음, 다음 실행부터 정상). 수집 주기가 짧은 모니터링이 있으면 저부하 시간대에 ALTER합니다.
- 업데이트 스크립트 안의 함수 호출은 모두 `pg_catalog.`로 한정되어 있어, 확장 스키마에 다른 롤이 만든 같은 이름의 함수가 ALTER 실행 권한으로 호출되지 않습니다.
- `ALTER EXTENSION UPDATE`는 확장 코멘트를 바꾸지 않으므로 스크립트가 `COMMENT ON EXTENSION`으로 맞춥니다.

## PostgreSQL 15/16/17/18 → 19 업그레이드 (pg_upgrade)
1. 19 서버에 **1.13e1을 먼저 설치**한 뒤 pg_upgrade를 실행합니다. 업스트림 19 라이브러리에는 옛 eXperDB 정의(1.12e2, 1.11e2, 1.10e2 등)의 C 함수가 없어 스키마 복원 단계에서 실패합니다. `pg_upgrade --check`로는 걸러지지 않습니다.
2. 18 미만에서 올릴 때 19의 `initdb`는 기본으로 데이터 체크섬을 켭니다. 옛 클러스터가 체크섬 없이 만들어졌으면 `initdb --no-data-checksums`로 새 클러스터를 만듭니다.
3. pg_upgrade 직후에도 뷰와 헬퍼는 조회됩니다(옛 정의 그대로).
4. 바로 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.13e1';`을 실행합니다. 경로는 서버가 직접 스크립트(`<옛 버전>--1.13e1`)로 자동 선택합니다. `SELECT * FROM pg_extension_update_paths('pg_stat_statements') WHERE target = '1.13e1';`로 확인할 수 있습니다.
5. PG15/16용 헬퍼 `get_pgss_r1`(본문이 `blk_read_time` 사용)은 19에서 동작하지 않으므로 PG17 이상 정의로 다시 등록합니다.

pg_upgrade는 PG17 이상의 규칙에 따라 뷰 소유자 권한에 MAINTAIN(`m`)을 붙입니다. 이 동작은 업스트림과 같습니다.

## 원복
PostgreSQL 19용 이전 eXperDB 버전이 없으므로 원복 스크립트는 없습니다.
- ALTER 전(업스트림 1.13 정의 그대로)이라면: 업스트림 19 소스로 `make install`하고 재기동합니다.
- ALTER 후에는 업스트림 1.13으로 내려가는 경로를 제공하지 않습니다. eXperDB 헬퍼가 `stats_last`를 읽기 때문에 1.13으로 내려가면 헬퍼가 동작하지 않습니다.

## 알려진 제한
- 헬퍼 함수 권한을 복원할 때 grantor는 함수 소유자로 다시 기록됩니다.
- 옛 `pg_stat_statements_reset(oid,oid,bigint)`에 사이트가 준 권한은 1.11에서 서명이 바뀔 때 사라집니다(1.10 계열에서 올라온 경우). 업스트림도 같습니다.
- 행 타입을 쓰는 프로시저, 집계, `BEGIN ATOMIC` 본문 함수는 저장·복원 대상이 아닙니다. 이런 객체가 있으면 ALTER가 오류로 멈추고 아무것도 바뀌지 않습니다.
