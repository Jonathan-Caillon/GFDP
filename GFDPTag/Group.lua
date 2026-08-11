-- GFDP Tag : affichage du tag sur les cadres de groupe
local ADDON_NAME, ns = ...

local Group = {}
ns.Group = Group

-- Retire un prefixe deja pose, quels que soient la couleur et le texte du tag.
local function Strip(text)
    if not text or text == "" then return text end
    return (text:gsub("^|cff%x%x%x%x%x%x%[.-%]|r ", ""))
end

--- Pose ou retire le tag selon que l'unite est dans la liste.
local function Apply(fontString, unit)
    if not ns.db then return end
    if not fontString or not unit then return end

    local current = fontString:GetText()
    if not current or current == "" then return end

    local wanted = Strip(current)
    if ns.db.group and UnitExists(unit) and UnitIsPlayer(unit) then
        local name, realm = UnitName(unit)
        if name and ns.Roster:IsTagged(name, realm) then
            wanted = ns.ColoredTag() .. " " .. wanted
        end
    end

    if wanted ~= current then
        fontString:SetText(wanted)
    end
end

-- Parcourt les cadres de groupe standard.
-- Retail expose PartyFrame.MemberFrame1..4, Classic PartyMemberFrame1..4.
--
-- Les cadres de raid et les cadres de groupe "style raid" sont volontairement
-- exclus : voir le commentaire de Init().
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
function Group:Refresh()
    self:UpdatePartyFrames()
end

function Group:Init()
    if self.initialized then return end
    self.initialized = true

    -- Pas de hook sur CompactUnitFrame_UpdateName, donc pas de tag sur les
    -- cadres de raid ni sur les cadres de groupe "style raid".
    --
    -- hooksecurefunc fait tourner le code de l'addon a l'interieur de la chaine
    -- d'appel de Blizzard. Depuis Midnight, l'execution est alors marquee comme
    -- contaminee, et la suite de la chaine (UpdateAll -> UpdateHealth ->
    -- UpdateHealthColor) compare des valeurs "secretes", ce que le client
    -- refuse en execution contaminee :
    --
    --   CompactUnitFrame.lua:692: attempt to compare local 'oldR'
    --   (a secret number value, while execution tainted by 'GFDPTag')
    --
    -- L'erreur se repetait a chaque reconstruction des cadres. Aucun reglage du
    -- hook n'evite cela : c'est le fait meme d'executer du code d'addon dans
    -- cette chaine qui contamine. Les cadres ci-dessous sont mis a jour depuis
    -- notre propre contexte (evenement + timer), jamais depuis celui de Blizzard.
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
