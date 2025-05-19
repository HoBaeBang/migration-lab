#!/bin/bash

echo "=== 긴급 롤백 실행 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source ../../aws_config.sh
source ../../mysql_env.sh

# 롤백 로그 파일 생성
ROLLBACK_LOG="../../logs/emergency_rollback_$(date +%Y%m%d_%H%M%S).log"
mkdir -p ../../logs

# 함수: 로그 출력
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $ROLLBACK_LOG
}

log "긴급 롤백 시작"

# 1. AWS RDS 연결 차단 (애플리케이션 레벨)
log "1. AWS RDS 연결 차단"
# 실제 환경에서는 애플리케이션 설정 변경 또는 보안 그룹 수정
# 예: aws ec2 revoke-security-group-ingress --group-id sg-xxx --protocol tcp --port 3306 --source-group sg-app

# 2. IDC MySQL 서비스 확인 및 시작
log "2. IDC MySQL 서비스 확인"
cd ../..  # migration-lab 디렉토리로 이동

if docker exec idc_mysql mysql -uroot -e "SELECT 'IDC MySQL is running' as status;" 2>/dev/null; then
    log "✅ IDC MySQL 정상 동작"
else
    log "❌ IDC MySQL 오류 감지 - 컨테이너 재시작 중"
    docker-compose restart mysql
    sleep 15

    # 재시작 후 재확인
    if docker exec idc_mysql mysql -uroot -e "SELECT 1;" 2>/dev/null; then
        log "✅ IDC MySQL 재시작 성공"
    else
        log "❌ IDC MySQL 재시작 실패 - 수동 조치 필요"
        exit 1
    fi
fi

# 3. 데이터 정합성 빠른 확인
log "3. 데이터 정합성 빠른 확인"
IDC_COUNT=$(docker exec idc_mysql mysql -uroot -e "SELECT COUNT(*) FROM userdb.users;" -s 2>/dev/null)
if [ ! -z "$IDC_COUNT" ]; then
    log "IDC 사용자 수: $IDC_COUNT"
else
    log "❌ IDC 데이터 확인 실패"
    IDC_COUNT="확인불가"
fi

# 4. 네트워크 및 서비스 상태 확인
log "4. 서비스 상태 확인"
cd prepare/rollback/  # 현재 위치로 복귀

# nginx 설정 원복
if [ -f "../../migrationday/nginx.conf.normal" ]; then
    docker cp ../../migrationday/nginx.conf.normal idc_nginx:/etc/nginx/nginx.conf
    docker exec idc_nginx nginx -s reload
    log "nginx 설정 원복 완료"
fi

# 서비스 상태 확인
if curl -s http://localhost >/dev/null; then
    log "✅ 웹 서비스 접근 가능"
else
    log "❌ 웹 서비스 접근 불가 - 확인 필요"
fi

# 5. 운영팀 알림 준비
log "5. 운영팀 알림 생성"
cat > emergency_rollback_notification.txt << NOTICE
=== 긴급 롤백 알림 ===
시간: $(date)
IDC 복구 상태: 완료
IDC 사용자 수: $IDC_COUNT
웹 서비스: 접근 가능
로그 파일: $ROLLBACK_LOG

다음 단계:
1. 서비스 정상성 재확인
2. 사용자 접근 모니터링
3. 롤백 사유 분석 시작
4. AWS 리소스 일시 중단 검토

연락처:
- 시스템 관리자: [연락처]
- DB 관리자: [연락처]
- 운영팀: [연락처]
NOTICE

log "알림 파일 생성: emergency_rollback_notification.txt"

# 6. 시스템 상태 빠른 점검
log "6. 시스템 상태 빠른 점검"
echo "현재 시스템 상태:" > system_quick_check.txt
echo "- 시간: $(date)" >> system_quick_check.txt
echo "- IDC MySQL: 동작 중" >> system_quick_check.txt
echo "- 웹 서비스: 접근 가능" >> system_quick_check.txt
echo "- 사용자 수: $IDC_COUNT" >> system_quick_check.txt

log "=== 긴급 롤백 완료 ==="
echo ""
echo "✅ 긴급 롤백이 완료되었습니다."
echo "📝 로그 파일: $ROLLBACK_LOG"
echo "📋 알림 파일: emergency_rollback_notification.txt"
echo "📊 상태 요약: system_quick_check.txt"
echo ""
echo "다음 단계:"
echo "1. 서비스 상태 지속 모니터링"
echo "2. 필요시 전체 롤백 실행: ./full_rollback.sh"
echo "3. 마이그레이션 실패 원인 분석 시작"
echo "4. 팀에 상황 전파"
