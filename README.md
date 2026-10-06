# pg_stat_statements 1.10e2 (eXperDB) — PostgreSQL 15

업스트림 PostgreSQL 15(REL_15_19) `contrib/pg_stat_statements`(1.10)에 eXperDB 모니터링이 쓰는 두 컬럼
`stats_last`, `stats_since`만 추가한 버전입니다. 뷰는 45컬럼입니다(업스트림 43개 + 2개).
1.10e1에 있던 `bind_types` 기능은 컬럼과 계산 코드를 모두 제거했습니다. 이 계산 코드에는 리터럴이 많은 쿼리에서
백엔드를 크래시시키던 힙 오버플로가 있었습니다. PostgreSQL 17용 1.11e2와 같은 방식입니다.

## 업스트림 대비 변경점

| 파일 | 변경 |
|---|---|
| `pg_stat_statements.c` | `pgssEntry.stats_since`/`stats_last` 추가, `pgss_store()`에서 카운터 갱신 시각 기록, 통계 파일 저장/복원, 뷰 출력(`pg_stat_statements_1_10e2`), `PGSS_FILE_HEADER` 변경, 1.10e1 SQL 정의(46컬럼) 호환 출력 |
| `pg_stat_statements--1.10--1.10e2.sql` | 업스트림 1.10 → 1.10e2 |
| `pg_stat_statements--1.10e1--1.10e2.sql` | 1.10e1 → 1.10e2 (`bind_types` 컬럼 제거) |
| `pg_stat_statements--1.10e2--1.10e1.sql` | 원복용 1.10e2 → 1.10e1 |
| `pg_stat_statements.control` | `default_version = '1.10e2'` |
| `Makefile` | 새 SQL 스크립트를 설치 목록에 추가 |
| `sql/oldextversions.sql`, `expected/oldextversions.out` | 1.10e2 업그레이드, 원복, 의존 함수 보존 회귀 테스트 |

- `stats_last`: 해당 항목의 카운터가 마지막으로 갱신된 시각(계획 또는 실행 종료 시점). 단조 증가하며 재시작 후에도 저장·복원됩니다.
- `stats_since`: 항목이 통계에 처음 등록된 시각. 재시작 후에도 저장·복원됩니다.
- 1.10e1은 복원 시 `stats_last`를 파일에서 읽지 않아 쓰레기 값이 보일 수 있었습니다. 1.10e2는 두 값을 모두 저장/복원합니다.

### 업데이트 스크립트가 의존 객체를 보존함
컬럼 구성이 바뀌므로 업데이트 스크립트는 뷰를 다시 만듭니다. 뷰의 행 타입을 쓰는 함수(eXperDB 헬퍼
`get_stat_statements()`, `get_stat_statements_r1()` 등 `RETURNS SETOF pg_stat_statements`)는 **정의, 소유자, 권한, 코멘트**와
**뷰 권한**을 저장했다가 그대로 복원하며, 확장 멤버로 들어가지 않도록 처리합니다. `CASCADE`로 지우지 않습니다.
함수가 아닌 객체(사용자 뷰 등)가 이 뷰에 의존하면 업스트림과 마찬가지로 오류가 나며, 그 객체를 먼저 정리해야 합니다.

### 1.10e1과의 차이 (소비자 영향)
- 46번째 컬럼 `bind_types`가 없어졌습니다. 앞 45개 컬럼의 이름, 순서, 타입은 같습니다.
- `bind_types`를 이름으로 참조하는 쿼리는 수정해야 합니다. eXperDB metric은 이 컬럼을 읽지 않습니다.

## 빌드 / 설치
```bash
make USE_PGXS=1 PG_CONFIG=<PGHOME>/bin/pg_config
make USE_PGXS=1 PG_CONFIG=<PGHOME>/bin/pg_config install
```

## 1.10e1 → 1.10e2 적용 (primary / standby)
1. **모든 노드**에 빌드·설치합니다. 실행 중인 서버는 재기동 전까지 옛 .so를 계속 씁니다.
2. **standby 먼저, 그다음 primary**를 재기동합니다. 재기동만으로 결함 코드가 사라지며, ALTER 전에도 뷰(46컬럼 정의)는 그대로 동작합니다(`bind_types`만 NULL).
3. **primary에서만**, 확장이 설치된 각 DB에 대해 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';`를 실행합니다. standby는 복제로 따라옵니다.

신규 설치는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.10e2(45컬럼)가 됩니다.
절차와 주의 사항은 PostgreSQL 17용 패치 가이드(PATCH_GUIDE)와 같으며, 버전 문자열만 `1.10e1`/`1.10e2`로 바뀝니다.

## 원복 (1.10e2 → 1.10e1)
- ALTER 전이라면 1.10e1 소스로 `make install` 후 재기동합니다.
- ALTER 후라면 primary에서 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.10e1';`(1.10e2 .so가 로드된 상태, 의존 함수 보존) →
  모든 노드에 1.10e1 `make install` → standby, primary 순으로 재기동합니다. 원복하면 크래시 결함도 다시 생깁니다.
