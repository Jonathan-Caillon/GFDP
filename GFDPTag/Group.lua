-- GFDP Tag : affichage du tag sur les cadres de groupe et de raid
local ADDON_NAME, ns = ...

local Group = {}
ns.Group = Group

-- Garde-fou : SetText ne redeclenche pas UpdateName, mais si un autre addon
-- s'intercale dans la chaine, ce drapeau empeche toute reentrance.
local busy = false

-- Retire un prefixe deja pose, quels que soient la couleur et le texte du tag.
local function Strip(text)
    if not text or text == "" then return text end
    return (text:gsub("^|cff%x%x%x%x%x%x%[.-%]|r ", ""))
end

--- Pose ou retire le tag selon que l'unite est dans la liste.
-- Le retrait est fait ici aussi : c'est ce qui permet a un /gfdp del de
-- s'appliquer aux cadres de raid sans avoir a forcer un rafraichissement.
local function Apply(fontString, unit)
    if busy then return end
    if not ns.db then return end
    if not fontString or not unit then return end

    local current = fontString:GetText()
    if not current or current == "" then return end

    local wanted = current
    if ns.db.group and UnitExists(unit) and UnitIsPlayer(unit) then
        local name, realm = UnitName(unit)
        if name and ns.Roster:IsTagged(name, realm) then
            wanted = ns.ColoredTag() .. " " .. Strip(current)
        else
            wanted = Strip(current)
        end
    else
        wanted = Strip(current)
    end

    if wanted ~= current then
        busy = true
        fontString:SetText(wanted)
        busy = false
    end
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

function Group:UpdatePartyFrames()
    ForEachPartyFrame(Apply)
end

--- Reapplique le tag apres un import ou un changement de reglage.
-- Ne touche volontairement pas aux cadres de raid : CompactRaidFrameContainer
-- est pilote par du code securise, l'appeler depuis un addon le contaminerait
-- et provoquerait des "action bloquee" a repetition. Les cadres de raid se
-- remettent a jour seuls au prochain passage de Blizzard sur UpdateName.
function Group:Refresh()
    self:UpdatePartyFrames()
end

function Group:Init()
    if self.initialized then return end
    self.initialized = true

    -- Cadres de raid, et cadres de groupe en mode "raid" : un seul point d'entree.
    -- Blizzard reconstruit le nom a chaque appel, le hook repasse donc apres lui.
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if frame and frame.unit and frame.name then
                Apply(frame.name, frame.unit)
            end
        end)
    end

    -- Cadres de groupe classiques : aucune fonction globale hookable sur toutes
    -- les versions, on repasse donc sur evenement.
    --
    -- UNIT_NAME_UPDATE n'est volontairement PAS ecoute : sans filtre il se
    -- declenche pour toutes les unites du monde, des dizaines de fois par
    -- seconde, et empilait autant de timers. Le nom des membres est de toute
    -- facon ecrit lors des changements de roster.
    local pending = false
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if pending then return end   -- un seul passage en attente a la fois
        pending = true
        C_Timer.After(0.1, function()
            pending = false
            Group:UpdatePartyFrames()
        end)
    end)
end
