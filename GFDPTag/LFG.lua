-- GFDP Tag : affichage du tag dans la recherche de groupe
local ADDON_NAME, ns = ...

local LFG = {}
ns.LFG = LFG

local INTERVAL = 0.25   -- frequence de rafraichissement, en secondes

--------------------------------------------------------------------------------
-- Parcours des lignes affichees
--------------------------------------------------------------------------------

-- Les listes utilisent un ScrollBox depuis Dragonflight, un ScrollFrame avant.
local function ForEachRow(panel, callback)
    if not panel or not panel:IsShown() then return end

    local box = panel.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(callback)
        return
    end

    local scroll = panel.ScrollFrame
    if scroll and scroll.buttons then
        for _, button in ipairs(scroll.buttons) do
            if button:IsShown() then callback(button) end
        end
    end
end

--------------------------------------------------------------------------------
-- Liste des groupes : on tague le chef de groupe
--------------------------------------------------------------------------------

local function DecorateSearchResults()
    if not LFGListFrame or not C_LFGList then return end

    ForEachRow(LFGListFrame.SearchPanel, function(row)
        if not row or not row.resultID or not row.Name then return end
        local info = C_LFGList.GetSearchResultInfo(row.resultID)
        -- Le nom du chef n'est pas toujours connu (groupe non encore charge)
        ns.ApplyTagTo(row.Name, info and info.leaderName, ns.db.lfg)
    end)
end

--------------------------------------------------------------------------------
-- Candidatures a ton groupe : on tague le postulant
--------------------------------------------------------------------------------

local function DecorateApplicants()
    if not LFGListFrame or not C_LFGList then return end

    ForEachRow(LFGListFrame.ApplicationViewer, function(row)
        if not row or not row.applicantID or not row.Name then return end
        local name = C_LFGList.GetApplicantMemberInfo(row.applicantID, 1)
        ns.ApplyTagTo(row.Name, name, ns.db.lfg)
    end)
end

--------------------------------------------------------------------------------

function LFG:Refresh()
    DecorateSearchResults()
    DecorateApplicants()
end

function LFG:Init()
    if self.initialized then return end
    self.initialized = true

    -- Aucun hook sur les fonctions de Blizzard : le code de l'addon tourne
    -- uniquement dans son propre contexte (OnUpdate), jamais a l'interieur de
    -- la chaine d'appel du jeu. C'est ce qui avait contaminee l'execution et
    -- casse les cadres de raid ; voir le commentaire de Group.lua:Init.
    --
    -- Contrepartie : les lignes etant reconstruites par Blizzard au defilement
    -- comme au rafraichissement, il faut repasser periodiquement. On ne le fait
    -- que lorsque la fenetre est ouverte.
    local elapsed = 0
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < INTERVAL then return end
        elapsed = 0

        if not ns.db or not ns.db.lfg then return end
        if not LFGListFrame or not LFGListFrame:IsShown() then return end

        LFG:Refresh()
    end)
end
