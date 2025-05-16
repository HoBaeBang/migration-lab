# 2. 기존 AWS RDS 정보 설정
export RDS_ENDPOINT="AWS의 엔드포인트를 작성해주시면 됩니다 ~~~rds.amazonaws.com"
export RDS_USERNAME="rds의 username을 작성해주시면 됩니다."
export RDS_PASSWORD="rds의 password를 작성해주시면 됩니다."
export RDS_DATABASE="userdb"
export RDS_PORT="3306"

# AWS 리전 설정
export AWS_REGION="ap-northeast-2"

echo "AWS 환경 변수 설정 완료"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Database: $RDS_DATABASE"
echo "Region: $AWS_REGION"
