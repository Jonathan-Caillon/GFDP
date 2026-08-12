-- GFDP Tag : ajout du tag dans l'infobulle des joueurs
local ADDON_NAME, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- Coupe-circuit : une erreur desactive la fonctionnalite au lieu de se repeter
-- a chaque infobulle. Le drapeau vit sur le module pour que /gfdp tooltip on
-- puisse le rearmer : sinon la commande annoncerait une reactivation sans effet.
Tooltip.disabled = false

local function TagColor()
    local color = (ns.db and ns.db.color) or "33ff99"
    return tonumber(color:sub(1, 2), 16) / 255,
           tonumber(color:sub(3, 4), 16) / 255,
           tonumber(color:sub(5, 6), 16) / 255
end

--- Identifie le joueur de l'infobulle, royaume compris.
--
-- On ne passe pas par tooltip:GetUnit() : depuis Midnight il renvoie une valeur
-- "secrete", que UnitExists ou UnitName refusent de traiter en execution
-- contaminee — donc toujours, dans le code d'un addon.
--
-- Le GUID expose par GetPrimaryTooltipData(), lui, est exploitable. Il est
-- resolu directement par ns.PlayerNameRealmFromGUID, sans passer par un jeton
-- d'unite : UnitTokenFromGUID renvoie nil des que le joueur ne correspond a
-- aucun jeton actif, ce qui faisait echouer la resolution sans raison.
--
-- Il n'y a volontairement aucun repli sur le nom affiche dans l'infobulle :
-- ce texte ne permet ni de verifier qu'il s'agit d'un joueur (le tag ne doit
-- jamais apparaitre sur un PNJ) ni de connaitre le royaume. Si le GUID est
-- inexploitable, on n'affiche rien. RaiderIO fait le meme choix.
--
-- Le filtrage des PNJ est assure par le prefixe "Player-" du GUID, verifie dans
-- ns.PlayerNameRealmFromGUID.
--
-- @return name, realm  ou nil si l'identification echoue
local function GetTooltipPlayer(tooltip)
    if not tooltip.GetPrimaryTooltipData then return end
    if tooltip.IsTooltipType and not tooltip:IsTooltipType(Enum.TooltipDataType.Unit) then return end

    local data = tooltip:GetPrimaryTooltipData()
    local guid = ns.SafeString(data and data.guid)
    if not guid then return end

    return ns.PlayerNameRealmFromGUID(guid)
end

local function AddTagLine(tooltip, name, realm)
    if not name or not ns.Roster:IsTagged(name, realm) then return end
    local r, g, b = TagColor()
    tooltip:AddLine(ns.db.tag, r, g, b)
    tooltip:Show()
end

-- Enveloppe un handler : en cas d'erreur, on previent une fois et on s'arrete.
local function Guard(fn)
    return function(...)
        if Tooltip.disabled then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            Tooltip.disabled = true
            ns.Print("|cffff5555Tag dans les infobulles desactive|r apres une erreur : %s", tostring(err))
        end
    end
end

function Tooltip:Init()
    if self.initialized then return end
    self.initialized = true

    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Unit then
        ns.Print("API d'infobulle indisponible : le tag dans les infobulles est desactive.")
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Guard(function(tooltip)
        if not ns.db or not ns.db.tooltip then return end

        -- Le post-call se declenche pour toute infobulle de type Unit, y compris
        -- celles d'autres addons et les infobulles de comparaison. On se limite
        -- aux deux infobulles de jeu.
        if tooltip ~= GameTooltip and tooltip ~= GameTooltipTooltip then return end

        AddTagLine(tooltip, GetTooltipPlayer(tooltip))
    end))
end
