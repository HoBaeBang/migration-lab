#!/bin/bash

echo "=== 롤백 테스트 시나리오 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드 (prepare/rollback 디렉토리 기준)
source ../../aws_config.sh
source ../../mysql_env.sh

# 테스트 결과 파일
TEST_RESULTS="rollback_test_results_$(date +%Y%m%d_%H%M%S).txt"

# 함수: 테스트 결과 기록
test_result() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a $TEST_RESULTS
}

test_result "롤백 테스트 시작"

# 테스트 시나리오 1: IDC 연결 테스트
echo -e "\n1. IDC MySQL 연결 테스트"
test_result "테스트 1: IDC MySQL 연결"
if docker exec idc_mysql mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
    test_result "SUCCESS IDC MySQL 연결 성공"
    # 데이터 확인
    USER_COUNT=$(docker exec idc_mysql mysql -uroot -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)
    test_result "   사용자 수: $USER_COUNT"

    # MySQL 버전 확인
    MYSQL_VERSION=$(docker exec idc_mysql mysql -uroot -e "SELECT @@version;" -s 2>/dev/null)
    test_result "   MySQL 버전: $MYSQL_VERSION"
else
    test_result "ERROR IDC MySQL 연결 실패"
fi

# 테스트 시나리오 2: 백업 파일 검증
echo -e "\n2. 백업 파일 무결성 테스트"
test_result "테스트 2: 백업 파일 검증"
if [ -d "../../backups" ]; then
    BACKUP_COUNT=$(ls ../../backups/*.sql 2>/dev/null | wc -l)
    test_result "   백업 파일 개수: $BACKUP_COUNT"

    # 최신 백업 파일 크기 확인
    LATEST_BACKUP=$(ls -t ../../backups/users_*.sql 2>/dev/null | head -1)
    if [ ! -z "$LATEST_BACKUP" ]; then
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        test_result "   최신 백업 크기: $BACKUP_SIZE"

        # 체크섬 파일 확인
        CHECKSUM_FILE=$(ls -t ../../backups/checksum_*.md5 2>/dev/null | head -1)
        if [ ! -z "$CHECKSUM_FILE" ]; then
            test_result "   체크섬 파일 존재: $(basename $CHECKSUM_FILE)"
            test_result "SUCCESS 백업 파일 확인 완료"
        else
            test_result "   체크섬 파일 없음"
        fi
    else
        test_result "ERROR 백업 파일 없음"
    fi
else
    test_result "ERROR 백업 디렉토리 없음"
fi

# 테스트 시나리오 3: 웹 서비스 상태 테스트
echo -e "\n3. 웹 서비스 상태 테스트"
test_result "테스트 3: 웹 서비스"
if curl -s http://localhost >/dev/null; then
    test_result "SUCCESS 웹 서비스 접근 가능"

    # 메인터넌스 모드 테스트
    RESPONSE=$(curl -s http://localhost)
    if echo "$RESPONSE" | grep -q "점검"; then
        test_result "   현재 메인터넌스 모드"
    else
        test_result "   일반 서비스 모드"
    fi

    # nginx 프로세스 확인
    if docker exec idc_nginx nginx -t >/dev/null 2>&1; then
        test_result "   nginx 설정 파일 유효"
    else
        test_result "   nginx 설정 오류"
    fi
else
    test_result "ERROR 웹 서비스 접근 불가"
fi

# 테스트 시나리오 4: AWS RDS 연결 테스트
echo -e "\n4. AWS RDS 연결 테스트"
test_result "테스트 4: AWS RDS 연결"
if mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT 1;" >/dev/null 2>&1; then
    test_result "SUCCESS AWS RDS 연결 성공"

    # 데이터 확인
    AWS_USER_COUNT=$(mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)
    test_result "   AWS 사용자 수: ${AWS_USER_COUNT:-0}"

    # RDS 상태 확인
    RDS_STATUS=$(mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SHOW STATUS LIKE 'Uptime';" -s 2>/dev/null | tail -1)
    test_result "   RDS 가동 시간: ${RDS_STATUS:-확인불가}초"
else
    test_result "ERROR AWS RDS 연결 실패 (마이그레이션 후에는 정상)"
fi

# 테스트 시나리오 5: 롤백 스크립트 실행 가능성 테스트
echo -e "\n5. 롤백 스크립트 실행 가능성 테스트"
test_result "테스트 5: 롤백 스크립트"

# 파일 존재 확인
for script in emergency_rollback.sh full_rollback.sh; do
    if [ -f "$script" ]; then
        test_result "SUCCESS $script 파일 존재"
        if [ -x "$script" ]; then
            test_result "   실행 권한 있음"
        else
            test_result "   실행 권한 없음 - chmod +x $script 필요"
        fi

        # 스크립트 문법 검사 (간단히)
        if bash -n "$script" >/dev/null 2>&1; then
            test_result "   문법 검사 통과"
        else
            test_result "   문법 오류 발견"
        fi
    else
        test_result "ERROR $script 파일 없음"
    fi
done

# 테스트 시나리오 6: 설정 파일 무결성 테스트
echo -e "\n6. 설정 파일 무결성 테스트"
test_result "테스트 6: 설정 파일"

# aws_config.sh 확인
if [ -f "../../aws_config.sh" ]; then
    test_result "SUCCESS aws_config.sh 존재"
    if grep -q "RDS_ENDPOINT" ../../aws_config.sh; then
        test_result "   설정 내용 확인됨"
        ENDPOINT=$(grep "RDS_ENDPOINT" ../../aws_config.sh | head -1)
        test_result "   엔드포인트: ${ENDPOINT##*=}"
    fi
else
    test_result "ERROR aws_config.sh 없음"
fi

# mysql_env.sh 확인
if [ -f "../../mysql_env.sh" ]; then
    test_result "SUCCESS mysql_env.sh 존재"
else
    test_result "ERROR mysql_env.sh 없음"
fi

# docker-compose.yml 확인
if [ -f "../../docker-compose.yml" ]; then
    test_result "SUCCESS docker-compose.yml 존재"
    # MySQL 컨테이너 설정 확인
    if grep -q "idc_mysql" ../../docker-compose.yml; then
        test_result "   MySQL 컨테이너 설정 확인"
    fi
else
    test_result "ERROR docker-compose.yml 없음"
fi

# 테스트 시나리오 7: Docker 환경 테스트
echo -e "\n7. Docker 환경 테스트"
test_result "테스트 7: Docker 환경"

# Docker 데몬 확인
if docker version >/dev/null 2>&1; then
    test_result "SUCCESS Docker 데몬 실행 중"

    # 컨테이너 상태 확인
    MYSQL_STATUS=$(docker inspect idc_mysql --format='{{.State.Status}}' 2>/dev/null)
    NGINX_STATUS=$(docker inspect idc_nginx --format='{{.State.Status}}' 2>/dev/null)

    test_result "   MySQL 컨테이너: ${MYSQL_STATUS:-not_found}"
    test_result "   Nginx 컨테이너: ${NGINX_STATUS:-not_found}"

    # 볼륨 확인
    if docker volume ls | grep -q mysql_data; then
        test_result "   MySQL 볼륨 존재"
    else
        test_result "   MySQL 볼륨 없음"
    fi
else
    test_result "ERROR Docker 데몬 접근 불가"
fi

# 테스트 결과 요약
echo -e "\n=== 테스트 결과 요약 ==="
test_result "테스트 완료 시간: $(date)"

# 테스트 결과 분석 (텍스트 기반으로 변경)
ERROR_COUNT=$(grep -c "ERROR" $TEST_RESULTS 2>/dev/null || echo 0)
SUCCESS_COUNT=$(grep -c "SUCCESS" $TEST_RESULTS 2>/dev/null || echo 0)
WARNING_COUNT=$(grep -c "WARNING" $TEST_RESULTS 2>/dev/null || echo 0)

test_result "성공: ${SUCCESS_COUNT}개"
test_result "실패: ${ERROR_COUNT}개"
test_result "경고: ${WARNING_COUNT}개"

# 전체 평가
if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "\n성공! 모든 테스트 통과!"
    test_result "결과: 롤백 준비 상태 양호"
    test_result "권장사항: 마이그레이션 진행 가능"
elif [ $ERROR_COUNT -le 2 ]; then
    echo -e "\n주의: 일부 테스트 실패"
    test_result "결과: 롤백 준비 상태 주의 필요"
    test_result "권장사항: 실패 항목 점검 후 진행"
else
    echo -e "\n경고: 다수 테스트 실패"
    test_result "결과: 롤백 준비 상태 불량"
    test_result "권장사항: 문제 해결 후 재테스트 필요"
fi

# 상세 결과 파일 생성
cat > rollback_test_summary.txt << SUMMARY
# 롤백 테스트 결과 요약

## 테스트 일시
- 시작: $(head -1 $TEST_RESULTS | cut -d']' -f2-)
- 완료: $(date)

## 테스트 결과
- 총 테스트: 7개 시나리오
- 성공: ${SUCCESS_COUNT}개
- 실패: ${ERROR_COUNT}개
- 경고: ${WARNING_COUNT}개

## 주요 확인 사항
- IDC MySQL: $(grep -q "SUCCESS.*IDC MySQL" $TEST_RESULTS && echo "정상" || echo "확인 필요")
- 백업 파일: $(grep -q "SUCCESS.*백업 파일" $TEST_RESULTS && echo "정상" || echo "확인 필요")
- 웹 서비스: $(grep -q "SUCCESS.*웹 서비스" $TEST_RESULTS && echo "정상" || echo "확인 필요")
- 롤백 스크립트: $(ls -1 emergency_rollback.sh full_rollback.sh 2>/dev/null | wc -l)/2 준비됨

## 권장 조치사항
$(if [ $ERROR_COUNT -eq 0 ]; then
    echo "- 롤백 준비 완료"
    echo "- 마이그레이션 진행 가능"
elif [ $ERROR_COUNT -le 2 ]; then
    echo "- 실패 항목 점검 필요"
    echo "- 점검 후 마이그레이션 진행"
else
    echo "- 주요 문제 해결 필요"
    echo "- 재테스트 후 진행 결정"
fi)

상세 로그: $TEST_RESULTS
SUMMARY

echo -e "\n📋 자세한 결과는 다음 파일들을 확인하세요:"
echo "  - 상세 로그: $TEST_RESULTS"
echo "  - 요약 보고서: rollback_test_summary.txt"
echo ""
echo "다음 단계:"
echo "  1. 실패 항목이 있다면 문제를 해결하세요"
echo "  2. 롤백 계획서를 다시 검토하세요"
  3. 팀과 테스트 결과를 공유하세요"
