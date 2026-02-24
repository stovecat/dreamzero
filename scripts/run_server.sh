#!/bin/bash

# ==========================================
# 1. 인자(Argument) 처리: GPU 세팅
# ==========================================
# 실행 시 첫 번째 인자($1)를 확인합니다. (공백이 있을 경우 제거)
INPUT_ARGS="${1// /}"

if [ -z "$INPUT_ARGS" ]; then
    # 인자가 없으면 기본값: 0번 GPU 1개 사용 (Single GPU)
    GPU_IDS="0"
    GPU_COUNT=1
else
    # 인자가 있으면 (예: 0,1) 해당 값을 사용 (Multi GPU)
    GPU_IDS="$INPUT_ARGS"
    
    # 콤마(,)를 기준으로 배열로 만들어 GPU 개수(nproc_per_node)를 계산합니다.
    IFS=',' read -ra GPU_ARRAY <<< "$GPU_IDS"
    GPU_COUNT=${#GPU_ARRAY[@]}
fi

# ==========================================
# 2. 경로 및 환경 변수 설정
# ==========================================
BASE_PATH="/mnt/sda/hojae/dreamzero"
MODEL_PATH="/mnt/sdb/hojae/.cache/pretrained/"
LOG_DIR="logs"
CONDA_ENV="dreamzero"

# 모델 관련 필수 환경 변수 내보내기
export HF_HOME="/mnt/sdb/hojae/.cache/huggingface"
export TORCH_COMPILE_DISABLE=1
# 할당된 GPU ID만 보이도록 설정
export CUDA_VISIBLE_DEVICES="$GPU_IDS"

# ==========================================
# 3. Conda 가상환경 활성화 및 작업 경로 이동
# ==========================================
eval "$(conda shell.bash hook)"
conda activate "${CONDA_ENV}"

# BASE_PATH로 이동 (실패 시 안전을 위해 종료)
cd "${BASE_PATH}" || { echo "❌ 에러: ${BASE_PATH} 로 이동할 수 없습니다."; exit 1; }

# ==========================================
# 4. 로그 폴더 생성 및 서버 스크립트 실행
# ==========================================
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/server_$(date +'%Y%m%d_%H%M%S').log"

echo "=========================================="
echo "▶ 환경: Conda [${CONDA_ENV}] 활성화 완료"
echo "▶ 작업 디렉토리: ${BASE_PATH}"
echo "▶ 할당된 GPU (CUDA_VISIBLE_DEVICES): ${GPU_IDS}"
echo "▶ 실행되는 프로세스 수 (nproc_per_node): ${GPU_COUNT}"
echo "▶ 서버 스크립트 실행 시작"
echo "▶ 로그 파일: ${LOG_FILE}"
echo "=========================================="

# GPU_COUNT 변수를 사용하여 single/multi 동적 실행
python -m torch.distributed.run \
    --standalone \
    --nproc_per_node="${GPU_COUNT}" \
    socket_test_optimized_AR.py \
    --port 5000 \
    --enable-dit-cache \
    --model-path "${MODEL_PATH}" 2>&1 | tee "${LOG_FILE}"

# 실행 결과 체크
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ 에러: 서버 스크립트 실행 중 문제가 발생했습니다."
    conda deactivate
    exit 1
fi

echo "=========================================="
echo "✅ 서버 스크립트 실행 종료!"
echo "=========================================="

# 가상환경 안전하게 비활성화
conda deactivate
