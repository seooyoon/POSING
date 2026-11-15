<p align="center">
  <img width="220" height="220" alt="image" src="https://github.com/user-attachments/assets/302de9f3-a425-4888-b311-80fdee8bf3a8" />
</p>

<div>

## 📸 POSING

> **"Your friend's camera skills? Not your problem anymore." <br> 친구의 사진 실력? 이제 걱정하지 마세요.**

</div>

<br>

## 📌 포징은 이런 앱이에요

> 여행지에서 다른 사람에게 사진을 부탁하면 원하는 구도를 말로 설명하기 어렵고, 결과물도 매번 달라진다. 포징은 아이폰 기본 카메라와 똑같은 화면에 **포즈 테두리**나 **내가 고른 참고 사진**을 반투명하게 겹쳐 보여줘서, 찍어주는 사람이 화면만 보고 같은 구도로 찍을 수 있게 하기 위해 만들었다.

### 🔥 기본 카메라 그대로

> 처음 써보는 사람도 설명 없이 바로 찍을 수 있습니다

아이폰 기본 카메라(iOS 26)와 같은 배치·아이콘·동작을 그대로 따랐다. 앱을 켜면 홈 화면 없이 바로 카메라가 나오고, 찍은 사진·영상은 아이폰 사진 앱에 바로 저장된다. 기본 카메라에 더한 건 상단 왼쪽 **초기화 · 포즈 · MY** 버튼 3개, 셔터 왼쪽 **카메라 버튼**, 셔터 오른쪽 **분할 버튼**뿐이다.

### 🔥 포즈 · MY 레이어

> 포즈 테두리와 참고 사진을 화면에 겹쳐 구도를 맞춥니다

- **포즈**: 미리 넣어 둔 포즈 테두리를 겹쳐 보여준다 (기본 투명도 100%)
- **MY**: 앱에 넣어 둔 사진 패키지나 내가 추가한 사진을 반투명하게 겹친다 (기본 투명도 35%). 패키지 대표 이미지를 꾹 누르면 사진 앱에서 골라 그 패키지에 바로 추가된다
- 포즈 1개 + MY 1개까지 동시에 겹칠 수 있고, 패널의 조절 바로 투명도를 바꾼다. 레이어는 늘 같은 자리에 고정되어 찍는 동안 흔들리지 않는다
- **초기화**: 탭하면 겹친 레이어를 모두 끄고, 꾹 누르면 설정 화면(앱 아이콘 · 격자 · 포즈 · MY · 카메라 목록 편집)이 열린다
- 겹친 레이어는 **화면에만** 보이고, 저장되는 사진·영상에는 **절대** 들어가지 않는다

### 🔥 카메라별 색감 · 스타일

> 카메라 기종을 고르면 그 카메라의 사진 느낌으로 찍힙니다

셔터 왼쪽 카메라 버튼으로 카메라(예: POSING)를 고르면 그 색감이 미리보기와 사진에 적용된다. 탭하면 카메라 목록이 열리고, 꾹 누르거나 위아래로 밀면 손을 떼지 않고 바로 바꿀 수 있다. 자주 쓰는 카메라는 두 번 탭해 즐겨찾기로 맨 위에 둔다. 기본 카메라의 사진 스타일과 같은 화면·조작으로 톤·색상·팔레트도 조절할 수 있다.

### 🔥 분할 사진

> 여러 장을 한 장에 담는 네컷 사진을 바로 찍습니다

셔터 오른쪽 분할 버튼으로 2 · 3 · 4분할을 고르면 미리보기가 칸으로 나뉘고, 지금 찍을 칸에만 실시간 화면이 보인다. 칸마다 한 장씩 찍고, 마음에 안 드는 칸은 오른쪽 위 목록에서 눌러 다시 찍는다. 다 찍으면 셔터가 노란 **저장** 버튼으로 바뀌고, 누르면 합친 사진과 칸별 원본이 사진 앱에 저장된다. 고른 카메라 색감 · 스타일도 칸마다 그대로 들어간다.

### 🔥 완전 오프라인

> 인터넷 없이 모든 기능이 동작합니다

촬영, 저장, 포즈·MY, 분할 사진, 설정까지 비행기 모드에서도 전부 쓸 수 있다. 네트워크 코드와 외부 라이브러리를 쓰지 않는다.

<br>

## 👤 POSING을 만든 사람

| 역할 | 담당 |
|:---|:---|
| 📱 iOS | 배서윤 |
| 🎨 Design | 배서윤 |

<br>

## ⚙️ 기술 스택

| 구분 | 기술 | 용도 |
| --- | --- | --- |
| Language | ![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white) | App |
| UI | ![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?style=for-the-badge&logo=swift&logoColor=white) | 카메라 화면 · 패널 · 설정 화면 |
| Camera | ![AVFoundation](https://img.shields.io/badge/AVFoundation-000000?style=for-the-badge&logo=apple&logoColor=white) | 촬영 · 녹화 · 배율 · 초점 (애플 [AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app) 예제 기반) |
| Image | ![Core Image](https://img.shields.io/badge/Core%20Image-000000?style=for-the-badge&logo=apple&logoColor=white) ![ImageIO](https://img.shields.io/badge/ImageIO-000000?style=for-the-badge&logo=apple&logoColor=white) | 스타일 · 카메라 색감 보정, 비율 자르기, 분할 사진 합치기 (EXIF 유지) |
| Rendering | ![Metal](https://img.shields.io/badge/Metal-000000?style=for-the-badge&logo=apple&logoColor=white) | 스타일 · 색감 실시간 미리보기 |
| Vision | ![Vision](https://img.shields.io/badge/Vision-000000?style=for-the-badge&logo=apple&logoColor=white) | 플래시 사진의 사람 영역 인식 (기기 안 처리) |
| Photos | ![Photos](https://img.shields.io/badge/Photos%20%C2%B7%20PhotosUI-000000?style=for-the-badge&logo=apple&logoColor=white) | 사진 앱 저장, MY 사진 고르기 |
| Sensor | ![CoreMotion](https://img.shields.io/badge/CoreMotion-000000?style=for-the-badge&logo=apple&logoColor=white) | 수평계 · 아이콘 회전 |
| IDE | ![Xcode](https://img.shields.io/badge/Xcode-147EFB?style=for-the-badge&logo=xcode&logoColor=white) | 빌드 · 서명 · 기기 설치 |

<br>

## ⚙️ 실행 환경

- **대상 기기**: iPhone 16 Pro (세로 고정)
- **최소 iOS**: `26.0`
- **외부 라이브러리**: 없음 (애플 기본 프레임워크만 사용)
- **여는 방법**
  ```bash
  git clone https://github.com/seooyoon/POSING.git
  cd POSING
  ```
  Xcode로 프로젝트를 열고 **Signing & Capabilities**에서 Team과 Bundle Identifier를 내 계정으로 바꿉니다.

- **실행**: 아이폰을 연결하고 Xcode에서 ▶
  > 시뮬레이터에는 카메라가 없어서 샘플 이미지로 화면만 확인할 수 있습니다. 카메라 동작은 실기기에서 확인합니다.
  > 무료 애플 ID로 설치하면 7일 동안 유지됩니다.

<br>

## 🔗 Git Convention

### 1️⃣ Git Flow

```
  main ← develop ← feature 브랜치
```

- `main branch` : 배포 브랜치 (여행 전 폰에 설치하는 버전)
- `develop branch` : 개발 브랜치, 작업 브랜치가 merge됨
- `feat / fix / chore / refactor ...` : 작업 브랜치

  <br/>

### 2️⃣ Flow

- 이슈 생성 (제목은 작업 종류로 시작, 예: `[FEAT] 포즈 · MY 레이어`. 로드맵 단계는 본문 작업 요약에)
- 이슈 번호에 맞게 `develop` 브랜치에서 새로운 브랜치 생성
- 작업 완료 후 커밋 컨벤션에 맞게 커밋
- PR 생성 (PR 템플릿의 절대 규칙 체크리스트 확인)
- CodeRabbit 리뷰 반영 + 실기기 확인 후 `develop` 브랜치로 병합
- `main`, `develop`에는 직접 push하지 않음

  <br/>

### 3️⃣ Branch Naming Convention

- **구조**: `브랜치종류/#이슈번호-기능설명`
- **구분자**: 하이픈(`-`) 사용
- **예시**: `feat/#3-pose-layer`, `fix/#12-zoom-dial`

| Prefix     | 설명               |
| ---------- | ------------------ |
| `init`     | 초기 프로젝트 세팅 |
| `feat`     | 새로운 기능 추가   |
| `fix`      | 버그 수정          |
| `docs`     | 문서 변경          |
| `style`    | UI 수정            |
| `refactor` | 코드 리팩토링      |
| `test`     | 테스트 코드 관련   |
| `chore`    | 설정 파일 변경     |
| `security` | 보안약점 조치      |
| `hotfix`   | 긴급한 버그 수정   |
| `deploy`   | 배포 관련 작업     |

  <br/>

### 4️⃣ Commit Message

- **구조**: `prefix: 내용 (#이슈번호)`
- **예시**
  - `init: AVCam 예제 프로젝트 추가 (#1)`
  - `feat: 포즈 패널과 투명도 조절 바 구현 (#3)`
  - `fix: 1:1 비율 저장 시 EXIF 누락 수정 (#12)`

| Prefix     | 설명               |
| ---------- | ------------------ |
| `init`     | 초기 프로젝트 세팅 |
| `feat`     | 새로운 기능 추가   |
| `fix`      | 버그 수정          |
| `docs`     | 문서 변경          |
| `style`    | UI 수정            |
| `refactor` | 코드 리팩토링      |
| `test`     | 테스트 코드 관련   |
| `chore`    | 설정 파일 변경     |
| `security` | 보안약점 조치      |
| `hotfix`   | 긴급한 버그 수정   |
| `deploy`   | 배포 관련 작업     |

  <br/>

## 📂 프로젝트 구조

  ```
  📦 POSING
  ├─ 📁 .github
  │  ├─ 📁 ISSUE_TEMPLATE
  │  │  ├─ 📄 feat.md              # [FEAT] 이슈 템플릿
  │  │  ├─ 📄 bug.md               # [BUG] 이슈 템플릿
  │  │  ├─ 📄 chore.md             # [CHORE] 이슈 템플릿
  │  │  └─ 📄 docs.md              # [DOCS] 이슈 템플릿
  │  └─ 📄 pull_request_template.md
  ├─ 📄 .coderabbit.yaml           # CodeRabbit 리뷰 언어/설정
  ├─ 📄 .gitattributes
  ├─ 📄 .gitignore
  ├─ 📄 README.md
  ├─ 📄 START_HERE.md              # 처음 설치 · 실행 방법
  ├─ 📄 CLAUDE.md                  # 개발 지시서 (절대 규칙, 임시 기본값)
  ├─ 📁 docs
  │  ├─ 📄 01_SPEC.md              # 기능 명세
  │  ├─ 📄 02_UI.md                # 화면 배치와 동작
│  ├─ 📄 03_ROADMAP.md           # 개발 단계
│  ├─ 📄 04_ASSETS.md            # 포즈 · 아이콘 · 카메라 규격
│  ├─ 📄 05_TECH_NOTES.md        # 기술 메모
│  └─ 📁 reference               # 기본 카메라 참고 스크린샷
├─ 📄 LICENSE-AVCam.txt          # 애플 AVCam 예제 라이선스
├─ 📁 Configuration              # 샘플 코드 빌드 설정 (xcconfig)
├─ 📁 AVCam.xcodeproj            # Xcode 프로젝트
├─ 📁 AVCam                      # 앱 본체 (애플 AVCam 예제 기반)
│  ├─ 📄 AVCamApp.swift           # 앱 시작점
│  ├─ 📄 CameraView.swift         # 카메라 화면 (미리보기 · 오버레이 · UI 쌓기)
│  ├─ 📄 CameraModel.swift        # 화면과 촬영 서비스를 잇는 모델
│  ├─ 📄 CaptureService.swift     # 카메라 세션 (actor, 메인 스레드 밖)
│  ├─ 📁 Capture                  # 사진 · 동영상 촬영, 색감 · 스타일 보정, 비율 자르기, 분할 사진 합치기
│  ├─ 📁 Model                    # 상태 · 데이터 타입 · 사진 앱 저장
│  │  ├─ 📁 Focus                 # 초점 · 수평계
│  │  ├─ 📁 Layers                # 포즈 · MY · 카메라 목록
│  │  ├─ 📁 Split                 # 분할 사진 상태
│  │  ├─ 📁 Zoom                  # 배율
│  │  └─ 📁 Intent                # 잠금화면 촬영 인텐트
│  ├─ 📁 Views                    # 화면
│  │  ├─ 📁 TopBar                # 상단 바 · 빠른 설정 판
│  │  ├─ 📁 Toolbars              # 셔터 · 카메라 버튼 · 하단 줄
│  │  ├─ 📁 Controls              # 배율 버튼 · 다이얼 · 모드 선택
│  │  ├─ 📁 Overlays              # 격자 · 수평계 · 초점 · 상태 표시
│  │  ├─ 📁 Layers                # 포즈 · MY 레이어 표시
│  │  ├─ 📁 Panels                # 포즈 · MY 패널 · 투명도 조절 바
│  │  ├─ 📁 Split                 # 분할 버튼 · 칸 보기 · 칸 목록
│  │  ├─ 📁 MoreMenu              # 더보기 메뉴 · 스타일 화면
│  │  ├─ 📁 Settings              # 설정 화면
│  │  └─ 📁 Layout                # 화면 배치 계산 · 공통 모양
│  ├─ 📁 Support                  # 기본값(AppDefaults) · 설정 키 · 확장 함수
│  ├─ 📁 Resources                # 포즈 · MY 패키지 · 카메라 이미지
│  ├─ 📁 Assets.xcassets          # 앱 아이콘 · 로고 · 색
│  └─ 📁 Preview Content          # 시뮬레이터 · 프리뷰용 가짜 카메라
├─ 📁 AVCamCaptureExtension       # 잠금화면 카메라 확장
└─ 📁 AVCamControlCenterExtension # 제어 센터 · 카메라 컨트롤 위젯
```
