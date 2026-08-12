-- GFDP Tag : prefixe les messages de chat des joueurs tagges
local ADDON_NAME, ns = ...

local Chat = {}
ns.Chat = Chat

local EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
    -- Canal des communautes : canal social courant des guildes actuelles, un
    -- membre y ecrivant n'etait pas tague alors qu'il l'etait dans /guilde.
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

-- Le tag est insere en tete du message plutot que dans le nom de l'auteur :
-- modifier le nom casserait le lien cliquable et le menu contextuel du joueur.
local function Filter(frame, event, msg, author, ...)
    if not ns.db or not ns.db.chat then return false end

    -- Teste le caractere secret avant toute comparaison : voir ns.SafeString
    local sender = ns.SafeString(author)
    if not sender then return false end

    local name, realm = ns.SplitName(sender)
    if ns.Roster:IsTagged(name, realm) then
        -- Le texte du message peut lui aussi etre une valeur secrete : le
        -- concatener sans l'avoir valide leverait une erreur.
        local safeMessage = ns.SafeString(msg)
        if not safeMessage then return false end

        return false, ns.ColoredTag() .. " " .. safeMessage, author, ...
    end
    return false
end

function Chat:Init()
    if self.initialized then return end
    self.initialized = true
    for _, event in ipairs(EVENTS) do
        ChatFrame_AddMessageEventFilter(event, Filter)
    end
end
