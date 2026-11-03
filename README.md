# pg_stat_statements 1.12e2 (eXperDB) — PostgreSQL 18

업스트림 PostgreSQL 18.6 `contrib/pg_stat_statements`(1.12)에 **`stats_last` 컬럼 하나만** 추가한 버전입니다.
뷰는 53컬럼(업스트림 52개 + `stats_last`)으로 1.12e1과 같습니다.

1.12e1과 비교해 바뀐 점은 다음과 같습니다.
- 업데이트 스크립트가 eXperDB 헬퍼 함수를 지우지 않습니다. 1.12e1의 `1.12--1.12e1.sql`은 `DROP VIEW ... CASCADE`를 써서 `get_stat_statements()`, `get_stat_statements_r1()` 같은 헬퍼를 조용히 삭제했습니다.
- PostgreSQL 15/16/17 클러스터를 pg_upgrade로 18에 올릴 수 있습니다. 1.12e1 라이브러리에는 옛 eXperDB 정의의 C 함수가 없어 pg_upgrade가 실패했습니다.
- 기반이 업스트림 18.6입니다. 1.12e1은 18.1~18.3 기반이었습니다.

1.12e1에는 크래시 결함이 없습니다(PG15/16/17의 e1 버전에 있던 `bind_types` 코드가 애초에 없음).

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_12e2`), `PGSS_FILE_HEADER` 변경, 옛 eXperDB SQL 정의 호환 출력(아래 표) |
| `pg_stat_statements--1.12--1.12e2.sql` | 업스트림 1.12 → 1.12e2 |
| `pg_stat_statements--1.12e1--1.12e2.sql` | 1.12e1 → 1.12e2. 컬럼이 같으므로 뷰를 다시 만들지 않고 C 함수만 교체 |
| `pg_stat_statements--1.12e2--1.12e1.sql` | 원복용 1.12e2 → 1.12e1(같은 방식) |
| `pg_stat_statements--1.12--1.12e1.sql` | 1.12e1의 CASCADE 스크립트를 헬퍼 보존 방식으로 교체(같은 파일명이라 `make install`이 덮어씀) |
| `pg_stat_statements--1.8/1.9/1.10/1.10e1/1.10e2/1.11/1.11e1/1.11e2--1.12e2.sql` | pg_upgrade로 올라온 서버용 직접 경로. 1.9의 `pg_stat_statements_info`, 1.11의 `pg_stat_statements_reset(minmax_only)` 변경을 함께 적용 |
| `pg_stat_statements.control` | `default_version = '1.12e2'`, 코멘트에 1.12e2 표시 |
| `Makefile`, `meson.build` | 새 SQL 스크립트를 설치 목록에 추가(1.12e1의 자기 자신을 복사하는 `all:` 규칙 제거) |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.12e2 업그레이드, 원복, 의존 함수·뷰 권한·초기 권한 보존, 직접 경로, 옛 정의 호환 출력 회귀 테스트 |

`stats_last`는 해당 항목의 카운터가 마지막으로 갱신된 시각입니다(계획 또는 실행 종료 시점).
- 동시 갱신 시에도 뒤로 가지 않습니다(단조 증가). 시각은 스핀락 밖에서 구하고 스핀락 안에서 비교·기록합니다.
- 재시작 후에도 통계 파일로 저장·복원됩니다.
- 한 번도 갱신되지 않은 항목은 NULL입니다. 1.12e1은 이때 쓰레기 값이나 2000-01-01이 보일 수 있었습니다.

### 이 라이브러리가 처리하는 SQL 정의

| 정의(어디서 왔나) | 컬럼 수 | C 함수 |
|---|---|---|
| 1.12e2 | 53 | `pg_stat_statements_1_12e2` |
| 1.12e1 (PG18, ALTER 전) | 53 | `pg_stat_statements_1_12` |
| 업스트림 1.12 / 1.11 / 1.10 … | 52 / 49 / 43 … | 업스트림 그대로 |
| 1.11e2 (PG17에서 pg_upgrade) | 50 | `pg_stat_statements_1_11e2` |
| 1.11e1 (PG17에서 pg_upgrade) | 51 (`bind_types`는 NULL) | `pg_stat_statements_1_11` |
| 1.10e2 (PG15/16에서 pg_upgrade) | 45 | `pg_stat_statements_1_10e2` |
| 1.10e1 (PG15/16에서 pg_upgrade) | 46 (`bind_types`는 NULL) | `pg_stat_statements_1_10` |

### 업데이트 스크립트가 의존 객체와 권한을 보존함
- **1.12e1 ↔ 1.12e2**: 컬럼이 같으므로 `CREATE OR REPLACE FUNCTION`으로 C 함수만 바꿉니다. 뷰, 뷰 권한, 뷰를 쓰는 헬퍼 함수와 사이트 뷰가 모두 그대로 남습니다.
- **그 밖의 경로**(1.12, pg_upgrade로 올라온 버전): 컬럼 구성이 바뀌므로 뷰를 다시 만듭니다. 이때 다음을 처리합니다.
  1. 뷰의 행 타입(또는 그 배열 타입)을 쓰는 함수의 **정의, 소유자, 권한, 코멘트**를 저장합니다. 뷰의 **테이블·컬럼 권한**도 저장합니다.
  2. 함수를 지우고 뷰를 다시 만든 뒤, 저장해 둔 것을 그대로 복원합니다. 함수가 확장 멤버로 들어가지 않게 하고, 그 함수의 `pg_init_privs` 기록도 남기지 않습니다.
  3. 뷰의 초기 권한(`pg_init_privs`)은 `CREATE EXTENSION` 직후와 같게(소유자 + PUBLIC SELECT) 되돌립니다. 그래서 `pg_dump`가 사이트에서 준 뷰 권한(예: 모니터링 롤 GRANT)을 계속 덤프합니다.

`CASCADE`로 조용히 지우는 일은 없습니다. 뷰를 다시 만드는 경로에서 함수가 아닌 객체(사용자 뷰 등)가 이 뷰에 의존하면 업스트림과 마찬가지로 오류가 나고 아무것도 바뀌지 않습니다. 그 경우 해당 객체를 먼저 정리합니다.

## 빌드 / 설치
```bash
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config install
```

## 1.12e1 → 1.12e2 적용 (primary / standby)
1. **모든 노드**에 빌드·설치합니다. 실행 중인 서버는 재기동 전까지 옛 .so를 계속 씁니다.
2. **standby 먼저, 그다음 primary**를 재기동합니다. ALTER 전에도 뷰는 그대로 동작합니다(새 .so가 1.12e1 정의를 처리).
3. **primary에서만**, 확장이 설치된 각 DB에서 실행합니다.
   ```sql
   SET lock_timeout = '10s';
   ALTER EXTENSION pg_stat_statements UPDATE TO '1.12e2';
   ```
   standby는 복제로 따라옵니다.

신규 설치는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.12e2(53컬럼)가 됩니다.

주의
- `ALTER EXTENSION`은 **모든 노드를 재기동한 뒤에** 실행합니다. 재기동 전 노드에서는 `could not find function "pg_stat_statements_1_12e2"` 오류가 납니다.
- 재기동 전에 `DROP EXTENSION` / `CREATE EXTENSION`을 하지 마세요.
- `PGSS_FILE_HEADER`가 바뀌었으므로 이전 통계 파일은 첫 기동 때 `LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"`와 함께 버려집니다(통계 한 번 초기화).
- 뷰를 다시 만드는 경로(1.12 또는 pg_upgrade 후)에서는 ALTER 직후 `SELECT *`로 뷰를 읽던 prepared statement가 한 번 `cached plan must not change result type` 오류를 받을 수 있습니다. 1.12e1 → 1.12e2는 뷰를 그대로 두므로 해당하지 않습니다.
- `ALTER EXTENSION UPDATE`는 확장 코멘트를 바꾸지 않으므로 스크립트가 `COMMENT ON EXTENSION`으로 맞춥니다.

## PostgreSQL 15/16/17 → 18 업그레이드 (pg_upgrade)
1. 18 서버에 **1.12e2를 먼저 설치**한 뒤 pg_upgrade를 실행합니다. 1.12e1을 설치한 상태에서는 옛 eXperDB 정의(1.11e2, 1.10e2 등)의 C 함수가 없어 스키마 복원 단계에서 실패합니다. `pg_upgrade --check`로는 걸러지지 않습니다.
2. pg_upgrade 직후에도 뷰와 헬퍼는 조회됩니다(옛 정의 그대로).
3. 바로 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.12e2';`를 실행합니다. 경로는 서버가 직접 스크립트(`<옛 버전>--1.12e2`)로 자동 선택합니다. `SELECT * FROM pg_extension_update_paths('pg_stat_statements') WHERE target = '1.12e2';`로 확인할 수 있습니다.
4. PG15/16용 헬퍼 `get_pgss_r1`(본문이 `blk_read_time` 사용)은 18에서 동작하지 않으므로 PG17 이상 정의로 다시 등록합니다. 이 패키지의 `helpers/`를 사용합니다.

pg_upgrade는 PG17 이상의 규칙에 따라 뷰 소유자 권한에 MAINTAIN(`m`)을 붙입니다. 이 동작은 업스트림과 같습니다.

## 원복 (1.12e2 → 1.12e1)
- ALTER 전이라면: 1.12e1 소스로 `make install`하고 재기동합니다.
- ALTER 후라면:
  1. primary에서 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.12e1';`을 실행합니다. 함수만 교체하므로 헬퍼와 권한은 그대로입니다.
  2. 모든 노드에 1.12e1 소스로 `make install`합니다.
  3. standby, primary 순으로 재기동합니다.

원복 후 주의할 점이 두 가지 있습니다.
- 1.12e1 소스의 `make install`은 CASCADE를 쓰는 옛 `1.12--1.12e1.sql`을 다시 설치합니다.
- 이 패키지의 `*1.12e2*.sql` 파일은 지워지지 않습니다. 그 상태에서 새 DB에 `CREATE EXTENSION`을 하면 1.12e2를 거치는 경로가 선택되어 `could not find function "pg_stat_statements_1_12e2"` 오류가 납니다. 원복한 서버에서 확장을 새로 만들 일이 있으면 share/extension의 해당 파일을 먼저 지웁니다.

## 알려진 제한
- 뷰를 다시 만드는 경로에서는 아래 사항이 업스트림과 같거나 비슷하게 동작합니다.
  - 헬퍼 함수 권한을 복원할 때 grantor는 함수 소유자로 다시 기록됩니다.
  - 옛 `pg_stat_statements_reset(oid,oid,bigint)`에 사이트가 준 권한은 1.11에서 서명이 바뀔 때 사라집니다(1.10 계열에서 올라온 경우). 업스트림도 같습니다.
- 행 타입을 쓰는 프로시저, 집계, `BEGIN ATOMIC` 본문 함수는 저장·복원 대상이 아닙니다. 이런 객체가 있으면 ALTER가 오류로 멈추고 아무것도 바뀌지 않습니다.
- `UPDATE TO '1.12e1'`은 1.12e2(또는 1.12)에서 되돌리는 용도입니다. 1.11에서 바로 1.12e1을 지정하면 서버가 업스트림 경로(`1.11 → 1.12 → 1.12e1`)를 고를 수 있고, 헬퍼가 있으면 업스트림 `DROP VIEW`에서 오류로 멈춥니다(삭제는 없음). 하위 버전에서는 1.12e2로 올립니다.
