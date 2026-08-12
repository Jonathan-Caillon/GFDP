-- GFDP Tag : entree dans le menu contextuel des joueurs
local ADDON_NAME, ns = ...

local ContextMenu = {}
ns.ContextMenu = ContextMenu

-- Coupe-circuit, comme ailleurs dans l'addon : une erreur previent une fois
-- puis retire l'entree, au lieu de se repeter a chaque clic droit. Le drapeau
-- vit sur le module pour pouvoir etre rearme sans /reload.
ContextMenu.disabled = false

-- Menus ou l'entree est proposee, et si le type garantit qu'il s'agit d'un
-- joueur. Les deux menus a false s'ouvrent aussi sur un PNJ : il faut alors le
-- verifier a l'execution.
--
-- La cle sert a la fois de suffixe de tag ("MENU_UNIT_<cle>") et de valeur
-- attendue dans contextData.which. Un tag inconnu du client est ignore par
-- Menu.ModifyMenu, la liste peut donc etre large sans risque.
local MENUS = {
    PLAYER                   = true,
    PARTY                    = true,
    RAID                     = true,
    RAID_PLAYER              = true,
    FRIEND                   = true,
    ENEMY_PLAYER             = true,
    ARENAENEMY               = true,
    CHAT_ROSTER              = true,   -- nom clique dans le chat
    GUILD                    = true,
    GUILD_OFFLINE            = true,
    COMMUNITIES_GUILD_MEMBER = true,
    COMMUNITIES_WOW_MEMBER   = true,
    TARGET                   = false,  -- portrait de la cible, PNJ possible
    FOCUS                    = false,  -- portrait du focus, PNJ possible
}

--- L'unite visee est-elle un joueur ?
-- @return true, false, ou nil si indeterminable
local function IsPlayer(contextData)
    -- Le GUID d'un joueur commence par "Player-", celui d'un PNJ par
    -- "Creature-", "Vehicle-" ou "Pet-". C'est le controle le plus fiable, et il
    -- ne demande aucune API d'unite.
    local guid = ns.SafeString(contextData.guid)
    if guid then
        return guid:sub(1, 7) == "Player-"
    end

    local unit = ns.SafeString(contextData.unit)
    if unit then
        local ok, isPlayer = pcall(UnitIsPlayer, unit)
        if ok then return isPlayer and true or false end
    end

    return nil   -- ni GUID ni jeton exploitable
end

--- Identifie le joueur vise par le menu, royaume compris.
--
-- Le menu fournit deja name et server pour les joueurs, ce qui evite de toucher
-- au jeton d'unite. On teste quand meme chaque valeur : depuis Midnight,
-- l'interface peut renvoyer des valeurs "secretes" que les API refusent de
-- traiter en execution contaminee.
--
-- @return name, realm  ou nil si l'identification echoue
local function ResolvePlayer(contextData)
    local name = ns.SafeString(contextData.name)
    local realm = ns.SafeString(contextData.server)

    -- Premier repli : le GUID, resolu sans passer par un jeton d'unite.
    if not name then
        name, realm = ns.PlayerNameRealmFromGUID(contextData.guid)
    end

    -- Dernier repli, pour les menus qui ne fournissent qu'un jeton d'unite.
    if not name then
        name, realm = ns.UnitNameRealm(contextData.unit)
    end
    if not name then return end

    return name, realm or GetNormalizedRealmName()
end

local function Toggle(name, realm)
    -- realm peut etre nil si GetNormalizedRealmName n'a rien rendu : le passer
    -- tel quel a string.format leverait "bad argument (string expected, got nil)".
    local label = (realm and realm ~= "") and (name .. "-" .. realm) or name

    if ns.Roster:IsTagged(name, realm) then
        ns.Roster:Remove(name, realm)
        ns.Print("%s retire de la liste (total : %d).", label, ns.Roster:Count())
    else
        ns.Roster:Add(name, realm)
        ns.Print("|cff33ff99%s|r ajoute a la liste (total : %d).", label, ns.Roster:Count())
    end
end

--- @param trustTag true si le menu d'enregistrement ne concerne que des joueurs
local function AddEntry(rootDescription, contextData, trustTag)
    if ContextMenu.disabled then return end

    local ok, err = pcall(function()
        if not contextData then return end

        -- Le type reel du menu prime sur celui de l'enregistrement : un menu
        -- inattendu est ignore.
        local trusted = trustTag
        local which = ns.SafeString(contextData.which)
        if which then
            if MENUS[which] == nil then return end
            trusted = MENUS[which]
        end

        -- Sur un menu ambigu, on n'ajoute rien tant qu'on n'a pas confirme qu'il
        -- s'agit d'un joueur : sans cela, l'entree apparaitrait sur les PNJ.
        local isPlayer = IsPlayer(contextData)
        if isPlayer == false then return end
        if isPlayer == nil and not trusted then return end

        local name, realm = ResolvePlayer(contextData)
        if not name then return end

        local tagged = ns.Roster:IsTagged(name, realm)
        local label = (tagged and "Retirer du tag " or "Ajouter au tag ") .. (ns.db.tag or "GFDP")

        rootDescription:CreateDivider()
        rootDescription:CreateButton(label, function()
            -- Le pcall ci-dessus ne couvre que la construction du menu : ce
            -- callback s'execute au clic, bien plus tard. Sans cette protection,
            -- une erreur ici remonterait brute au joueur.
            local okClick, errClick = pcall(Toggle, name, realm)
            if not okClick then
                ContextMenu.disabled = true
                ns.Print("|cffff5555Entree de menu desactivee|r apres une erreur : %s", tostring(errClick))
            end
        end)
    end)

    if not ok then
        ContextMenu.disabled = true
        ns.Print("|cffff5555Entree de menu desactivee|r apres une erreur : %s", tostring(err))
    end
end

function ContextMenu:Init()
    if self.initialized then return end
    self.initialized = true

    if not Menu or not Menu.ModifyMenu then
        ns.Print("API Menu indisponible : l'entree de menu contextuel est desactivee.")
        return
    end

    -- Enregistrement direct a l'initialisation.
    --
    -- Le systeme de menus actuel regenere les modifications avant chaque
    -- affichage, l'enregistrement n'a donc pas besoin d'attendre. Une version
    -- precedente le retardait jusqu'au premier menu ouvert par Blizzard, ce qui
    -- privait le tout premier clic droit de la session de l'entree.
    --
    -- A surveiller : RaiderIO retarde volontairement cet appel, au motif qu'un
    -- ModifyMenu trop precoce contamine le systeme de menus. Si des erreurs de
    -- contamination apparaissent au clic droit, c'est la premiere piste.
    self.menuHandles = self.menuHandles or {}

    for name, trustTag in pairs(MENUS) do
        -- Copies locales : les callbacks ne doivent pas dependre de la variable
        -- de boucle, reutilisee a chaque tour.
        local menuName, menuTrust = name, trustTag
        local handle = Menu.ModifyMenu("MENU_UNIT_" .. menuName, function(_, rootDescription, contextData)
            AddEntry(rootDescription, contextData, menuTrust)
        end)
        self.menuHandles[#self.menuHandles + 1] = handle
    end
end
