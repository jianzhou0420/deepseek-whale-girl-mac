# 🐳 DeepSeek Whale Girl · mascotte de bureau pour Mac

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Une fille-baleine DeepSeek qui vit en bas de l'écran de votre Mac. Elle court partout, suit votre curseur du regard, parle quand vous cliquez sur elle, pleure quand vous la soulevez et, quand elle s'ennuie, se lance dans une « réflexion approfondie ». Il lui arrive aussi de brandir une pancarte « 区 » en demandant ce que veut dire « 凶 ».

![Aperçu](docs/preview.png)

> Ceci est un projet de fans non officiel. Il n'est ni affilié à DeepSeek ni approuvé par DeepSeek.

## Installation

Nécessite macOS 13 ou une version ultérieure. Fonctionne sur les Mac Apple Silicon et Intel.

### Option 1 : installation en une ligne (recommandée)

Ouvrez Terminal, collez cette ligne et appuyez sur Retour :

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

L'app est installée dans `~/Applications`, puis lancée.

### Option 2 : téléchargement manuel

1. Téléchargez `WhaleGirl-macOS.zip` depuis les [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) et double-cliquez dessus pour le décompresser.
2. Glissez `WhaleGirl.app` dans le dossier Applications.
3. À la première ouverture, macOS indique qu'il ne peut pas vérifier le développeur, car l'app n'est pas notarisée. Pour l'ouvrir quand même :
   - Faites un **clic droit** sur `WhaleGirl.app`, choisissez **Ouvrir**, puis cliquez à nouveau sur **Ouvrir**.
   - Si elle ne s'ouvre toujours pas, exécutez ceci dans Terminal :
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### Option 3 : compiler depuis les sources

Il vous faut Xcode ou les outils en ligne de commande Xcode (sinon, lancez `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## Comment jouer

Elle parle chinois. Ses répliques sont des clins d'œil à DeepSeek, comme « 服务器繁忙，请稍后再试 » (« Le serveur est occupé, veuillez réessayer plus tard »).

| Vous | Elle |
|---|---|
| Bougez la souris | Tourne la tête vers le curseur (16 directions) |
| Cliquez sur elle | Fait coucou, sautille, dit quelque chose ou se met à « réfléchir en profondeur » |
| Faites-la glisser | Pleure « pose-moi ! » et retombe au sol quand vous la lâchez |
| Clic droit sur elle, ou 🐳 dans la barre des menus | Menu : parler, réfléchir, montrer la pancarte, dormir, revenir au centre, quitter |
| Laissez-la tranquille | Se promène, rêvasse, fait la sieste et montre sa pancarte |

Elle ne vous gêne pas : les clics sur la zone transparente autour d'elle passent directement à la fenêtre située derrière.

**Quitter** : Cliquez sur 🐳 dans la barre des menus et choisissez 退出鲸鱼娘 (Quitter). L'app n'a pas d'icône dans le Dock, donc ⌘Q ne fonctionne pas.

**La rouvrir** : Cherchez `WhaleGirl` dans Spotlight (⌘ Espace).

**Désinstaller** : Quittez-la, puis placez `WhaleGirl.app` dans la Corbeille.

## La personnaliser

Tout le code tient dans un seul fichier, [`main.swift`](main.swift) :

- Ses répliques et les textes du menu sont dans `enum Lines`.
- Les images d'animation utilisées pour chaque état sont dans `struct Anim`.
- La fréquence à laquelle elle marche, dort et parle est définie dans `decide()`.

Après vos modifications, relancez `./build.sh`.

## Crédits et licence

- Planche d'animation du personnage par [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (licence MIT). Voir [`assets/SOURCE.md`](assets/SOURCE.md) et [`assets/LICENSE`](assets/LICENSE).
- Le code de ce projet est publié sous [licence MIT](LICENSE).
- Le nom et le logo DeepSeek appartiennent à leurs propriétaires respectifs.
