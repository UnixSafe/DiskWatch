# Journal des modifications

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et le versionnage [SemVer](https://semver.org/lang/fr/).

## [2.1] — 2026-10-19

### Corrigé

- **L'aire du graphique débordait sur le reste du panneau.** `AreaMark(x:y:)`
  remplit depuis la courbe jusqu'à zéro. Sur une échelle resserrée — 160 à
  164 Go — le zéro se trouve très loin sous le cadre, et le dégradé recouvrait
  la liste des dossiers. L'aire reçoit désormais un `yStart` explicite calé sur
  le bas de l'échelle, et la zone de tracé est découpée (`chartPlotStyle`) pour
  absorber les dépassements de l'interpolation `catmullRom`.
- **Les projections s'affichaient en heures sans limite** : « saturation dans
  1511 h ». `Fmt.duration` connaît maintenant les jours et les mois, et
  `Trend.timeToFull` ne renvoie plus rien au-delà d'un an — extrapoler trois
  heures de relevés sur plus longtemps n'apprend rien.
- **L'axe du temps affichait l'heure sur les vues 7 et 30 jours**, ce qui donnait
  une colonne de « 00:00 ». Au-delà de 36 h, il affiche la date.
- **Les étiquettes des axes étaient illisibles** par-dessus le dégradé : passées
  de `.tertiary` à `.secondary`.
- **La fenêtre de réglages coupait son contenu.** Hauteur portée de 420 à 620 pt
  pour que les onglets Général et Alertes tiennent en entier.

### Modifié

- `TrendChart` découpé en sous-expressions : le vérificateur de types de Swift
  n'arrivait plus à traiter le corps de la vue dans un temps raisonnable.

## [2.0] — 2026-10-18

Réécriture complète. Le fichier unique de 860 lignes devient quinze fichiers
organisés en couches (`Support`, `Models`, `Core`, `App`, `UI`).

### Ajouté

- Panneau SwiftUI avec anneau de capacité, courbe Swift Charts commutable
  (24 h / 7 j / 30 j), variations à 1 h, 24 h et 7 jours, et liste des dossiers
  triés par croissance puis par taille.
- Fenêtre de réglages à quatre onglets, appliqués à chaud.
- Projection de saturation quand la pente est franchement négative.
- Mesure des dossiers annulable, avec barre de progression.
- Lancement à l'ouverture de session via `SMAppService`, avec repli LaunchAgent.
- Quatre formats d'icône de barre de menus.

### Modifié

- Les variations sous 50 Mo s'affichent en tiret : un « +0,0 Go » laissait croire
  à une mesure plus fine qu'elle ne l'est.
- Le classement des dossiers ignore les variations sous ce même seuil, sans quoi
  il paraissait aléatoire quand rien ne bougeait.
