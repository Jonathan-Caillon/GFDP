-- GFDP Tag : ajout du tag dans l'infobulle des joueurs
local ADDON_NAME, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local function AddTagLine(tooltip, unit)
    if not ns.db.tooltip then return end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local name, realm = UnitName(unit)
    if not name then return end

    if ns.Roster:IsTagged(name, realm) then
        local db = ns.db
        local r, g, b =
            tonumber(db.color:sub(1, 2), 16) / 255,
            tonumber(db.color:sub(3, 4), 16) / 255,
            tonumber(db.color:sub(5, 6), 16) / 255
        tooltip:AddLine(db.tag, r, g, b)
        tooltip:Show()
    end
end

function Tooltip:Init()
    if self.initialized then return end
    self.initialized = true

    -- Retail / Dragonflight+ : API TooltipDataProcessor
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if tooltip ~= GameTooltip and tooltip ~= GameTooltipTooltip then return end
            local _, unit = tooltip:GetUnit()
            AddTagLine(tooltip, unit)
        end)
    else
        -- Classic / Cataclysm : script OnTooltipSetUnit
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            local _, unit = tooltip:GetUnit()
            AddTagLine(tooltip, unit)
        end)
    end
end
