#!/bin/bash

# 환경 변수 로드
source ../aws_config.sh
source ../mysql_env.sh

MIGRATION_START=$(date)
LOG_FILE="../logs/migration_log_$(date +%Y%m%d_%H%M%S).log"
mkdir -p ../logs

echo "=== MySQL 마이그레이션 실행 시작 ===" | tee -a $LOG_FILE
echo "시작 시간: $MIGRATION_START" | tee -a $LOG_FILE

# 1. 최신 덤프 파일 확인
BACKUP_DIR="../backups"
echo "1. 덤프 파일 확인" | tee -a $LOG_FILE
LATEST_SCHEMA=$(ls -t $BACKUP_DIR/schema_*.sql 2>/dev/null | head -1)
LATEST_USERS=$(ls -t $BACKUP_DIR/users_*.sql 2>/dev/null | head -1)
LATEST_PROFILES=$(ls -t $BACKUP_DIR/user_profiles_*.sql 2>/dev/null | head -1)
LATEST_RESULTS=$(ls -t $BACKUP_DIR/analysis_results_*.sql 2>/dev/null | head -1)

# 백업 파일 존재 확인
if [ -z "$LATEST_SCHEMA" ] || [ -z "$LATEST_USERS" ]; then
    echo "❌ 백업 파일을 찾을 수 없습니다. prepare/create_dump.sh를 먼저 실행하세요." | tee -a $LOG_FILE
    exit 1
fi

echo "스키마 파일: $LATEST_SCHEMA" | tee -a $LOG_FILE
echo "사용자 파일: $LATEST_USERS" | tee -a $LOG_FILE

# 2. RDS 데이터베이스 준비
echo -e "\n2. RDS 데이터베이스 준비" | tee -a $LOG_FILE

# Docker 컨테이너를 통해 RDS 접속 (호환성 문제 해결)
# 기존 데이터 백업 (필요한 경우)
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
CREATE DATABASE IF NOT EXISTS userdb_backup_$(date +%Y%m%d);" 2>/dev/null

# userdb 초기화
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
CREATE DATABASE IF NOT EXISTS $RDS_DATABASE;
USE $RDS_DATABASE;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS analysis_results;
DROP TABLE IF EXISTS user_profiles;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;"

# 3. 스키마 생성
echo -e "\n3. 스키마 생성" | tee -a $LOG_FILE
# 백업 파일을 컨테이너로 복사
docker cp $LATEST_SCHEMA idc_mysql:/tmp/schema.sql

# 컨테이너 내에서 mysql 명령을 실행하고 파일을 읽기
docker exec idc_mysql bash -c "mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD $RDS_DATABASE < /tmp/schema.sql"

if [ $? -eq 0 ]; then
    echo "✅ 스키마 생성 성공" | tee -a $LOG_FILE
else
    echo "❌ 스키마 생성 실패" | tee -a $LOG_FILE
    exit 1
fi

# 4. 데이터 로드
echo -e "\n4. 데이터 로드" | tee -a $LOG_FILE

# 사용자 데이터
echo "4-1. 사용자 데이터 로딩..." | tee -a $LOG_FILE
docker cp $LATEST_USERS idc_mysql:/tmp/users.sql
docker exec idc_mysql bash -c "mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD $RDS_DATABASE < /tmp/users.sql"

if [ $? -eq 0 ]; then
    echo "✅ 사용자 데이터 로드 성공" | tee -a $LOG_FILE
else
    echo "❌ 사용자 데이터 로드 실패" | tee -a $LOG_FILE
    exit 1
fi

# 사용자 프로필 데이터
echo "4-2. 사용자 프로필 데이터 로딩..." | tee -a $LOG_FILE
docker cp $LATEST_PROFILES idc_mysql:/tmp/profiles.sql
docker exec idc_mysql bash -c "mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD $RDS_DATABASE < /tmp/profiles.sql"

# 분석 결과 데이터
echo "4-3. 분석 결과 데이터 로딩..." | tee -a $LOG_FILE
docker cp $LATEST_RESULTS idc_mysql:/tmp/results.sql
docker exec idc_mysql bash -c "mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD $RDS_DATABASE < /tmp/results.sql"

# 5. 데이터 검증
echo -e "\n5. 데이터 검증" | tee -a $LOG_FILE
IDC_COUNT=$(docker exec idc_mysql mysql -uroot -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)
AWS_COUNT=$(docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT COUNT(*) FROM userdb.users;" -s)

echo "IDC 사용자 수: $IDC_COUNT" | tee -a $LOG_FILE
echo "AWS 사용자 수: $AWS_COUNT" | tee -a $LOG_FILE

if [ "$IDC_COUNT" -eq "$AWS_COUNT" ] && [ "$AWS_COUNT" -gt 0 ]; then
    echo "✅ 데이터 검증 성공!" | tee -a $LOG_FILE
else
    echo "❌ 데이터 검증 실패!" | tee -a $LOG_FILE
    echo "롤백을 진행하세요: cd ../prepare/rollback && ./emergency_rollback.sh" | tee -a $LOG_FILE
    exit 1
fi

# 6. 성능 최적화
echo -e "\n6. 성능 최적화 적용" | tee -a $LOG_FILE
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD $RDS_DATABASE -e "
ANALYZE TABLE users, user_profiles, analysis_results;
OPTIMIZE TABLE users, user_profiles, analysis_results;"

# 7. 서비스 전환 준비
echo -e "\n7. 서비스 전환 준비" | tee -a $LOG_FILE
# 애플리케이션 설정을 AWS RDS로 변경하는 단계
# (실제 환경에서는 애플리케이션 설정 파일 수정)
echo "RDS 엔드포인트로 전환: $RDS_ENDPOINT" | tee -a $LOG_FILE

# 8. 메인터넌스 모드 해제
echo -e "\n8. 메인터넌스 모드 해제" | tee -a $LOG_FILE

# 정상 서비스 설정으로 복구
if [ -f "nginx.conf.normal" ]; then
    echo "정상 서비스 설정 적용 중..." | tee -a $LOG_FILE
    docker cp nginx.conf.normal idc_nginx:/etc/nginx/nginx.conf

    # nginx 설정 테스트
    if docker exec idc_nginx nginx -t >/dev/null 2>&1; then
        docker exec idc_nginx nginx -s reload
        echo "✅ 정상 서비스 모드로 전환 완료" | tee -a $LOG_FILE
    else
        echo "❌ nginx 설정 오류 - 메인터넌스 모드 유지" | tee -a $LOG_FILE
    fi
else
    echo "❌ nginx.conf.normal 파일을 찾을 수 없습니다" | tee -a $LOG_FILE
    echo "수동으로 메인터넌스 모드를 해제하세요" | tee -a $LOG_FILE
fi

# 임시 파일 정리
echo -e "\n9. 임시 파일 정리" | tee -a $LOG_FILE
docker exec idc_mysql rm -f /tmp/schema.sql /tmp/users.sql /tmp/profiles.sql /tmp/results.sql

MIGRATION_END=$(date)
echo -e "\n=== 마이그레이션 완료 ===" | tee -a $LOG_FILE
echo "완료 시간: $MIGRATION_END" | tee -a $LOG_FILE
echo "새로운 RDS 엔드포인트: $RDS_ENDPOINT" | tee -a $LOG_FILE
echo "로그 파일: $LOG_FILE" | tee -a $LOG_FILE

# 10. 다음 단계 안내
echo -e "\n다음 단계:" | tee -a $LOG_FILE
echo "1. ./postmigration/verify_migration.sh 실행" | tee -a $LOG_FILE
echo "2. ./postmigration/performance_test.sh 실행" | tee -a $LOG_FILE
echo "3. 14일 후 ./postmigration/cleanup_idc.sh 실행" | tee -a $LOG_FILE

# 11. 서비스 상태 확인
echo -e "\n11. 서비스 상태 확인" | tee -a $LOG_FILE
echo "웹 서비스 확인: http://localhost" | tee -a $LOG_FILE

# curl로 간단한 확인
if curl -s http://localhost >/dev/null; then
    echo "✅ 웹 서비스 정상 접근 가능" | tee -a $LOG_FILE
else
    echo "❌ 웹 서비스 접근 불가 - 확인 필요" | tee -a $LOG_FILE
fi
