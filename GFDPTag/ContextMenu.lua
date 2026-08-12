-- GFDP Tag : entree dans le menu contextuel des joueurs
local ADDON_NAME, ns = ...

local ContextMenu = {}
ns.ContextMenu = ContextMenu

-- Coupe-circuit, comme ailleurs dans l'addon : une erreur previent une fois
-- puis retire l'entree, au lieu de se repeter a chaque clic droit.
local disabled = false

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
    local guid = contextData.guid
    if type(guid) == "string" and guid ~= "" and not ns.IsSecret(guid) then
        return guid:sub(1, 7) == "Player-"
    end

    local unit = contextData.unit
    if unit and not ns.IsSecret(unit) then
        return UnitIsPlayer(unit) and true or false
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
    local name = contextData.name
    local realm = contextData.server

    if ns.IsSecret(name) then name = nil end
    if ns.IsSecret(realm) then realm = nil end
    if type(name) ~= "string" or name == "" then name = nil end
    if type(realm) ~= "string" or realm == "" then realm = nil end

    -- Repli sur le jeton d'unite si le menu n'a pas donne le nom
    if not name then
        name, realm = ns.UnitNameRealm(contextData.unit)
    end
    if not name then return end

    if not realm or realm == "" then
        realm = GetNormalizedRealmName()
    end
    return name, realm
end

local function Toggle(name, realm)
    if ns.Roster:IsTagged(name, realm) then
        ns.Roster:Remove(name, realm)
        ns.Print("%s-%s retire de la liste (total : %d).", name, realm, ns.Roster:Count())
    else
        ns.Roster:Add(name, realm)
        ns.Print("|cff33ff99%s-%s|r ajoute a la liste (total : %d).", name, realm, ns.Roster:Count())
    end
end

--- @param trustTag true si le menu d'enregistrement ne concerne que des joueurs
local function AddEntry(rootDescription, contextData, trustTag)
    if disabled then return end

    local ok, err = pcall(function()
        if not contextData then return end

        -- Le type reel du menu prime sur celui de l'enregistrement : un menu
        -- inattendu est ignore.
        local trusted = trustTag
        local which = contextData.which
        if which ~= nil then
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
            Toggle(name, realm)
        end)
    end)

    if not ok then
        disabled = true
        ns.Print("|cffff5555Entree de menu desactivee|r apres une erreur : %s", tostring(err))
    end
end

function ContextMenu:Init()
    if self.initialized then return end
    self.initialized = true

    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if not Menu or not Menu.ModifyMenu or not manager then
        ns.Print("API Menu indisponible : l'entree de menu contextuel est desactivee.")
        return
    end

    local registered = false
    local function Register()
        if registered then return end
        registered = true
        for name, trustTag in pairs(MENUS) do
            Menu.ModifyMenu("MENU_UNIT_" .. name, function(_, rootDescription, contextData)
                AddEntry(rootDescription, contextData, trustTag)
            end)
        end
    end

    -- L'enregistrement est volontairement retarde jusqu'a ce que Blizzard ait
    -- ouvert un menu lui-meme.
    --
    -- Appeler ModifyMenu des la connexion se fait avant que le code securise
    -- ait initialise son etat interne, ce qui contamine tout le systeme de
    -- menus. Contrepartie assumee, et documentee par RaiderIO d'ou vient
    -- l'approche : le tout premier menu de la session n'aura pas l'entree, il
    -- faut le rouvrir une fois.
    hooksecurefunc(manager, "OpenMenu", Register)
    hooksecurefunc(manager, "OpenContextMenu", Register)
end
