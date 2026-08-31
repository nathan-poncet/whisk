# Architecture

Whisk suit la Clean Architecture : les entités et les use cases seuls au
centre de l'oignon, un ring d'interface adapters complet autour d'eux
(controllers, presenters, gateways), et les frameworks tout au bord. Le
graphe de cibles SwiftPM *est* la Dependency Rule — chaque flèche pointe
vers l'intérieur.

## La carte

```
        Whisk  (exécutable — frameworks & drivers + racine de composition, puits)
        Vues SwiftUI · NSPanel · NSStatusItem · Timer · raccourci · CGEvent
                │ peut tout nommer
   ┌────────────┼───────────────────────┬─────────────────────┐
   ▼            ▼                       ▼                     ▼
WhiskAdapters   HistoryStoreFile   PasteboardAppKit      WhiskTestKit
controllers +   gateway (fichiers) gateway (NSPasteboard)  fakes de test
presenters      │                       │                     │
   └────────────┴───────────┬───────────┴─────────────────────┘
                            ▼
                       WhiskKernel
                entités · use cases · ports
```

## Les rings

1. **Noyau (entités + use cases).** `WhiskKernel` contient `Entities/` et
   `UseCases/` avec ses `UseCases/Ports/`. Il n'importe que Foundation —
   jamais AppKit, jamais SwiftUI. Les ports sont des protocoles aux noms de
   rôle (`Pasteboard`, `HistoryStore`, `Clock`), un fichier par port,
   chacun possédant son type d'erreur. Les use cases sont génériques sur
   leurs ports et restent synchrones et purs ; le temps entre par `Clock`.
2. **Interface adapters.**
   - *Controllers* (`WhiskAdapters/Controllers`) : traduisent les
     événements UI et OS en invocations de use cases.
     `ClipboardController` reçoit les gateways, construit les use cases,
     possède l'`History` courant et la requête de recherche, et gère les
     échecs de stockage sans tuer la session.
   - *Presenters* (`WhiskAdapters/Presenters`) : transformation pure
     entités → view state. `HistoryPresenter` décide chaque chaîne
     d'affichage (labels de type, temps relatifs, détection de couleurs
     hex, troncature des listes de fichiers) et émet un `HistoryViewState`
     que les vues rendent tel quel. Il ne lit jamais l'horloge système —
     `now` est un argument.
   - *Gateways* (`HistoryStoreFile`, `PasteboardAppKit`) : implémentent
     les ports du noyau. Cibles séparées nommées `<Rôle><Tech>` pour
     qu'une dépendance framework (AppKit) ne fuie jamais dans le reste du
     ring.
3. **Frameworks & drivers.** L'exécutable `Whisk` est la racine de
   composition et un puits : vues SwiftUI (rendus muets du
   `HistoryViewState`), le `NSPanel` flottant, l'icône de barre de menus,
   le `Timer` de polling, le raccourci Carbon et la simulation de collage.
   L'asynchrone vit ici et seulement ici.

## Invariants

- **Newtypes plutôt que primitives ; états illégaux irreprésentables.**
  `HistoryCapacity` rejette zéro à la construction ; `History` fait
  respecter son invariant d'éviction dans chaque mutation.
- **Fail closed.** Aucun force-unwrap dans les chemins de production. Un
  échec de stockage est journalisé et l'historique en mémoire continue de
  fonctionner ; une entrée persistée corrompue est ignorée, jamais fatale.
- **Des octets opaques traversent les coutures.** Le noyau et le view
  state transportent les images comme `Data`. `PasteboardAppKit` possède
  la normalisation PNG ; `HistoryStoreFile` possède le format d'index JSON
  et fixe les dates à la milliseconde entière pour qu'un historique
  sauvegardé se recharge à l'identique.

## Tests

- `WhiskTestKit` est le kit de test partagé : `FakeClock`,
  `InMemoryHistoryStore`, `FailingHistoryStore`, `ScriptedPasteboard` —
  des doublures déterministes pour chaque port.
- Le comportement du noyau, l'orchestration du controller et le formatage
  du presenter ont chacun leur suite ; les noms de tests énoncent un
  comportement (`a_storage_failure_keeps_the_presented_state_alive`).
- Le port `HistoryStore` a une suite de contrat exécutée contre
  l'adaptateur fichier dans un répertoire temporaire neuf par test. Tout
  futur gateway (SQLite, CloudKit) devra passer le même contrat.
