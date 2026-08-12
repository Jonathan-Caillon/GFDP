# GFDP Tag

Addon World of Warcraft qui marque du tag **GFDP** les joueurs présents dans une liste importée depuis un fichier `.csv`.

## Installation

Copier le dossier `GFDPTag` dans :

```
World of Warcraft\_retail_\Interface\AddOns\GFDPTag
```

Redémarrer le jeu, ou taper `/reload` si le client tourne déjà.

L'addon vise **uniquement le client retail** : il utilise des API absentes de Classic (`TooltipDataProcessor`), et le `.toc` déclare l'interface retail.

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
| Cadres de raid | `[GFDP]` affiché juste après le nom |

Tout est affiché localement : l'addon n'écrit aucune donnée côté serveur.

## Ajouter un joueur en jeu

Clic droit sur le portrait d'un joueur — ta cible, un membre du groupe, ton focus, ou son nom dans le chat — puis **Ajouter au tag GFDP** en bas du menu. La même entrée devient **Retirer du tag GFDP** si le joueur y est déjà.

Le royaume est repris automatiquement, donc un joueur d'un autre royaume est enregistré comme `Nom-Royaume` et non confondu avec un homonyme du tien.

L'entrée **n'apparaît jamais sur un PNJ**. Le menu de la cible et celui du focus s'ouvrent aussi bien sur une créature, un familier ou un véhicule ; l'addon vérifie le préfixe du GUID (`Player-`) avant de proposer quoi que ce soit, et s'abstient s'il ne peut pas conclure.

**Le tout premier menu ouvert dans une session n'aura pas l'entrée** — il faut le rouvrir une fois. C'est délibéré : appeler `Menu.ModifyMenu` dès la connexion se fait avant que le code sécurisé du jeu ait initialisé son état interne, ce qui contamine tout le système de menus. L'addon attend donc que Blizzard ouvre un menu avant de s'enregistrer. Approche reprise de [RaiderIO](https://github.com/RaiderIO/raiderio-addon).

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
| `/gfdp tooltip on\|off` | tag dans les infobulles |
| `/gfdp chat on\|off` | tag dans le chat |
| `/gfdp raid on\|off` | tag sur les cadres de raid |
| `/gfdp tag <texte>` | change le texte du tag (défaut : `GFDP`) |

## Logo

Le logo est `Icone.tga` : il apparaît dans la liste des addons (via `## IconTexture` dans le `.toc`) et en haut de la fenêtre d'import.

**Le client WoW ne lit pas le PNG** : pour changer le logo, repartir d'une image source et la convertir en TGA.

```bash
python -c "from PIL import Image; im=Image.open('source.png').convert('RGBA'); s=min(im.size); l,t=(im.size[0]-s)//2,(im.size[1]-s)//2; im.crop((l,t,l+s,t+s)).resize((128,128), Image.LANCZOS).save('Icone.tga', format='TGA')"
```

Le `.tga` doit rester **non compressé, 32 bits, en dimensions puissance de 2** (ici 128×128), sinon la texture ne s'affiche pas.

## Notes

- Sur les cadres de raid, le tag n'est **pas** un préfixe du nom : c'est un `FontString` appartenant à l'addon, positionné juste après le texte du nom. Deux raisons. D'abord, préfixer faisait scintiller le tag, Blizzard réécrivant le nom à chaque survol de cible ; un texte qui nous appartient n'est jamais réécrit par le jeu. Ensuite, l'addon n'utilise **aucun hook** : une version antérieure passait par `hooksecurefunc("CompactUnitFrame_UpdateName")`, ce qui exécutait son code dans la chaîne d'appel de Blizzard et provoquait `attempt to compare local 'oldR' (a secret number value, while execution tainted by 'GFDPTag')` en boucle. Les cadres sont désormais atteints par leurs noms globaux (`CompactRaidFrame1`…), sans jamais toucher à `CompactRaidFrameContainer`.
- Depuis Midnight, `tooltip:GetUnit()` renvoie une valeur « secrète » : la passer à `UnitExists`, `UnitIsPlayer` ou `UnitName` est refusé tant que l'exécution est contaminée, ce qui est toujours le cas dans le code d'un addon. L'infobulle passe donc par le **GUID** de `GetPrimaryTooltipData()`, qui reste exploitable, et le reconvertit en jeton d'unité avec `UnitTokenFromGUID`. Technique reprise de l'addon [RaiderIO](https://github.com/RaiderIO/raiderio-addon).

  Chaque valeur est testée avec `issecretvalue()` avant usage, plutôt que de subir l'erreur. En dernier recours, l'addon se rabat sur le nom affiché dans l'infobulle — sans royaume, la correspondance se faisant alors sur ton propre royaume.
- Dans le chat, le tag est placé devant le message et non dans le nom de l'auteur : modifier le nom casserait le lien cliquable et le menu contextuel du joueur.
