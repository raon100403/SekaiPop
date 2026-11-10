# SekaiPop Fedora 설치 지원 스크립트 (비공식)

원본: https://github.com/Blapples/SekaiPop

**대상:** Fedora Workstation 44/45(일반 RPM/DNF 환경), Hyprland 0.55 이상, Quickshell. Silverblue/Kinoite 같은 **rpm-ostree 기반 Atomic 환경은 지원하지 않습니다.** 기존 GNOME 데스크톱을 제거하지 않으며, Hyprland 로그인 세션을 추가하는 방식입니다.

이 프로젝트의 원래 `install.sh` / `install-deps.sh`는 Arch Linux의 `pacman`, AUR을 전제로 합니다. 이 보조 스크립트는 **Fedora 의존성만 DNF로 설치**하고, SekaiPop 본체·백업·모니터 설정 작업은 원본 `install.sh --no-deps`에 맡깁니다. 마지막으로 원본이 Fedora에서 놓치는 **Qt 셰이더 재컴파일**을 처리합니다.

## Fedora 44 + Hyprland가 이미 설치된 경우 (권장 경로)

**Hyprland를 재설치하거나 외부 COPR을 활성화하지 마세요.** 먼저 `Hyprland --version`으로 **0.55 이상**인지 확인합니다. 그보다 낮으면 바로 설치하지 말고 Hyprland 업그레이드 방법부터 정해야 합니다.

이미 사용 중인 Waybar/Quickshell과 바인딩 등을 **한 글자도 바꾸지 않는 초기 시험 설치**는 다음과 같습니다. 다운로드한 스크립트가 있는 디렉터리에서 실행합니다.

```bash
chmod +x ./install-sekaipop-fedora.sh
./install-sekaipop-fedora.sh --dry-run --hypr skip --no-services
./install-sekaipop-fedora.sh --hypr skip --no-services
```

- `--hypr skip`: `~/.config/hypr`를 변경하지 않습니다. SekaiPop 자동실행도 설치하지 않습니다.
- `--no-services`: 이미 작동 중인 NetworkManager/블루투스/PipeWire 서비스 구성을 바꾸지 않습니다.
- `--enable-copr` 옵션을 넣지 마세요. **기존 Hyprland가 0.55 이상이라면 불필요**합니다.
- 먼저 `qs -c sekaipop`을 실행하여 수동으로 확인합니다. 기존 바/위젯과 겹치면 테스트 후 어느 쪽을 유지할지 정하세요.
- 나중에 자동실행을 붙이려면 `--hypr merge --no-services`로 재실행할 수 있습니다. 이때 설정 파일 백업이 만들어지고 로더가 추가됩니다.

이 절은 **일반 DNF/RPM 기반 Fedora 44**용입니다. Atomic 변형판에는 사용하지 마세요.

## 빠른 설치

1. `install-sekaipop-fedora.sh`를 다운로드하여 터미널에서 해당 위치로 이동합니다.
2. **설치 전 반드시 드라이런과 내용 검토를 진행하세요.** COPR 사용을 명시적으로 선택해야 Hyprland를 자동으로 준비할 수 있습니다.

```bash
chmod +x ./install-sekaipop-fedora.sh
./install-sekaipop-fedora.sh --dry-run --enable-copr
```

3. 출력에 문제가 없다면 설치합니다(일반 사용자 계정에서 실행하고, `sudo`로 스크립트를 실행하지 마세요).

```bash
./install-sekaipop-fedora.sh --enable-copr
```

기존 Hyprland 설정 파일이 있으면 **자동으로 merge** 모드(기존 설정을 백업한 뒤 시작 명령만 추가)를 사용하고, 설정 파일이 없는 신규 설치면 **full** 모드(원본 Hyprland 프리셋 설치)를 사용합니다. `--enable-copr`는 Fedora 공식 저장소가 아닌 `ashbuk/Hyprland-Fedora` COPR을 활성화합니다. 원치 않으면 COPR 옵션 없이, Hyprland 0.55 이상을 직접 준비하세요.

로그아웃 후 로그인 화면에서 **plain Hyprland** 세션(uwsm 아님)을 선택합니다. 기존 Hyprland 안에서 수동으로 시작할 때는:

```bash
qs -c sekaipop
```

## 기존 Hyprland를 최대한 유지할 때

```bash
./install-sekaipop-fedora.sh --enable-copr --hypr merge
```

이 모드는 `~/.config/hypr/hyprland.lua` 또는 `hyprland.conf`에 SekaiPop 자동실행용 로더 한 줄을 추가하고, 변경 전 원본 파일을 `*.sekaipop-backup-날짜` 이름으로 보존합니다. Hyprland 설정이 이미 다른 Quickshell을 실행하도록 구성돼 있다면 중복 실행을 직접 확인하세요.

만약 Hyprland 설정은 직접 관리하고 싶다면:

```bash
./install-sekaipop-fedora.sh --enable-copr --hypr skip
```

`skip`은 Hyprland 설정을 변경하지 않습니다. `qs -c sekaipop`을 직접 실행하거나 자동 시작 설정을 별도로 추가해야 합니다.

## 사용 가능한 옵션

| 옵션 | 설명 |
|---|---|
| `--dry-run` | 파일·패키지·서비스를 변경하지 않고 계획 표시 |
| `--enable-copr` | `ashbuk/Hyprland-Fedora` COPR 활성화(외부 저장소) |
| `--copr nett00n/hyprland` | 다른 커뮤니티 Hyprland COPR 사용 |
| `--hypr auto\|full\|merge\|skip` | 설정 통합 방식 선택 (`auto`가 기본값) |
| `--source /path/to/SekaiPop` | 로컬에 이미 받은 원본 소스 사용 |
| `--no-features` | 선택 기능용 패키지 설치 생략 |
| `--no-fonts` | 사용자 폰트 다운로드 생략 |
| `--no-services` | systemd 서비스 설정 생략 |
| `--no-packages` | DNF 패키지 설치 생략 |
| `--yes` | DNF 및 원본 설치기의 확인 자동 승인 (COPR은 별도 옵션이 있어야만 활성화됨) |

## 주의 사항과 알려진 제약

- **Fedora 실기기에서 설치 검증을 마친 배포판은 아닙니다.** `bash -n`과 비-Fedora 환경의 `--dry-run`만 통과시켰습니다. Fedora 버전, COPR 빌드 상황, GNOME/KDE 설정에 따라 실제 설치 실패 가능성이 있습니다.
- **Hyprland 0.55 이상이 필수**입니다. 원본 설정은 `hyprland.lua`를 사용합니다. Fedora 44 기본 저장소만으로는 해당 버전을 확보하기 어려워 외부 COPR 또는 직접 빌드가 필요할 수 있습니다.
- **COPR은 제3자 소프트웨어 공급원**입니다. 외부 저장소 활성화는 향후 DNF 업그레이드 결과에도 영향을 미칠 수 있습니다. 패키지 출처를 확인한 후 실행하세요.
- 이 스크립트는 GPU 드라이버를 설치하거나 변경하지 않습니다. 특히 NVIDIA는 Hyprland 작동을 별도 확인하세요.
- 일부 기능(녹화·음악 인식·밝기·Hyprland 유틸리티·포털·클립보드 등)은 Fedora 저장소에서 패키지가 제공되지 않으면 자동 생략되어 동작하지 않을 수 있습니다. **핵심 설치 성공이 전체 기능의 호환을 보장하지는 않습니다.**
- SekaiPop의 **Arch용 업데이트 표시/패키지 관리 명령은 아직 Fedora용으로 포팅하지 않았습니다.** 원본 코드가 업데이트되면 후속 수정이 필요할 수도 있습니다.
- 셰이더는 Fedora Qt 버전이 6.12 미만일 경우 설치본의 `shaders/compile-shaders.sh`를 실행하여 다시 컴파일합니다. 해당 작업이 실패하면 전체 기능을 장담할 수 없습니다.
- Google Sans Flex는 원본이 쓰는 `end-4/google-sans-flex`와 Material Symbols Rounded는 Google 공식 아이콘 저장소에서 가져옵니다. 네트워크가 막히면 폰트만 누락될 수 있습니다.
- 원본의 `check-deps.sh`는 Arch 전용이므로 Fedora 패키지 누락을 정확히 진단하지 못합니다.
- 원본의 화면 검색/Google Lens 연동은 잘린 스크린샷을 **외부 업로드 서버에 전송**하는 기능이 있으니 민감한 화면에서는 사용하지 마세요.

## 문제 진단

```bash
Hyprland --version       # 0.55 이상 확인
qs -c sekaipop log       # Quickshell 오류 로그
hyprctl configerrors    # Hyprland 설정 오류
rpm -q quickshell qt6-qtbase qt6-qtshadertools
```

Qt 애니메이션이나 월페이퍼 전환이 보이지 않는다면:

```bash
bash ~/.config/quickshell/sekaipop/shaders/compile-shaders.sh
```

Fedora의 Qt 셰이더 도구는 `/usr/lib64/qt6/bin/qsb` 또는 `/usr/bin/qsb-qt6`에 설치될 수 있습니다.

## 되돌리기

- **`--hypr merge`:** 변경된 `hyprland.lua` 또는 `hyprland.conf`의 `*.sekaipop-backup-타임스탬프` 백업 파일이 있습니다. 백업한 시점 이후 추가한 사용자 설정이 있다면 먼저 수동으로 비교한 후 원래 파일로 복원하세요. `sekaipop_session.lua` / `sekaipop_session.conf`도 필요 없으면 지울 수 있습니다.
- **`--hypr full`:** 원본 설치기가 생성한 `~/.config/hypr.sekaipop-backup-*`를 보존합니다. 복원 명령은 `bash ~/.cache/sekaipop-fedora/SekaiPop/install.sh --restore`입니다. (`--source`로 설치했다면 그 로컬 소스의 `install.sh --restore`를 사용하세요.)
- **SekaiPop 본체만 제거:** `~/.config/quickshell/sekaipop` 폴더를 삭제하되, 설정 파일의 자동실행 줄도 제거해야 합니다. 사용자 개인 설정은 `~/.local/state/sekaipop`에 따로 남습니다.
- DNF로 설치된 패키지와 활성화된 COPR은 자동 삭제하지 않습니다. 필요 시 `sudo dnf copr disable ashbuk/Hyprland-Fedora`를 사용하고, `dnf history`에서 설치 트랜잭션을 확인하세요.

## 검증 범위

- 원본 README 및 `install.sh`, `install-deps.sh`, `compile-shaders.sh`에서 필요한 버전과 동작 경로 검토
- Fedora 공식 패키지 목록에서 `quickshell` / `qt6-qtshadertools` / `dnf5-plugins` 확인
- Bash 구문 검사 및 비-Fedora 비특권 사용자 드라이런 확인
- **실제 Fedora에서 DNF 설치 및 Wayland 로그인 동작은 미검증**

프로젝트 라이선스는 GPL-3.0입니다. 이 보조 스크립트 또한 GPL-3.0-or-later로 제공합니다.
