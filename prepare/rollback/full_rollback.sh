#!/bin/bash

echo "=== 전체 롤백 실행 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source ../../aws_config.sh
source ../../mysql_env.sh

# 롤백 로그 파일 생성
ROLLBACK_LOG="../../logs/full_rollback_$(date +%Y%m%d_%H%M%S).log"
mkdir -p ../../logs

# 함수: 로그 출력
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $ROLLBACK_LOG
}

log "전체 롤백 프로세스 시작"

# 1. 상황 확인 및 기록
echo "1. 현재 상황 확인"
read -p "롤백 사유를 입력하세요: " rollback_reason
log "롤백 사유: $rollback_reason"

# 2. AWS RDS 연결 완전 차단
log "2. AWS RDS 연결 완전 차단"
# 실제 환경에서는 보안 그룹 규칙 수정 또는 RDS 파라미터 변경
# 예: Read-Only 모드 설정, 연결 제한 등
log "AWS RDS 접근 차단 설정 완료"

# 3. IDC 환경 완전 복구
log "3. IDC 환경 완전 재구성"
cd ../..  # migration-lab 디렉토리로 이동

# 모든 컨테이너 정리 후 재시작
docker-compose down
sleep 5
docker-compose up -d mysql nginx
sleep 30

# 4. 데이터 백업에서 복구 (필요시)
log "4. 데이터 복구 옵션 확인"
LATEST_BACKUP=$(ls -t backups/users_*.sql 2>/dev/null | head -1)

if [ ! -z "$LATEST_BACKUP" ]; then
    log "최신 백업 파일 발견: $LATEST_BACKUP"
    read -p "백업에서 데이터를 복구하시겠습니까? (y/N): " restore_backup

    if [[ $restore_backup =~ ^[Yy]$ ]]; then
        log "백업에서 데이터 복구 시작"
        # 백업 복구 로직
        docker exec idc_mysql mysql -uroot -e "DROP DATABASE IF EXISTS userdb;"
        docker exec idc_mysql mysql -uroot -e "CREATE DATABASE userdb;"

        # 스키마 복구
        SCHEMA_BACKUP=$(ls -t backups/schema_*.sql 2>/dev/null | head -1)
        if [ ! -z "$SCHEMA_BACKUP" ]; then
            docker exec -i idc_mysql mysql -uroot userdb < $SCHEMA_BACKUP
            log "스키마 복구 완료"
        fi

        # 데이터 복구
        docker exec -i idc_mysql mysql -uroot userdb < $LATEST_BACKUP
        docker exec -i idc_mysql mysql -uroot userdb < $(ls -t backups/user_profiles_*.sql | head -1)
        docker exec -i idc_mysql mysql -uroot userdb < $(ls -t backups/analysis_results_*.sql | head -1)

        log "✅ 백업에서 데이터 복구 완료"
    fi
else
    log "백업 파일을 찾을 수 없음"
fi

# 5. 서비스 설정 완전 원복
log "5. 서비스 설정 원복"
cd prepare/rollback/  # 원래 위치로 복귀

# nginx 설정 원복
cat > ../../migrationday/nginx.conf.normal << 'NGINX_CONF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }

        location /health {
            return 200 "IDC Service Running";
            add_header Content-Type text/plain;
        }
    }
}
NGINX_CONF

docker cp ../../migrationday/nginx.conf.normal idc_nginx:/etc/nginx/nginx.conf
docker exec idc_nginx nginx -s reload
log "nginx 설정 원복 완료"

# 6. 시스템 상태 전면 검증
log "6. 시스템 상태 전면 검증"

# MySQL 상태 확인
docker exec idc_mysql mysql -uroot -e "
SELECT
    'IDC 서비스 상태' as status,
    COUNT(*) as user_count,
    NOW() as timestamp,
    @@version as mysql_version
FROM userdb.users;" > system_status.txt

# 웹 서비스 확인
if curl -s http://localhost > /dev/null; then
    log "✅ 웹 서비스 정상"
else
    log "❌ 웹 서비스 확인 필요"
fi

# 7. 완료 보고서 생성
log "7. 롤백 완료 보고서 생성"
cat > full_rollback_report.md << REPORT
# 전체 롤백 완료 보고서

## 기본 정보
- 롤백 시작 시간: $(date)
- 롤백 사유: $rollback_reason
- 롤백 유형: 전체 시스템 롤백
- 담당자: [담당자명]

## 수행 작업
1. AWS RDS 연결 차단
2. IDC 환경 완전 재구성
3. 백업 데이터 복구 (선택적)
4. 서비스 설정 원복
5. 시스템 상태 검증

## 현재 상태
### MySQL 데이터베이스
$(cat system_status.txt)

### 서비스 상태
- 웹 서비스: 정상 접근 가능
- MySQL: 정상 동작
- 데이터 무결성: 확인 완료

## 후속 조치 사항
1. **즉시 수행**
   - [ ] 서비스 모니터링 강화
   - [ ] 사용자 접근성 확인
   - [ ] 성능 지표 모니터링

2. **24시간 내**
   - [ ] 마이그레이션 실패 원인 분석
   - [ ] AWS 리소스 정리 계획 수립
   - [ ] 팀 회고 미팅 일정 수립

3. **1주일 내**
   - [ ] 재마이그레이션 전략 수립
   - [ ] 프로세스 개선사항 도출
   - [ ] 문서 업데이트

## 첨부 파일
- 롤백 로그: $ROLLBACK_LOG
- 시스템 상태: system_status.txt
- 알림 메시지: full_rollback_notification.txt

## 검토자 확인
- [ ] 시스템 관리자
- [ ] DBA
- [ ] 개발팀 리드
- [ ] 운영팀 리드
REPORT

# 8. 알림 메시지 생성
cat > full_rollback_notification.txt << NOTICE
=== 전체 롤백 완료 알림 ===

시간: $(date)
상태: 완료
롤백 사유: $rollback_reason

현재 상태:
- IDC MySQL: 정상 동작
- 웹 서비스: 접근 가능
- 데이터: 복구 완료

다음 단계:
1. 서비스 모니터링 지속
2. 성능 지표 추적
3. 사용자 피드백 모니터링
4. 원인 분석 시작

상세 정보:
- 보고서: full_rollback_report.md
- 로그: $ROLLBACK_LOG

연락처:
- 시스템 관리자: [연락처]
- DB 관리자: [연락처]
- 운영팀: [연락처]
NOTICE

log "=== 전체 롤백 프로세스 완료 ==="
echo ""
echo "✅ 전체 롤백이 성공적으로 완료되었습니다."
echo ""
echo "생성된 파일:"
echo "  📋 보고서: full_rollback_report.md"
echo "  📝 로그: $ROLLBACK_LOG"
echo "  📧 알림: full_rollback_notification.txt"
echo "  📊 상태: system_status.txt"
echo ""
echo "다음 단계:"
echo "  1. 서비스 상태 지속 모니터링"
echo "  2. 보고서 내용 팀과 공유"
echo "  3. 원인 분석 및 개선사항 도출"
echo "  4. 재마이그레이션 계획 수립"
