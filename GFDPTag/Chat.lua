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
}

-- Le tag est insere en tete du message plutot que dans le nom de l'auteur :
-- modifier le nom casserait le lien cliquable et le menu contextuel du joueur.
local function Filter(frame, event, msg, author, ...)
    if not ns.db or not ns.db.chat then return false end
    if not author or author == "" then return false end

    local name, realm = ns.SplitName(author)
    if ns.Roster:IsTagged(name, realm) then
        return false, ns.ColoredTag() .. " " .. msg, author, ...
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
