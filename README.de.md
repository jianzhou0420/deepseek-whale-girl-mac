# 🐳 DeepSeek Whale Girl · Desktop-Maskottchen für den Mac

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Ein DeepSeek-Walmädchen, das am unteren Rand deines Mac-Bildschirms wohnt. Sie rennt herum, folgt deinem Mauszeiger mit den Augen, redet, wenn du sie anklickst, weint, wenn du sie hochhebst, und verfällt in „tiefes Nachdenken“, wenn ihr langweilig ist. Manchmal hält sie ein Schild mit „区“ hoch und fragt, was „凶“ bedeutet.

![Vorschau](docs/preview.png)

> Dies ist ein inoffizielles Fanprojekt. Es steht in keiner Verbindung zu DeepSeek und wird nicht von DeepSeek unterstützt.

## Installation

Benötigt macOS 13 oder neuer. Läuft auf Macs mit Apple Silicon und Intel.

### Option 1: Installation mit einer Zeile (empfohlen)

Öffne das Terminal, füge diese Zeile ein und drücke die Eingabetaste:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

Die App wird in `~/Applications` installiert und gestartet.

### Option 2: Manuell herunterladen

1. Lade `WhaleGirl-macOS.zip` unter [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) herunter und entpacke die Datei per Doppelklick.
2. Ziehe `WhaleGirl.app` in den Ordner „Programme“.
3. Beim ersten Öffnen meldet macOS, dass der Entwickler nicht überprüft werden kann, weil die App nicht notarisiert ist. So öffnest du sie trotzdem:
   - Klicke mit der **rechten Maustaste** auf `WhaleGirl.app`, wähle **Öffnen** und klicke dann erneut auf **Öffnen**.
   - Falls sie sich immer noch nicht öffnet, führe im Terminal Folgendes aus:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### Option 3: Aus dem Quellcode bauen

Du brauchst Xcode oder die Xcode-Befehlszeilentools (falls nicht vorhanden: `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## So spielst du mit ihr

Sie spricht Chinesisch. Ihre Sprüche sind DeepSeek-Insiderwitze, etwa „服务器繁忙，请稍后再试“ („Der Server ist ausgelastet, bitte versuche es später erneut“).

| Du | Sie |
|---|---|
| Maus bewegen | Dreht den Kopf zum Mauszeiger (16 Richtungen) |
| Anklicken | Winkt, hüpft, sagt etwas oder beginnt mit „tiefem Nachdenken“ |
| Ziehen | Weint „Lass mich runter!“ und fällt beim Loslassen zurück auf den Boden |
| Rechtsklick auf sie oder 🐳 in der Menüleiste | Menü: reden, nachdenken, Schild hochhalten, schlafen, zur Bildschirmmitte, beenden |
| In Ruhe lassen | Läuft herum, träumt vor sich hin, macht ein Nickerchen und hält ihr Schild hoch |

Sie ist dir nicht im Weg. Klicks auf den transparenten Bereich um sie herum gehen direkt an das Fenster dahinter.

**Beenden**: Klicke in der Menüleiste auf 🐳 und wähle 退出鲸鱼娘 (Beenden). Die App hat kein Dock-Symbol, deshalb funktioniert ⌘Q nicht.

**Wieder öffnen**: Suche in Spotlight (⌘ Leertaste) nach `WhaleGirl`.

**Deinstallieren**: Beende sie und lege `WhaleGirl.app` in den Papierkorb.

## Pass sie an

Der gesamte Code steckt in einer einzigen Datei, [`main.swift`](main.swift):

- Ihre Sprüche und die Menütexte stehen in `enum Lines`.
- Welche Animationsbilder jeder Zustand nutzt, steht in `struct Anim`.
- Wie oft sie läuft, schläft und redet, wird in `decide()` festgelegt.

Führe nach Änderungen erneut `./build.sh` aus.

## Credits und Lizenz

- Animations-Atlas der Figur von [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT-Lizenz). Siehe [`assets/SOURCE.md`](assets/SOURCE.md) und [`assets/LICENSE`](assets/LICENSE).
- Der Code dieses Projekts steht unter der [MIT-Lizenz](LICENSE).
- Name und Logo von DeepSeek gehören ihren jeweiligen Inhabern.
