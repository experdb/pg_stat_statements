# pg_stat_statements 1.10e2 (eXperDB) — PostgreSQL 16

업스트림 PostgreSQL 16(REL_16_15) `contrib/pg_stat_statements`(1.10)에 eXperDB 모니터링이 쓰는 두 컬럼
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
| `pg_stat_statements--1.8--1.10e2.sql`, `--1.9--1.10e2.sql` | pg_upgrade로 올라온 서버용 직접 경로(1.8/1.9 → 1.10e2 한 번에). 1.9의 `pg_stat_statements_info` 추가를 함께 적용 |
| `pg_stat_statements.control` | `default_version = '1.10e2'` |
| `Makefile`, `meson.build` | 새 SQL 스크립트를 설치 목록에 추가 |
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
2. **standby 먼저, 그다음 primary**를 재기동합니다. 재기동만으로 결함 코드가 사라지며, ALTER 전에도 뷰(46컬럼 정의)는 그대로 동작합니다(`bind_types`만 NULL). 통계 파일 형식이 바뀌어 이 재기동 때 누적 통계가 1회 초기화됩니다(`LOG:  ignoring invalid data in file "pg_stat/pg_stat_statements.stat"`, 정상).
3. **primary에서만**, 확장이 설치된 각 DB에 대해 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';`를 실행합니다. standby는 복제로 따라옵니다.

신규 설치는 `CREATE EXTENSION pg_stat_statements`만 실행하면 1.10e2(45컬럼)가 됩니다.
절차와 주의 사항은 PostgreSQL 17용 패치 가이드(PATCH_GUIDE)와 같으며, 버전 문자열만 `1.10e1`/`1.10e2`로 바뀝니다.

주의
- `ALTER EXTENSION`은 뷰에 배타 잠금을 잡습니다. 모니터링 수집이 도는 중이면 `SET lock_timeout = '10s';` 후 실행하고, 시간 초과 시 다시 실행합니다.
- 뷰를 `SELECT *`로 읽는 prepared statement를 쥐고 있던 세션은 ALTER 직후 한 번 `cached plan must not change result type` 오류를 받고 다음 실행부터 정상입니다. standby에서 뷰를 읽던 쿼리는 복제 적용 시점에 1회 취소될 수 있습니다.
- 스크립트가 `COMMENT ON EXTENSION`으로 확장 설명을 1.10e2에 맞추므로 `\dx`에 버전과 설명이 함께 갱신됩니다.
- 논리 덤프: 헬퍼 함수의 권한은 복원 마지막에 확장 멤버에서 빼면서 "확장 초기 권한"(`pg_init_privs`) 기록도 함께 지우므로 `pg_dump`가 계속 덤프합니다. 뷰 자체에 사이트가 추가한 `GRANT`는 초기 권한에 포함되어 `pg_dump`가 내보내지 않으니, 덤프/복원 뒤에는 뷰 권한을 다시 확인합니다(PUBLIC SELECT는 유지됨).

### 하위 버전에서 바로 업데이트 (pg_upgrade로 올라온 서버)
PG13/14에서 pg_upgrade로 올라온 클러스터는 확장 버전이 `1.8`/`1.9`로 남아 있습니다. 업스트림 경로(`1.8 → 1.9 → 1.10 → 1.10e2`)는 중간 단계에서 헬퍼 함수 때문에 `DROP VIEW`가 실패하므로, 이 패키지는 `1.8`, `1.9`에서 1.10e2로 한 번에 가는 직접 스크립트를 제공합니다. 명령은 같은 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.10e2';`이며, pg_upgrade 뒤에 바로 실행합니다(1.8/1.9 정의는 업스트림 코드가 호환 출력하므로 그 전에도 뷰는 조회됩니다).

이후 **PostgreSQL 17로 pg_upgrade** 할 때는 17 쪽에 반드시 **1.11e2**가 설치되어 있어야 합니다. 1.10e2 정의는 C 심볼 `pg_stat_statements_1_10e2`에 묶여 있고 pg_upgrade가 이를 확인하므로, 이 심볼이 없는 1.11e1 라이브러리로는 pg_upgrade가 스키마 복원 단계에서 실패합니다(`--check`로는 걸러지지 않음). 1.11e2는 이 정의를 호환 출력하며, 올라간 뒤 `UPDATE TO '1.11e2'`로 한 번에 갱신됩니다.

## 원복 (1.10e2 → 1.10e1)
- ALTER 전이라면 1.10e1 소스로 `make install` 후 재기동합니다.
- ALTER 후라면 primary에서 `ALTER EXTENSION pg_stat_statements UPDATE TO '1.10e1';`(어느 라이브러리가 로드되어 있어도 됨, 의존 함수 보존) →
  모든 노드에 1.10e1 `make install` → standby, primary 순으로 재기동합니다. 원복하면 크래시 결함도 다시 생깁니다.
- 원복 후 주의: 1.10e1 소스의 `make install`은 이 패키지의 스크립트 파일(`pg_stat_statements--*1.10e2*.sql`)을 지우지 않습니다. 그 상태에서 새 DB에 `CREATE EXTENSION`을 하면 1.10e2를 거치는 더 짧은 경로가 선택되어 `could not find function "pg_stat_statements_1_10e2"` 오류가 나므로, 원복한 서버에서 확장을 새로 만들 일이 있으면 해당 파일들을 먼저 지웁니다.

## 참고: 뷰에 권한을 준 롤을 나중에 삭제할 때 (PostgreSQL 15/16)
사이트가 `pg_stat_statements` 뷰에 직접 `GRANT`한 롤이 있으면 업데이트 스크립트가 그 권한을 복원하면서 "확장 초기 권한"(`pg_init_privs`)에도 기록됩니다. PostgreSQL 15/16은 롤을 지울 때 이 기록을 정리하지 못하므로(17은 정리함), 그런 롤을 `DROP ROLE` 하기 전에 다음을 실행해 기록에서 빼 둡니다. 그러지 않으면 이후 `pg_dump`가 존재하지 않는 롤 OID에 대한 `REVOKE`를 내보내 복원이 실패할 수 있습니다.
```sql
ALTER EXTENSION pg_stat_statements DROP VIEW pg_stat_statements;
REVOKE ALL ON pg_stat_statements FROM <롤>;
ALTER EXTENSION pg_stat_statements ADD VIEW pg_stat_statements;
```
