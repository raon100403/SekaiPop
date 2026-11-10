# 점검 기록

- `bash -n install-sekaipop-fedora.sh` : 통과
- 일반 비특권 계정(nobody)에서 `--dry-run --source <mock checkout> --hypr full --enable-copr --no-fonts` : 통과
- 드라이런에서 `dnf`, COPR, 원본 설치, 서비스 변경, Qt 셰이더 재컴파일이 실제 실행되지 않는 흐름 확인
- Fedora 실제 PC 또는 VM에서 통합 설치 테스트 : 미수행
