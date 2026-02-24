#!/bin/bash

# ==========================================
# 1. 경로 및 환경 변수 설정
# ==========================================
BASE_PATH="/mnt/sda/hojae/dreamzero"
VIDEO_PATH="/mnt/sdb/hojae/.cache/pretrained"
LOG_DIR="logs"
VIDEO_DIR="videos"
CONDA_ENV="dreamzero" # Conda 가상환경 이름

# ==========================================
# 2. Conda 가상환경 활성화 (매우 중요!)
# ==========================================
# 스크립트 내에서 conda activate를 사용하기 위한 초기화 과정입니다.
eval "$(conda shell.bash hook)"
conda activate "${CONDA_ENV}"

# ==========================================
# 3. 로그 폴더 생성 및 Python 스크립트 실행
# ==========================================
cd ${BASE_PATH}
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +'%Y%m%d_%H%M%S').log"

echo "=========================================="
echo "▶ 환경: Conda [${CONDA_ENV}] 활성화 완료"
echo "▶ Python 스크립트 실행 시작"
echo "▶ 로그 파일: ${LOG_FILE}"
echo "=========================================="

python test_client_AR.py --port 5000 2>&1 | tee "${LOG_FILE}"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ 에러: Python 스크립트 실행 중 문제가 발생했습니다."
    # 가상환경을 끄고 종료 (선택 사항이지만 깔끔한 종료를 위해)
    conda deactivate
    exit 1
fi

echo "✅ Python 스크립트 실행 완료!"
echo ""

# ==========================================
# 4. 비디오 폴더 생성 및 폴더 안전 복사 (cp -r 후 rm -rf)
# ==========================================
mkdir -p "${VIDEO_DIR}"

if ls "${VIDEO_PATH}"/real_world_eval_gen_* 1> /dev/null 2>&1; then
    echo "▶ 비디오 폴더 복사 중... (${VIDEO_PATH} -> ${VIDEO_DIR})"
    
    # 변경점 1: 폴더 복사를 위해 -r 옵션 추가
    cp -r "${VIDEO_PATH}"/real_world_eval_gen_* "${VIDEO_DIR}/"
    
    if [ $? -eq 0 ]; then
        echo "✅ 복사 완료! 원본 폴더를 안전하게 삭제합니다."
        # 변경점 2: 폴더 삭제를 위해 -rf 옵션 추가
        rm -rf "${VIDEO_PATH}"/real_world_eval_gen_*
    else
        echo "❌ 에러: 폴더 복사 중 문제가 발생했습니다! 원본 보존 후 종료합니다."
        conda deactivate
        exit 1
    fi
else
    echo "⚠️ 알림: 복사할 비디오 폴더가 존재하지 않습니다."
fi

echo "=========================================="
echo "🎉 모든 작업이 성공적으로 마무리되었습니다!"
echo "=========================================="

# 작업이 모두 끝나면 가상환경을 안전하게 비활성화
conda deactivate
