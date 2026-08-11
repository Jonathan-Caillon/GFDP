-- GFDP Tag : fenetre d'import CSV (copier/coller depuis le fichier)
local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local HELP_TEXT =
    "Ouvre ton fichier .csv (Bloc-notes, Excel...), selectionne tout (Ctrl+A), copie (Ctrl+C), "
    .. "puis colle ici (Ctrl+V).\n"
    .. "Formats acceptes : |cffffff00Nom|r, |cffffff00Nom-Royaume|r, ou colonnes |cffffff00nom;royaume|r. "
    .. "Une ligne d'en-tete est detectee automatiquement."

local function CreateFrame_Import()
    local f = CreateFrame("Frame", "GFDPTagImportFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(520, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- L'emplacement du titre differe selon les versions du client
    local title = "GFDP Tag - Import CSV"
    if f.SetTitle then
        f:SetTitle(title)
    elseif f.TitleText then
        f.TitleText:SetText(title)
    elseif f.TitleContainer and f.TitleContainer.TitleText then
        f.TitleContainer.TitleText:SetText(title)
    end

    -- Texte d'aide
    local help = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 18, -34)
    help:SetPoint("TOPRIGHT", -18, -34)
    help:SetJustifyH("LEFT")
    help:SetText(HELP_TEXT)

    -- Zone de saisie defilante
    local scroll = CreateFrame("ScrollFrame", "GFDPTagImportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 76)

    local edit = CreateFrame("EditBox", "GFDPTagImportEditBox", scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(440)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnTextChanged", function(self)
        local lines = select(2, self:GetText():gsub("\n", "")) + 1
        f.status:SetText(("%d ligne(s) collee(s)"):format(self:GetText() == "" and 0 or lines))
    end)
    scroll:SetScrollChild(edit)
    f.edit = edit

    -- Fond de la zone de saisie
    local bg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    bg:SetPoint("TOPLEFT", scroll, -6, 6)
    bg:SetPoint("BOTTOMRIGHT", scroll, 28, -6)
    bg:SetFrameLevel(f:GetFrameLevel() + 1)
    scroll:SetFrameLevel(bg:GetFrameLevel() + 1)
    edit:SetScript("OnMouseUp", function() edit:SetFocus() end)

    -- Etat / compteur
    local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 20, 54)
    status:SetText("0 ligne(s) collee(s)")
    f.status = status

    -- Boutons
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(150, 24)
    addBtn:SetPoint("BOTTOMLEFT", 18, 18)
    addBtn:SetText("Ajouter a la liste")
    addBtn:SetScript("OnClick", function() UI:DoImport(false) end)

    local replaceBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    replaceBtn:SetSize(150, 24)
    replaceBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    replaceBtn:SetText("Remplacer la liste")
    replaceBtn:SetScript("OnClick", function() UI:DoImport(true) end)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 24)
    clearBtn:SetPoint("LEFT", replaceBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Vider le champ")
    clearBtn:SetScript("OnClick", function()
        f.edit:SetText("")
        f.edit:SetFocus()
    end)

    tinsert(UISpecialFrames, "GFDPTagImportFrame")   -- fermeture avec Echap
    return f
end

function UI:Toggle()
    if not self.frame then
        self.frame = CreateFrame_Import()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self.frame.edit:SetFocus()
    end
end

function UI:DoImport(replace)
    local text = self.frame.edit:GetText()
    if ns.Trim(text) == "" then
        ns.Print("Le champ est vide : colle d'abord le contenu de ton fichier CSV.")
        return
    end

    local added, parsed, stats = ns.Roster:ImportCSV(text, replace)
    ns.Print("Import termine : |cff33ff99%d|r nouveau(x) joueur(s) sur %d ligne(s) lue(s)%s. Total : %d.",
        added, parsed,
        stats.skipped > 0 and (", " .. stats.skipped .. " ignoree(s)") or "",
        ns.Roster:Count())

    self.frame.edit:SetText("")
    self.frame:Hide()
end
