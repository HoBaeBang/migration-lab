#!/bin/bash

# MySQL 환경 설정 로드
source ../mysql_env.sh

echo "=== IDC MySQL 데이터베이스 현황 분석 ==="

echo "1. 데이터베이스 크기 확인"
docker exec idc_mysql mysql -uroot -e "
SELECT
    table_schema,
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'userdb'
ORDER BY (data_length + index_length) DESC;"

echo -e "\n2. 테이블 레코드 수 확인"
docker exec idc_mysql mysql -uroot -e "
SELECT
    'users' AS table_name, COUNT(*) AS row_count
FROM userdb.users
UNION ALL
SELECT
    'user_profiles' AS table_name, COUNT(*) AS row_count
FROM userdb.user_profiles
UNION ALL
SELECT
    'analysis_results' AS table_name, COUNT(*) AS row_count
FROM userdb.analysis_results;"

echo -e "\n3. 인덱스 현황 확인"
docker exec idc_mysql mysql -uroot -e "
SELECT
    table_schema,
    table_name,
    index_name,
    column_name
FROM information_schema.statistics
WHERE table_schema = 'userdb'
ORDER BY table_name, index_name;"

echo -e "\n4. 스토리지 엔진 및 설정 확인"
docker exec idc_mysql mysql -uroot -e "
SELECT
    table_name,
    engine,
    table_collation,
    create_options
FROM information_schema.tables
WHERE table_schema = 'userdb';"

echo -e "\n5. MySQL 설정 정보"
docker exec idc_mysql mysql -uroot -e "
SELECT @@version as mysql_version,
       @@max_connections as max_connections,
       @@innodb_buffer_pool_size as buffer_pool_size;"

echo -e "\n=== 분석 완료 ==="
