# DiskWatch

Surveillance de l'espace disque dans la barre de menus macOS, avec alertes dès
qu'un dossier se met à gonfler.

Écrit en Swift, sans aucune dépendance externe : AppKit, SwiftUI, Swift Charts
et `du`. Le binaire pèse environ 1 Mo.

## Installation

```bash
./build.sh                 # installe dans ~/Applications
./build.sh /Applications   # ou ailleurs
open ~/Applications/DiskWatch.app
```

Prérequis : macOS 14 ou plus récent, et les outils en ligne de commande de Xcode
pour `swiftc`.

## Le panneau

Clic gauche sur l'icône de la barre :

- **anneau de capacité** et espace libre, avec le taux d'occupation ;
- **projection de saturation** — « saturation dans 6 h à ce rythme » — affichée
  seulement quand la pente est franchement négative ;
- **courbe** sur 24 h, 7 jours ou 30 jours, et tendance en Go/h lissée sur 3 h ;
- **variations** à 1 h, 24 h et 7 jours ;
- **dossiers surveillés**, les plus en croissance d'abord puis les plus gros,
  chacun avec sa taille, sa variation et un filet de proportion ;
- **copie du rapport** en texte dans le presse-papiers.

Clic droit : menu contextuel avec réglages, rapport, analyse immédiate et quitter.

## Les quatre alertes

| Alerte | Déclenchement | Anti-répétition |
|---|---|---|
| Espace faible | franchissement d'un seuil, 60 / 30 / 15 / 7 Go par défaut | une fois par seuil, réarmé si l'espace remonte de 8 % au-dessus |
| Chute rapide | perte ≥ 5 Go en 1 h | 30 min, et déclenche une mesure des dossiers |
| Baisse continue | perte ≥ 25 Go sur 24 h | 24 h |
| Dossier qui gonfle | un dossier prend ≥ 5 Go entre deux mesures | 6 h par dossier |

La chute rapide enchaîne sur une mesure des dossiers : tu reçois d'abord
« −7 Go en 1 h », puis « ~/Documents/projets : +6,8 Go » quelques minutes plus
tard. Le coupable se désigne tout seul.

## Réglages

Quatre onglets, modifiables à chaud — aucun redémarrage n'est nécessaire.

- **Général** : format de l'icône, fréquence des relevés et des mesures,
  conservation de l'historique, lancement à l'ouverture de session.
- **Alertes** : notifications, seuils d'espace faible (ajout et retrait libres),
  sensibilité des trois détections de dérive.
- **Dossiers** : liste des chemins surveillés, avec leur taille mesurée.
- **À propos** : compteurs, accès au dossier de données, remise à zéro.

Évite d'imbriquer un chemin surveillé dans un autre : les tailles seraient
comptées deux fois et les variations deviendraient illisibles.

## Deux limites, dites franchement

**La barre de menus peut être pleine.** Quand elle est saturée, macOS attribue
une position au nouvel élément mais ne le dessine pas — le symptôme se reproduit
avec une application témoin de douze lignes, ce n'est pas propre à DiskWatch.
D'où le format « jauge » par défaut, le plus étroit. Si l'icône reste invisible,
il faut libérer de la place dans la barre. Pour savoir si l'élément est dessiné
ou seulement alloué :

```bash
osascript -e 'tell application "System Events" to tell process "DiskWatch" \
  to get {position, size} of menu bar item 1 of menu bar 1'
```

Compare la position obtenue avec celle de l'élément visible le plus à gauche.

**Les bannières portent l'identité de l'Éditeur de script.** L'application est
signée « ad hoc » ; sans certificat Developer ID, macOS n'accorde pas
l'autorisation `UNUserNotificationCenter` et le code retombe sur `osascript`.
Les alertes arrivent normalement, seul l'habillage est faux. Avec un certificat,
remplace `codesign --force --sign -` par ton identité dans `build.sh` : le code
bascule seul sur l'API native, l'autorisation étant relue à chaque envoi.

## Permissions

La mesure des dossiers lit `~/Documents`, `~/Downloads` et `~/Library`. macOS
demande l'autorisation au premier passage. Pour ne plus être interrompu, accorde
l'**Accès complet au disque** à DiskWatch.app dans Réglages Système ▸
Confidentialité et sécurité. Les dossiers refusés sont simplement absents du
relevé, sans erreur.

## Données

Tout vit dans `~/Library/Application Support/DiskWatch/` :

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
```

## Licence

MIT.
