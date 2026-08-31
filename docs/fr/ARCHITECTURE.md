# Architecture

Whisk suit la Clean Architecture : un noyau pur derrière des ports, des
adaptateurs en périphérie, une unique racine de composition. Le graphe de
cibles SwiftPM *est* la Dependency Rule — le noyau ne dépend de rien qui
nous appartienne, les adaptateurs ne dépendent que du noyau, et seul
l'exécutable peut tout nommer.

## La carte

```
                      Whisk  (exécutable — racine de composition, puits)
                         │ peut tout nommer
          ┌──────────────┼──────────────────┐
          ▼              ▼                  ▼
   WhiskKernel   HistoryStoreFile   PasteboardAppKit
                         │ (adaptateur)     │ (adaptateur)
                         └──────────┬───────┘
                                    ▼
                            WhiskKernel
```

## Les règles

1. **Un seul bounded context.** `WhiskKernel` contient `Entities/` et
   `UseCases/` avec ses `UseCases/Ports/`. Il n'importe que Foundation —
   jamais AppKit, jamais SwiftUI.
2. **Les ports vivent dans le noyau**, un fichier par port, des noms de
   rôle (`Pasteboard`, `HistoryStore`, `Clock`) ; `HistoryStore` possède
   son `HistoryStoreError`.
3. **Les adaptateurs sont des cibles séparées**, nommées `<Rôle><Tech>`
   (`HistoryStoreFile`, `PasteboardAppKit`) ; chacune dépend du noyau et de
   rien d'autre qui nous appartienne.
4. **La racine de composition est un puits.** L'exécutable `Whisk` câble
   les adaptateurs dans les use cases (`UseCaseBundle`) et possède toute
   l'UI ; rien ne dépend de lui.
5. **Cœur synchrone et pur ; le temps en périphérie.** Les use cases sont
   synchrones et reçoivent leur horloge comme port. Le timer de polling vit
   dans l'app, pas dans le noyau.
6. **Newtypes plutôt que primitives ; états illégaux irreprésentables.**
   `HistoryCapacity` rejette zéro à la construction ; `History` fait
   respecter son invariant d'éviction dans chaque mutation.
7. **Fail closed.** Aucun force-unwrap dans les chemins de production. Un
   échec de stockage est journalisé et l'historique en mémoire continue de
   fonctionner ; une entrée persistée corrompue est ignorée, jamais fatale.
8. **Des octets opaques traversent les coutures.** Le noyau voit les images
   comme `Data`. `PasteboardAppKit` possède la normalisation PNG ;
   `HistoryStoreFile` possède le format d'index JSON et fixe les dates à la
   milliseconde entière pour qu'un historique sauvegardé se recharge à
   l'identique.

## Tests

- Le comportement du noyau est testé avec des fakes déterministes : une
  `FakeClock` gelée, un `ScriptedPasteboard`, un `InMemoryHistoryStore`.
  Les noms de tests énoncent un comportement
  (`a_duplicate_copy_moves_the_existing_item_to_the_front…`).
- Le port `HistoryStore` a une suite de contrat exécutée contre
  l'adaptateur fichier dans un répertoire temporaire neuf par test. Tout
  futur adaptateur (SQLite, CloudKit) devra passer le même contrat.
