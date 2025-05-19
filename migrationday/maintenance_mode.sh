#!/bin/bash

echo "=== 메인터넌스 모드 활성화 ==="
echo "시작 시간: $(date)"

# 필요한 파일들이 존재하는지 확인
if [ ! -f "nginx.conf.maintenance" ]; then
    echo "❌ nginx.conf.maintenance 파일이 없습니다."
    exit 1
fi

if [ ! -f "maintenance.html" ]; then
    echo "❌ maintenance.html 파일이 없습니다."
    exit 1
fi

# nginx 설정을 메인터넌스 모드로 변경
echo "메인터넌스 설정 적용 중..."
docker cp nginx.conf.maintenance idc_nginx:/etc/nginx/nginx.conf

# 메인터넌스 페이지 복사
echo "메인터넌스 페이지 복사 중..."
docker cp maintenance.html idc_nginx:/usr/share/nginx/html/maintenance.html

# nginx 설정 테스트
echo "nginx 설정 검증 중..."
if docker exec idc_nginx nginx -t; then
    echo "✅ nginx 설정 검증 성공"
    # nginx 재로드
    docker exec idc_nginx nginx -s reload
    echo "✅ nginx 재로드 완료"
else
    echo "❌ nginx 설정 오류 발견"
    exit 1
fi

echo "메인터넌스 모드 활성화 완료"
echo "메인터넌스 페이지 확인: http://localhost"

# 확인
echo ""
echo "확인 방법:"
echo "1. 브라우저: http://localhost (Ctrl+Shift+R로 하드 리프레시)"
echo "2. curl: curl http://localhost"
