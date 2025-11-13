if not InventoryManager then return end
local IM = InventoryManager

function IM:SaveConfig()
    -- Force save the configuration
    IM_ConfigDB = self.db
end

function IM:CreateConfigPanel()
    local frame = CreateFrame("Frame", "IM_ConfigFrame", UIParent)
    frame:SetSize(600, 700)
    frame:SetPoint("CENTER", 0, 0)
    
    -- Make it movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IM:SaveFramePosition(self)
    end)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.9)
    
    -- Border
    frame.border = CreateFrame("Frame", nil, frame)
    frame.border:SetPoint("TOPLEFT", -3, 3)
    frame.border:SetPoint("BOTTOMRIGHT", 3, -3)
    frame.border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame.border:SetBackdropColor(0, 0, 0, 0.8)
    frame.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -15)
    frame.title:SetText("Inventory Manager Settings")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame
    frame.scroll = CreateFrame("ScrollFrame", "IM_ConfigScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -40)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    
    frame.scrollChild = CreateFrame("Frame", "IM_ConfigScrollChild")
    frame.scrollChild:SetWidth(580)
    frame.scrollChild:SetHeight(650)
    frame.scroll:SetScrollChild(frame.scrollChild)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_ConfigScrollFrameScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Enable checkbox
    local enableCheckbox = CreateFrame("CheckButton", "IM_EnableCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -20)
    _G[enableCheckbox:GetName().."Text"]:SetText("Enable Inventory Manager")
    enableCheckbox:SetChecked(self.db.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        IM.db.enabled = self:GetChecked()
        IM:SaveConfig()
        IM:RefreshUI()
    end)
    
    -- Quality settings
    local qualityTitle = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityTitle:SetPoint("TOPLEFT", 20, -60)
    qualityTitle:SetText("Ignore Gear Quality:")
    
    local qualityCheckboxes = {}
    local qualityColors = {
        [6] = "|cFFE6CC80",
        [5] = "|cFFFF8000",
        [4] = "|cFFA335EE",
        [3] = "|cFF0070DD",
        [2] = "|cFF1EFF00",
        [1] = "|cFFFFFFFF",
        [0] = "|cFF9D9D9D",
    }
    
    local qualityOrder = {"POOR", "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "ARTIFACT"}
    local qualityDisplayNames = {
        POOR = "Poor (Grey)",
        COMMON = "Common (White)", 
        UNCOMMON = "Uncommon (Green)",
        RARE = "Rare (Blue)",
        EPIC = "Epic (Purple)",
        LEGENDARY = "Legendary (Orange)",
        ARTIFACT = "Artifact (Gold)"
    }
    
    for i, qualityKey in ipairs(qualityOrder) do
        local qualityNum = i - 1  -- Convert to 0-based quality number
        qualityCheckboxes[qualityKey] = CreateFrame("CheckButton", "IM_Quality_"..qualityKey, frame.scrollChild, "OptionsCheckButtonTemplate")
        qualityCheckboxes[qualityKey]:SetPoint("TOPLEFT", 30, -90 - ((i-1) * 30))
        _G[qualityCheckboxes[qualityKey]:GetName().."Text"]:SetText(qualityColors[qualityNum] .. qualityDisplayNames[qualityKey])
        qualityCheckboxes[qualityKey]:SetChecked(self.db.ignoreQuality[qualityKey])
        qualityCheckboxes[qualityKey]:SetScript("OnClick", function(self)
            IM.db.ignoreQuality[qualityKey] = self:GetChecked() and true or false
            IM:SaveConfig()
            IM:RefreshUI()
        end)
    end
    
    -- Item type settings
    local typeTitle = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeTitle:SetPoint("TOPLEFT", 200, -60)
    typeTitle:SetText("Ignore Items by Type:")
    
    local itemTypes = {"Weapon", "Armor", "Consumable", "Miscellaneous", "Quest", "Recipe", }
    local typeCheckboxes = {}
    
    for i, typeName in ipairs(itemTypes) do
        typeCheckboxes[typeName] = CreateFrame("CheckButton", "IM_Type_"..typeName, frame.scrollChild, "OptionsCheckButtonTemplate")
        typeCheckboxes[typeName]:SetPoint("TOPLEFT", 210, -90 - ((i-1) * 30))
        _G[typeCheckboxes[typeName]:GetName().."Text"]:SetText(typeName)
        local isChecked = self.db.ignoreItemTypes[typeName] and true or false
        typeCheckboxes[typeName]:SetChecked(isChecked)
        
        typeCheckboxes[typeName]:SetScript("OnClick", function(self)
            IM.db.ignoreItemTypes[typeName] = self:GetChecked() and true or false
            IM:SaveConfig()
            IM:RefreshUI()
        end)
    end
    
        -- Trade Goods Categories
    local tradeGoodsTitle = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tradeGoodsTitle:SetPoint("TOPLEFT", 350, -60)
    tradeGoodsTitle:SetText("Ignore Trade Goods:")
    
    local tradeGoodsCategories = {"Cloth", "Leather", "Metal", "Stone", "Meat", "Herb", "Elemental", "Enchanting", "Jewelcrafting", "Gem", "Parts", "Other"}
    local tradeGoodsCheckboxes = {}
    
    for i, category in ipairs(tradeGoodsCategories) do
        -- Create a container frame for proper alignment
        local container = CreateFrame("Frame", nil, frame.scrollChild)
        container:SetSize(120, 25)
        
        -- Position the container
        if i <= 7 then
            container:SetPoint("TOPLEFT", 360, -90 - ((i-1) * 30))
        else
            container:SetPoint("TOPLEFT", 460, -90 - ((i-7) * 30))
        end
        
        -- Create checkbox using UICheckButtonTemplate
        tradeGoodsCheckboxes[category] = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        tradeGoodsCheckboxes[category]:SetSize(25, 25)
        tradeGoodsCheckboxes[category]:SetPoint("LEFT", 0, 0)
        
        -- Create text label
        local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", tradeGoodsCheckboxes[category], "RIGHT", 5, 0)
        text:SetText(category)
        
        -- Store reference
        tradeGoodsCheckboxes[category].text = text
        tradeGoodsCheckboxes[category].container = container
        
        -- Get the current value, ensuring it exists
        local currentValue = self.db.ignoreTradeGoodsTypes[category]
        if currentValue == nil then
            -- If the value doesn't exist, set it to the default and save
            currentValue = self.defaultConfig.ignoreTradeGoodsTypes[category] or false
            self.db.ignoreTradeGoodsTypes[category] = currentValue
            self:SaveConfig()
        end
        
        tradeGoodsCheckboxes[category]:SetChecked(currentValue)
        
        -- Set click handler
        tradeGoodsCheckboxes[category]:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            -- Convert nil to false for unchecked boxes
            if checked == nil then
                checked = false
            end
            IM.db.ignoreTradeGoodsTypes[category] = checked
            IM:SaveConfig()
            IM:RefreshUI()
        end)
    end
    
    -- Stack value setting - converted to sliders
    local stackLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackLabel:SetPoint("TOPLEFT", 20, -330)
    stackLabel:SetText("Ignore items worth more than (per item):")
    stackLabel:SetTextColor(1, 1, 1)
    
    -- Gold slider for min item value
    local stackGoldSlider = CreateFrame("Slider", "IM_StackValueGold", frame.scrollChild, "OptionsSliderTemplate")
    stackGoldSlider:SetPoint("TOPLEFT", 20, -355)
    stackGoldSlider:SetWidth(150)
    stackGoldSlider:SetHeight(17)
    stackGoldSlider:SetMinMaxValues(0, 50)
    stackGoldSlider:SetValueStep(1)
    stackGoldSlider:SetValue(math.floor(self.db.minItemValue))
    _G[stackGoldSlider:GetName().."Text"]:SetText(string.format("%dg", math.floor(self.db.minItemValue)))
    _G[stackGoldSlider:GetName().."Low"]:SetText("0g")
    _G[stackGoldSlider:GetName().."High"]:SetText("50g")
    
    local stackGoldLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackGoldLabel:SetPoint("TOPLEFT", 180, -355)
    stackGoldLabel:SetText("Gold")
    stackGoldLabel:SetTextColor(1, 1, 0)
    
    -- Silver slider for min item value
    local stackSilverSlider = CreateFrame("Slider", "IM_StackValueSilver", frame.scrollChild, "OptionsSliderTemplate")
    stackSilverSlider:SetPoint("TOPLEFT", 20, -385)
    stackSilverSlider:SetWidth(150)
    stackSilverSlider:SetHeight(17)
    stackSilverSlider:SetMinMaxValues(0, 99)
    stackSilverSlider:SetValueStep(1)
    stackSilverSlider:SetValue(math.floor((self.db.minItemValue * 100) % 100))
    _G[stackSilverSlider:GetName().."Text"]:SetText(string.format("%ds", math.floor((self.db.minItemValue * 100) % 100)))
    _G[stackSilverSlider:GetName().."Low"]:SetText("0s")
    _G[stackSilverSlider:GetName().."High"]:SetText("99s")
    
    local stackSilverLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackSilverLabel:SetPoint("TOPLEFT", 180, -385)
    stackSilverLabel:SetText("Silver")
    stackSilverLabel:SetTextColor(0.75, 0.75, 0.75)
    
    -- Copper slider for min item value
    local stackCopperSlider = CreateFrame("Slider", "IM_StackValueCopper", frame.scrollChild, "OptionsSliderTemplate")
    stackCopperSlider:SetPoint("TOPLEFT", 20, -415)
    stackCopperSlider:SetWidth(150)
    stackCopperSlider:SetHeight(17)
    stackCopperSlider:SetMinMaxValues(0, 99)
    stackCopperSlider:SetValueStep(1)
    stackCopperSlider:SetValue(math.floor((self.db.minItemValue * 10000) % 100))
    _G[stackCopperSlider:GetName().."Text"]:SetText(string.format("%dc", math.floor((self.db.minItemValue * 10000) % 100)))
    _G[stackCopperSlider:GetName().."Low"]:SetText("0c")
    _G[stackCopperSlider:GetName().."High"]:SetText("99c")
    
    local stackCopperLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackCopperLabel:SetPoint("TOPLEFT", 180, -415)
    stackCopperLabel:SetText("Copper")
    stackCopperLabel:SetTextColor(0.8, 0.5, 0.2)
    
    -- Update function for min item value sliders
    local function UpdateMinItemValue()
        local gold = stackGoldSlider:GetValue()
        local silver = stackSilverSlider:GetValue()
        local copper = stackCopperSlider:GetValue()
        IM.db.minItemValue = gold + (silver / 100) + (copper / 10000)
        IM:SaveConfig()
        IM:RefreshUI()
    end
    
    stackGoldSlider:SetScript("OnValueChanged", function(self, value)
        -- Round to nearest whole number to fix stepping issues
        value = math.floor(value + 0.5)
        _G[self:GetName().."Text"]:SetText(string.format("%dg", value))
        UpdateMinItemValue()
    end)
    
    stackSilverSlider:SetScript("OnValueChanged", function(self, value)
        -- Round to nearest whole number to fix stepping issues
        value = math.floor(value + 0.5)
        _G[self:GetName().."Text"]:SetText(string.format("%ds", value))
        UpdateMinItemValue()
    end)
    
    stackCopperSlider:SetScript("OnValueChanged", function(self, value)
        -- Round to nearest whole number to fix stepping issues
        value = math.floor(value + 0.5)
        _G[self:GetName().."Text"]:SetText(string.format("%dc", value))
        UpdateMinItemValue()
    end)
    
    -- Gear consideration
    local gearValueCheckbox = CreateFrame("CheckButton", "IM_GearValueCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    gearValueCheckbox:SetPoint("TOPLEFT", 280, -325)
    _G[gearValueCheckbox:GetName().."Text"]:SetText("Ignore Gear Value")
    gearValueCheckbox:SetChecked(self.db.ignoreGearValue)
    gearValueCheckbox:SetScript("OnClick", function(self)
        IM.db.ignoreGearValue = self:GetChecked()
        IM:SaveConfig()
        IM:RefreshUI()
    end)
    
    local autoDeleteCheckbox = CreateFrame("CheckButton", "IM_AutoDeleteCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoDeleteCheckbox:SetPoint("TOPLEFT", 280, -350)
    _G[autoDeleteCheckbox:GetName().."Text"]:SetText("Enable Auto-Delete")
    autoDeleteCheckbox:SetChecked(self.db.autoDeleteEnabled)
    autoDeleteCheckbox:SetScript("OnClick", function(self)
        IM.db.autoDeleteEnabled = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Auto-sell at vendor
    local autoSellCheckbox = CreateFrame("CheckButton", "IM_AutoSellCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoSellCheckbox:SetPoint("TOPLEFT", 20, -450)
    _G[autoSellCheckbox:GetName().."Text"]:SetText("Automatically sell vendor list items at vendors")
    autoSellCheckbox:SetChecked(self.db.autoSellAtVendor)
    autoSellCheckbox:SetScript("OnClick", function(self)
        IM.db.autoSellAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Show sell list at vendor
    local showSellListCheckbox = CreateFrame("CheckButton", "IM_ShowSellListCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    showSellListCheckbox:SetPoint("TOPLEFT", 20, -480)
    _G[showSellListCheckbox:GetName().."Text"]:SetText("Show sell list when vendor window opens")
    showSellListCheckbox:SetChecked(self.db.showSellListAtVendor)
    showSellListCheckbox:SetScript("OnClick", function(self)
        IM.db.showSellListAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Auto-open on low bag space
    local autoOpenCheckbox = CreateFrame("CheckButton", "IM_AutoOpenCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    autoOpenCheckbox:SetPoint("TOPLEFT", 20, -510)
    _G[autoOpenCheckbox:GetName().."Text"]:SetText("Auto-open when bag space is low")
    autoOpenCheckbox:SetChecked(self.db.autoOpenOnLowSpace)
    autoOpenCheckbox:SetScript("OnClick", function(self)
        IM.db.autoOpenOnLowSpace = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Low space threshold slider 
    local thresholdLabel = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thresholdLabel:SetPoint("TOPLEFT", 40, -540)
    thresholdLabel:SetText("Low space threshold:")
    thresholdLabel:SetTextColor(1, 1, 1)
    
    local thresholdSlider = CreateFrame("Slider", "IM_ThresholdSlider", frame.scrollChild, "OptionsSliderTemplate")
    thresholdSlider:SetPoint("TOPLEFT", 200, -540)
    thresholdSlider:SetWidth(150)
    thresholdSlider:SetHeight(17)
    thresholdSlider:SetMinMaxValues(50, 95)
    thresholdSlider:SetValueStep(5)
    thresholdSlider:SetValue(self.db.lowSpaceThreshold * 100)
    _G[thresholdSlider:GetName().."Text"]:SetText(string.format("%d%%", self.db.lowSpaceThreshold * 100))
    _G[thresholdSlider:GetName().."Low"]:SetText("50%")
    _G[thresholdSlider:GetName().."High"]:SetText("95%")
    
    thresholdSlider:SetScript("OnValueChanged", function(self, value)
        IM.db.lowSpaceThreshold = value / 100
        _G[self:GetName().."Text"]:SetText(string.format("%d%%", value))
        IM:SaveConfig()
    end)
    
    local deletionLogCheckbox = CreateFrame("CheckButton", "IM_DeletionLogCheckbox", frame.scrollChild, "OptionsCheckButtonTemplate")
    deletionLogCheckbox:SetPoint("TOPLEFT", 20, -570)
    _G[deletionLogCheckbox:GetName().."Text"]:SetText("Enable Deletion Logging")
    deletionLogCheckbox:SetChecked(self.db.deletionLogEnabled)
    deletionLogCheckbox:SetScript("OnClick", function(self)
        IM.db.deletionLogEnabled = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame.scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("TOPLEFT", 20, -610)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("IM_CONFIRM_RESET")
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Reset confirmation dialog
    StaticPopupDialogs["IM_CONFIRM_RESET"] = {
        text = "Are you sure you want to reset all settings to defaults for this character? This will reload the UI.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            IM.db = IM:CopyTable(IM.defaultConfig)
            IM:SaveConfig()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    -- Store references for refresh
    frame.qualityCheckboxes = qualityCheckboxes
    frame.typeCheckboxes = typeCheckboxes
    frame.tradeGoodsCheckboxes = tradeGoodsCheckboxes
    frame.stackGoldSlider = stackGoldSlider
    frame.stackSilverSlider = stackSilverSlider
    frame.stackCopperSlider = stackCopperSlider
    frame.thresholdSlider = thresholdSlider
    
    frame:SetScript("OnShow", function()
        -- Refresh all UI elements with current values
        enableCheckbox:SetChecked(IM.db.enabled)
        
        for i, qualityKey in ipairs(qualityOrder) do
            if qualityCheckboxes[qualityKey] then
                qualityCheckboxes[qualityKey]:SetChecked(IM.db.ignoreQuality[qualityKey])
            end
        end
        
        for i, typeName in ipairs(itemTypes) do
            if typeCheckboxes[typeName] then
                local isChecked = IM.db.ignoreItemTypes[typeName]
                if isChecked == nil then
                    isChecked = IM.defaultConfig.ignoreItemTypes[typeName] or false
                end
                typeCheckboxes[typeName]:SetChecked(isChecked)
            end
        end
        
        -- Refresh trade goods checkboxes - FIXED: Handle nil values
        for i, category in ipairs(tradeGoodsCategories) do
            if tradeGoodsCheckboxes[category] then
                local isChecked = IM.db.ignoreTradeGoodsTypes[category]
                if isChecked == nil then
                    isChecked = IM.defaultConfig.ignoreTradeGoodsTypes[category] or false
                    IM.db.ignoreTradeGoodsTypes[category] = isChecked
                    IM:SaveConfig()
                end
                tradeGoodsCheckboxes[category]:SetChecked(isChecked)
            end
        end
        
        -- Set min item value sliders
        local minItemValue = IM.db.minItemValue or 1
        stackGoldSlider:SetValue(math.floor(minItemValue))
        stackSilverSlider:SetValue(math.floor((minItemValue * 100) % 100))
        stackCopperSlider:SetValue(math.floor((minItemValue * 10000) % 100))
        _G[stackGoldSlider:GetName().."Text"]:SetText(string.format("%dg", math.floor(minItemValue)))
        _G[stackSilverSlider:GetName().."Text"]:SetText(string.format("%ds", math.floor((minItemValue * 100) % 100)))
        _G[stackCopperSlider:GetName().."Text"]:SetText(string.format("%dc", math.floor((minItemValue * 10000) % 100)))
        
        gearValueCheckbox:SetChecked(IM.db.ignoreGearValue)
        autoDeleteCheckbox:SetChecked(IM.db.autoDeleteEnabled)
        autoSellCheckbox:SetChecked(IM.db.autoSellAtVendor)
        showSellListCheckbox:SetChecked(IM.db.showSellListAtVendor)
        autoOpenCheckbox:SetChecked(IM.db.autoOpenOnLowSpace)
        deletionLogCheckbox:SetChecked(IM.db.deletionLogEnabled)
        thresholdSlider:SetValue(IM.db.lowSpaceThreshold * 100)
        _G[thresholdSlider:GetName().."Text"]:SetText(string.format("%d%%", IM.db.lowSpaceThreshold * 100))
    end)
    
    -- Hide by default
    frame:Hide()
    
    IM_ConfigFrame = frame
    return frame
end

function IM:ShowConfigFrame()
    if not IM_ConfigFrame then
        self:CreateConfigPanel()
    end
    
    -- Restore position
    self:RestoreFramePosition(IM_ConfigFrame, "CENTER", 0, 0)
    
    IM_ConfigFrame:Show()
end