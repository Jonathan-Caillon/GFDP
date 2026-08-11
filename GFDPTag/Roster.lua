-- GFDP Tag : gestion de la liste de joueurs + parseur CSV
local ADDON_NAME, ns = ...

local Roster = {}
ns.Roster = Roster

--------------------------------------------------------------------------------
-- Parseur CSV
--------------------------------------------------------------------------------

-- Detecte le separateur le plus probable en comptant les occurrences sur
-- l'ensemble du fichier (une seule ligne ne suffit pas : un fichier peut
-- commencer par une colonne unique et utiliser un separateur plus bas).
local function DetectDelimiter(text)
    local best, bestCount = ",", 0
    for _, sep in ipairs({ ",", ";", "\t", "|" }) do
        local _, count = text:gsub("%" .. sep, "")
        if count > bestCount then
            best, bestCount = sep, count
        end
    end
    return best
end

-- Parseur CSV tolerant : gere les guillemets, les guillemets doubles ("") et CRLF
local function ParseCSV(text, delim)
    text = text:gsub("^\239\187\191", "")   -- retire le BOM UTF-8
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    delim = delim or DetectDelimiter(text)

    local rows, row, field = {}, {}, {}
    local inQuotes = false
    local i, len = 1, #text

    local function endField()
        row[#row + 1] = ns.Trim(table.concat(field))
        field = {}
    end

    local function endRow()
        endField()
        local hasContent = false
        for _, v in ipairs(row) do
            if v ~= "" then hasContent = true break end
        end
        if hasContent then rows[#rows + 1] = row end
        row = {}
    end

    while i <= len do
        local c = text:sub(i, i)
        if inQuotes then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then
                    field[#field + 1] = '"'
                    i = i + 1
                else
                    inQuotes = false
                end
            else
                field[#field + 1] = c
            end
        else
            if c == '"' then
                inQuotes = true
            elseif c == delim then
                endField()
            elseif c == "\n" then
                endRow()
            else
                field[#field + 1] = c
            end
        end
        i = i + 1
    end
    endRow()

    return rows
end

-- Mots-cles reconnus dans la ligne d'en-tete (FR + EN)
local NAME_KEYS = {
    ["name"] = true, ["nom"] = true, ["player"] = true, ["joueur"] = true,
    ["character"] = true, ["personnage"] = true, ["perso"] = true,
    ["charactername"] = true, ["playername"] = true, ["pseudo"] = true,
}
local REALM_KEYS = {
    ["realm"] = true, ["royaume"] = true, ["server"] = true, ["serveur"] = true,
    ["realmname"] = true,
}

local function HeaderIndexes(row)
    local nameCol, realmCol
    for idx, value in ipairs(row) do
        local key = value:lower():gsub("[%s_%-]", "")
        if NAME_KEYS[key] and not nameCol then
            nameCol = idx
        elseif REALM_KEYS[key] and not realmCol then
            realmCol = idx
        end
    end
    return nameCol, realmCol
end

--- Analyse un texte CSV et renvoie une liste { {name=, realm=}, ... }
-- @return entries, stats  (stats = { rows, skipped, header })
function Roster:ParseCSVText(text)
    local rows = ParseCSV(text)
    local entries, skipped = {}, 0
    if #rows == 0 then
        return entries, { rows = 0, skipped = 0, header = false }
    end

    local nameCol, realmCol = HeaderIndexes(rows[1])
    local startRow = 1
    local hasHeader = false
    if nameCol then
        hasHeader = true
        startRow = 2
    else
        nameCol = 1
        realmCol = 2   -- par convention : colonne 1 = nom, colonne 2 = royaume (si presente)
    end

    for r = startRow, #rows do
        local row = rows[r]
        local raw = ns.Trim(row[nameCol] or "")
        local realm = realmCol and ns.Trim(row[realmCol] or "") or ""

        -- Supporte aussi "Nom-Royaume" dans une seule colonne
        local name, inlineRealm = ns.SplitName(raw)
        if inlineRealm and inlineRealm ~= "" then
            realm = inlineRealm
        end

        -- Ignore les lignes vides ou manifestement invalides
        if name == "" or name:find("[%d%p]") == 1 then
            skipped = skipped + 1
        else
            entries[#entries + 1] = { name = name, realm = realm ~= "" and realm or nil }
        end
    end

    return entries, { rows = #rows, skipped = skipped, header = hasHeader }
end

--------------------------------------------------------------------------------
-- Lecture / ecriture de la liste
--------------------------------------------------------------------------------

local function FullKey(name, realm)
    return ns.NormalizeName(name) .. "-" .. ns.NormalizeRealm(realm)
end

--- Ajoute un joueur. Si realm est nil, le joueur est tagge sur tous les royaumes.
function Roster:Add(name, realm)
    name = ns.Trim(name)
    if name == "" then return false end

    local inlineName, inlineRealm = ns.SplitName(name)
    name = inlineName
    realm = ns.Trim(realm or inlineRealm or "")

    if realm ~= "" then
        local key = FullKey(name, realm)
        if ns.db.entriesByFull[key] then return false end
        ns.db.entriesByFull[key] = { name = name, realm = realm }
    else
        local key = ns.NormalizeName(name)
        if ns.db.entriesByName[key] then return false end
        ns.db.entriesByName[key] = { name = name }
    end
    return true
end

--- Retire un joueur (avec ou sans royaume).
function Roster:Remove(name, realm)
    name = ns.Trim(name)
    if name == "" then return false end

    local inlineName, inlineRealm = ns.SplitName(name)
    name = inlineName
    realm = ns.Trim(realm or inlineRealm or "")

    local removed = false
    if realm ~= "" then
        local key = FullKey(name, realm)
        if ns.db.entriesByFull[key] then
            ns.db.entriesByFull[key] = nil
            removed = true
        end
    end
    -- Retire aussi l'entree "tous royaumes" et toutes les variantes du nom
    local nameKey = ns.NormalizeName(name)
    if ns.db.entriesByName[nameKey] then
        ns.db.entriesByName[nameKey] = nil
        removed = true
    end
    if realm == "" then
        for key, data in pairs(ns.db.entriesByFull) do
            if ns.NormalizeName(data.name) == nameKey then
                ns.db.entriesByFull[key] = nil
                removed = true
            end
        end
    end
    return removed
end

--- Le joueur est-il dans la liste ?
-- @param name  nom du personnage (peut contenir "-Royaume")
-- @param realm royaume (optionnel ; par defaut celui du joueur connecte)
function Roster:IsTagged(name, realm)
    if not name or name == "" then return false end

    local inlineName, inlineRealm = ns.SplitName(name)
    name = inlineName
    realm = ns.Trim(realm or inlineRealm or "")
    if realm == "" then
        realm = ns.PlayerRealm()
    end

    local nameKey = ns.NormalizeName(name)
    local fullKey = nameKey .. "-" .. ns.NormalizeRealm(realm)

    return (ns.db.entriesByFull[fullKey] ~= nil)
        or (ns.db.entriesByName[nameKey] ~= nil)
end

--- Vide entierement la liste.
function Roster:Clear()
    local count = self:Count()
    wipe(ns.db.entriesByFull)
    wipe(ns.db.entriesByName)
    return count
end

--- Nombre d'entrees dans la liste.
function Roster:Count()
    local n = 0
    for _ in pairs(ns.db.entriesByFull) do n = n + 1 end
    for _ in pairs(ns.db.entriesByName) do n = n + 1 end
    return n
end

--- Liste triee de toutes les entrees : { { name=, realm= }, ... }
function Roster:GetAll()
    local out = {}
    for _, data in pairs(ns.db.entriesByFull) do
        out[#out + 1] = { name = data.name, realm = data.realm }
    end
    for _, data in pairs(ns.db.entriesByName) do
        out[#out + 1] = { name = data.name, realm = nil }
    end
    table.sort(out, function(a, b)
        if a.name == b.name then
            return (a.realm or "") < (b.realm or "")
        end
        return a.name < b.name
    end)
    return out
end

--- Importe un texte CSV. replace = true pour remplacer la liste existante.
-- @return added, total, stats
function Roster:ImportCSV(text, replace)
    local entries, stats = self:ParseCSVText(text)
    if replace then
        self:Clear()
    end
    local added = 0
    for _, entry in ipairs(entries) do
        if self:Add(entry.name, entry.realm) then
            added = added + 1
        end
    end
    return added, #entries, stats
end
