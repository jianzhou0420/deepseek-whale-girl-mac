# 🐳 DeepSeek 고래 소녀 · Mac 데스크톱 펫

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **한국어** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Mac 화면 아래쪽에 사는 DeepSeek 고래 소녀입니다. 여기저기 뛰어다니고, 마우스 커서를 눈으로 따라가고, 클릭하면 말을 하고, 집어 들면 울고, 심심하면 "딥 씽킹"을 합니다. 가끔은 "区"라고 쓴 팻말을 들고 "凶"이 무슨 뜻이냐고 묻기도 해요.

![미리보기](docs/preview.png)

> 커뮤니티에서 만든 비공식 팬 프로젝트입니다. DeepSeek와는 관련이 없으며 보증을 받지 않았습니다.

## 설치

macOS 13 이상이 필요합니다. Apple 실리콘과 Intel Mac 모두에서 작동합니다.

### 방법 1: 명령어 한 줄로 설치 (추천)

"터미널"을 열고 아래 한 줄을 붙여 넣은 뒤 Return 키를 누르세요.

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

앱이 `~/Applications`에 설치되고 바로 실행됩니다.

### 방법 2: 직접 다운로드

1. [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest)에서 `WhaleGirl-macOS.zip`을 다운로드한 뒤 더블 클릭해 압축을 풉니다.
2. `WhaleGirl.app`을 "응용 프로그램" 폴더로 드래그합니다.
3. 처음 열 때 앱이 공증되지 않았기 때문에 macOS가 "개발자를 확인할 수 없습니다"라고 표시합니다. 이렇게 하면 열 수 있습니다.
   - `WhaleGirl.app`을 **오른쪽 클릭**하고 "열기"를 선택한 다음, 다시 "열기"를 클릭합니다.
   - 그래도 열리지 않으면 터미널에서 다음을 실행합니다.
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### 방법 3: 소스에서 직접 빌드

Xcode 또는 Xcode 명령어 도구가 필요합니다. 없다면 `xcode-select --install`을 실행하세요.

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## 사용법

대사는 중국어입니다. 대부분 DeepSeek 밈으로, 예를 들어 "服务器繁忙，请稍后再试"(서버가 혼잡합니다. 잠시 후 다시 시도해 주세요) 같은 말을 합니다.

| 이렇게 하면 | 이렇게 반응해요 |
|---|---|
| 마우스 움직이기 | 커서 쪽으로 고개를 돌림 (16방향) |
| 클릭하기 | 손 흔들기, 깡충 뛰기, 말하기, 또는 "딥 씽킹" 시작 |
| 드래그하기 | "내려 줘!" 하고 울다가, 놓으면 바닥으로 떨어짐 |
| 오른쪽 클릭, 또는 메뉴 막대의 🐳 | 메뉴: 말하기, 생각하기, 팻말 들기, 잠자기, 화면 가운데로 이동, 종료 |
| 가만히 두기 | 돌아다니고, 멍때리고, 낮잠 자고, 팻말을 듦 |

작업을 방해하지 않습니다. 몸 주변의 투명한 부분을 클릭하면 뒤에 있는 창으로 그대로 전달됩니다.

**종료**: 메뉴 막대의 🐳을 클릭하고 "退出鲸鱼娘"(종료)를 선택하세요. Dock 아이콘이 없어서 ⌘Q는 작동하지 않습니다.

**다시 열기**: Spotlight(⌘ + 스페이스)에서 `WhaleGirl`을 검색하세요.

**삭제**: 종료한 다음 `WhaleGirl.app`을 휴지통으로 옮기면 됩니다.

## 마음대로 바꾸기

모든 코드는 [`main.swift`](main.swift) 파일 하나에 들어 있습니다.

- 대사와 메뉴 문구는 `enum Lines`에 있습니다.
- 상태마다 사용하는 애니메이션 프레임은 `struct Anim`에 있습니다.
- 걷기, 잠자기, 말하기 빈도는 `decide()`에서 정합니다.

수정한 뒤 `./build.sh`를 다시 실행하세요.

## 크레디트 및 라이선스

- 캐릭터 애니메이션 아틀라스: [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT 라이선스). 자세한 내용은 [`assets/SOURCE.md`](assets/SOURCE.md)와 [`assets/LICENSE`](assets/LICENSE)를 참고하세요.
- 이 프로젝트의 코드는 [MIT 라이선스](LICENSE)로 공개되어 있습니다.
- DeepSeek 이름과 로고의 권리는 각 권리자에게 있습니다.
