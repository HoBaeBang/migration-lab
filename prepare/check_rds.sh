#!/bin/bash

# AWS 환경 변수 로드
source ../aws_config.sh
source ../mysql_env.sh

echo "=== AWS RDS 연결 및 상태 확인 ==="

# 1. RDS 연결 테스트 (경고 메시지 제거)
echo "1. RDS MySQL 연결 테스트"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -s -e "SELECT VERSION() as version, NOW() as datetime, USER() as user_info;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ RDS 연결 성공"
else
    echo "❌ RDS 연결 실패. 설정을 확인해주세요."
    echo "문제 해결 방법:"
    echo "1. 보안 그룹에서 3306 포트 허용 확인"
    echo "2. RDS 인스턴스가 public access 가능한지 확인"
    echo "3. VPC 설정 확인"
    echo "4. 연결 정보 재확인"
    exit 1
fi

# 2. 기존 데이터베이스 확인
echo -e "\n2. 기존 데이터베이스 목록"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -s -e "SHOW DATABASES;" 2>/dev/null

# 3. userdb 데이터베이스 생성 및 확인 (출력 개선)
echo -e "\n3. userdb 데이터베이스 준비"
# 데이터베이스 생성 결과 확인
RESULT=$(docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -e "CREATE DATABASE IF NOT EXISTS $RDS_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; SELECT 'Database created/exists' as status;" 2>/dev/null)
echo "$RESULT"

# 테이블 목록 확인
echo "현재 userdb의 테이블 목록:"
TABLES=$(docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -s -e "USE $RDS_DATABASE; SHOW TABLES;" 2>/dev/null)

if [ -z "$TABLES" ]; then
    echo "  (테이블 없음 - 정상 상태)"
else
    echo "$TABLES"
fi

# 4. RDS 인스턴스 설정 정보
echo -e "\n4. RDS 인스턴스 설정 정보"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -s -e "SELECT @@version_comment as comment, @@max_connections as max_conn, @@character_set_server as charset;" 2>/dev/null

# 5. 인증 플러그인 확인
echo -e "\n5. 인증 플러그인 호환성 확인"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD \
    -s -e "SELECT plugin from mysql.user where user='$RDS_USERNAME';" 2>/dev/null

# 6. AWS CLI를 통한 RDS 정보 (선택사항)
echo -e "\n6. AWS CLI RDS 인스턴스 정보"
if command -v aws &> /dev/null; then
    AWS_PAGER="" aws rds describe-db-instances \
        --region $AWS_REGION \
        --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion,AllocatedStorage]' \
        --output table 2>/dev/null
else
    echo "AWS CLI가 설치되지 않았습니다. 아래 설치 방법을 참고하세요:"
    echo "macOS: brew install awscli"
    echo "또는: pip3 install awscli"
fi

echo -e "\n=== RDS 확인 완료 ==="
