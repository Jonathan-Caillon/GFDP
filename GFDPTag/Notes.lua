-- GFDP Tag : ecriture du tag dans les notes de la liste d'amis
local ADDON_NAME, ns = ...

local Notes = {}
ns.Notes = Notes

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
