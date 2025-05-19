#!/bin/bash

# 환경 변수 로드
source ../aws_config.sh

echo "=== CloudWatch 모니터링 설정 (실습용) ==="
echo "⚠️  알림: CloudWatch 알람은 월 10개까지 무료입니다."
echo "현재 설정하는 알람 수: 3개 (무료 범위 내)"
echo ""

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되지 않았습니다."
    echo "설치 방법:"
    echo "  macOS: brew install awscli"
    echo "  또는: pip3 install awscli"
    echo ""
    echo "AWS CLI 없이도 AWS 콘솔에서 수동으로 설정 가능합니다."
    echo "콘솔 접속: https://console.aws.amazon.com/cloudwatch/"
    exit 1
fi

# AWS 자격 증명 확인
echo "AWS 자격 증명 확인 중..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS 자격 증명이 설정되지 않았습니다."
    echo "설정 방법: aws configure"
    exit 1
fi

# RDS 인스턴스 식별자 추출
RDS_INSTANCE_ID=$(echo $RDS_ENDPOINT | cut -d. -f1)
echo "✅ RDS 인스턴스 ID: $RDS_INSTANCE_ID"

# 사용자 확인
echo ""
read -p "CloudWatch 알람을 설정하시겠습니까? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "모니터링 설정을 취소했습니다."
    echo ""
    echo "수동 설정 방법:"
    echo "1. AWS 콘솔 → CloudWatch → 알람"
    echo "2. 알람 생성 → RDS 메트릭 선택"
    echo "3. 임계값 설정 (CPU: 80%, 연결수: 50개)"
    exit 0
fi

# 1. RDS CPU 사용률 모니터링
echo -e "\n1. CPU 사용률 알람 설정 (임계값: 80%)"
aws cloudwatch put-metric-alarm \
    --region $AWS_REGION \
    --alarm-name "RDS-CPU-Utilization-$RDS_INSTANCE_ID" \
    --alarm-description "RDS CPU 사용률 모니터링 (실습용)" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=$RDS_INSTANCE_ID \
    --evaluation-periods 2

if [ $? -eq 0 ]; then
    echo "✅ CPU 사용률 알람 설정 완료"
else
    echo "❌ CPU 사용률 알람 설정 실패"
fi

# 2. RDS 연결 수 모니터링
echo -e "\n2. 연결 수 알람 설정 (임계값: 50개)"
aws cloudwatch put-metric-alarm \
    --region $AWS_REGION \
    --alarm-name "RDS-Connection-Count-$RDS_INSTANCE_ID" \
    --alarm-description "RDS 연결 수 모니터링 (실습용)" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 50 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=$RDS_INSTANCE_ID \
    --evaluation-periods 2

if [ $? -eq 0 ]; then
    echo "✅ 연결 수 알람 설정 완료"
else
    echo "❌ 연결 수 알람 설정 실패"
fi

# 3. RDS 디스크 여유 공간 모니터링
echo -e "\n3. 디스크 여유 공간 알람 설정 (임계값: 2GB)"
aws cloudwatch put-metric-alarm \
    --region $AWS_REGION \
    --alarm-name "RDS-Disk-FreeSpace-$RDS_INSTANCE_ID" \
    --alarm-description "RDS 디스크 여유 공간 모니터링 (실습용)" \
    --metric-name FreeStorageSpace \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 2000000000 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=$RDS_INSTANCE_ID \
    --evaluation-periods 2

if [ $? -eq 0 ]; then
    echo "✅ 디스크 여유 공간 알람 설정 완료"
else
    echo "❌ 디스크 여유 공간 알람 설정 실패"
fi

# 4. 설정된 알람 확인
echo -e "\n4. 설정된 알람 확인"
aws cloudwatch describe-alarms \
    --region $AWS_REGION \
    --alarm-names "RDS-CPU-Utilization-$RDS_INSTANCE_ID" "RDS-Connection-Count-$RDS_INSTANCE_ID" "RDS-Disk-FreeSpace-$RDS_INSTANCE_ID" \
    --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
    --output table

# 5. 비용 및 정리 안내
echo -e "\n=== 모니터링 설정 완료 ==="
echo "📊 설정된 알람: 3개 (무료 범위 내)"
echo "💰 예상 비용: $0 (무료)"
echo ""
echo "CloudWatch 콘솔에서 확인:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#alarmsV2:"
echo ""
echo "실습 완료 후 정리 방법:"
echo "./postmigration/cleanup_monitoring.sh"
echo ""
echo "또는 수동 삭제:"
echo "AWS 콘솔 → CloudWatch → 알람 → 알람 선택 → 삭제"
