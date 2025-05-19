#!/bin/bash

# 환경 변수 로드
source ../aws_config.sh
source ../mysql_env.sh

echo "=== 성능 테스트 시작 ==="

# 1. 간단한 쿼리 성능 테스트
echo "1. 간단한 쿼리 성능 테스트"

# IDC 성능 측정
echo "IDC MySQL 성능 측정 중..."
IDC_START=$(date +%s.%N)
docker exec idc_mysql mysql -uroot -e "
SELECT COUNT(*) FROM userdb.users WHERE created_at >= '2020-01-01';" > /dev/null
IDC_END=$(date +%s.%N)
IDC_SIMPLE_TIME=$(echo "$IDC_END - $IDC_START" | bc)

# AWS 성능 측정 (Docker를 통해 실행)
echo "AWS RDS 성능 측정 중..."
AWS_START=$(date +%s.%N)
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT COUNT(*) FROM userdb.users WHERE created_at >= '2020-01-01';" > /dev/null
AWS_END=$(date +%s.%N)
AWS_SIMPLE_TIME=$(echo "$AWS_END - $AWS_START" | bc)

echo "간단한 쿼리 결과:"
echo "  IDC 시간: ${IDC_SIMPLE_TIME} 초"
echo "  AWS 시간: ${AWS_SIMPLE_TIME} 초"

# 2. 복잡한 조인 쿼리 성능 테스트
echo -e "\n2. 복잡한 조인 쿼리 성능 테스트"

# IDC 복잡 쿼리 성능
echo "IDC 복잡 쿼리 성능 측정 중..."
IDC_START=$(date +%s.%N)
docker exec idc_mysql mysql -uroot -e "
SELECT
    up.gender,
    COUNT(*) as count,
    AVG(ar.sperm_count) as avg_count,
    AVG(ar.motility_percentage) as avg_motility
FROM userdb.users u
JOIN userdb.user_profiles up ON u.id = up.user_id
JOIN userdb.analysis_results ar ON u.id = ar.user_id
GROUP BY up.gender;" > /dev/null
IDC_END=$(date +%s.%N)
IDC_COMPLEX_TIME=$(echo "$IDC_END - $IDC_START" | bc)

# AWS 복잡 쿼리 성능 (Docker를 통해 실행)
echo "AWS 복잡 쿼리 성능 측정 중..."
AWS_START=$(date +%s.%N)
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT
    up.gender,
    COUNT(*) as count,
    AVG(ar.sperm_count) as avg_count,
    AVG(ar.motility_percentage) as avg_motility
FROM userdb.users u
JOIN userdb.user_profiles up ON u.id = up.user_id
JOIN userdb.analysis_results ar ON u.id = ar.user_id
GROUP BY up.gender;" > /dev/null
AWS_END=$(date +%s.%N)
AWS_COMPLEX_TIME=$(echo "$AWS_END - $AWS_START" | bc)

echo "복잡한 쿼리 결과:"
echo "  IDC 시간: ${IDC_COMPLEX_TIME} 초"
echo "  AWS 시간: ${AWS_COMPLEX_TIME} 초"

# 3. 성능 개선률 계산
if (( $(echo "$IDC_SIMPLE_TIME > 0" | bc -l) )); then
    SIMPLE_IMPROVEMENT=$(echo "scale=2; ($IDC_SIMPLE_TIME - $AWS_SIMPLE_TIME) / $IDC_SIMPLE_TIME * 100" | bc)
    echo -e "\n간단한 쿼리 성능 변화: ${SIMPLE_IMPROVEMENT}%"

    if (( $(echo "$SIMPLE_IMPROVEMENT > 0" | bc -l) )); then
        echo "  → AWS RDS가 ${SIMPLE_IMPROVEMENT}% 더 빠름"
    else
        SIMPLE_IMPROVEMENT_ABS=$(echo "scale=2; $SIMPLE_IMPROVEMENT * -1" | bc)
        echo "  → IDC가 ${SIMPLE_IMPROVEMENT_ABS}% 더 빠름"
    fi
fi

if (( $(echo "$IDC_COMPLEX_TIME > 0" | bc -l) )); then
    COMPLEX_IMPROVEMENT=$(echo "scale=2; ($IDC_COMPLEX_TIME - $AWS_COMPLEX_TIME) / $IDC_COMPLEX_TIME * 100" | bc)
    echo "복잡한 쿼리 성능 변화: ${COMPLEX_IMPROVEMENT}%"

    if (( $(echo "$COMPLEX_IMPROVEMENT > 0" | bc -l) )); then
        echo "  → AWS RDS가 ${COMPLEX_IMPROVEMENT}% 더 빠름"
    else
        COMPLEX_IMPROVEMENT_ABS=$(echo "scale=2; $COMPLEX_IMPROVEMENT * -1" | bc)
        echo "  → IDC가 ${COMPLEX_IMPROVEMENT_ABS}% 더 빠름"
    fi
fi

# 4. 현재 연결 수 및 상태 확인
echo -e "\n4. AWS RDS 연결 수 및 상태"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';
SHOW VARIABLES LIKE 'max_connections';"

# 5. 추가 성능 지표
echo -e "\n5. 추가 성능 지표"

# 인덱스 스캔 vs 풀 테이블 스캔 테스트
echo "인덱스 스캔 테스트 (WHERE email = ...):"

# IDC 인덱스 스캔
IDC_START=$(date +%s.%N)
docker exec idc_mysql mysql -uroot -e "
SELECT COUNT(*) FROM userdb.users WHERE email LIKE 'user1%';" > /dev/null
IDC_END=$(date +%s.%N)
IDC_INDEX_TIME=$(echo "$IDC_END - $IDC_START" | bc)

# AWS RDS 인덱스 스캔
AWS_START=$(date +%s.%N)
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
SELECT COUNT(*) FROM userdb.users WHERE email LIKE 'user1%';" > /dev/null
AWS_END=$(date +%s.%N)
AWS_INDEX_TIME=$(echo "$AWS_END - $AWS_START" | bc)

echo "  IDC 인덱스 스캔: ${IDC_INDEX_TIME} 초"
echo "  AWS 인덱스 스캔: ${AWS_INDEX_TIME} 초"

# 6. 쿼리 실행 계획 비교 (옵션)
echo -e "\n6. 쿼리 실행 계획 비교"
echo "IDC 실행 계획:"
docker exec idc_mysql mysql -uroot -e "
EXPLAIN SELECT COUNT(*) FROM userdb.users WHERE created_at >= '2020-01-01';" 2>/dev/null

echo -e "\nAWS RDS 실행 계획:"
docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "
EXPLAIN SELECT COUNT(*) FROM userdb.users WHERE created_at >= '2020-01-01';" 2>/dev/null

echo -e "\n=== 성능 테스트 완료 ==="
