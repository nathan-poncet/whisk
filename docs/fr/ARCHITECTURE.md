# Architecture

Whisk est une application Swift simple qui suit la Clean Architecture :
les entités et les use cases seuls au centre de l'oignon, un ring
d'interface adapters complet autour d'eux (controllers, presenters,
gateways), et les frameworks tout au bord. Les rings vivent comme des
dossiers dans un module unique ; la Dependency Rule est appliquée par
`scripts/check-dependency-rule.sh`, exécuté par la CI à chaque push — les
rings intérieurs ne peuvent importer que ce que leur ring autorise, les
flèches pointent uniquement vers l'intérieur.

## La carte

```
Sources/Whisk/
├── Entities/               History · ClipboardItem · Payload · SourceApp · HistoryCapacity
├── UseCases/               CaptureClipboardChange · SelectItem · FilterHistory ·
│   └── Ports/              TogglePin · DeleteItem · ClearHistory · LoadHistory · EnforceRetention
│                           Pasteboard · HistoryStore · Clock · Logger  (Foundation seulement)
├── Adapters/
│   ├── Controllers/        ClipboardController                     (Foundation seulement)
│   ├── Presenters/         HistoryPresenter · HistoryViewState     (Foundation seulement)
│   └── Gateways/           SQLiteHistoryStore · LegacyJSONHistory · VolatileHistoryStore ·
│                           AppKitPasteboard · ConsoleLogger        (Foundation + AppKit + SQLite3)
└── App/                    frameworks & drivers + racine de composition (tout est permis)
    ├── Views/              rendus SwiftUI du HistoryViewState
    └── …                   AppDelegate · HistoryStorage · PanelWiring · PanelKeyRouter ·
                            NSPanel · Timer · raccourci · CGEvent
```

## Les rings

1. **Noyau (entités + use cases).** `Entities/` et `UseCases/` avec ses
   `UseCases/Ports/` n'importent que Foundation — jamais AppKit, jamais
   SwiftUI. Les ports sont des protocoles aux noms de rôle (`Pasteboard`,
   `HistoryStore`, `Clock`, `Logger`), un fichier par port, chacun
   possédant son type d'erreur. Les use cases sont génériques sur leurs
   ports et restent synchrones et purs ; le temps entre par `Clock`.
2. **Interface adapters.**
   - *Controllers* : traduisent les événements UI et OS en invocations de
     use cases. `ClipboardController` reçoit les gateways, construit les
     use cases, possède l'`History` courant, la requête de recherche et la
     sélection clavier, et signale les échecs de stockage au `Logger` sans
     tuer la session.
   - *Presenters* : transformation pure entités → view state.
     `HistoryPresenter` décide chaque chaîne et symbole d'affichage (labels
     de type, temps relatifs, phrase de l'état vide, icônes des puces,
     détection de couleurs hex, troncature des listes de fichiers) et émet
     un `HistoryViewState` que les vues rendent tel quel. Il ne lit jamais
     l'horloge système — `now` est un argument. `ChipEntry.row` décide une
     seule fois l'ordre des puces de filtre ; le controller pilote le
     clavier le long de cette même liste.
   - *Gateways* : implémentent les ports du noyau. `SQLiteHistoryStore`
     possède le schéma de production ; `LegacyJSONHistory` lit l'index
     JSON d'avant SQLite pour l'import unique ; `VolatileHistoryStore`
     garde une session vivante quand aucune base ne peut s'ouvrir ;
     `AppKitPasteboard` possède la frontière NSPasteboard ;
     `ConsoleLogger` écrit dans le journal unifié. C'est le seul dossier
     du ring autorisé à importer AppKit.
3. **Frameworks & drivers (`App/`).** La racine de composition et tout ce
   qui a la forme d'un framework : vues SwiftUI (rendus muets du
   `HistoryViewState`), le `NSPanel` flottant, l'icône de barre de menus,
   le `Timer` de polling, le raccourci Carbon, la simulation de collage.
   `HistoryStorage` ouvre la base, la lit une fois avant de lui faire
   confiance, met de côté une base illisible, se replie sur la mémoire et
   importe l'historique legacy. Deux morceaux de ce ring portent des
   règles plutôt que du câblage et sont tenus à part pour être testés :
   `PanelWiring` construit la table d'actions du panneau (quelles actions
   vident le debounce de recherche, lesquelles ferment et collent), et
   `PanelKeyRouter` transforme les touches en actions — mode normal de
   vim, raccourcis de l'utilisateur, ⌘chiffres. `AppDelegate` ne fait
   qu'assembler. L'asynchrone vit ici et seulement ici.

## Invariants

- **Newtypes plutôt que primitives ; états illégaux irreprésentables.**
  `HistoryCapacity` rejette zéro à la construction ; `SourceApp` garantit
  au moins un champ identifiant ; `History` fait respecter son invariant
  d'éviction dans chaque mutation.
- **Fail closed.** Aucun force-unwrap dans les chemins de production. Un
  échec de stockage est journalisé et l'historique en mémoire continue de
  fonctionner ; une entrée persistée corrompue est ignorée, jamais
  fatale ; une base qui ne s'ouvre pas est mise de côté et la session
  tourne en mémoire plutôt que de refuser de démarrer.
- **Des octets opaques traversent les coutures.** Le noyau et le view
  state transportent les images comme `Data`. Le gateway presse-papiers
  possède la normalisation PNG ; le gateway SQLite possède le schéma et
  fixe les dates à la milliseconde entière pour qu'un historique
  sauvegardé se recharge à l'identique.

## Tests

Une seule cible `WhiskTests` (`@testable import Whisk`) avec les doublures
déterministes dans `Fakes.swift` : `FakeClock`, `InMemoryHistoryStore`,
`FailingHistoryStore`, `SaveFailingHistoryStore`, `ScriptedPasteboard`,
`RecordingLogger`. Les noms de tests énoncent un comportement
(`a_storage_failure_is_logged_and_the_presented_state_stays_alive`).

- **Noyau et adaptateurs** sont couverts ligne à ligne : le comportement
  de l'historique, chaque use case, la navigation et les facettes du
  controller, les chaînes, icônes et libellés VoiceOver du presenter. Le
  contrat `HistoryStore` est une seule suite paramétrée, exécutée contre
  chaque gateway (SQLite, mémoire) dans un répertoire temporaire neuf par
  test ; une connexion brute sabote le schéma pour atteindre chaque chemin
  d'erreur. Le lecteur JSON legacy est testé contre une fixture de son
  format sur disque, le bootstrap de stockage contre des répertoires
  corrompus, dérivés ou legacy, le gateway presse-papiers contre un
  presse-papiers privé, les catalogues de chaînes contre le code qui les
  lit.
- **Le ring des frameworks est testé sans écran.** Les vues sont dessinées
  hors écran avec `ImageRenderer` dans chaque état possible, et hébergées
  dans une fenêtre jamais affichée pour que le flou derrière la fenêtre
  reçoive un layer et une passe de layout ; le panneau reçoit des
  changements d'état et un tour de run loop pour que ses observateurs
  s'exécutent. Le routage clavier est piloté par des `NSEvent`
  synthétiques, le debouncer par un ordonnanceur à manivelle, la
  vérification de mise à jour par des réponses en conserve, QuickLook et
  LinkPresentation en attendant leurs valeurs publiées. Un test n'affiche
  jamais de fenêtre.
- **Hors de la suite, à dessein :** `AppDelegate` (icône de menu,
  raccourcis globaux, timers — la racine de composition que le smoke test
  de release couvre), `HotKey` (en enregistrer un détournerait le
  raccourci du testeur), `PasteSimulator` (envoie ⌘V à l'app au premier
  plan), `main`, et les parties de `PanelController` qui affichent des
  fenêtres. `scripts/coverage.sh` exécute la suite avec la couverture et
  affiche le rapport que la CI archive.
