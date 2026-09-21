# App Store listing

The texts of the Mac App Store listing, kept with the code so they change
with it. `metadata.json` next to this file is what `scripts/appstore-metadata.py`
pushes to App Store Connect; this page is the readable version. Field limits: name 30, subtitle 30, promotional text 170,
description 4000, keywords 100 characters in one comma-separated line.

## English (U.S.), primary

**Name:** Whisk

**Subtitle:** Your clipboard, remembered

**Promotional text:** Everything you copy, a shortcut away. Search it,
pin it, paste it back: text, links, images, files, colors and code.

**Description:**

Whisk remembers everything you copy and brings it back through a
floating panel at the bottom of your screen. Press ⇧⌘V, find the card,
press Return: pasted.

EVERYTHING YOU COPIED, ONE PANEL
Text, links, images, files, colors and code, each on a card that shows
what it is: a link with its title and picture, a color as a swatch, code
highlighted, files with a thumbnail.

FIND IT AGAIN
Search as you type. Filter by application or by kind with one click, or
narrow down with app:mail and type:color. Pin what you always need.

PASTE IN SEQUENCE
Queue several cards and pop them one after another with ⌥⌘V: one field,
then the next.

PASTE IT YOUR WAY
Paste as plain text, or rewritten: upper case, lower case, trimmed,
URL-encoded, base64, formatted JSON. Edit a card's text in place. Undo a
deletion.

MADE FOR THE KEYBOARD
Every action has a shortcut, and every shortcut can be rebound. Vim
navigation, if that is how you move. Pasting straight into the app you
were typing in works with Accessibility access, which is optional.

YOURS
Your history stays on your Mac. No account, no analytics, no tracking.
Pause capture, exclude apps such as password managers, choose how long
items are kept and how many. Free and open source under the GPL; the
source is on GitHub.

**Keywords:** clipboard,manager,copy,paste,history,paste stack,pins,productivity,keyboard,vim,snippet

**Support URL:** https://github.com/nathan-poncet/whisk/issues

**Marketing URL:** https://nathan-poncet.github.io/whisk/

**Privacy Policy URL:** https://nathan-poncet.github.io/whisk/privacy.html

**Copyright:** 2026 Nathan Poncet

**What's New (0.11.0):** First release on the Mac App Store. Whisk keeps
everything you copy, searchable and a shortcut away.

## French

**Nom :** Whisk – Presse-papiers

Le nom « Whisk » seul est déjà pris dans la localisation française par une autre app ; le store le refuse (erreur 409 à la création).

**Sous-titre :** Votre presse-papiers, mémorisé

**Texte promotionnel :** Tout ce que vous copiez, à un raccourci de
distance. Cherchez, épinglez, recollez : texte, liens, images, fichiers,
couleurs et code.

**Description :**

Whisk retient tout ce que vous copiez et vous le rend dans un panneau
flottant en bas de l'écran. ⇧⌘V, la carte, Entrée : collé.

TOUT CE QUE VOUS AVEZ COPIÉ, UN SEUL PANNEAU
Texte, liens, images, fichiers, couleurs et code, chacun sur une carte
qui montre ce qu'il est : un lien avec son titre et son image, une
couleur en pastille, du code coloré, des fichiers avec leur vignette.

RETROUVEZ-LE
Cherchez en tapant. Filtrez par application ou par type d'un clic, ou
affinez avec app:mail et type:color. Épinglez l'indispensable.

COLLEZ EN SÉQUENCE
Mettez plusieurs cartes en file et dépilez-les l'une après l'autre avec
⌥⌘V : un champ, puis le suivant.

COLLEZ À VOTRE FAÇON
En texte brut, ou réécrit : majuscules, minuscules, sans espaces
superflus, encodé pour une URL, en base64, en JSON mis en forme.
Modifiez le texte d'une carte sur place. Annulez une suppression.

FAIT POUR LE CLAVIER
Chaque action a son raccourci, et chaque raccourci se change. Navigation
vim, si c'est votre façon de vous déplacer. Le collage direct dans
l'application où vous écriviez fonctionne avec l'accès Accessibilité,
facultatif.

À VOUS
Votre historique reste sur votre Mac. Ni compte, ni statistiques, ni
pistage. Mettez la capture en pause, excluez des applications comme les
gestionnaires de mots de passe, choisissez la durée et le nombre
d'éléments conservés. Gratuit et open source sous licence GPL ; le code
est sur GitHub.

**Mots-clés :** presse-papiers,copier,coller,historique,pile,épingles,productivité,clavier,vim,gestionnaire

**Nouveautés (0.11.0) :** Première version sur le Mac App Store. Whisk
garde tout ce que vous copiez, à portée de recherche et de raccourci.

## Notes for App Review (English)

Whisk is a menu bar app: after launch there is no window, only the cup
icon in the menu bar. Press ⇧⌘V to open the panel, or click the icon and
choose Show Panel. Copy a few things first so the history has cards:
some text in TextEdit, a link in Safari, a file in Finder, a color code
such as #4CAF50.

Pasting straight into the previous application needs Accessibility
access (System Settings → Privacy & Security → Accessibility); the app
explains this at first launch and works without it, copying the chosen
card to the clipboard for a manual paste.

No account, no sign-in, no in-app purchase. This build does not check
for updates. Search operators to try: type:link, app:safari.

## Answers on the record

- **App Privacy:** Data Not Collected.
- **Export compliance:** no encryption beyond HTTPS; `ITSAppUsesNonExemptEncryption` is false in the Info.plist.
- **Content rights:** the Neovim mark, used as the code-category icon, is by Jason Long under CC BY 3.0.
- **Category:** Productivity. **Price:** free.
