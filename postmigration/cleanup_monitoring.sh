#!/bin/bash
source ../aws_config.sh

RDS_INSTANCE_ID=$(echo $RDS_ENDPOINT | cut -d. -f1)

echo "CloudWatch 알람 삭제 중..."
aws cloudwatch delete-alarms \
    --region $AWS_REGION \
    --alarm-names \
    "RDS-CPU-Utilization-$RDS_INSTANCE_ID" \
    "RDS-Connection-Count-$RDS_INSTANCE_ID" \
    "RDS-Disk-FreeSpace-$RDS_INSTANCE_ID"

echo "모니터링 정리 완료"
