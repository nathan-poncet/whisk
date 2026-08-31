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
├── UseCases/               CaptureClipboardChange · SelectItem · SearchHistory ·
│   └── Ports/              TogglePin · DeleteItem · ClearHistory · LoadHistory
│                           Pasteboard · HistoryStore · Clock        (Foundation seulement)
├── Adapters/
│   ├── Controllers/        ClipboardController                     (Foundation seulement)
│   ├── Presenters/         HistoryPresenter · HistoryViewState     (Foundation seulement)
│   └── Gateways/           FileHistoryStore · AppKitPasteboard     (Foundation + AppKit)
└── App/                    frameworks & drivers + racine de composition (tout est permis)
    ├── Views/              rendus SwiftUI du HistoryViewState
    └── …                   AppDelegate · NSPanel · Timer · raccourci · CGEvent
```

## Les rings

1. **Noyau (entités + use cases).** `Entities/` et `UseCases/` avec ses
   `UseCases/Ports/` n'importent que Foundation — jamais AppKit, jamais
   SwiftUI. Les ports sont des protocoles aux noms de rôle (`Pasteboard`,
   `HistoryStore`, `Clock`), un fichier par port, chacun possédant son type
   d'erreur. Les use cases sont génériques sur leurs ports et restent
   synchrones et purs ; le temps entre par `Clock`.
2. **Interface adapters.**
   - *Controllers* : traduisent les événements UI et OS en invocations de
     use cases. `ClipboardController` reçoit les gateways, construit les
     use cases, possède l'`History` courant et la requête de recherche, et
     gère les échecs de stockage sans tuer la session.
   - *Presenters* : transformation pure entités → view state.
     `HistoryPresenter` décide chaque chaîne d'affichage (labels de type,
     temps relatifs, détection de couleurs hex, troncature des listes de
     fichiers) et émet un `HistoryViewState` que les vues rendent tel quel.
     Il ne lit jamais l'horloge système — `now` est un argument.
   - *Gateways* : implémentent les ports du noyau. `FileHistoryStore`
     possède le format de persistance (index JSON + blobs) ;
     `AppKitPasteboard` possède la frontière NSPasteboard. C'est le seul
     dossier du ring autorisé à importer AppKit.
3. **Frameworks & drivers (`App/`).** La racine de composition et tout ce
   qui a la forme d'un framework : vues SwiftUI (rendus muets du
   `HistoryViewState`), le `NSPanel` flottant, l'icône de barre de menus,
   le `Timer` de polling, le raccourci Carbon, la simulation de collage.
   L'asynchrone vit ici et seulement ici.

## Invariants

- **Newtypes plutôt que primitives ; états illégaux irreprésentables.**
  `HistoryCapacity` rejette zéro à la construction ; `SourceApp` garantit
  au moins un champ identifiant ; `History` fait respecter son invariant
  d'éviction dans chaque mutation.
- **Fail closed.** Aucun force-unwrap dans les chemins de production. Un
  échec de stockage est journalisé et l'historique en mémoire continue de
  fonctionner ; une entrée persistée corrompue est ignorée, jamais fatale.
- **Des octets opaques traversent les coutures.** Le noyau et le view
  state transportent les images comme `Data`. Le gateway presse-papiers
  possède la normalisation PNG ; le gateway fichier possède le format
  d'index JSON et fixe les dates à la milliseconde entière pour qu'un
  historique sauvegardé se recharge à l'identique.

## Tests

Une seule cible `WhiskTests` (`@testable import Whisk`) avec les doublures
déterministes dans `Fakes.swift` : `FakeClock`, `InMemoryHistoryStore`,
`FailingHistoryStore`, `ScriptedPasteboard`. Le comportement du noyau,
l'orchestration du controller et le formatage du presenter ont chacun leur
suite ; les noms de tests énoncent un comportement
(`a_storage_failure_keeps_the_presented_state_alive`). Le port
`HistoryStore` a une suite de contrat exécutée contre le gateway fichier
dans un répertoire temporaire neuf par test ; tout futur gateway (SQLite,
CloudKit) devra passer le même contrat.
