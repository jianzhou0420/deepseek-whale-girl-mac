# 🐋 WhaleSeek · ein Walmädchen, das deine KI-Nutzung auf dem Mac im Blick behält

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Ein DeepSeek-Walmädchen, das in einer Ecke deines Mac-Bildschirms wohnt. Ihre Sprechblase zeigt dein DeepSeek-Guthaben, die heutigen Ausgaben und einen Countdown bis zum nächsten Wechsel zwischen Haupt- und Nebenzeit. Es ist eine native Mac-Portierung des [DSH-Guthaben-Widgets](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) und braucht kein DeepSeek Harness.

![Vorschau](docs/preview.png)

![10 KI-generierte Bewegungen](docs/animations.gif)

> Dies ist ein inoffizielles Fanprojekt. Es steht in keiner Verbindung zu DeepSeek und wird nicht von DeepSeek unterstützt.
>
> Früher WhaleBalance; seit v0.0.6 heißt sie WhaleSeek. Beim Update werden Einstellungen, Kassenbuch und API-Schlüssel automatisch übernommen.

## Funktionen

- **Guthaben**: fragt dein DeepSeek-Guthaben mit deinem API-Schlüssel ab, aktualisiert alle 60 Sekunden und beim Anklicken. Gesamtguthaben, Bonus und aufgeladenes Guthaben lassen sich getrennt anzeigen.
- **Heutige Ausgaben**: zählt Guthabenrückgänge als Ausgaben. Aufladungen werden getrennt erfasst und heben Ausgaben nie auf, und jeden Tag kannst du von Hand korrigieren. Jeder API-Schlüssel bekommt ein eigenes Kassenbuch.
- **Kassenbuch-Fenster**: heute, die letzten 7 Tage oder alle Einträge, mit Einzelposten, Suche nach Datum oder Modell und Ausgabenaufteilung.
- **Haupt- / Nebenzeit**: werktags 9–12 und 14–18 Uhr (Pekinger Zeit) ist Hauptzeit; Wochenenden und chinesische Feiertage sind ganztägig Nebenzeit. Fünf Anzeigestile, darunter ein Live-Countdown.
- **Eigene Sprechblasen**: Klickfolge, gewichtete A/B-Auswahl und Module für Text, Links, zufällige Sprüche, Bilder, Guthaben, heutige Ausgaben, Haupt-/Nebenzeit, andere Anbieter und Codex-Nutzung. Jedes Modul hat eigene Größe, Farben, animierten Verlauf und Schrift.
- **Warnungen**: Warnungen bei niedrigem Guthaben und beim Tagesbudget, mit frei bearbeitbarem Inhalt.
- **Andere Anbieter**: 34 Vorlagen, darunter Guthaben von OpenRouter, Kimi, StepFun und Novita, Abo-Kontingente von Zhipu, Kimi Coding, MiniMax und OpenCode Go sowie OpenAI-kompatible Gateways. Schlüssel gehen nur an den offiziellen Endpunkt der jeweiligen Vorlage, außer du erlaubst einen eigenen.
- **Codex-Statistik**: liest lokale Codex-Sitzungsprotokolle für Token-Verbrauch und Abo-Zeitfenster, ganz ohne Netzwerk.
- **Native Mac-App**: zieh sie überallhin; sie rastet an Bildschirmrändern ein und spiegelt sich am linken Rand. Guthaben in der Menüleiste, Start bei der Anmeldung und API-Schlüssel im Schlüsselbund.
- **Abos und API-Kosten**: erkennt automatisch cswap (5-Stunden-, 7-Tage-, Zusatz- und Modellnutzung jedes Claude-Kontos), dein Claude-Code-Abo samt Token-Verbrauch und das ChatGPT-Abo hinter Codex. Mit einem Admin-Schlüssel der Organisation zeigt es auch die Kosten der OpenAI- und Claude-API.
- **Autoplay**: Alle 1–3 Minuten macht sie von selbst etwas: eine kleine Bewegung, eine zufällige Sprechblase oder einen Nutzungsbericht. Jede Bewegung hat 5 passende Sätze, die sich nicht wiederholen. Sie meldet sich auch beim Wechsel zwischen Haupt- und Nebenzeit und wenn ein Abo eine Schwelle überschreitet oder zurückgesetzt wird. Im Vollbild, in Meetings, wenn du weg bist und nachts bleibt sie ruhig, und Autoplay spielt nie Töne ab.
- **KI-generierte Bewegungen**: 10 Einzelbildanimationen aus der Grafik-Pipeline (Strecken, Essen, Dösen, Tippen, Tanzen, Geld zählen und mehr), gemischt mit den ursprünglichen Bewegungen.
- **Mit ihr chatten**: Maus über sie bewegen und auf den Chat-Knopf klicken. Sie antwortet über die DeepSeek-API: frech, aber Guthaben, heutige Ausgaben und Abo-Auslastung nennt sie korrekt. Mit „innere Stimme“ zeigt sie zusätzlich eine Zeile mit ihren eigentlichen Gedanken. Auf Wunsch spricht sie beim Autoplay auch von sich aus (standardmäßig aus). Beim Chatten werden Persona, Guthaben, heutige Ausgaben, Abo-Prozente und die letzten Nachrichten an api.deepseek.com gesendet und von deinem DeepSeek-Guthaben abgerechnet; der Verlauf bleibt auf deinem Mac.

Nicht portiert sind Kosten pro Runde, der Ton bei Aufgabenende, Hinweise zu Rückfragen und Freigaben sowie das Modul für den Gesprächsnamen. Sie hängen von internen Ereignissen in DeepSeek Harness ab, die eine eigenständige App nicht sieht.

## Installation

Benötigt macOS 13 oder neuer. Läuft auf Macs mit Apple Silicon und Intel.

### Option 1: Installation mit einer Zeile (empfohlen)

Öffne das Terminal, füge diese Zeile ein und drücke die Eingabetaste:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/whaleseek/main/install.sh | bash
```

Die App wird in `~/Applications` installiert und gestartet.

### Option 2: Manuell herunterladen

1. Lade `WhaleSeek-macOS.zip` unter [Releases](https://github.com/jianzhou0420/whaleseek/releases/latest) herunter und entpacke die Datei per Doppelklick.
2. Ziehe `WhaleSeek.app` in den Ordner „Programme“.
3. Beim ersten Öffnen meldet macOS, dass der Entwickler nicht überprüft werden kann, weil die App nicht notarisiert ist. So öffnest du sie trotzdem:
   - Klicke mit der **rechten Maustaste** auf `WhaleSeek.app`, wähle **Öffnen** und klicke dann erneut auf **Öffnen**.
   - Falls sie sich immer noch nicht öffnet, führe im Terminal Folgendes aus:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleSeek.app
     ```

### Option 3: Aus dem Quellcode bauen

Du brauchst Xcode oder die Xcode-Befehlszeilentools (falls nicht vorhanden: `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/whaleseek.git
cd whaleseek
./build.sh
open WhaleSeek.app
```

Beim ersten Start öffnet sich das Einstellungsfenster. Füge deinen DeepSeek-API-Schlüssel ein und speichere ihn. Der Schlüssel liegt nur im macOS-Schlüsselbund.

## Bedienung

| Du | Sie |
|---|---|
| Sie anklicken | Aktualisiert das Guthaben und zeigt die Guthaben-Sprechblase |
| Sprechblase anklicken | Zeigt den nächsten Eintrag (zufällige Sprüche und Bilder) und schließt nach dem letzten |
| Sie ziehen | Verschiebt sie; beim Loslassen rastet sie am nächsten Rand ein |
| Chat-Knopf (beim Überfahren) oder Menüpunkt 「和鲸鱼娘聊天」 | Chatfenster öffnen |
| Rechtsklick auf sie, die ⋯-Taste oder 🐳 in der Menüleiste | Menü: Größe, Töne, Sprechblasen, Einrasten, Kassenbuch, Einstellungen, Beenden |

## Grafik-Pipeline

`art-pipeline/` erzeugt neue Posen des Walmädchens mit der in Codex CLI eingebauten Bildgenerierung und nutzt dein ChatGPT-Abo statt eines API-Schlüssels. Sie stellt den Hintergrund frei, säubert die Kanten, prüft jedes Bild, erzeugt Fehlschläge neu und übernimmt gelungene Bilder in die eingebaute Galerie der App. Trag neue Posen in `art-pipeline/assets.json` ein und führe aus:

```bash
codex login
./art.sh all
```

`./art.sh anim` erzeugt Einzelbildanimationen aus `art-pipeline/anims.json`: 6 Bilder pro Grafik, automatisch zerlegt, an den Füßen ausgerichtet und auf Einheitlichkeit geprüft. `./art.sh anim-install` fügt sie dann der App hinzu.

Ein Bild dauert etwa 40 Sekunden. Bildgenerierung verbraucht Codex-Kontingent 3–5-mal schneller als Text.

![Von der Pipeline erzeugte Bilder](docs/generated-art.png)

Suchst du das herumlaufende Desktop-Maskottchen aus der ersten Version? Es gibt es weiterhin im [Release v0.0.1](https://github.com/jianzhou0420/whaleseek/releases/tag/v0.0.1).

## Credits und Lizenz

- Funktionsdesign, Buchungsregeln, Anbietervorlagen und Standardsprüche sind von [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT) portiert. Dessen Bilder und Töne stehen nicht unter MIT und werden hier nicht verwendet.
- Figurengrafik von [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT).
- Die Bilder in `assets/generated` hat die Pipeline mit OpenAIs gpt-image-2 nach dieser Figur als Vorlage erzeugt. Siehe [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Der Code dieses Projekts steht unter der [MIT-Lizenz](LICENSE).
