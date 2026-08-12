-- GFDP Tag : ajout du tag dans l'infobulle des joueurs
local ADDON_NAME, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- Coupe-circuit : une erreur desactive la fonctionnalite pour la session au
-- lieu de se repeter a chaque infobulle affichee.
local disabled = false

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
-- Le GUID expose par GetPrimaryTooltipData(), lui, est exploitable, et
-- UnitTokenFromGUID en redérive un jeton d'unite utilisable. Technique reprise
-- de l'addon RaiderIO.
--
-- Il n'y a volontairement aucun repli sur le nom affiche dans l'infobulle :
-- ce texte ne permet ni de verifier qu'il s'agit d'un joueur (le tag ne doit
-- jamais apparaitre sur un PNJ) ni de connaitre le royaume. Si le GUID est
-- inexploitable, on n'affiche rien. RaiderIO fait le meme choix.
--
-- Le filtrage des PNJ est assure par ns.UnitNameRealm, qui appelle UnitIsPlayer.
--
-- @return name, realm  ou nil si l'identification echoue
local function GetTooltipPlayer(tooltip)
    if not tooltip.GetPrimaryTooltipData then return end
    if tooltip.IsTooltipType and not tooltip:IsTooltipType(Enum.TooltipDataType.Unit) then return end

    local data = tooltip:GetPrimaryTooltipData()
    local guid = ns.SafeString(data and data.guid)
    if not guid then return end

    return ns.UnitNameRealm(UnitTokenFromGUID(guid))
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
        if disabled then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            disabled = true
            ns.Print("|cffff5555Tag dans les infobulles desactive|r apres une erreur : %s", tostring(err))
        end
    end
end

function Tooltip:Init()
    if self.initialized then return end
    self.initialized = true

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Guard(function(tooltip)
        if not ns.db or not ns.db.tooltip then return end
        AddTagLine(tooltip, GetTooltipPlayer(tooltip))
    end))
end
