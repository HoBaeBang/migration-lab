# 마이그레이션 후 검증 단계 (Post Migration)

마이그레이션 완료 후 시스템 검증 및 정리 작업을 수행합니다.

## 주요 작업
1. 데이터 정합성 검증
2. 성능 테스트
3. 모니터링 설정
4. IDC 리소스 정리

## 실행 순서
```bash
# 1. 마이그레이션 검증
./postmigration/verify_migration.sh

# 2. 성능 테스트
./postmigration/performance_test.sh

# 3. 모니터링 설정 (선택사항)
./postmigration/setup_monitoring.sh

# 4. IDC 리소스 정리 (14일 후)
./postmigration/cleanup_idc.sh
