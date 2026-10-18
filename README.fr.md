# 🐋 WhaleSeek · une fille baleine qui suit votre usage de l'IA sur Mac

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Une fille-baleine DeepSeek qui vit dans un coin de l'écran de votre Mac. Sa bulle affiche votre solde DeepSeek, les dépenses du jour et un compte à rebours jusqu'au prochain passage heures pleines / heures creuses. C'est un portage natif pour Mac du [widget de solde DSH](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget), sans besoin de DeepSeek Harness.

![Aperçu](docs/preview.png)

![10 gestes générés par IA](docs/animations.gif)

> Ceci est un projet de fans non officiel. Il n'est ni affilié à DeepSeek ni approuvé par DeepSeek.
>
> Anciennement WhaleBalance ; renommée WhaleSeek à partir de la v0.3.0. Lors de la mise à jour, les réglages, le registre et les clés d'API sont migrés automatiquement.

## Fonctionnalités

- **Solde** : interroge votre solde DeepSeek avec votre clé d'API, se met à jour toutes les 60 secondes et quand vous cliquez sur elle. Solde total, crédit offert et crédit rechargé peuvent s'afficher séparément.
- **Dépenses du jour** : additionne les baisses de solde comme dépenses. Les recharges sont enregistrées à part et n'annulent jamais les dépenses, et vous pouvez corriger n'importe quel jour à la main. Chaque clé d'API a son propre registre.
- **Fenêtre de comptes** : aujourd'hui, les 7 derniers jours ou tout l'historique, avec le détail des entrées, la recherche par date ou par modèle, et la répartition des dépenses.
- **Heures pleines / creuses** : les jours ouvrés de 9 h à 12 h et de 14 h à 18 h (heure de Pékin) sont pleins ; les week-ends et jours fériés chinois sont creux toute la journée. Cinq styles d'affichage, dont un compte à rebours en direct.
- **Bulles personnalisables** : séquence de clics, choix A/B pondéré, et modules de texte, liens, phrases aléatoires, images, solde, dépenses du jour, état plein / creux, autres fournisseurs et usage Codex. Chaque module a sa propre taille, ses couleurs, son dégradé animé et sa police.
- **Alertes** : alertes de solde bas et de budget quotidien, au contenu modifiable.
- **Autres fournisseurs** : 34 modèles, dont les soldes OpenRouter, Kimi, StepFun et Novita, les quotas d'abonnement Zhipu, Kimi Coding, MiniMax et OpenCode Go, et les passerelles compatibles OpenAI. Les clés ne partent que vers le point d'accès officiel de chaque modèle, sauf si vous en autorisez un autre.
- **Statistiques Codex** : lit les journaux de session Codex locaux pour compter les tokens et les fenêtres d'abonnement, sans accès réseau.
- **App Mac native** : déplacez-la où vous voulez ; elle s'aimante aux bords de l'écran et se retourne quand elle est collée à gauche. Solde dans la barre des menus, lancement à l'ouverture de session et clés d'API dans le trousseau.
- **Abonnements et coûts d'API** : détecte automatiquement cswap (usage sur 5 heures, 7 jours, dépenses supplémentaires et par modèle pour chaque compte Claude), l'abonnement et les tokens de Claude Code, et l'abonnement ChatGPT derrière Codex. Avec une clé Admin d'organisation, affiche aussi les coûts des API OpenAI et Claude.
- **Lecture automatique** : toutes les 1 à 3 minutes, elle fait quelque chose d'elle-même : un petit geste, une bulle aléatoire ou un point sur l'utilisation. Chaque geste a 5 répliques assorties qui ne se répètent pas. Elle prévient aussi au passage heures pleines/creuses, ou quand un abonnement dépasse son seuil ou se réinitialise. Elle reste discrète en plein écran, en réunion, quand vous êtes absent et la nuit, et la lecture automatique n'émet jamais de son.
- **Gestes générés par IA** : 10 animations image par image créées par le pipeline graphique (s'étirer, manger, somnoler, taper au clavier, danser, compter de l'argent, etc.), jouées avec les gestes d'origine.

Le coût par tour, le son de fin de tâche, les invites de question et d'approbation et le module de nom de conversation ne sont pas portés. Ils dépendent d'événements internes à DeepSeek Harness, inaccessibles à une app autonome.

## Installation

Nécessite macOS 13 ou une version ultérieure. Fonctionne sur les Mac Apple Silicon et Intel.

### Option 1 : installation en une ligne (recommandée)

Ouvrez Terminal, collez cette ligne et appuyez sur Retour :

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/whaleseek/main/install.sh | bash
```

L'app est installée dans `~/Applications`, puis lancée.

### Option 2 : téléchargement manuel

1. Téléchargez `WhaleSeek-macOS.zip` depuis les [Releases](https://github.com/jianzhou0420/whaleseek/releases/latest) et double-cliquez dessus pour le décompresser.
2. Glissez `WhaleSeek.app` dans le dossier Applications.
3. À la première ouverture, macOS indique qu'il ne peut pas vérifier le développeur, car l'app n'est pas notarisée. Pour l'ouvrir quand même :
   - Faites un **clic droit** sur `WhaleSeek.app`, choisissez **Ouvrir**, puis cliquez à nouveau sur **Ouvrir**.
   - Si elle ne s'ouvre toujours pas, exécutez ceci dans Terminal :
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleSeek.app
     ```

### Option 3 : compiler depuis les sources

Il vous faut Xcode ou les outils en ligne de commande Xcode (sinon, lancez `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/whaleseek.git
cd whaleseek
./build.sh
open WhaleSeek.app
```

Au premier lancement, la fenêtre de réglages s'ouvre. Collez votre clé d'API DeepSeek et enregistrez-la. La clé est stockée uniquement dans le trousseau macOS.

## Utilisation

| Vous | Elle |
|---|---|
| Cliquez sur elle | Met à jour le solde et affiche la bulle du solde |
| Cliquez sur la bulle | Affiche l'élément suivant (phrases et images aléatoires) et se ferme après le dernier |
| Faites-la glisser | La déplace ; elle s'aimante au bord le plus proche quand vous la lâchez |
| Clic droit sur elle, le bouton ⋯ ou 🐳 dans la barre des menus | Menu : taille, sons, bulles, aimantation, comptes, réglages, quitter |

## Chaîne de création d'images

`art-pipeline/` génère de nouvelles poses de la fille-baleine avec la génération d'images intégrée à Codex CLI, en utilisant votre abonnement ChatGPT plutôt qu'une clé d'API. Elle détoure le fond, nettoie les bords, contrôle chaque image, régénère celles qui échouent et installe les bonnes dans la galerie intégrée de l'app. Décrivez les nouvelles poses dans `art-pipeline/assets.json`, puis lancez :

```bash
codex login
./art.sh all
```

`./art.sh anim` génère des animations à partir de `art-pipeline/anims.json` : 6 images par planche, découpées automatiquement, alignées sur les pieds et vérifiées pour leur cohérence. `./art.sh anim-install` les ajoute ensuite à l'app.

Chaque image prend environ 40 secondes. La génération d'images consomme les limites Codex 3 à 5 fois plus vite que le texte.

![Images produites par la chaîne](docs/generated-art.png)

Vous cherchez la mascotte qui se promène sur le bureau de la première version ? Elle est toujours disponible dans la [version v0.0.1](https://github.com/jianzhou0420/whaleseek/releases/tag/v0.0.1).

## Crédits et licence

- La conception des fonctions, les règles de comptabilité, les modèles de fournisseurs et les phrases par défaut sont portés de [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT). Ses images et sons ne sont pas sous licence MIT et ne sont pas utilisés ici.
- Illustrations du personnage par [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT).
- Les images de `assets/generated` ont été produites par la chaîne avec gpt-image-2 d'OpenAI, à partir de ce personnage. Voir [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Le code de ce projet est publié sous [licence MIT](LICENSE).
