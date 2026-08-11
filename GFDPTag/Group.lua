-- GFDP Tag : affichage du tag sur les cadres de groupe et de raid
local ADDON_NAME, ns = ...

local Group = {}
ns.Group = Group

-- Prefixe le nom affiche par le tag, sans jamais l'appliquer deux fois.
local function Decorate(fontString, unit)
    if not ns.db or not ns.db.group then return end
    if not fontString or not unit then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local name, realm = UnitName(unit)
    if not name or not ns.Roster:IsTagged(name, realm) then return end

    local current = fontString:GetText()
    if not current or current == "" then return end

    local prefix = ns.ColoredTag() .. " "
    if current:sub(1, #prefix) == prefix then return end   -- deja decore

    fontString:SetText(prefix .. current)
end

-- Parcourt les cadres de groupe, quelle que soit la version du client.
-- Retail expose PartyFrame.MemberFrame1..4, Classic PartyMemberFrame1..4.
local function ForEachPartyFrame(callback)
    if PartyFrame then
        for i = 1, 4 do
            local member = PartyFrame["MemberFrame" .. i]
            if member then
                callback(member.Name, member.unit or ("party" .. i))
            end
        end
    end
    for i = 1, 4 do
        local fontString = _G["PartyMemberFrame" .. i .. "Name"]
        if fontString then
            local frame = _G["PartyMemberFrame" .. i]
            callback(fontString, frame and frame.unit or ("party" .. i))
        end
    end
end

-- Retire un prefixe deja pose. Blizzard ne reecrit le nom des cadres de groupe
-- qu'au prochain changement de roster : sans ce nettoyage, le tag resterait
-- affiche apres un /gfdp del ou un /gfdp group off.
local function Undecorate(fontString)
    if not fontString then return end
    local current = fontString:GetText()
    if not current or current == "" then return end
    local stripped = current:gsub("^|cff%x%x%x%x%x%x%[.-%]|r ", "")
    if stripped ~= current then
        fontString:SetText(stripped)
    end
end

function Group:UpdatePartyFrames()
    ForEachPartyFrame(function(fontString, unit)
        Undecorate(fontString)
        Decorate(fontString, unit)
    end)
end

--- Reapplique le tag partout (apres un import ou un changement de reglage).
function Group:Refresh()
    self:UpdatePartyFrames()
    if CompactRaidFrameContainer and CompactRaidFrameContainer.TryUpdate then
        CompactRaidFrameContainer:TryUpdate()
    end
end

function Group:Init()
    if self.initialized then return end
    self.initialized = true

    -- Cadres de raid, et cadres de groupe en mode "raid" : un seul point d'entree.
    -- Blizzard reconstruit le nom a chaque appel, le hook repasse donc apres lui.
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if frame and frame.unit and frame.name then
                Decorate(frame.name, frame.unit)
            end
        end)
    end

    -- Cadres de groupe classiques : pas de fonction globale a hooker sur toutes
    -- les versions, on repasse donc sur evenement.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("UNIT_NAME_UPDATE")
    watcher:SetScript("OnEvent", function()
        -- Blizzard ecrit le nom dans la meme frame que l'evenement : on repasse apres.
        C_Timer.After(0.1, function() Group:UpdatePartyFrames() end)
    end)
end
