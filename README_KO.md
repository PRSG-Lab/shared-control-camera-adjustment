# 논문 v0.19 MATLAB 통합 재현 패키지

버전 **1.1.0 (2026-09-30)**. 최종으로 사용된 `PR_Revision_MATLAB_v1`과 `PR_Native_Chart_Postprocess_v1`을 한 실행 체계로 통합했습니다. 본실험 엔진은 이름이 비슷한 옛 `JoG_MATLAB_v2` 폴더가 아니라, 최종 결과에 포함된 **JoG v2.1**입니다. 포함된 43개 엔진 파일과 원래 실행에 저장된 코드가 일치하는지 확인했습니다.

## 가장 빠르게 결과 확인하기

압축을 풀고 MATLAB의 Current Folder를 이 패키지의 최상위 폴더로 지정한 다음 실행합니다.

```matlab
file = RUN_REFERENCE;
```

포함된 최종 수치 데이터를 읽어 본문 **Figure 2–6, Table 1–5**, 기존 부가 분석 **Figure S1–S13, Table S1–S5** 및 본문 수치 진단을 다시 계산·출력합니다. 생성된 폴더는 실행 마지막에 표시됩니다. 완성된 그림과 표는 `reference_products/`에도 미리 넣었습니다. **Figure 1은 사용자가 제작하는 개념도이므로 기본 출력에서 제외했습니다.**

각 그림은 PNG(600 dpi), 벡터 PDF, 편집 가능한 MATLAB FIG와 수치 MAT 파일로 저장됩니다. 표는 CSV, 표시 자릿수를 적용한 CSV, LaTeX 조각과 MAT 데이터로 저장됩니다. MATLAB로 다시 그린 결과는 수치와 패널 내용을 재현하며, 기존 원고 그림과 픽셀 단위로 같은 이미지는 아닙니다.

## 새 관측값부터 실험 다시 실행하기

```matlab
smoke_file = RUN_SMOKE;   % 작은 표본으로 전체 실행 경로 확인
paper_file = RUN_PAPER;   % 논문의 표본 수와 설정으로 전체 계산
```

두 명령은 목적에 맞게 선택해서 실행하십시오. `RUN_SMOKE`는 별도 seed와 작은 표본을 사용하므로 논문 수치 재현용이 아닙니다. `RUN_PAPER`는 원래 엔진과 최종 추가 분석을 사용하여 관측값 생성, 조정, target 전파, 더 큰 회전 실험, bias 진단, direct-focal 재적합 및 native-chart 분석을 수행합니다. 새 계산에서 누락된 결과를 포함된 기준 데이터로 대체하지 않습니다.

본실험 원래 결과는 **123개 조건, 102,000 condition–realisations, 416,000 fits, 415,744 valid fits**입니다. 102,000×4에 E03의 추가 공분산 처리 8,000건을 더한 값이며, 이후의 stronger-rotation 24,000 fits 및 direct-focal 2,000 refits 등은 별도입니다. 본실험 원본 archive만 약 12.2 GB였고, 새 실행에서는 checkpoint와 임시 파일 공간이 추가로 필요합니다.

## 저장과 중단 후 재개

```matlab
folder = fullfile(pwd,'runs','paper_01');
file = RUN_PAPER(folder, 20);   % 현재 단계의 새 작업 20개까지만 진행
file = RUN_RESUME(folder);      % 같은 코드·설정으로 계속 진행
```

제한값은 초/분이 아니라 현재 계산 단계의 새 batch/task 수입니다. 완료한 작업은 다시 계산하지 않습니다. checkpoint 파일뿐 아니라 **run 폴더 전체**를 보관하십시오. 코드나 수치 설정을 바꾼 뒤 기존 checkpoint를 섞어 쓰면 실행이 거부됩니다. `RUN_EXISTING`으로 별도로 보유한 완료된 원본 MAT를 읽는 방법은 `docs/DATA_AND_RESUME.md`에 있습니다.

## 이번 통합에 포함한 최신 분석

- Figure 3: patch+global covariance 생략 실험과 patch-only variance 배율 실험을 별도 패널로 구성.
- 27개 reduced-model 조건의 동일 추출 오차를 이용한 비교, guard 기록과 오류 재구성 검증.
- 평면당 1,000점 조건의 sample SD에 대한 10,000회 bootstrap Monte Carlo 구간. 과거 NumPy seed 20260925의 추출 횟수 계획을 보관하고 MATLAB에서 현재 데이터로 다시 계산합니다. 결과값을 상수로 넣지 않았습니다.
- 전체 fit 수, invalid fit 수와 추가 8,000건의 조건별 내역.
- 본문 Table 2–5 수치 대조, native focal-coordinate 포함 여부, target별 오차·coverage, 고정 metric의 bias/scatter 분해.

## 요구 환경 및 검증 범위

MATLAB R2026a Update 4 / Apple silicon에서 실행했습니다. 일반 실행에는 Python이나 별도 MATLAB toolbox가 필요하지 않으며 JVM은 켜져 있어야 합니다. 다른 MATLAB 버전·운영체제의 동작과 비트 단위 동일성은 검증하지 않았습니다.

```matlab
report = RUN_VALIDATE;
```

이 명령은 해석적 항등식과 보관 데이터 기반 수치 대조를 실행합니다. 이번 검증의 상세 결과는 `validation/VALIDATION.md`와 JSON 기록에 있습니다. **보관된 최종 데이터의 재분석·그림 생성과 새 소규모 실험은 검증했으며, 전체 416,000회 본실험은 이번 통합 과정에서 다시 실행하지 않았습니다.**

기준 데이터는 필요한 수치·요약·대표 trial 기록을 보관한 압축된 자료입니다. 12.2 GB 원본의 모든 영상 관측값과 적합 기록은 ZIP에 넣지 않았습니다. 전체 원자료를 새로 생성하려면 `RUN_PAPER`를 사용하고 `raw/`를 포함한 결과 폴더 전체를 보관하십시오.

## 파일 안내

| 위치 | 내용 |
|---|---|
| `RUN_*.m` | 통합 실행 진입점 |
| `engines/revision/` | 최종 추가 실험 코드와 JoG v2.1 엔진 |
| `engines/native/` | 최종 native focal-chart 분석 코드 |
| `src/` | 통합 수집·분석·표·그림 생성 |
| `data/reference/` | 원래 최종 실행에서 추출한 기준 수치 데이터 |
| `data/resampling/` | reduced-model bootstrap의 고정 추출 횟수 계획 |
| `reference_products/` | 미리 생성한 그림, 표와 수치 파일 |
| `docs/EXPERIMENTS.md` | 실험 조건, seed, 표본 수 |
| `docs/MANUSCRIPT_MAP.md` | 논문 그림·표와 코드·실험의 대응 |
| `docs/PROVENANCE.md` | 최종 원본 확인 근거와 변경 범위 |
| `validation/` | 실제 실행 및 대조 결과 |
| `SHA256SUMS` | 배포 파일 무결성 확인용 해시 |

폴더 전체를 재귀적으로 MATLAB path에 추가하지 마십시오. 하위 원본 코드에 같은 이름의 실행 파일이 있으므로 최상위 폴더에서 `prpaper_setup` 또는 `RUN_*`를 호출해야 합니다.
