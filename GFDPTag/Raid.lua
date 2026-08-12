-- GFDP Tag : affichage du tag sur les cadres de raid
local ADDON_NAME, ns = ...

local Raid = {}
ns.Raid = Raid

-- Le sondage ne sert qu'a suivre l'unite affectee a chaque cadre, que Blizzard
-- peut changer sans prevenir (tri, arrivee, depart). Le tag, lui, tient tout
-- seul entre deux passages : un intervalle large suffit donc.
local INTERVAL = 0.5

--------------------------------------------------------------------------------
-- Parcours des cadres
--------------------------------------------------------------------------------

-- Les cadres compacts portent des noms globaux, ce qui permet de les atteindre
-- sans jamais toucher a CompactRaidFrameContainer, pilote par du code securise.
local function ForEachCompactFrame(callback)
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then callback(frame) end
    end
    -- Groupe affiche en "style raid"
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then callback(frame) end
    end
    -- Disposition "garder les groupes ensemble"
    for g = 1, 8 do
        for m = 1, 5 do
            local frame = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if frame then callback(frame) end
        end
    end
end

--------------------------------------------------------------------------------
-- Le tag, dans notre propre FontString
--------------------------------------------------------------------------------

-- Prefixer le nom faisait scintiller le tag : Blizzard reecrit ce texte tres
-- souvent, notamment au survol d'une cible, ce qui effaçait le prefixe jusqu'au
-- passage suivant du sondage. Un FontString qui nous appartient n'est jamais
-- reecrit par le jeu : l'affichage est stable par construction.
local function EnsureTagString(frame)
    if frame.GFDPTagText then return frame.GFDPTagText end

    local fs = frame:CreateFontString(nil, "OVERLAY")
    -- Meme police que le nom, pour suivre les reglages d'affichage du joueur
    fs:SetFontObject(frame.name and frame.name:GetFontObject() or GameFontNormalSmall)
    frame.GFDPTagText = fs
    return fs
end

-- Place le tag juste apres le texte du nom.
--
-- On ne peut pas se contenter d'ancrer a droite du FontString du nom : sa boite
-- fait toute la largeur du cadre, le tag se retrouverait colle au bord. On
-- calcule donc la largeur reellement occupee par le texte, en tenant compte de
-- sa justification.
local function PositionTag(nameString, tagString)
    local width = nameString:GetStringWidth() or 0
    local justify = nameString:GetJustifyH()

    tagString:ClearAllPoints()
    if justify == "RIGHT" then
        tagString:SetPoint("LEFT", nameString, "RIGHT", 3, 0)
    elseif justify == "CENTER" then
        tagString:SetPoint("LEFT", nameString, "CENTER", (width / 2) + 3, 0)
    else
        tagString:SetPoint("LEFT", nameString, "LEFT", width + 3, 0)
    end
end

--------------------------------------------------------------------------------

function Raid:Update()
    ForEachCompactFrame(function(frame)
        local nameString = frame.name
        if not nameString then return end

        -- frame.unit peut etre une valeur "secrete" : le passer a UnitIsPlayer ou
        -- UnitName provoquerait une erreur en execution contaminee. ns.IsSecret
        -- le teste avant, et on se rabat sur le nom affiche le cas echeant --
        -- sans royaume, donc, la correspondance se faisant alors sur le royaume
        -- du joueur connecte.
        -- Aucun repli sur le texte affiche : il ne permet pas de verifier qu'il
        -- s'agit d'un joueur, et les cadres compacts affichent aussi les
        -- familiers. ns.UnitNameRealm appelle UnitIsPlayer, ce qui les ecarte.
        local show = false
        if ns.db and ns.db.raid and frame:IsShown() then
            local name, realm = ns.UnitNameRealm(frame.unit)
            show = (name and ns.Roster:IsTagged(name, realm)) and true or false
        end

        -- Rien a afficher : on evite de creer un FontString inutile
        if not show then
            if frame.GFDPTagText then frame.GFDPTagText:SetText("") end
            return
        end

        local tagString = EnsureTagString(frame)
        tagString:SetText(ns.ColoredTag())
        -- Recalcule a chaque passage : la largeur change avec le nom affiche
        PositionTag(nameString, tagString)
    end)
end

function Raid:Init()
    if self.initialized then return end
    self.initialized = true

    -- AUCUN hook. hooksecurefunc("CompactUnitFrame_UpdateName") faisait tourner
    -- le code de l'addon a l'interieur de la chaine d'appel de Blizzard. Depuis
    -- Midnight, l'execution etait alors marquee comme contaminee, et la suite de
    -- la chaine comparait des valeurs "secretes", ce que le client refuse :
    --
    --   CompactUnitFrame.lua:692: attempt to compare local 'oldR'
    --   (a secret number value, while execution tainted by 'GFDPTag')
    --
    -- Ici tout se fait depuis notre propre contexte : on ne compare aucune
    -- valeur secrete et on n'appelle aucune fonction protegee.
    -- Coupe-circuit : le sondage tourne en continu, une erreur non capturee
    -- serait repetee deux fois par seconde. On previent une fois et on s'arrete.
    local disabled = false

    local elapsed = 0
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, delta)
        if disabled then return end

        elapsed = elapsed + delta
        if elapsed < INTERVAL then return end
        elapsed = 0

        if not ns.db or not ns.db.raid then return end
        if not IsInGroup() then return end

        local ok, err = pcall(Raid.Update, Raid)
        if not ok then
            disabled = true
            ns.Print("|cffff5555Tag sur les cadres de raid desactive|r apres une erreur : %s", tostring(err))
        end
    end)
end
