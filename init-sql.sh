# 2. Docker MySQL 컨테이너에 SQL 파일 실행
echo "예시 데이터 생성 중... (몇 분 소요됩니다)"
docker exec -i idc_mysql mysql -uroot -pidcpassword < init-data.sql

# 3. 결과 확인
echo -e "\n=== 데이터베이스 생성 결과 확인 ==="
docker exec idc_mysql mysql -uroot -pidcpassword -e "USE userdb; SHOW TABLES;"

# 4. 레코드 수 확인
echo -e "\n=== 테이블별 레코드 수 확인 ==="
docker exec idc_mysql mysql -uroot -pidcpassword -e "USE userdb;
                                                     SELECT 'Users' as table_name, COUNT(*) as count FROM users
                                                     UNION ALL
                                                     SELECT 'User Profiles' as table_name, COUNT(*) as count FROM user_profiles
                                                     UNION ALL
                                                     SELECT 'Analysis Results' as table_name, COUNT(*) as count FROM analysis_results;"
