-- GFDP Tag : commandes /gfdp
local ADDON_NAME, ns = ...

SLASH_GFDPTAG1 = "/gfdp"
SLASH_GFDPTAG2 = "/gfdptag"

local function ShowHelp()
    ns.Print("Commandes disponibles :")
    local lines = {
        { "/gfdp",                    "ouvre la fenetre d'import CSV" },
        { "/gfdp add <Nom[-Royaume]>", "ajoute un joueur a la liste" },
        { "/gfdp del <Nom[-Royaume]>", "retire un joueur de la liste" },
        { "/gfdp check <Nom>",        "verifie si un joueur est dans la liste" },
        { "/gfdp list",               "affiche la liste complete" },
        { "/gfdp count",              "nombre de joueurs dans la liste" },
        { "/gfdp clear",              "vide la liste" },
        { "/gfdp tooltip on|off",     "tag dans les infobulles" },
        { "/gfdp chat on|off",        "tag dans le chat" },
        { "/gfdp raid on|off",        "tag sur les cadres de raid" },
        { "/gfdp lfg on|off",         "tag dans la recherche de groupe" },
        { "/gfdp tag <texte>",        "change le texte du tag (defaut : GFDP)" },
    }
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(("  |cffffff00%s|r  -  %s"):format(line[1], line[2]))
    end
end

local function ParseToggle(value)
    value = (value or ""):lower()
    if value == "on" or value == "1" or value == "oui" then return true end
    if value == "off" or value == "0" or value == "non" then return false end
    return nil
end

SlashCmdList["GFDPTAG"] = function(input)
    input = ns.Trim(input)
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = ns.Trim(rest)

    if cmd == "" or cmd == "import" then
        ns.UI:Toggle()

    elseif cmd == "add" or cmd == "ajouter" then
        if rest == "" then
            ns.Print("Usage : /gfdp add <Nom[-Royaume]>")
        elseif ns.Roster:Add(rest) then
            ns.Print("|cff33ff99%s|r ajoute a la liste (total : %d).", rest, ns.Roster:Count())
        else
            ns.Print("%s est deja dans la liste.", rest)
        end

    elseif cmd == "del" or cmd == "remove" or cmd == "supprimer" then
        if rest == "" then
            ns.Print("Usage : /gfdp del <Nom[-Royaume]>")
        elseif ns.Roster:Remove(rest) then
            ns.Print("%s retire de la liste (total : %d).", rest, ns.Roster:Count())
        else
            ns.Print("%s n'est pas dans la liste.", rest)
        end

    elseif cmd == "check" then
        if rest == "" then
            ns.Print("Usage : /gfdp check <Nom[-Royaume]>")
        elseif ns.Roster:IsTagged(rest) then
            ns.Print("%s est |cff33ff99dans|r la liste.", rest)
        else
            ns.Print("%s n'est |cffff5555pas|r dans la liste.", rest)
        end

    elseif cmd == "list" or cmd == "liste" then
        local all = ns.Roster:GetAll()
        if #all == 0 then
            ns.Print("La liste est vide. Tape |cffffff00/gfdp|r pour importer un CSV.")
        else
            ns.Print("%d joueur(s) :", #all)
            for _, entry in ipairs(all) do
                DEFAULT_CHAT_FRAME:AddMessage(("  %s%s"):format(
                    entry.name,
                    entry.realm and ("|cff888888-" .. entry.realm .. "|r") or "|cff888888 (tous royaumes)|r"))
            end
        end

    elseif cmd == "count" or cmd == "nombre" then
        ns.Print("%d joueur(s) dans la liste.", ns.Roster:Count())

    elseif cmd == "clear" or cmd == "vider" then
        local removed = ns.Roster:Clear()
        ns.Print("Liste videe (%d entree(s) supprimee(s)).", removed)

    elseif cmd == "tooltip" or cmd == "infobulle" then
        local value = ParseToggle(rest)
        if value == nil then
            ns.Print("Infobulle : %s. Usage : /gfdp tooltip on|off", ns.db.tooltip and "activee" or "desactivee")
        else
            ns.db.tooltip = value
            ns.Print("Infobulle %s.", value and "activee" or "desactivee")
        end

    elseif cmd == "chat" then
        local value = ParseToggle(rest)
        if value == nil then
            ns.Print("Chat : %s. Usage : /gfdp chat on|off", ns.db.chat and "active" or "desactive")
        else
            ns.db.chat = value
            ns.Print("Chat %s.", value and "active" or "desactive")
        end

    elseif cmd == "raid" then
        local value = ParseToggle(rest)
        if value == nil then
            ns.Print("Cadres de raid : %s. Usage : /gfdp raid on|off", ns.db.raid and "active" or "desactive")
        else
            ns.db.raid = value
            ns.Raid:Update()   -- retire les tags deja poses si on desactive
            ns.Print("Tag sur les cadres de raid %s.", value and "active" or "desactive")
        end

    elseif cmd == "lfg" or cmd == "recherche" then
        local value = ParseToggle(rest)
        if value == nil then
            ns.Print("Recherche de groupe : %s. Usage : /gfdp lfg on|off", ns.db.lfg and "active" or "desactive")
        else
            ns.db.lfg = value
            ns.LFG:Refresh()   -- retire les tags deja poses si on desactive
            ns.Print("Tag dans la recherche de groupe %s.", value and "active" or "desactive")
        end

    elseif cmd == "tag" then
        if rest == "" then
            ns.Print("Tag actuel : %s. Usage : /gfdp tag <texte>", ns.ColoredTag())
        else
            ns.db.tag = rest
            ns.Print("Tag defini sur %s.", ns.ColoredTag())
        end

    else
        ShowHelp()
    end
end
