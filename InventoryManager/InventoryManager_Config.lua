local addonName, IM = ...

function IM:SaveConfig()
    IM_ConfigDB = self.db
end

-- Helper function to safely set CheckButton label text
local function SetCheckboxText(cb, text)
    local name = cb:GetName()
    if name and _G[name .. "Text"] then
        _G[name .. "Text"]:SetText(text)
    elseif cb.Text then
        cb.Text:SetText(text)
    end
end

function IM:SetFreeSlotsThreshold(value)
    value = tonumber(value) or 1
    if value ~= value or value == math.huge or value == -math.huge then
        value = 1
    end
    value = math.max(0, math.min(10, math.floor(value)))
    self.db.freeSlotsThreshold = value
    self:SaveConfig()

    local sliderNames = {
        "IM_LowSpaceThresholdSlider",
        "IM_Cfg_FreeSlotsSlider",
    }
    for _, name in ipairs(sliderNames) do
        local slider = _G[name]
        if slider and slider:GetValue() ~= value then
            slider:SetValue(value)
        end
    end
end

function IM:SetAutoOpenOnLowSpace(enabled)
    self.db.autoOpenOnLowSpace = enabled and true or false
    self:SaveConfig()

    local checkboxNames = {
        "IM_SimpleAutoOpenCB",
        "IM_Cfg_AutoOpenCB",
    }
    for _, name in ipairs(checkboxNames) do
        local checkbox = _G[name]
        if checkbox then
            checkbox:SetChecked(self.db.autoOpenOnLowSpace)
        end
    end

    local sliderNames = {
        "IM_LowSpaceThresholdSlider",
        "IM_Cfg_FreeSlotsSlider",
    }
    for _, name in ipairs(sliderNames) do
        local slider = _G[name]
        if slider then
            local label = _G[name .. "Text"]
            if self.db.autoOpenOnLowSpace then
                slider:Enable()
                if label then label:SetTextColor(1, 0.82, 0) end
            else
                slider:Disable()
                if label then label:SetTextColor(0.5, 0.5, 0.5) end
            end
        end
    end
end

function IM:CreateConfigPanel()
    if IM_ConfigFrame then return IM_ConfigFrame end

    local frame = CreateFrame("Frame", "IM_ConfigFrame", UIParent)
    IM:StyleFrame(frame, 560, 620, IM:L("Inventory Manager — Configuration"))

    -- Scroll frame
    frame.scroll = CreateFrame("ScrollFrame", "IM_ConfigScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -35)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 40)

    frame.scrollChild = CreateFrame("Frame", "IM_ConfigScrollChild")
    frame.scrollChild:SetWidth(500)
    frame.scrollChild:SetHeight(720)
    frame.scroll:SetScrollChild(frame.scrollChild)

    -- Scrollbar positioning
    local scrollBar = _G["IM_ConfigScrollFrameScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 6, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 6, 16)
    end

    ---------------------------------------------------------
    -- Section 1: General Options
    ---------------------------------------------------------
    local enableCheckbox = CreateFrame("CheckButton", "IM_Cfg_EnableCB", frame.scrollChild, "OptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 15, -10)
    SetCheckboxText(enableCheckbox, "Enable Inventory Manager")
    enableCheckbox:SetChecked(self.db.enabled)
    enableCheckbox:SetScript("OnClick", function(s)
        IM.db.enabled = s:GetChecked() and true or false
        IM:SaveConfig()
        IM:RefreshUI()
    end)

    IM:CreateDivider(frame.scrollChild, -45)

    ---------------------------------------------------------
    -- Section 2: Filters Grid (Quality & Item Types)
    ---------------------------------------------------------
    local qualHeader = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualHeader:SetPoint("TOPLEFT", 15, -55)
    qualHeader:SetText(IM:L("Ignore Gear Quality:"))

    local qualityOrder = {"POOR", "COMMON", "UNCOMMON"}
    local qualityCheckboxes = {}

    for i, qualityKey in ipairs(qualityOrder) do
        local cb = CreateFrame("CheckButton", "IM_Cfg_Quality_" .. qualityKey, frame.scrollChild, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, -75 - ((i - 1) * 26))
        
        local qColor = (IM.qualityColors and IM.qualityColors[i-1]) or "|cFFFFFFFF"
        local qName = (IM.qualityNames and IM.qualityNames[i-1]) or qualityKey
        SetCheckboxText(cb, qColor .. IM:L(qName))

        cb:SetChecked(self.db.ignoreQuality and self.db.ignoreQuality[qualityKey])
        cb:SetScript("OnClick", function(s)
            IM.db.ignoreQuality[qualityKey] = s:GetChecked() and true or false
            IM:SaveConfig()
            IM:RefreshUI()
        end)
        qualityCheckboxes[qualityKey] = cb
    end

    local typeHeader = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeHeader:SetPoint("TOPLEFT", 220, -55)
    typeHeader:SetText(IM:L("Ignore Item Types:"))

    local itemTypes = {"Weapon", "Armor", "Consumable", "Miscellaneous", "Quest", "Recipe"}
    local typeCheckboxes = {}

    for i, typeName in ipairs(itemTypes) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cb = CreateFrame("CheckButton", "IM_Cfg_Type_" .. typeName, frame.scrollChild, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 220 + (col * 130), -75 - (row * 26))
        SetCheckboxText(cb, IM:L(typeName))
        cb:SetChecked(self.db.ignoreItemTypes and self.db.ignoreItemTypes[typeName])
        cb:SetScript("OnClick", function(s)
            IM.db.ignoreItemTypes[typeName] = s:GetChecked() and true or false
            IM:SaveConfig()
            IM:RefreshUI()
        end)
        typeCheckboxes[typeName] = cb
    end

    IM:CreateDivider(frame.scrollChild, -170)

    ---------------------------------------------------------
    -- Section 3: Trade Goods
    ---------------------------------------------------------
    local tgHeader = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tgHeader:SetPoint("TOPLEFT", 15, -180)
    tgHeader:SetText(IM:L("Ignore Trade Goods Categories:"))

    local tradeGoodsCategories = {
        "Cloth", "Leather", "Metal", "Stone", "Meat", "Herb", 
        "Elemental", "Enchanting", "Jewelcrafting", "Gem", "Parts", "Inscription", "Other"
    }
    local tradeGoodsCheckboxes = {}

    for i, category in ipairs(tradeGoodsCategories) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local cb = CreateFrame("CheckButton", "IM_Cfg_TG_" .. category, frame.scrollChild, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20 + (col * 155), -200 - (row * 26))
        SetCheckboxText(cb, IM:L(category))
        cb:SetChecked(self.db.ignoreTradeGoodsTypes and self.db.ignoreTradeGoodsTypes[category] or false)
        cb:SetScript("OnClick", function(s)
            IM.db.ignoreTradeGoodsTypes[category] = s:GetChecked() and true or false
            IM:SaveConfig()
            IM:RefreshUI()
        end)
        tradeGoodsCheckboxes[category] = cb
    end

    IM:CreateDivider(frame.scrollChild, -340)

    ---------------------------------------------------------
    -- Section 4: Value Thresholds & Automation
    ---------------------------------------------------------
    local valLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valLabel:SetPoint("TOPLEFT", 15, -355)
    valLabel:SetText(IM:L("Suggest items worth less than:"))

    local goldInput = CreateFrame("EditBox", "IM_Cfg_MinGoldEditBox", frame.scrollChild, "InputBoxTemplate")
    goldInput:SetSize(60, 20)
    goldInput:SetPoint("LEFT", valLabel, "RIGHT", 15, 0)
    goldInput:SetAutoFocus(false)
    goldInput:SetNumeric(false)
    goldInput:SetText(string.format("%.2f", self.db.minItemValue or 0.25))

    local goldSymbol = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldSymbol:SetPoint("LEFT", goldInput, "RIGHT", 5, 0)
    goldSymbol:SetText(IM:L("Gold"))

    local goldError = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldError:SetPoint("TOPLEFT", 15, -378)
    goldError:SetTextColor(1, 0.35, 0.35)

    goldInput:SetScript("OnEnterPressed", function(s)
        local val = tonumber(s:GetText())
        if not val or val ~= val or val < 0 or val == math.huge then
            goldError:SetText(IM:L("Enter a valid, non-negative value in gold."))
            return
        end

        IM.db.minItemValue = val
        goldError:SetText("")
        s:SetText(string.format("%.2f", val))
        IM:SaveConfig()
        IM:RefreshUI()
        s:ClearFocus()
    end)

    -- Automation Checkboxes
    local autoSellCB = CreateFrame("CheckButton", "IM_Cfg_AutoSellCB", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoSellCB:SetPoint("TOPLEFT", 15, -400)
    SetCheckboxText(autoSellCB, "Auto-sell vendor trash at merchant")
    autoSellCB:SetChecked(self.db.autoSellAtVendor)
    autoSellCB:SetScript("OnClick", function(s)
        IM.db.autoSellAtVendor = s:GetChecked() and true or false
        IM:SaveConfig()
    end)

    local showSellCB = CreateFrame("CheckButton", "IM_Cfg_ShowSellCB", frame.scrollChild, "OptionsCheckButtonTemplate")
    showSellCB:SetPoint("TOPLEFT", 15, -426)
    SetCheckboxText(showSellCB, "Show Sell List panel at vendor")
    showSellCB:SetChecked(self.db.showSellListAtVendor)
    showSellCB:SetScript("OnClick", function(s)
        IM.db.showSellListAtVendor = s:GetChecked() and true or false
        IM:SaveConfig()
    end)

    local autoOpenCB = CreateFrame("CheckButton", "IM_Cfg_AutoOpenCB", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoOpenCB:SetPoint("TOPLEFT", 15, -452)
    SetCheckboxText(autoOpenCB, "Auto-open suggestion window when free bag slots are low")
    autoOpenCB:SetChecked(self.db.autoOpenOnLowSpace)
    autoOpenCB:SetScript("OnClick", function(s)
        IM:SetAutoOpenOnLowSpace(s:GetChecked())
    end)

    local autoDeleteCB = CreateFrame("CheckButton", "IM_Cfg_AutoDeleteCB", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoDeleteCB:SetPoint("TOPLEFT", 15, -478)
    SetCheckboxText(autoDeleteCB, "Automatically delete items on the Auto-Delete list")
    autoDeleteCB:SetChecked(self.db.autoDeleteEnabled)
    autoDeleteCB:SetScript("OnClick", function(s)
        IM.db.autoDeleteEnabled = s:GetChecked() and true or false
        IM:SaveConfig()
    end)

    local autoDeleteWarning = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoDeleteWarning:SetPoint("TOPLEFT", 42, -503)
    autoDeleteWarning:SetWidth(440)
    autoDeleteWarning:SetJustifyH("LEFT")
    autoDeleteWarning:SetText(IM:L("Warning: matching items are permanently deleted from your bags without another prompt."))
    autoDeleteWarning:SetTextColor(1, 0.55, 0.35)

    IM:SetFreeSlotsThreshold(self.db.freeSlotsThreshold or 1)
    local freeSlotsSlider = CreateFrame("Slider", "IM_Cfg_FreeSlotsSlider", frame.scrollChild, "OptionsSliderTemplate")
    freeSlotsSlider:SetPoint("TOPLEFT", 25, -550)
    freeSlotsSlider:SetSize(190, 16)
    freeSlotsSlider:SetMinMaxValues(0, 10)
    freeSlotsSlider:SetValueStep(1)
    freeSlotsSlider:SetValue(self.db.freeSlotsThreshold or 1)
    _G[freeSlotsSlider:GetName() .. "Text"]:SetText(IM:L("Open at or below: %d free slots", self.db.freeSlotsThreshold or 1))
    _G[freeSlotsSlider:GetName() .. "Low"]:SetText("0")
    _G[freeSlotsSlider:GetName() .. "High"]:SetText("10")
    freeSlotsSlider:SetScript("OnValueChanged", function(slider, value)
        local threshold = math.floor(value)
        _G[slider:GetName() .. "Text"]:SetText(IM:L("Open at or below: %d free slots", threshold))
        IM:SetFreeSlotsThreshold(threshold)
    end)
    if not self.db.autoOpenOnLowSpace then
        freeSlotsSlider:Disable()
        _G[freeSlotsSlider:GetName() .. "Text"]:SetTextColor(0.5, 0.5, 0.5)
    end

    ---------------------------------------------------------
    -- Bottom Action Buttons
    ---------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 12, 10)
    resetBtn:SetText(IM:L("Defaults"))
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("IM_CONFIRM_RESET")
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    closeBtn:SetText(IM:L("Close"))
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    StaticPopupDialogs["IM_CONFIRM_RESET"] = {
        text = IM:L("Reset Inventory Manager configuration to defaults? The interface will reload to apply the reset."),
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            IM.db = IM:CopyTable(IM.defaultConfig)
            IM:SaveConfig()
            ReloadUI()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    frame:Hide()
    IM_ConfigFrame = frame
    return frame
end

function IM:ShowConfigFrame()
    if not IM_ConfigFrame then
        self:CreateConfigPanel()
    end
	
	if IM_MainFrame and IM_MainFrame:IsShown() then
		IM_MainFrame:Hide()
	end
    
    if self.RestoreFramePosition then
        self:RestoreFramePosition(IM_ConfigFrame, "CENTER", 0, 0)
    else
        IM_ConfigFrame:ClearAllPoints()
        IM_ConfigFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    IM_ConfigFrame:Show()
end