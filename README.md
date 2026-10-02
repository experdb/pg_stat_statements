# pg_stat_statements 1.11e2 (eXperDB) — PostgreSQL 17

업스트림 PostgreSQL 17.5 `contrib/pg_stat_statements`(1.11)에 **`stats_last` 컬럼 하나만** 추가한 버전입니다.
뷰는 50컬럼입니다(업스트림 49개 + `stats_last`). PG18용 1.12e1과 같은 방식입니다.
1.11e1에 있던 `bind_types` 기능은 컬럼과 계산 코드를 모두 제거했습니다. 이 계산 코드에는 리터럴이 많은 쿼리에서 크래시를 일으키던 힙 오버플로가 있었습니다.

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_11e2`), `PGSS_FILE_HEADER` 변경, 1.11e1 SQL 정의(51컬럼) 호환 출력 |
| `pg_stat_statements--1.11--1.11e2.sql` | 업스트림 1.11 → 1.11e2 |
| `pg_stat_statements--1.11e1--1.11e2.sql` | 1.11e1 → 1.11e2 (`bind_types` 컬럼 제거) |
| `pg_stat_statements--1.11e2--1.11e1.sql` | 원복용 1.11e2 → 1.11e1 |
| `pg_stat_statements.control` | `default_version = '1.11e2'` |
| `Makefile`, `meson.build` | 새 SQL 스크립트를 설치 목록에 추가 |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.11e2 업그레이드, 원복, 의존 함수 보존 회귀 테스트 |

`stats_last`는 해당 항목의 카운터가 마지막으로 갱신된 시각입니다(계획 또는 실행 종료 시점, 1.11e1과 같은 의미).
- 동시 갱신 시에도 뒤로 가지 않습니다(단조 증가).
- 재시작 후에도 통계 파일로 저장·복원됩니다. 1.11e1은 복원 시 이 값을 읽지 않아 쓰레기 값이 보일 수 있었습니다.

### 업데이트 스크립트가 의존 객체를 보존함
컬럼 구성이 바뀌므로 업데이트 스크립트는 뷰를 다시 만듭니다. 이때 뷰의 행 타입을 쓰는 함수가 있으면 업스트림 방식으로는 DROP VIEW가 실패합니다. 예를 들어 eXperDB 헬퍼 `get_stat_statements()`, `get_stat_statements_r1()`은 `RETURNS SETOF pg_stat_statements`로 정의되어 있습니다.

그래서 세 스크립트 모두 다음을 수행합니다.
1. 그런 함수의 **정의, 소유자, 권한, 코멘트**와 **뷰 권한**을 저장합니다.
2. 함수를 지우고 뷰를 다시 만듭니다.
3. 저장해 둔 것을 그대로 복원합니다. 함수가 확장 멤버로 들어가지 않도록 처리합니다.

`CASCADE`로 조용히 지우는 일은 없습니다. 함수가 아닌 객체(사용자 뷰 등)가 이 뷰에 의존하면 업스트림과 마찬가지로 오류가 나며, 그 경우 해당 객체를 먼저 정리해야 합니다.

### 1.11e1과의 차이 (소비자 영향)
- 51번째 컬럼 `bind_types`가 없어졌습니다. 앞 50개 컬럼의 이름, 순서, 타입은 같습니다.
- `bind_types`를 이름으로 참조하는 쿼리는 수정해야 합니다. eXperDB metric은 이 컬럼을 읽지 않습니다.

## 빌드 / 설치
```bash
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config install
```

## 1.11e1 → 1.11e2 적용 (primary / standby)
1. **모든 노드**에 빌드·설치합니다. 실행 중인 서버는 재기동 전까지 옛 .so를 계속 씁니다.
2. **standby 먼저, 그다음 primary**를 재기동합니다.
   - 재기동만으로 결함 코드가 사라집니다.
   - ALTER 전에도 뷰는 그대로 동작합니다. 새 .so가 1.11e1 정의(51컬럼)를 처리하며, 이때 `bind_types`는 NULL입니다.
3. **primary에서만**, 확장이 설치된 각 DB에 대해 실행합니다.
   ```sql
   ALTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
   ```
   standby는 복제로 따라옵니다.

신규 설치는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.11e2(50컬럼)가 됩니다.

주의
- `ALTER EXTENSION`은 **모든 노드를 재기동한 뒤에** 실행합니다. 재기동 전 노드에서는 `could not find function "pg_stat_statements_1_11e2"` 오류가 납니다.
- 재기동 전에 `DROP EXTENSION` / `CREATE EXTENSION`을 하지 마세요.
- `PGSS_FILE_HEADER`가 바뀌었으므로 이전 통계 파일은 첫 기동 때 `LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"`와 함께 버려집니다(통계 초기화).
- 기존 `pg_stat_statements--1.10--1.11e1.sql`은 `make install`이 지우지 않습니다. 남겨 두세요. 원복이나 pg_upgrade 때 필요합니다.

## 원복 (1.11e2 → 1.11e1)
- ALTER 전이라면: 1.11e1 소스로 `make install`하고 재기동합니다.
- ALTER 후라면:
  1. primary에서 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.11e1';`를 실행합니다. 1.11e2 .so가 로드된 상태에서 해야 하며, 의존 함수는 보존됩니다.
  2. 모든 노드에 1.11e1 소스로 `make install`합니다.
  3. standby, primary 순으로 재기동합니다.

원복하면 크래시 결함도 다시 생깁니다.
