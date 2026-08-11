-- GFDP Tag : noyau de l'addon (config, evenements, utilitaires)
local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = "1.0.0"

-- Valeurs par defaut de la base sauvegardee (SavedVariables : GFDPTagDB)
local DEFAULTS = {
    tag        = "GFDP",     -- texte du tag
    color      = "33ff99",   -- couleur RRGGBB du tag
    tooltip    = true,       -- afficher le tag dans l'infobulle des joueurs
    chat       = true,       -- prefixer les messages de chat des joueurs tagges
    entriesByFull = {},      -- ["nom-royaume"] = { name = "Nom", realm = "Royaume" }
    entriesByName = {},      -- ["nom"]         = { name = "Nom" }  (tous royaumes)
}

--------------------------------------------------------------------------------
-- Utilitaires
--------------------------------------------------------------------------------

function ns.Print(msg, ...)
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GFDP|r: " .. tostring(msg))
end

function ns.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Normalise un nom de royaume : "Conseil des Ombres" -> "conseildesombres"
function ns.NormalizeRealm(realm)
    realm = ns.Trim(realm)
    if realm == "" then return "" end
    realm = realm:gsub("[%s%-'’]", "")
    return realm:lower()
end

-- Normalise un nom de personnage (sans royaume)
function ns.NormalizeName(name)
    name = ns.Trim(name)
    if name == "" then return "" end
    return name:lower()
end

-- Coupe "Nom-Royaume" en deux. Accepte aussi "Nom" seul.
function ns.SplitName(full)
    full = ns.Trim(full)
    local name, realm = full:match("^([^%-]+)%-(.+)$")
    if name then
        return ns.Trim(name), ns.Trim(realm)
    end
    return full, nil
end

-- Royaume du joueur connecte, normalise
function ns.PlayerRealm()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = GetRealmName() or ""
    end
    return ns.NormalizeRealm(realm)
end

-- Le tag colore, pret a etre insere dans du texte
function ns.ColoredTag()
    local db = GFDPTagDB or DEFAULTS
    return ("|cff%s[%s]|r"):format(db.color or "33ff99", db.tag or "GFDP")
end

-- Le tag brut (pour les notes de guilde / d'amis, qui n'acceptent pas les codes couleur)
function ns.PlainTag()
    local db = GFDPTagDB or DEFAULTS
    return db.tag or "GFDP"
end

--------------------------------------------------------------------------------
-- Initialisation
--------------------------------------------------------------------------------

local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
            else
                db[k] = v
            end
        end
    end
    return db
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        GFDPTagDB = ApplyDefaults(GFDPTagDB or {}, DEFAULTS)
        ns.db = GFDPTagDB
    elseif event == "PLAYER_LOGIN" then
        ns.Tooltip:Init()
        ns.Chat:Init()
        ns.Print("v%s charge. %d joueur(s) dans la liste. Tape |cffffff00/gfdp|r pour importer un CSV.",
            ns.VERSION, ns.Roster:Count())
    end
end)
