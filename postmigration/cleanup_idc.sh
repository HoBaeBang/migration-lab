#!/bin/bash

echo "=== IDC 리소스 정리 ==="

# 1. 경고 메시지
echo "⚠️  주의: 이 작업은 IDC 환경을 완전히 제거합니다 ⚠️"
echo "14일 이상 안정적으로 운영된 후에만 실행하세요!"
echo ""

# 2. 최종 데이터 동기화 확인
echo "1. 최종 데이터 동기화 확인"
source ../aws_config.sh
source ../mysql_env.sh

IDC_COUNT=$(docker exec idc_mysql mysql -uroot -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)
# Docker 컨테이너를 통해 RDS 연결
AWS_COUNT=$(docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)

echo "IDC 사용자 수: $IDC_COUNT"
echo "AWS 사용자 수: $AWS_COUNT"

# 빈 값 확인 및 기본값 설정
if [ -z "$IDC_COUNT" ]; then IDC_COUNT=0; fi
if [ -z "$AWS_COUNT" ]; then AWS_COUNT=0; fi

if [ "$IDC_COUNT" -eq "$AWS_COUNT" ] && [ "$AWS_COUNT" -gt 0 ]; then
    echo "✅ 데이터 동기화 확인 완료"
else
    echo "❌ 데이터 동기화 불일치 감지!"
    echo "IDC: $IDC_COUNT, AWS: $AWS_COUNT"

    # AWS 연결 테스트
    echo "AWS RDS 연결 테스트..."
    if docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ AWS RDS 연결 가능"
    else
        echo "❌ AWS RDS 연결 실패 - 네트워크 확인 필요"
    fi

    read -p "그래도 계속 진행하시겠습니까? (y/N): " force_continue
    if [[ ! $force_continue =~ ^[Yy]$ ]]; then
        echo "정리 작업이 취소되었습니다."
        exit 1
    fi
fi

# 3. 사용자 확인
read -p "정말로 IDC 환경을 정리하시겠습니까? (y/N): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    # 4. 최종 백업
    echo -e "\n2. 최종 백업 수행"
    cd ../prepare
    ./create_dump.sh
    cd ../postmigration

    # 5. IDC 컨테이너 중지
    echo -e "\n3. IDC 컨테이너 중지"
    cd ..
    docker-compose stop mysql nginx

    # 6. 볼륨 정리 여부 확인
    read -p "데이터 볼륨도 삭제하시겠습니까? (y/N): " delete_volume
    if [[ $delete_volume =~ ^[Yy]$ ]]; then
        echo "4. MySQL 볼륨 삭제"
        docker-compose down -v
        docker volume rm migration-lab_mysql_data 2>/dev/null || true
        echo "✅ 볼륨 삭제 완료"
    else
        echo "4. 컨테이너만 중지 (볼륨 유지)"
        docker-compose down
        echo "✅ 컨테이너 중지 완료 (볼륨 보존)"
    fi

    # 7. 정리 완료 보고서
    echo -e "\n=== IDC 리소스 정리 완료 ==="
    echo "- MySQL 컨테이너: 중지됨"
    echo "- Nginx 컨테이너: 중지됨"
    echo "- 백업 파일: ./backups/ 디렉토리에 보관됨"
    echo "- 로그 파일: ./logs/ 디렉토리에 보관됨"
    echo "- AWS RDS로 완전 전환 완료"
    echo ""
    echo "보관된 파일들:"
    echo "  📁 백업 파일: ./backups/"
    echo "  📁 로그 파일: ./logs/"
    echo "  📄 설정 파일: aws_config.sh"
    echo ""
    echo "🎉 마이그레이션 프로젝트 완료!"
    echo "📊 최종 결과: IDC → AWS RDS 이전 성공 ($IDC_COUNT명)"

    # 8. 최종 AWS RDS 연결 확인
    echo -e "\n5. 최종 AWS RDS 연결 확인"
    echo "AWS RDS 엔드포인트: $RDS_ENDPOINT"
    echo "데이터베이스: $RDS_DATABASE"
    echo "리전: $AWS_REGION"

else
    echo "정리 작업이 취소되었습니다."
    echo "AWS RDS는 계속 운영되며, IDC 환경은 유지됩니다."
    echo ""
    echo "현재 상태:"
    echo "- IDC MySQL: 운영 중 (백업용)"
    echo "- AWS RDS: 운영 중 (메인)"
    echo "- 웹 서비스: AWS RDS 사용 중"
fi

echo -e "\n=== 정리 완료 ==="
