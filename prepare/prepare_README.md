# 준비 단계 (Prepare Phase)

이 단계에서는 마이그레이션을 위한 준비 작업을 수행합니다.

## 수행 작업
1. IDC 데이터베이스 분석
2. 기존 RDS 상태 확인
3. 데이터 덤프 생성
4. 롤백 계획 검증

## 실행 순서
```bash
# 1. IDC 데이터베이스 분석
./prepare/analyze_db.sh

# 2. RDS 연결 확인
./prepare/check_rds.sh

# 3. 데이터 덤프 생성
./prepare/create_dump.sh

# 4. 롤백 계획 검증
./prepare/rollback_plan.sh
```

## 롤백 관련 파일

롤백 관련 모든 파일은 `./prepare/rollback/` 디렉토리에 미리 준비되어 있습니다

- `rollback_plan.md`: 마이그레이션 롤백 계획서
- `emergency_rollback.sh`: 긴급 롤백 스크립트
- `full_rollback.sh`: 전체 롤백 스크립트
- `rollback_test.sh`: 롤백 테스트 스크립트
- `rollback_checklist.txt`: 롤백 체크리스트

마이그레이션 전에 롤백 계획서를 팀과 함께 검토하고, 롤백 테스트를 실행해보세요.
