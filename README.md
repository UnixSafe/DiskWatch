<div align="center">

<img src="docs/icon.png" alt="DiskWatch" width="112">

# DiskWatch

<sub>**Français** · [English](README.en.md)</sub>

**Surveillance de l'espace disque dans la barre de menus macOS,
avec alerte dès qu'un dossier se met à gonfler.**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Sans dépendance](https://img.shields.io/badge/d%C3%A9pendances-aucune-2ea44f)](#architecture)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

<img src="docs/demo.gif" alt="Démonstration de DiskWatch" width="420">

</div>

---

Un disque ne se remplit presque jamais d'un coup. Il se remplit par un dossier
de build oublié, un cache qui ne se purge pas, une image Docker de plus. Quand
l'avertissement de macOS arrive, il est trop tard pour savoir **qui** a pris la
place.

DiskWatch relève l'espace libre toutes les cinq minutes, mesure les dossiers que
vous lui désignez, et vous prévient au moment où l'un d'eux grossit — pas trois
semaines plus tard.

Écrit en Swift, **sans aucune dépendance externe** : AppKit, SwiftUI,
Swift Charts et `du`. 1 892 lignes, un binaire de **903 Ko**.

## Installation

### Image disque

Téléchargez le `.dmg` depuis la [dernière
version](https://github.com/UnixSafe/DiskWatch/releases/latest), puis glissez
DiskWatch dans Applications.

<div align="center">
<img src="docs/install.png" alt="Installation par glisser-déposer" width="430">
</div>

**Au premier lancement, macOS bloquera l'application** : elle est signée « ad
hoc », sans certificat Developer ID. Faites un **clic droit sur DiskWatch.app ▸
Ouvrir**, puis **Ouvrir** dans la boîte de dialogue. Une seule fois.

Si le message dit que l'application est « endommagée », c'est l'attribut de mise
en quarantaine :

```bash
xattr -dr com.apple.quarantine /Applications/DiskWatch.app
```

### Depuis les sources

```bash
git clone https://github.com/UnixSafe/DiskWatch.git
cd DiskWatch
./build.sh                 # installe dans ~/Applications
open ~/Applications/DiskWatch.app
```

`./build.sh /Applications` pour installer ailleurs, `./make-dmg.sh` pour
fabriquer l'image disque. Prérequis : macOS 14 ou plus récent, et les outils en
ligne de commande de Xcode pour `swiftc`.

## Le panneau

<div align="center">
<img src="docs/panel.png" alt="Panneau principal de DiskWatch" width="430">
</div>

Clic gauche sur l'icône de la barre :

- **anneau de capacité** et espace libre, avec le taux d'occupation ;
- **projection de saturation** — « saturation dans 20 j à ce rythme » — affichée
  seulement quand la pente est franchement négative, et jamais au-delà d'un an ;
- **courbe** sur 24 h, 7 jours ou 30 jours, et tendance en Go/h lissée sur 3 h ;
- **variations** à 1 h, 24 h et 7 jours ;
- **dossiers surveillés**, les plus en croissance d'abord puis les plus gros,
  chacun avec sa taille, sa variation et un filet de proportion ;
- **copie du rapport** en texte dans le presse-papiers.

Clic droit : menu contextuel avec réglages, rapport, analyse immédiate, quitter.

La vue 30 jours raconte ce que les 24 heures ne montrent pas — ici une dérive
lente, puis un grand nettoyage :

<div align="center">
<img src="docs/panel-30j.png" alt="Vue sur 30 jours" width="430">
</div>

## Les quatre alertes

| Alerte | Déclenchement | Anti-répétition |
|---|---|---|
| Espace faible | franchissement d'un seuil, 60 / 30 / 15 / 7 Go par défaut | une fois par seuil, réarmé si l'espace remonte de 8 % au-dessus |
| Chute rapide | perte ≥ 5 Go en 1 h | 30 min, et déclenche une mesure des dossiers |
| Baisse continue | perte ≥ 25 Go sur 24 h | 24 h |
| Dossier qui gonfle | un dossier prend ≥ 5 Go entre deux mesures | 6 h par dossier |

La chute rapide enchaîne sur une mesure des dossiers : vous recevez d'abord
« −7 Go en 1 h », puis « Developer/CoreSimulator : +6,8 Go » quelques minutes
plus tard. Le coupable se désigne tout seul.

## Réglages

Quatre onglets, modifiables à chaud — aucun redémarrage n'est nécessaire.

| | |
|---|---|
| <img src="docs/settings-general.png" alt="Onglet Général" width="330"> | <img src="docs/settings-alertes.png" alt="Onglet Alertes" width="330"> |
| **Général** — format de l'icône, fréquence des relevés et des mesures, conservation de l'historique, lancement à l'ouverture de session. | **Alertes** — notifications, seuils d'espace faible (ajout et retrait libres), sensibilité des trois détections de dérive. |
| <img src="docs/settings-dossiers.png" alt="Onglet Dossiers" width="330"> | <img src="docs/settings-apropos.png" alt="Onglet À propos" width="330"> |
| **Dossiers** — liste des chemins surveillés, avec leur taille mesurée. Ajout par un sélecteur Finder. | **À propos** — compteurs, accès au dossier de données, remise à zéro. |

Évitez d'imbriquer un chemin surveillé dans un autre : les tailles seraient
comptées deux fois et les variations deviendraient illisibles.

## L'icône de la barre

<div align="center">
<img src="docs/menubar.png" alt="Formats d'icône : jauge et icône seule" width="320">
</div>

Quatre formats au choix : **jauge** (34 pt, à gauche ci-dessus), **icône seule**
(38 pt, à droite), **icône + nombre**, **icône + taille**. La jauge donne le taux
d'occupation d'un coup d'œil et reste le format par défaut — pour la raison
expliquée juste en dessous.

## Deux limites, dites franchement

### La barre de menus peut être pleine

Quand elle est saturée, macOS attribue une position au nouvel élément mais **ne
le dessine pas**. Ce n'est pas propre à DiskWatch : le symptôme se reproduit avec
une application témoin de douze lignes.

Mesuré sur la machine de développement, barre bien remplie :

| Format | Largeur | Dessiné ? |
|---|---|---|
| Jauge | 34 pt | oui |
| Icône seule | 38 pt | oui |
| Icône + nombre | 73 pt | **non** |

En « icône + nombre », l'accessibilité rapporte bien une position et une taille,
mais `CGWindowListCopyWindowInfo` ne renvoie aucune fenêtre : l'emplacement est
réservé, rien n'est peint. D'où la jauge par défaut. Si l'icône reste invisible,
il faut libérer de la place dans la barre.

Pour savoir si l'élément est dessiné ou seulement alloué :

```bash
osascript -e 'tell application "System Events" to tell process "DiskWatch" \
  to get {position, size} of menu bar item 1 of menu bar 1'
```

Comparez la position obtenue avec celle de l'élément visible le plus à gauche.

### Les bannières portent l'identité de l'Éditeur de script

L'application est signée « ad hoc ». Sans certificat Developer ID, macOS
n'accorde pas l'autorisation `UNUserNotificationCenter` et le code retombe sur
`osascript`. Les alertes arrivent normalement, seul l'habillage est faux.

Avec un certificat, remplacez `codesign --force --sign -` par votre identité
dans `build.sh` : le code bascule seul sur l'API native, l'autorisation étant
relue à chaque envoi.

## Permissions

La mesure des dossiers lit `~/Documents`, `~/Downloads` et `~/Library`. macOS
demande l'autorisation au premier passage. Pour ne plus être interrompu,
accordez l'**Accès complet au disque** à DiskWatch.app dans Réglages Système ▸
Confidentialité et sécurité. Les dossiers refusés sont simplement absents du
relevé, sans erreur.

## Données

Tout vit dans `~/Library/Application Support/DiskWatch/`, en clair, et rien ne
sort de la machine :

| Fichier | Contenu |
|---|---|
| `history.jsonl` | un relevé par ligne, purgé selon la durée de conservation (~1 Mo/an) |
| `folders.json` | les deux dernières mesures, pour calculer les variations |
| `state.json` | mémoire anti-répétition des alertes |
| `config.json` | les réglages |

## Coût

Le relevé d'espace libre est un appel système, négligeable. La mesure des
dossiers lance des `du -skx` en `nice -n 10`, six en parallèle, à l'intervalle
choisi : quelques minutes de lecture d'inodes en priorité basse, annulables
depuis le panneau.

## Architecture

```
Sources/
  Support/Formatting.swift   formats français, abréviation des chemins
  Models/Models.swift        relevés, instantanés, réglages, gravité
  Core/Disk.swift            lecture du volume de données
  Core/Store.swift           persistance (JSONL append-only)
  Core/FolderScanner.swift   du parallélisé, annulable
  Core/Analyzer.swift        tendances et classement
  Core/Notifier.swift        notifications, avec repli osascript
  Core/LoginItem.swift       SMAppService, avec repli LaunchAgent
  App/AppState.swift         état observable, orchestration, alertes
  App/AppController.swift    élément de barre, panneau, fenêtre de réglages
  UI/Theme.swift             couleurs et métriques
  UI/StatusIcon.swift        rendu de l'icône de barre
  UI/PanelView.swift         panneau principal
  UI/SettingsView.swift      réglages

Resources/
  make-icon.swift            dessine l'icône de l'application
  make-icns.sh               assemble le .icns dans toutes les tailles

build.sh                     compile, fabrique le bundle, signe
make-dmg.sh                  fabrique l'image disque de distribution
```

Les captures de ce README utilisent un jeu de données de démonstration : les
chemins affichés sont des dossiers système génériques, pas ceux d'un poste réel.

## Licence

MIT — voir [LICENSE](LICENSE).
Journal des modifications : [CHANGELOG.md](CHANGELOG.md).
