#!/bin/bash

# 환경 변수 로드 (prepare 디렉토리 기준)
source ../aws_config.sh
source ../mysql_env.sh

echo "=== 롤백 계획 검증 및 확인 ==="

# 1. 롤백 파일 존재 확인
echo "1. 롤백 파일 존재 확인"
ROLLBACK_DIR="rollback"

# 확인할 파일 목록
FILES_TO_CHECK=(
    "rollback_plan.md"
    "emergency_rollback.sh"
    "full_rollback.sh"
    "rollback_test.sh"
    "rollback_checklist.md"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$ROLLBACK_DIR/$file" ]; then
        echo "  ✅ $file 존재"
    else
        echo "  ❌ $file 없음"
    fi
done

# 2. 롤백 스크립트 실행 권한 확인
echo -e "\n2. 롤백 스크립트 실행 권한 확인"
SCRIPT_FILES=("emergency_rollback.sh" "full_rollback.sh" "rollback_test.sh")

for script in "${SCRIPT_FILES[@]}"; do
    if [ -x "$ROLLBACK_DIR/$script" ]; then
        echo "  ✅ $script 실행 권한 있음"
    else
        echo "  ❌ $script 실행 권한 없음"
        echo "      chmod +x $ROLLBACK_DIR/$script 실행 필요"
    fi
done

# 3. 롤백 계획서 내용 미리보기
echo -e "\n3. 롤백 계획서 내용 미리보기"
if [ -f "$ROLLBACK_DIR/rollback_plan.md" ]; then
    echo "  📋 롤백 계획서 요약:"
    head -20 "$ROLLBACK_DIR/rollback_plan.md" | grep -E "(##|###)" | head -10
else
    echo "  ❌ 롤백 계획서를 찾을 수 없습니다"
fi

# 4. 환경 설정 검증
echo -e "\n4. 롤백에 필요한 환경 설정 검증"

# IDC 연결 확인 (출력 완전히 숨김)
if docker exec idc_mysql mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
    echo "  ✅ IDC MySQL 연결 가능"
else
    echo "  ❌ IDC MySQL 연결 불가"
fi

# AWS RDS 연결 확인 (출력 완전히 숨김)
if docker exec idc_mysql mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USERNAME -p$RDS_PASSWORD -e "SELECT 1;" >/dev/null 2>&1; then
    echo "  ✅ AWS RDS 연결 가능"
else
    echo "  ❌ AWS RDS 연결 불가 (마이그레이션 전 정상 상태)"
fi

# 백업 파일 확인
if [ -d "../backups" ] && [ "$(ls -1 ../backups/*.sql 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  ✅ 백업 파일 존재"
    # 백업 파일 개수 표시
    BACKUP_COUNT=$(ls -1 ../backups/*.sql 2>/dev/null | wc -l)
    echo "      백업 파일 수: ${BACKUP_COUNT}개"
else
    echo "  ❌ 백업 파일 없음 - create_dump.sh 먼저 실행"
fi

# 5. 롤백 테스트 실행 여부 확인
echo -e "\n5. 롤백 테스트 실행 옵션"
read -p "롤백 테스트를 실행하시겠습니까? (y/N): " run_test

if [[ $run_test =~ ^[Yy]$ ]]; then
    echo "롤백 테스트 실행 중..."
    cd $ROLLBACK_DIR
    ./rollback_test.sh
    cd ..
else
    echo "롤백 테스트를 건너뜁니다."
fi

# 6. 체크리스트 미리보기
echo -e "\n6. 체크리스트 미리보기"
if [ -f "$ROLLBACK_DIR/rollback_checklist.md" ]; then
    echo "  📝 주요 체크리스트 항목:"
    grep -E "^## " "$ROLLBACK_DIR/rollback_checklist.md" | head -8
elif [ -f "$ROLLBACK_DIR/rollback_checklist.txt" ]; then
    echo "  📝 주요 체크리스트 항목:"
    grep -E "^## " "$ROLLBACK_DIR/rollback_checklist.txt" | head -8
else
    echo "  ❌ 체크리스트를 찾을 수 없습니다"
fi

# 7. 권장 사항
echo -e "\n=== 권장 사항 ==="
echo "1. 롤백 계획서를 팀과 함께 검토하세요:"
echo "   cat prepare/rollback/rollback_plan.md"
echo ""
echo "2. 체크리스트를 숙지하세요:"
echo "   cat prepare/rollback/rollback_checklist.md"
echo ""
echo "3. 마이그레이션 실행 전 롤백 테스트를 진행하세요:"
echo "   cd prepare && ./rollback_plan.sh"
echo ""
echo "4. 급한 상황에서는 다음 스크립트를 사용하세요:"
echo "   긴급 롤백: cd prepare/rollback && ./emergency_rollback.sh"
echo "   전체 롤백: cd prepare/rollback && ./full_rollback.sh"
echo ""
echo "=== 검증 완료 ==="
