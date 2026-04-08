local ADDON_NAME = "Shifty"

Shifty = {}
Shifty.frame = CreateFrame("Frame", "ShiftyFrame")
Shifty.currentSuggestion = nil
Shifty.playerClass = nil
Shifty.currentForm = "None"

local DEFAULTS = {
    minimap = {
        angle = 220,
        hide = false,
    },

    general = {
        enabled = true,
        showSuggestionFrame = true,
        lockSuggestionFrame = false,
    },

    autobuff = {
        enabled = true,
        markOfTheWild = true,
        thorns = true,
        omenOfClarity = false,
    },

    forms = {
        None = {
            enabled = true,
            useRotation = true,
        },
        Bear = {
            enabled = true,
            useRotation = true,
        },
        Aquatic = {
            enabled = true,
            useRotation = true,
        },
        Cat = {
            enabled = true,
            useRotation = true,
        },
        Travel = {
            enabled = true,
            useRotation = true,
        },
        Tree = {
            enabled = true,
            useRotation = true,
        },
    },
}

local FORM_TEXTURES = {
    Bear = {
        "Ability_Racial_BearForm",
        "Ability_Druid_DireBearForm",
    },
    Aquatic = {
        "Ability_Druid_AquaticForm",
    },
    Cat = {
        "Ability_Druid_CatForm",
    },
    Travel = {
        "Ability_Druid_TravelForm",
    },
    Tree = {
        "Ability_Druid_TreeofLife",
    },
}

local PLAYER_BUFFS = {
    MarkOfTheWild = {
        texture = "Spell_Nature_Regeneration",
        spell = "Mark of the Wild",
    },
    Thorns = {
        texture = "Spell_Nature_Thorns",
        spell = "Thorns",
    },
    OmenOfClarity = {
        texture = "Spell_Nature_CrystalBall",
        spell = "Omen of Clarity",
    },
}

local function Shifty_DeepCopyDefaults(src, dst)
    if type(src) ~= "table" then return src end
    if type(dst) ~= "table" then dst = {} end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = Shifty_DeepCopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

local function Shifty_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fdfffShifty:|r " .. msg)
end

local function Shifty_IsPlayerDruid()
    local _, class = UnitClass("player")
    return class == "DRUID"
end

local function Shifty_HasBuffTexture(unit, textureFragment)
    local i = 1
    while true do
        local texture = UnitBuff(unit, i)
        if not texture then
            break
        end

        if string.find(string.lower(texture), string.lower(textureFragment), 1, true) then
            return true
        end
        i = i + 1
    end
    return false
end

local function Shifty_GetCurrentForm()
    local i = 1
    while true do
        local texture = UnitBuff("player", i)
        if not texture then
            break
        end

        for formName, textureList in pairs(FORM_TEXTURES) do
            local j
            for j = 1, table.getn(textureList) do
                if string.find(string.lower(texture), string.lower(textureList[j]), 1, true) then
                    return formName
                end
            end
        end

        i = i + 1
    end

    return "None"
end

local function Shifty_IsSpellReady(spellName)
    local i = 1
    while true do
        local spell = GetSpellName(i, BOOKTYPE_SPELL)
        if not spell then break end

        if spell == spellName then
            local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
            if enabled == 1 and (start == 0 or duration == 0) then
                return true
            end
            return false
        end

        i = i + 1
    end
    return false
end

local function Shifty_KnowsSpell(spellName)
    local i = 1
    while true do
        local spell = GetSpellName(i, BOOKTYPE_SPELL)
        if not spell then break end
        if spell == spellName then
            return true
        end
        i = i + 1
    end
    return false
end

local function Shifty_GetBuffSuggestion()
    if not ShiftyDB.autobuff.enabled then
        return nil
    end

    if ShiftyDB.autobuff.markOfTheWild then
        if Shifty_KnowsSpell(PLAYER_BUFFS.MarkOfTheWild.spell)
           and not Shifty_HasBuffTexture("player", PLAYER_BUFFS.MarkOfTheWild.texture) then
            return PLAYER_BUFFS.MarkOfTheWild.spell
        end
    end

    if ShiftyDB.autobuff.thorns then
        if Shifty_KnowsSpell(PLAYER_BUFFS.Thorns.spell)
           and not Shifty_HasBuffTexture("player", PLAYER_BUFFS.Thorns.texture) then
            return PLAYER_BUFFS.Thorns.spell
        end
    end

    if ShiftyDB.autobuff.omenOfClarity then
        if Shifty_KnowsSpell(PLAYER_BUFFS.OmenOfClarity.spell)
           and not Shifty_HasBuffTexture("player", PLAYER_BUFFS.OmenOfClarity.texture) then
            return PLAYER_BUFFS.OmenOfClarity.spell
        end
    end

    return nil
end

local function Shifty_UnitHasDebuffTexture(unit, textureFragment)
    local i = 1
    while true do
        local texture = UnitDebuff(unit, i)
        if not texture then
            break
        end

        if string.find(string.lower(texture), string.lower(textureFragment), 1, true) then
            return true
        end

        i = i + 1
    end
    return false
end

local function Shifty_GetComboPoints()
    if GetComboPoints then
        return GetComboPoints()
    end
    return 0
end

local function Shifty_SuggestCat()
    if not UnitExists("target") or UnitIsDead("target") or UnitCanAttack("player", "target") ~= 1 then
        return "Choose target"
    end

    if not Shifty_UnitHasDebuffTexture("target", "Ability_Druid_Disembowel") then
        if Shifty_KnowsSpell("Rake") then
            return "Rake"
        end
    end

    if Shifty_GetComboPoints() >= 5 then
        if Shifty_KnowsSpell("Rip") then
            return "Rip"
        end
        if Shifty_KnowsSpell("Ferocious Bite") then
            return "Ferocious Bite"
        end
    end

    if Shifty_KnowsSpell("Claw") then
        return "Claw"
    end

    return "Attack"
end

local function Shifty_SuggestBear()
    if not UnitExists("target") or UnitIsDead("target") or UnitCanAttack("player", "target") ~= 1 then
        return "Choose target"
    end

    if not Shifty_UnitHasDebuffTexture("target", "Ability_Physical_Taunt") then
        if Shifty_KnowsSpell("Demoralizing Roar") then
            return "Demoralizing Roar"
        end
    end

    if Shifty_KnowsSpell("Maul") then
        return "Maul"
    end

    return "Attack"
end

local function Shifty_SuggestNone()
    local buffSuggestion = Shifty_GetBuffSuggestion()
    if buffSuggestion then
        return buffSuggestion
    end

    if UnitExists("target") and UnitCanAttack("player", "target") == 1 then
        if Shifty_KnowsSpell("Moonfire") and not Shifty_UnitHasDebuffTexture("target", "Spell_Nature_StarFall") then
            return "Moonfire"
        end
        if Shifty_KnowsSpell("Wrath") then
            return "Wrath"
        end
    end

    return "Ready"
end

local function Shifty_SuggestTravel()
    local buffSuggestion = Shifty_GetBuffSuggestion()
    if buffSuggestion then
        return buffSuggestion
    end
    return "Travel active"
end

local function Shifty_SuggestAquatic()
    local buffSuggestion = Shifty_GetBuffSuggestion()
    if buffSuggestion then
        return buffSuggestion
    end
    return "Aquatic active"
end

local function Shifty_SuggestTree()
    local buffSuggestion = Shifty_GetBuffSuggestion()
    if buffSuggestion then
        return buffSuggestion
    end

    if UnitExists("target") and UnitIsFriend("player", "target") == 1 and not UnitIsDead("target") then
        if Shifty_KnowsSpell("Rejuvenation") then
            return "Rejuvenation"
        end
        if Shifty_KnowsSpell("Regrowth") then
            return "Regrowth"
        end
        if Shifty_KnowsSpell("Healing Touch") then
            return "Healing Touch"
        end
    end

    return "Tree active"
end

local function Shifty_GetRotationSuggestion()
    if not ShiftyDB.general.enabled then
        return nil
    end

    local buffSuggestion = Shifty_GetBuffSuggestion()
    if buffSuggestion then
        return buffSuggestion
    end

    local form = Shifty_GetCurrentForm()
    Shifty.currentForm = form

    if not ShiftyDB.forms[form] or not ShiftyDB.forms[form].enabled or not ShiftyDB.forms[form].useRotation then
        return nil
    end

    if form == "Cat" then
        return Shifty_SuggestCat()
    elseif form == "Bear" then
        return Shifty_SuggestBear()
    elseif form == "Aquatic" then
        return Shifty_SuggestAquatic()
    elseif form == "Travel" then
        return Shifty_SuggestTravel()
    elseif form == "Tree" then
        return Shifty_SuggestTree()
    else
        return Shifty_SuggestNone()
    end
end

local function Shifty_CreateSuggestionFrame()
    local f = CreateFrame("Frame", "ShiftySuggestionFrame", UIParent)
    f:SetWidth(170)
    f:SetHeight(54)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if not ShiftyDB.general.lockSuggestionFrame then
            this:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -8)
    f.title:SetText("Shifty")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.text:SetPoint("CENTER", f, "CENTER", 0, -4)
    f.text:SetText("Ready")

    Shifty.suggestionFrame = f
end

local function Shifty_UpdateSuggestionFrame()
    if not Shifty.suggestionFrame then return end

    if not ShiftyDB.general.showSuggestionFrame then
        Shifty.suggestionFrame:Hide()
        return
    end

    Shifty.suggestionFrame:Show()

    local suggestion = Shifty_GetRotationSuggestion()
    if not suggestion then
        suggestion = "Disabled"
    end

    Shifty.currentSuggestion = suggestion
    Shifty.suggestionFrame.text:SetText(suggestion)
end

local function Shifty_CreateMainPanel()
    local panel = CreateFrame("Frame", "ShiftyOptionsPanel", UIParent)
    panel:SetWidth(520)
    panel:SetHeight(420)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOP", panel, "TOP", 0, -16)
    panel.title:SetText("Shifty")

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOP", panel.title, "BOTTOM", 0, -4)
    panel.subtitle:SetText("Druid rotation and buff helper")

    panel.credits = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.credits:SetPoint("BOTTOM", panel, "BOTTOM", 0, 16)
    panel.credits:SetText("Credits to Skazz of Tel'Abin")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

    Shifty.optionsPanel = panel
end

local function Shifty_CreateCheckbox(parent, label, x, y, checkedFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    getglobal(cb:GetName() .. "Text"):SetText(label)

    cb:SetScript("OnShow", function()
        this:SetChecked(checkedFunc())
    end)

    cb:SetScript("OnClick", function()
        setFunc(this:GetChecked() == 1)
        Shifty_UpdateSuggestionFrame()
    end)

    return cb
end

local function Shifty_SelectTab(tabName)
    local i
    for i = 1, table.getn(Shifty.tabs) do
        local tab = Shifty.tabs[i]
        if tab.name == tabName then
            tab.button:LockHighlight()
            tab.content:Show()
        else
            tab.button:UnlockHighlight()
            tab.content:Hide()
        end
    end
end

local function Shifty_CreateTab(parent, name, index)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(70)
    button:SetHeight(22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 18 + ((index - 1) * 78), -54)
    button:SetText(name)

    local content = CreateFrame("Frame", nil, parent)
    content:SetWidth(480)
    content:SetHeight(250)
    content:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -90)
    content:Hide()

    local tab = {
        name = name,
        button = button,
        content = content,
    }

    button:SetScript("OnClick", function()
        Shifty_SelectTab(name)
    end)

    return tab
end

local function Shifty_CreateTabs()
    Shifty.tabs = {}

    local names = { "Bear", "Aquatic", "Cat", "Travel", "Tree", "None" }
    local i

    for i = 1, table.getn(names) do
        local tab = Shifty_CreateTab(Shifty.optionsPanel, names[i], i)
        table.insert(Shifty.tabs, tab)

        tab.header = tab.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.header:SetPoint("TOPLEFT", tab.content, "TOPLEFT", 6, -6)
        tab.header:SetText(names[i] .. " Settings")

        Shifty_CreateCheckbox(
            tab.content,
            "Enable " .. names[i] .. " helper",
            8,
            -28,
            function() return ShiftyDB.forms[names[i]].enabled end,
            function(v) ShiftyDB.forms[names[i]].enabled = v end
        )

        Shifty_CreateCheckbox(
            tab.content,
            "Enable rotation suggestions",
            8,
            -54,
            function() return ShiftyDB.forms[names[i]].useRotation end,
            function(v) ShiftyDB.forms[names[i]].useRotation = v end
        )

        local note = tab.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", tab.content, "TOPLEFT", 10, -88)
        note:SetWidth(440)
        note:SetJustifyH("LEFT")

        if names[i] == "Cat" then
            note:SetText("Starter priority: Rake > build combo points > Rip/Ferocious Bite.")
        elseif names[i] == "Bear" then
            note:SetText("Starter priority: Demoralizing Roar if missing, then Maul.")
        elseif names[i] == "Tree" then
            note:SetText("Starter priority: Rejuvenation / Regrowth / Healing Touch. Tree form support is included as a configurable section.")
        elseif names[i] == "None" then
            note:SetText("Caster priority: missing buffs first, then Moonfire / Wrath.")
        else
            note:SetText("This form currently uses lightweight helper logic and can be expanded later.")
        end
    end

    Shifty_SelectTab("Cat")
end

local function Shifty_CreateAutobuffSection()
    local panel = Shifty.optionsPanel

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -350)
    header:SetText("Autobuff")

    Shifty_CreateCheckbox(
        panel,
        "Enable autobuff suggestions",
        20,
        -368,
        function() return ShiftyDB.autobuff.enabled end,
        function(v) ShiftyDB.autobuff.enabled = v end
    )

    Shifty_CreateCheckbox(
        panel,
        "Mark of the Wild",
        200,
        -368,
        function() return ShiftyDB.autobuff.markOfTheWild end,
        function(v) ShiftyDB.autobuff.markOfTheWild = v end
    )

    Shifty_CreateCheckbox(
        panel,
        "Thorns",
        340,
        -368,
        function() return ShiftyDB.autobuff.thorns end,
        function(v) ShiftyDB.autobuff.thorns = v end
    )

    Shifty_CreateCheckbox(
        panel,
        "Omen of Clarity",
        20,
        -394,
        function() return ShiftyDB.autobuff.omenOfClarity end,
        function(v) ShiftyDB.autobuff.omenOfClarity = v end
    )

    Shifty_CreateCheckbox(
        panel,
        "Show suggestion frame",
        200,
        -394,
        function() return ShiftyDB.general.showSuggestionFrame end,
        function(v) ShiftyDB.general.showSuggestionFrame = v end
    )

    Shifty_CreateCheckbox(
        panel,
        "Lock suggestion frame",
        340,
        -394,
        function() return ShiftyDB.general.lockSuggestionFrame end,
        function(v) ShiftyDB.general.lockSuggestionFrame = v end
    )
end

local function Shifty_UpdateMinimapButtonPosition()
    if not Shifty.minimapButton then return end

    local angle = ShiftyDB.minimap.angle or 220
    local radius = 78
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    Shifty.minimapButton:ClearAllPoints()
    Shifty.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)

    if ShiftyDB.minimap.hide then
        Shifty.minimapButton:Hide()
    else
        Shifty.minimapButton:Show()
    end
end

local function Shifty_CreateMinimapButton()
    local button = CreateFrame("Button", "ShiftyMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetNormalTexture("Interface\\Icons\\Ability_Druid_CatForm")
    button:SetPushedTexture("Interface\\Icons\\Ability_Druid_Bash")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    button:EnableMouse(true)

    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" or arg1 == "RightButton" then
            if Shifty.optionsPanel:IsShown() then
                Shifty.optionsPanel:Hide()
            else
                Shifty.optionsPanel:Show()
            end
        end
    end)

    button:SetScript("OnDragStart", function()
        this.dragging = true
    end)

    button:SetScript("OnDragStop", function()
        this.dragging = false
    end)

    button:SetScript("OnUpdate", function()
        if this.dragging then
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            mx = mx / scale
            my = my / scale

            local cx, cy = Minimap:GetCenter()
            local dx = mx - cx
            local dy = my - cy
            local angle = math.atan2(dy, dx)

            ShiftyDB.minimap.angle = angle
            Shifty_UpdateMinimapButtonPosition()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Shifty")
        GameTooltip:AddLine("Left/Right Click: Open Settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move around minimap", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    Shifty.minimapButton = button
    Shifty_UpdateMinimapButtonPosition()
end

local function Shifty_CreateUI()
    Shifty_CreateSuggestionFrame()
    Shifty_CreateMainPanel()
    Shifty_CreateTabs()
    Shifty_CreateAutobuffSection()
    Shifty_CreateMinimapButton()
end

local function Shifty_Toggle()
    ShiftyDB.general.enabled = not ShiftyDB.general.enabled
    if ShiftyDB.general.enabled then
        Shifty_Print("Enabled")
    else
        Shifty_Print("Disabled")
    end
    Shifty_UpdateSuggestionFrame()
end

SLASH_SHIFTY1 = "/shifty"
SlashCmdList["SHIFTY"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "toggle" then
        Shifty_Toggle()
    elseif msg == "show" then
        Shifty.optionsPanel:Show()
    elseif msg == "hide" then
        Shifty.optionsPanel:Hide()
    elseif msg == "minimap" then
        ShiftyDB.minimap.hide = not ShiftyDB.minimap.hide
        Shifty_UpdateMinimapButtonPosition()
    else
        Shifty_Print("/shifty toggle - enable/disable helper")
        Shifty_Print("/shifty show - open settings")
        Shifty_Print("/shifty hide - close settings")
        Shifty_Print("/shifty minimap - show/hide minimap button")
    end
end

Shifty.frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not Shifty_IsPlayerDruid() then
            return
        end

        ShiftyDB = Shifty_DeepCopyDefaults(DEFAULTS, ShiftyDB or {})
        Shifty_CreateUI()
        Shifty_UpdateSuggestionFrame()
        Shifty_Print("Loaded. Credits to Skazz of Tel'Abin.")
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_AURAS_CHANGED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "ACTIONBAR_UPDATE_USABLE"
        or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "SPELLS_CHANGED" then

        if not Shifty_IsPlayerDruid() then
            return
        end

        Shifty_UpdateSuggestionFrame()
    end
end)

Shifty.frame:RegisterEvent("VARIABLES_LOADED")
Shifty.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Shifty.frame:RegisterEvent("PLAYER_AURAS_CHANGED")
Shifty.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
Shifty.frame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
Shifty.frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
Shifty.frame:RegisterEvent("SPELLS_CHANGED")