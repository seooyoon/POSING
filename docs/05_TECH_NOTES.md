# 05 기술 메모

구현할 때 참고할 API와 함정. "실기기 확인"이라고 적힌 값은 iPhone 16 Pro에서 실제 값을 로그로 찍어 확인한 뒤 확정한다.

## 1. 배율 (builtInTripleCamera)

- 후면은 `AVCaptureDevice.DeviceType.builtInTripleCamera` 가상 장치 사용 → iOS가 배율에 따라 초광각/메인/망원 렌즈를 자동 전환
- 이 장치의 `videoZoomFactor = 1.0`이 화면 표시 **0.5×**
- 표시 배율 = `videoZoomFactor × device.displayVideoZoomFactorMultiplier` (iOS 18+, 트리플 카메라에서 0.5 예상 — 실기기 확인)
- 렌즈 전환 지점: `virtualDeviceSwitchOverVideoZoomFactors` (16 Pro 예상 `[2, 10]` → 표시 1×, 5× — 실기기 확인)
- 버튼 → `videoZoomFactor`: `.5`=1, `1`=2, `2`=4, `5`=10
- 최대 25× 표시 = `videoZoomFactor 50`, 단 `maxAvailableVideoZoomFactor`보다 크면 그 값으로 제한
- 버튼 전환은 `ramp(toVideoZoomFactor:withRate:)`로 부드럽게, 다이얼·손가락은 즉시 설정
- 전면은 `builtInTrueDepthCamera`. 화각 버튼(넓게/가깝게)의 실제 배율 값은 실기기 확인

## 2. 접사 (꽃 버튼)

- 트리플 카메라는 가까운 물체에서 자동으로 초광각으로 바꿔 접사를 찍음 (`primaryConstituentDeviceSwitchingBehavior = .auto`)
- `activePrimaryConstituentDevice`를 관찰해서, 표시 배율이 1× 이상인데 활성 렌즈가 초광각이면 접사 중 → 꽃 버튼 노란색 표시
- 꽃 버튼 끄기: `setPrimaryConstituentDeviceSwitchingBehavior(.restricted, restrictedSwitchingBehaviorConditions: .videoZoomChanged)` → 배율 변경으로만 렌즈 전환. 켜기: 다시 `.auto`
- 꽃 버튼 표시 조건과 끄기 동작은 실기기 확인

## 3. 초점 · 노출 · 잠금

- 화면 좌표 → 장치 좌표: `AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)`
- 탭: `focusPointOfInterest` + `.autoFocus`, `exposurePointOfInterest` + `.autoExpose`. 몇 초 뒤 `.continuousAutoFocus`로 복귀 (기본 카메라처럼 피사체가 바뀌면 복귀)
- 밝기: `setExposureTargetBias(_:)`, UI 범위 ±2 EV (장치 min/max로 한 번 더 제한)
- 길게 누르기: focus `.locked`, exposure `.locked` + "AE/AF 잠금" 표시

## 4. 스타일 (사진 스타일과 비슷하게)

- 애플의 사진 스타일은 다른 앱에서 쓸 수 있는 API가 없음 → **Core Image로 직접 보정**
- 스타일 하나 = 기본 룩(LUT, `CIColorCubeWithColorSpace`) + 톤·색상·팔레트 값
  - 톤: 그림자 깊이·대비. `CIToneCurve`(그림자·중간 톤 점 이동) + `CIHighlightShadowAdjust`. 마이너스 = 그림자 진하게·대비 강하게, 플러스 = 밝고 부드럽게
  - 색상: 채도·색 강도. `CIColorControls.saturation` (+ 약간의 `CIVibrance`). 흑백 스타일에서는 흑백 톤의 따뜻함/차가움으로 사용
  - 팔레트: 기본 룩의 세기. 원본과 룩 적용본을 `CIDissolveTransition`(또는 mix)으로 0~100% 섞기
  - 흑백 스타일: `CIPhotoEffectMono`/`CIColorControls saturation 0` 후 톤 커브
- 룩 값은 참고 스크린샷(`docs/reference/style_*.png`)과 같은 장면을 나란히 찍어 비교하며 맞춤. 숫자는 코드 한 곳(`StylePresets.swift`)에 모아 쉽게 고치게
- **미리보기**: 보정이 보이려면 `AVCaptureVideoPreviewLayer` 대신 `AVCaptureVideoDataOutput` → CIImage → 필터 → `MTKView`(Metal) 렌더링 필요
  - 표준(보정 없음)일 때는 기존 미리보기 레이어를 쓰고, 다른 스타일일 때만 Metal 미리보기로 바꾸는 방식도 가능 (성능·배터리 유리)
  - Metal 미리보기를 쓰면 탭 초점 좌표 변환을 직접 계산해야 함 (미리보기 레이어의 변환 함수를 못 씀)
- **사진**: 촬영된 사진(`fileDataRepresentation`)에 같은 필터 체인 적용 → 메타데이터 유지해서 저장. 비율 자르기와 같은 단계에서 처리 (자르기 → 스타일 순)
- 스타일 적용 시 자동 지연 처리 끄기, LIVE 끔 (영상 부분 보정 불가)
- 화이트밸런스 직접 조절(gains)은 쓰지 않음 (스타일과 겹쳐서 헷갈림)
- **카메라 색감**(01_SPEC 7-1절)도 같은 필터 경로 사용: 최종 필터 = 카메라 색감(LUT 또는 값) → 스타일. 둘 다 기본/표준이면 필터 없이 기존 미리보기 레이어 사용
- `.cube` LUT 읽기: 텍스트 파싱 → `CIColorCubeWithColorSpace`의 cubeData (오프라인, 번들 파일)

## 5. 비율 (16:9, 1:1 자르기)

- 촬영은 항상 4:3으로 하고, 저장 직전에 가운데 기준으로 자름
- `fileDataRepresentation()` → `CGImageSource`로 읽기 → **방향(orientation)을 반영한 좌표계에서** 자르기 → `CGImageDestination`에 원본 메타데이터(EXIF, GPS 등)와 함께 같은 형식(HEIF/JPEG)으로 쓰기
- 자동 지연 처리(`isAutoDeferredPhotoDeliveryEnabled`)를 쓰면 처리 전 사진은 자를 수 없음 → 비율이 4:3이 아닐 때는 지연 처리 끄기
- 비율이 4:3이 아니면 LIVE 끔 (CLAUDE.md 6절 임시 기본값)
- 미리보기: 같은 비율의 프레임 사각형을 계산해 바깥을 검게 가리고, 레이어도 그 사각형 기준으로 배치

## 6. 레이어 좌표 · 순서

- 레이어 위치·크기는 **촬영 프레임 사각형 기준 0~1 비율 값**으로 저장 → 비율이 바뀌거나 화면 크기가 달라도 같은 자리에 유지
- 레이어 뷰는 촬영 프레임 사각형으로 잘라서(clip) 표시
- ZStack 순서 고정: MY 레이어 → 포즈 레이어 (선택 순서와 무관하게 포즈가 항상 위). `zIndex`도 명시
- 투명도는 레이어 뷰의 `.opacity()`로만 적용 (저장 경로와 무관)
- 레이어가 손가락 동작을 받는 동안에는 탭 초점이 동작하지 않게 우선순위 정리

## 7. 저장 · 사진 앱

- 저장: `PHPhotoLibrary.shared().performChanges` + `PHAssetCreationRequest`. 권한은 추가 전용(`.addOnly`)만 요청
- 라이브 포토: `.photo` 리소스 + `.pairedVideo` 리소스를 함께 추가
- 썸네일: 사진 앱 읽기 권한을 받지 않기 위해, 방금 찍은 사진의 작은 이미지를 앱 안에 캐시해서 표시
- 사진 앱 열기: `UIApplication.shared.open(URL(string: "photos-redirect://")!)` — 애플 공식 문서에 없는 주소지만 개인용 앱이라 사용. 열리지 않으면 아무 동작 안 함

## 8. MY 사진 고르기

- MY 버튼 꾹 누르기로 시스템 피커 열기: SwiftUI `.photosPicker(isPresented:selection:maxSelectionCount:selectionBehavior: .ordered, matching: .images)` — 여러 장 + 선택 순서 번호 + 오른쪽 위 "추가" 버튼이 시스템 기본으로 나옴
- 결과 배열 순서 = 선택 순서 → 역순으로 목록 앞에 끼워 넣어 1번이 맨 왼쪽이 되게
- `loadTransferable(type: Data.self)` → 앱 Documents/MY/ 에 `UUID.jpg`로 저장 + 목록 썸네일(약 200px) 따로 저장
- 목록 정보(순서, 파일 이름, 원본 `itemIdentifier`)는 JSON 파일로 저장. 같은 `itemIdentifier`를 다시 추가하면 중복 대신 맨 앞으로 이동
- 사진첩 읽기 권한 불필요
- 버튼 탭과 꾹 누르기 구분: `onTapGesture` + `onLongPressGesture(minimumDuration: 0.5)`를 같이 쓰되, 꾹 누르기가 인식되면 탭이 실행되지 않게 처리. 포즈 버튼에는 꾹 누르기 제스처를 달지 않음
- 오프라인에서 iCloud에만 있는 원본은 불러오기 실패 가능 → 실패 시 "이 사진은 지금 불러올 수 없어요 (iCloud)" 짧은 안내

## 9. 버튼 · 카메라 컨트롤

- 음량 버튼과 카메라 컨트롤 누르기: SwiftUI `.onCameraCaptureEvent` (iOS 18, AVCam에 있음)
- 카메라 컨트롤 밀기(배율): `AVCaptureSystemZoomSlider`를 세션 컨트롤에 추가 (AVCam에 있음)

## 10. 모드

- 슬로 모션: `videoSupportedFrameRateRanges` 최대 240 이상인 포맷 선택 → `activeFormat`, `activeVideoMin/MaxFrameDuration` 설정 후 녹화. 사진 앱이 슬로 모션으로 인식하는지 실기기 확인, 안 되면 저장 시 재생 속도를 늘려 저장
- 타임랩스: `AVCaptureVideoDataOutput`에서 일정 간격 프레임만 골라 `AVAssetWriter`로 30fps 영상 작성
- 비디오 해상도·FPS: 지원 포맷에서 4K/HD × 24/30/60 조합만 표시

## 11. 수평계

- CoreMotion `deviceMotion.gravity`로 기울기 계산. 수평 ±약 1° 안에서 가운데 선이 노랗게 일치 (기본 카메라 모양 참고)

## 12. 전면 카메라

- 미리보기는 거울 반전. 사진 출력 연결의 `isVideoMirrored`로 저장본 반전 여부 결정
- 화면 플래시: 촬영 순간 흰 화면 + 화면 밝기 최대 → 촬영 후 원래 밝기로

## 13. 시뮬레이터

- `#if targetEnvironment(simulator)`: 카메라 세션 대신 샘플 이미지를 미리보기에 표시, 셔터는 샘플 이미지 저장 흉내
- 카메라 하드웨어 관련 기능(배율, 초점, 접사 등)은 시뮬레이터에서 버튼만 반응하게 둠

## 14. 설정 화면

- 스위치 값(격자, 중심점): `@AppStorage`
- 포즈 순서: 포즈 파일 이름 배열을 JSON으로 저장. 새 포즈가 번들에 추가되면 목록 끝에 붙이고, 없어진 포즈는 무시
- MY 목록: 기존 MY 목록 JSON을 그대로 사용 (카메라 화면과 설정 화면이 같은 저장소 객체를 공유)
- 정렬·삭제: `List` + `ForEach` + `.onMove` / `.onDelete` + `EditButton`
- 설정 화면 진입: 초기화 버튼 꾹 누르기 → `.fullScreenCover`, 안에 `NavigationStack`

## 15. 카메라 컨트롤 버튼으로 앱 열기 (선택, 마무리 단계)

- iOS 18: 아이폰 설정 > 카메라 > 카메라 컨트롤에서 이 앱을 고르면 **측면 버튼 한 번 누르기**로 앱이 열림 (잠금화면 포함). 여는 동작은 iOS가 정하므로 "길게 누르기로 열기"는 불가
- 조건: 잠금화면 카메라 확장(LockedCameraCapture) + 카메라 컨트롤 위젯(CameraCaptureIntent). AVCam 예제에 이미 포함
- 무료 Personal Team으로 확장 서명이 되는지 0단계에서 확인. 안 되면 확장 타깃을 빼고 진행
- 앱 안에서: 누르기 = 촬영, 길게 누르기 = 동영상 녹화, 밀기 = 배율 (`onCameraCaptureEvent`, `AVCaptureSystemZoomSlider`)

## 16. 앱 아이콘 바꾸기

- `UIApplication.shared.setAlternateIconName("AppIcon-01")`, 기본으로 되돌릴 때는 `nil`. 현재 값은 `alternateIconName`
- `supportsAlternateIcons` 확인. 무료 Personal Team 설치에서도 동작, 오프라인 동작
- Xcode 빌드 설정: `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`에 `AppIcon-01 … AppIcon-10` (또는 "Include All App Icon Assets" 켜기)
- 목록 썸네일은 아이콘 세트를 직접 읽을 수 없으므로, 같은 그림의 작은 미리보기 이미지(`IconPreview-01` 등, 180px)를 일반 이미지로 함께 넣음
- 바꾼 직후 iOS가 알림창을 띄움 (막을 수 없음). 알림이 뜨는 동안 카메라 화면이 아니라 설정 화면이므로 문제없음
