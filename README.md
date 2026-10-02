# pg_stat_statements 1.11e2 (eXperDB) — PostgreSQL 17

업스트림 PostgreSQL 17.5 `contrib/pg_stat_statements`(1.11)에 **`stats_last` 기능 하나만** 추가한 버전입니다.
1.11e1에 있던 `bind_types` 계산 코드(및 그 안의 힙 오버플로)는 포함하지 않습니다.
뷰 형태는 1.11e1과 같은 51개 컬럼을 유지하며, `bind_types` 컬럼은 호환용으로만 남아 **항상 NULL**입니다.

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_11e2`), `PGSS_FILE_HEADER` 변경 |
| `pg_stat_statements--1.11--1.11e2.sql` | 업스트림 1.11 → 1.11e2 업그레이드 |
| `pg_stat_statements--1.11e1--1.11e2.sql` | 1.11e1 → 1.11e2 업그레이드 (뷰는 그대로 두고 C 진입점만 교체) |
| `pg_stat_statements--1.11e2--1.11e1.sql` | 원복용 1.11e2 → 1.11e1 (C 진입점만 되돌림) |
| `pg_stat_statements.control` | `default_version = '1.11e2'` |
| `Makefile`, `meson.build` | 새 SQL 스크립트 설치 목록 추가 |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.11e2 업그레이드 회귀 테스트 추가 |

`stats_last`: 해당 항목의 카운터가 마지막으로 갱신된 시각(계획 또는 실행 종료 시점, 1.11e1과 동일한 의미).
동시 갱신 시에도 뒤로 가지 않도록(단조 증가) 처리했습니다. 아직 한 번도 갱신되지 않은 항목은 NULL이지만,
그런 항목은 뷰에 노출되지 않는 pending 항목뿐이므로 실제로 NULL이 보일 일은 없습니다.

### 1.11e1과의 차이 (소비자 영향)

- 컬럼 이름, 순서, 타입이 1.11e1과 **완전히 같습니다**(51개). `bind_types`만 항상 NULL이 됩니다.
  - 이 뷰에 의존하는 함수/뷰(eXperDB 헬퍼 `get_stat_statements()` 등)를 건드리지 않고 업그레이드됩니다.
  - `pss.bind_types`를 읽는 수집/애플리케이션 쿼리도 수정 없이 동작합니다(값만 NULL).
- 1.11e1은 재시작 후 복원된 항목의 `stats_last`를 파일에서 읽지 않아 쓰레기 값이 보일 수 있었습니다. 1.11e2는 저장/복원합니다.

## 빌드 / 설치

```bash
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config install
```

## 1.11e1 → 1.11e2 적용 (primary / standby)

1. **모든 노드**(primary, standby)에 위와 같이 빌드/설치합니다.
   실행 중인 서버는 옛 .so를 계속 쓰고, 재기동 때 새 .so가 로드됩니다.
2. **standby 먼저, 그다음 primary**를 재기동합니다.
   - 재기동만으로 결함 코드가 사라집니다.
   - 재기동 직후에도 뷰는 그대로 동작합니다(1.11e1 SQL 정의를 새 .so가 같은 형태로 처리).
3. **primary에서만**, 확장이 설치된 각 데이터베이스에 대해:
   ```sql
   ALTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
   ```
   - 뷰를 DROP하지 않으므로 의존 객체가 있어도 성공합니다.
   - standby는 복제로 따라옵니다.

## 원복 (1.11e2 → 1.11e1)
- ALTER 전이라면: 1.11e1 소스로 `make install` 후 재기동하면 끝입니다.
- ALTER 후라면:
  1. primary에서 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.11e1';`를 실행합니다(1.11e2 .so가 로드된 상태에서).
  2. 모든 노드에 1.11e1 소스로 `make install`을 합니다.
  3. standby, primary 순으로 재기동합니다.
- 원복하면 크래시 결함도 다시 생깁니다.

새로 설치하는 경우는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.11e2가 됩니다.

주의
- `ALTER EXTENSION`은 **모든 노드를 재기동한 뒤에** 실행하세요.
  - 재기동 전 노드에서는 `could not find function "pg_stat_statements_1_11e2"` 오류가 납니다.
  - primary에서 ALTER가 먼저 복제되면, 아직 재기동하지 않은 standby의 뷰 조회가 같은 오류를 냅니다(그 standby를 재기동하면 해소).
- 재기동 전에 `DROP EXTENSION` / `CREATE EXTENSION`을 하지 마세요. CREATE가 위 오류로 실패해서 확장이 없는 상태가 됩니다.
- 업스트림 1.11에서 올리는 경우(`pg_stat_statements--1.11--1.11e2.sql`)는 컬럼이 2개 늘어나므로
  업스트림 1.10→1.11과 마찬가지로 뷰를 DROP 후 재생성합니다. 이 뷰에 의존하는 객체가 있으면 먼저 정리해야 합니다.
- `PGSS_FILE_HEADER`가 바뀌었으므로 1.11e1/업스트림이 저장해 둔 통계 파일은 첫 기동 때
  `LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"` 로그와 함께 버려집니다(통계 초기화).
- 기존에 설치돼 있던 `pg_stat_statements--1.10--1.11e1.sql`은 `make install`이 지우지 않습니다.
  남겨 두어도 무해하며, 1.11e1 상태의 클러스터를 pg_upgrade 할 때는 오히려 필요하므로 삭제하지 않는 것을 권장합니다.
