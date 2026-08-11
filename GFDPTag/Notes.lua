-- GFDP Tag : ecriture du tag dans les notes de guilde et les notes d'amis
local ADDON_NAME, ns = ...

local Notes = {}
ns.Notes = Notes

local GUILD_NOTE_MAX  = 31    -- limite du client pour les notes de guilde
local FRIEND_NOTE_MAX = 128   -- limite du client pour les notes d'amis
local WRITE_INTERVAL  = 0.25  -- delai entre deux ecritures (evite le throttle serveur)

--------------------------------------------------------------------------------
-- Utilitaires
--------------------------------------------------------------------------------

-- La note contient-elle deja le tag (en mot entier, insensible a la casse) ?
local function HasTag(note, tag)
    if not note or note == "" then return false end
    local lower, needle = note:lower(), tag:lower()
    local from = 1
    while true do
        local s, e = lower:find(needle, from, true)
        if not s then return false end
        local before = s > 1 and lower:sub(s - 1, s - 1) or " "
        local after  = e < #lower and lower:sub(e + 1, e + 1) or " "
        if not before:match("[%w]") and not after:match("[%w]") then
            return true
        end
        from = e + 1
    end
end

-- Renvoie la nouvelle note, ou nil si rien a faire / si le tag ne tient pas
local function BuildNote(note, tag, maxLen)
    note = ns.Trim(note or "")
    if HasTag(note, tag) then return nil end
    local newNote = (note == "") and tag or (note .. " " .. tag)
    if #newNote > maxLen then return nil, "trop long" end
    return newNote
end

-- File d'attente d'ecritures, traitee lentement pour ne pas saturer le serveur
local function RunQueue(queue, onDone)
    local index = 0
    local ticker
    ticker = C_Timer.NewTicker(WRITE_INTERVAL, function()
        index = index + 1
        local job = queue[index]
        if job then
            job()
        end
        if index >= #queue then
            ticker:Cancel()
            if onDone then onDone() end
        end
    end, #queue + 1)
end

--------------------------------------------------------------------------------
-- Notes de guilde
--------------------------------------------------------------------------------

local function SetGuildNote(index, note, isPublic)
    if C_GuildInfo and C_GuildInfo.SetNote then
        C_GuildInfo.SetNote(index, note, isPublic)
    elseif isPublic and GuildRosterSetPublicNote then
        GuildRosterSetPublicNote(index, note)
    elseif not isPublic and GuildRosterSetOfficerNote then
        GuildRosterSetOfficerNote(index, note)
    end
end

--- Applique le tag aux notes de guilde des membres presents dans la liste.
-- @param isPublic true = note publique, false = note d'officier
-- @param apply    false = simulation (aucune ecriture)
function Notes:ApplyToGuild(isPublic, apply)
    if not IsInGuild() then
        ns.Print("Tu n'es dans aucune guilde.")
        return
    end

    local canEdit
    if isPublic then
        canEdit = not CanEditPublicNote or CanEditPublicNote()
    else
        canEdit = not CanEditOfficerNote or CanEditOfficerNote()
    end
    if apply and not canEdit then
        ns.Print("|cffff5555Droits insuffisants|r pour modifier les notes %s.",
            isPublic and "publiques" or "d'officier")
        return
    end

    -- Force un rafraichissement du roster avant lecture
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end

    local total = GetNumGuildMembers()
    if total == 0 then
        -- Le roster se charge de maniere asynchrone apres la connexion
        ns.Print("Roster de guilde pas encore charge. Ouvre l'onglet Guilde et relance la commande.")
        return
    end

    local PREVIEW_MAX = 20
    local queue, skipped, alreadyTagged, tooLong = {}, 0, 0, 0

    for i = 1, total do
        local fullName, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(i)
        if fullName then
            local name, realm = ns.SplitName(fullName)
            if ns.Roster:IsTagged(name, realm) then
                local current = isPublic and publicNote or officerNote
                local newNote, reason = BuildNote(current, ns.PlainTag(), GUILD_NOTE_MAX)
                if newNote then
                    local index, note = i, newNote
                    queue[#queue + 1] = function()
                        SetGuildNote(index, note, isPublic)
                    end
                    if not apply and #queue <= PREVIEW_MAX then
                        ns.Print("  %s : \"%s\" -> \"%s\"", fullName, current or "", newNote)
                    end
                elseif reason == "trop long" then
                    tooLong = tooLong + 1
                    ns.Print("  |cffff5555%s|r : note trop longue (max %d car.), ignore.", fullName, GUILD_NOTE_MAX)
                else
                    alreadyTagged = alreadyTagged + 1
                end
            else
                skipped = skipped + 1
            end
        end
    end

    local kind = isPublic and "publiques" or "d'officier"
    if #queue == 0 then
        ns.Print("Rien a modifier (%d deja taggue(s), %d hors liste, %d trop longue(s)).",
            alreadyTagged, skipped, tooLong)
        return
    end

    if not apply then
        if #queue > PREVIEW_MAX then
            ns.Print("  ... et %d autre(s).", #queue - PREVIEW_MAX)
        end
        ns.Print("Simulation : %d note(s) %s seraient modifiee(s). Confirme avec |cffffff00/gfdp guild%s confirm|r.",
            #queue, kind, isPublic and "" or " officer")
        return
    end

    ns.Print("Ecriture de %d note(s) %s en cours (~%.0f s)...", #queue, kind, #queue * WRITE_INTERVAL)
    RunQueue(queue, function()
        ns.Print("Termine : %d note(s) %s mise(s) a jour.", #queue, kind)
    end)
end

--------------------------------------------------------------------------------
-- Notes d'amis
--------------------------------------------------------------------------------

--- Applique le tag aux notes de la liste d'amis.
function Notes:ApplyToFriends(apply)
    if not C_FriendList then
        ns.Print("API liste d'amis indisponible sur cette version du client.")
        return
    end

    C_FriendList.ShowFriends()

    local total = C_FriendList.GetNumFriends()
    local queue, skipped, alreadyTagged = {}, 0, 0

    for i = 1, total do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            local name, realm = ns.SplitName(info.name)
            if ns.Roster:IsTagged(name, realm) then
                local newNote = BuildNote(info.notes, ns.PlainTag(), FRIEND_NOTE_MAX)
                if newNote then
                    local friendName, note = info.name, newNote
                    queue[#queue + 1] = function()
                        C_FriendList.SetFriendNotes(friendName, note)
                    end
                    if not apply then
                        ns.Print("  %s : \"%s\" -> \"%s\"", info.name, info.notes or "", newNote)
                    end
                else
                    alreadyTagged = alreadyTagged + 1
                end
            else
                skipped = skipped + 1
            end
        end
    end

    if #queue == 0 then
        ns.Print("Rien a modifier (%d deja taggue(s), %d hors liste).", alreadyTagged, skipped)
        return
    end

    if not apply then
        ns.Print("Simulation : %d note(s) d'ami seraient modifiee(s). Confirme avec |cffffff00/gfdp friends confirm|r.", #queue)
        return
    end

    ns.Print("Ecriture de %d note(s) d'ami en cours...", #queue)
    RunQueue(queue, function()
        ns.Print("Termine : %d note(s) d'ami mise(s) a jour.", #queue)
    end)
end
