# GFDP Tag

Addon World of Warcraft qui marque du tag **GFDP** les joueurs présents dans une liste importée depuis un fichier `.csv`.

## Installation

Copier le dossier `GFDPTag` dans :

```
World of Warcraft\_retail_\Interface\AddOns\GFDPTag
```

(ou `_classic_` / `_classic_era_` selon la version). Redémarrer le jeu, ou taper `/reload` si le client tourne déjà.

## Importer la liste

Un addon WoW n'a **aucun accès au système de fichiers** : il ne peut pas lire un `.csv` sur ton disque. L'import se fait donc par copier/coller.

1. En jeu, taper `/gfdp` — la fenêtre d'import s'ouvre.
2. Ouvrir le `.csv` dans le Bloc-notes (ou Excel), tout sélectionner (`Ctrl+A`), copier (`Ctrl+C`).
3. Coller dans la fenêtre (`Ctrl+V`).
4. Cliquer sur **Ajouter à la liste** (fusionne) ou **Remplacer la liste** (écrase).

La liste est stockée dans les `SavedVariables` : elle survit aux déconnexions et aux `/reload`.

### Formats de CSV acceptés

Le séparateur (`,` `;` tabulation `|`) et la ligne d'en-tête sont détectés automatiquement. Les guillemets, le BOM UTF-8 et les fins de ligne Windows sont gérés.

```csv
nom;royaume
Thrall;Hyjal
Jaina;Kirin Tor
```

```csv
Thrall-Hyjal
Jaina-Kirin Tor
```

```csv
Thrall
Jaina
```

En-têtes reconnus : `nom`, `name`, `joueur`, `player`, `personnage`, `character`, `pseudo` / `royaume`, `realm`, `serveur`, `server`.

**Sans royaume**, le joueur est tagué sur tous les royaumes. **Avec royaume**, seul ce personnage précis l'est.

## Où le tag apparaît

| Emplacement | Comment |
|---|---|
| Infobulle des joueurs | automatique, ligne `GFDP` sous le nom |
| Chat | le message est préfixé de `[GFDP]` |
| Cadres de groupe | le nom affiché est préfixé de `[GFDP]` |
| Notes d'amis | `/gfdp friends confirm` |

La dernière écrit réellement des données côté serveur. **Sans le mot `confirm`, la commande fait une simulation** et se contente d'afficher ce qui serait modifié. Les écritures sont espacées de 0,25 s pour éviter la limitation serveur, et une note déjà taguée n'est jamais modifiée deux fois.

## Commandes

| Commande | Effet |
|---|---|
| `/gfdp` | ouvre la fenêtre d'import CSV |
| `/gfdp add <Nom[-Royaume]>` | ajoute un joueur |
| `/gfdp del <Nom[-Royaume]>` | retire un joueur |
| `/gfdp check <Nom>` | vérifie si un joueur est dans la liste |
| `/gfdp list` | affiche la liste complète |
| `/gfdp count` | nombre de joueurs |
| `/gfdp clear` | vide la liste |
| `/gfdp friends [confirm]` | tag dans les notes d'amis |
| `/gfdp tooltip on\|off` | tag dans les infobulles |
| `/gfdp chat on\|off` | tag dans le chat |
| `/gfdp group on\|off` | tag sur les cadres de groupe |
| `/gfdp tag <texte>` | change le texte du tag (défaut : `GFDP`) |

## Logo

Le logo est `Icone.tga` : il apparaît dans la liste des addons (via `## IconTexture` dans le `.toc`) et en haut de la fenêtre d'import.

**Le client WoW ne lit pas le PNG** : pour changer le logo, repartir d'une image source et la convertir en TGA.

```bash
python -c "from PIL import Image; im=Image.open('source.png').convert('RGBA'); s=min(im.size); l,t=(im.size[0]-s)//2,(im.size[1]-s)//2; im.crop((l,t,l+s,t+s)).resize((128,128), Image.LANCZOS).save('Icone.tga', format='TGA')"
```

Le `.tga` doit rester **non compressé, 32 bits, en dimensions puissance de 2** (ici 128×128), sinon la texture ne s'affiche pas.

## Notes

- **Les cadres de raid, et les cadres de groupe en « style raid », ne sont pas tagués.** Les taguer imposerait de hooker `CompactUnitFrame_UpdateName`, ce qui exécute du code d'addon à l'intérieur de la chaîne d'appel de Blizzard. Depuis Midnight, l'exécution est alors marquée comme contaminée, et la suite de la chaîne compare des valeurs « secrètes », ce que le client refuse : `attempt to compare local 'oldR' (a secret number value, while execution tainted by 'GFDPTag')`, répété à chaque reconstruction des cadres. Les cadres de groupe standard, eux, sont mis à jour depuis le contexte de l'addon et ne posent pas ce problème.
- Dans le chat, le tag est placé devant le message et non dans le nom de l'auteur : modifier le nom casserait le lien cliquable et le menu contextuel du joueur.
