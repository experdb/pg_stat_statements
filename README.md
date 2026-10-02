# pg_stat_statements 1.11e2 (eXperDB) — PostgreSQL 17

업스트림 PostgreSQL 17.5 `contrib/pg_stat_statements`(1.11)에 **`stats_last` 컬럼 하나만** 추가한 버전입니다.
1.11e1에 있던 `bind_types` 기능(및 그 안의 힙 오버플로)은 포함하지 않습니다.

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_11e2`), `PGSS_FILE_HEADER` 변경 |
| `pg_stat_statements--1.11--1.11e2.sql` | 업스트림 1.11 → 1.11e2 업그레이드 |
| `pg_stat_statements--1.11e1--1.11e2.sql` | 1.11e1 → 1.11e2 업그레이드 |
| `pg_stat_statements.control` | `default_version = '1.11e2'` |
| `Makefile`, `meson.build` | 새 SQL 스크립트 설치 목록 추가 |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.11e2 업그레이드 회귀 테스트 추가 |

`stats_last`: 해당 항목의 카운터가 마지막으로 갱신된 시각(계획 또는 실행 종료 시점, 1.11e1과 동일한 의미).
동시 갱신 시에도 뒤로 가지 않도록(단조 증가) 처리했습니다. 아직 한 번도 갱신되지 않은 항목은 NULL이지만,
그런 항목은 뷰에 노출되지 않는 pending 항목뿐이므로 실제로 NULL이 보일 일은 없습니다.

### 1.11e1과의 차이 (소비자 영향)

- 1.11e1의 51개 컬럼 중 마지막 `bind_types`가 **제거**되어 50개 컬럼입니다. 앞 50개 컬럼의 순서는 1.11e1과 동일합니다.
  `bind_types`를 참조하거나 `SELECT *`를 위치 기반으로 소비하는 수집 쿼리는 수정이 필요합니다.
- 1.11e1은 재시작 후 복원된 항목의 `stats_last`를 파일에서 읽지 않아 쓰레기 값이 보일 수 있었습니다. 1.11e2는 저장/복원합니다.

## 빌드 / 설치

```bash
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config
make USE_PGXS=1 PG_CONFIG=/app/postgres/pgsql/bin/pg_config install
```

## 적용 순서 (1.11e1 → 1.11e2, 업스트림 1.11 → 1.11e2 동일)

1. 위와 같이 빌드/설치 (`pg_stat_statements.so`와 SQL 스크립트가 교체됨)
2. PostgreSQL **재시작** (공유 메모리 항목 구조가 바뀌므로 필수)
3. 확장이 설치된 **모든** 데이터베이스에서:
   ```sql
   ALTER EXTENSION pg_stat_statements UPDATE TO '1.11e2';
   ```
   새로 설치하는 경우는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.11e2가 됩니다.

주의
- 순서를 지켜야 합니다. 재시작 **전에** `ALTER EXTENSION`을 실행하면 옛 .so가 로드된 상태라
  `could not find function "pg_stat_statements_1_11e2"` 오류가 납니다.
- **1.11e1에서 올리는 경우**: 재시작 직후 `ALTER EXTENSION` 전까지는 `pg_stat_statements` 뷰 조회가
  `incorrect number of output arguments` 오류를 냅니다(1.11e1 뷰 정의가 51컬럼이라서; 크래시 아님).
  **업스트림 1.11에서 올리는 경우**: 재시작 후에도 뷰는 정상 동작하며 `stats_last` 컬럼만 없는 상태입니다.
- `ALTER EXTENSION`은 내부적으로 `DROP VIEW pg_stat_statements`를 수행하므로(업스트림 1.10→1.11과 동일),
  이 뷰에 의존하는 사용자 뷰/머티리얼라이즈드 뷰/SQL 본문 함수가 있으면 실패합니다. 먼저 DROP 하고
  UPDATE 후 재생성하세요. PUBLIC 외의 GRANT나 COMMENT도 다시 적용해야 합니다.
- `PGSS_FILE_HEADER`가 바뀌었으므로 1.11e1/업스트림이 저장해 둔 통계 파일은 첫 기동 때
  `LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"` 로그와 함께 버려집니다(통계 초기화).
- 기존에 설치돼 있던 `pg_stat_statements--1.10--1.11e1.sql`은 `make install`이 지우지 않습니다.
  남겨 두어도 무해하며, 1.11e1 상태의 클러스터를 pg_upgrade 할 때는 오히려 필요하므로 삭제하지 않는 것을 권장합니다.
