#!/bin/bash

# 환경 변수 로드
source ../aws_config.sh
source ../mysql_env.sh

echo "=== 마이그레이션 검증 시작 ==="

# 1. 데이터 정합성 검증
echo "1. 데이터 정합성 검증"
echo "테이블별 레코드 수 비교:"

for table in users user_profiles analysis_results; do
    echo "테이블: $table"
    IDC_COUNT=$(docker exec idc_mysql mysql -uroot -e "SELECT COUNT(*) FROM userdb.$table;" -s)
    # Docker 컨테이너 내에서 RDS 접속
    AWS_COUNT=$(docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT COUNT(*) FROM userdb.$table;" -s)
    echo "  IDC: $IDC_COUNT"
    echo "  AWS: $AWS_COUNT"

    if [ "$IDC_COUNT" -eq "$AWS_COUNT" ]; then
        echo "  상태: ✅ 일치"
    else
        echo "  상태: ❌ 불일치"
    fi
    echo ""
done

# 2. 데이터 샘플 검증
echo "2. 데이터 샘플 검증"
echo "IDC 샘플 데이터 (첫 5개):"
docker exec idc_mysql mysql -uroot -e "
SELECT u.id, u.email, u.first_name, u.last_name, ar.sperm_count
FROM userdb.users u
JOIN userdb.user_profiles up ON u.id = up.user_id
JOIN userdb.analysis_results ar ON u.id = ar.user_id
LIMIT 5;"

echo -e "\nAWS RDS 샘플 데이터 (첫 5개):"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT u.id, u.email, u.first_name, u.last_name, ar.sperm_count
FROM userdb.users u
JOIN userdb.user_profiles up ON u.id = up.user_id
JOIN userdb.analysis_results ar ON u.id = ar.user_id
LIMIT 5;"

# 3. 외래키 제약 조건 확인
echo -e "\n3. 외래키 제약 조건 확인"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA = 'userdb';"

# 4. 연결성 테스트
echo -e "\n4. 연결성 테스트"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT
    'Connection successful' as result,
    @@hostname as server,
    NOW() as timestamp,
    CONNECTION_ID() as connection_id;"

# 5. 추가 검증: 테이블 구조 확인
echo -e "\n5. 테이블 구조 확인"
echo "IDC 테이블 구조:"
docker exec idc_mysql mysql -uroot -e "
DESC userdb.users;
DESC userdb.user_profiles;
DESC userdb.analysis_results;" 2>/dev/null

echo -e "\nAWS RDS 테이블 구조:"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
DESC userdb.users;
DESC userdb.user_profiles;
DESC userdb.analysis_results;" 2>/dev/null

echo -e "\n=== 검증 완료 ==="
