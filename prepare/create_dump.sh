#!/bin/bash

# MySQL 환경 설정 로드
source ../mysql_env.sh

DUMP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="../backups"
mkdir -p $BACKUP_DIR

echo "=== MySQL 데이터 덤프 생성 ==="
echo "시작 시간: $(date)"

# 1. 스키마 덤프 (DDL만)
echo -e "\n1. 스키마 덤프 생성 중..."
docker exec idc_mysql mysqldump -uroot \
    --no-data --routines --triggers \
    userdb > $BACKUP_DIR/schema_$DUMP_DATE.sql

# 2. 데이터 덤프 (테이블별)
echo -e "\n2. 사용자 데이터 덤프 중..."
docker exec idc_mysql mysqldump -uroot \
    --single-transaction --no-create-info \
    userdb users > $BACKUP_DIR/users_$DUMP_DATE.sql

echo -e "\n3. 사용자 프로필 데이터 덤프 중..."
docker exec idc_mysql mysqldump -uroot \
    --single-transaction --no-create-info \
    userdb user_profiles > $BACKUP_DIR/user_profiles_$DUMP_DATE.sql

echo -e "\n4. 분석 결과 데이터 덤프 중..."
docker exec idc_mysql mysqldump -uroot \
    --single-transaction --no-create-info \
    userdb analysis_results > $BACKUP_DIR/analysis_results_$DUMP_DATE.sql

# 3. 덤프 파일 검증
echo -e "\n5. 덤프 파일 검증 중..."
for file in $BACKUP_DIR/*_$DUMP_DATE.sql; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "✅ $(basename $file): $size"
    fi
done

# 4. 체크섬 생성
echo -e "\n6. 체크섬 생성 중..."
cd $BACKUP_DIR
md5sum *_$DUMP_DATE.sql > checksum_$DUMP_DATE.md5

echo -e "\n=== 덤프 완료 ==="
echo "덤프 파일 위치: $BACKUP_DIR"
echo "완료 시간: $(date)"
