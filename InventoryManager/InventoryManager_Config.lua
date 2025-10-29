if not InventoryManager then return end
local IM = InventoryManager

function IM:SaveConfig()
    -- Force save the configuration
    IM_ConfigDB = self.db
end

function IM:CreateConfigPanel()
    local panel = CreateFrame("Frame", "IM_ConfigPanel")
    panel.name = "Inventory Manager"
    local scrollFrame = CreateFrame("ScrollFrame", "IM_ConfigScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame", "IM_ConfigScrollChild")
    scrollChild:SetWidth(400)
    scrollChild:SetHeight(650)
    scrollFrame:SetScrollChild(scrollChild)
    
    local scrollBar = _G["IM_ConfigScrollFrameScrollBar"] or CreateFrame("Slider", "IM_ConfigScrollFrameScrollBar", scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    scrollBar:SetMinMaxValues(0, 300)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    
    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -15)
    title:SetText("Inventory Manager Settings")
    
    -- Enable checkbox
    local enableCheckbox = CreateFrame("CheckButton", "IM_EnableCheckbox", scrollChild, "OptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -50)
    _G[enableCheckbox:GetName().."Text"]:SetText("Enable Inventory Manager")
    enableCheckbox:SetChecked(self.db.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        IM.db.enabled = self:GetChecked()
        IM:SaveConfig()
        IM:RefreshUI()
    end)
    
    -- Quality settings
    local qualityTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityTitle:SetPoint("TOPLEFT", 20, -90)
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
		qualityCheckboxes[qualityKey] = CreateFrame("CheckButton", "IM_Quality_"..qualityKey, scrollChild, "OptionsCheckButtonTemplate")
		qualityCheckboxes[qualityKey]:SetPoint("TOPLEFT", 30, -120 - ((i-1) * 30))
		_G[qualityCheckboxes[qualityKey]:GetName().."Text"]:SetText(qualityColors[qualityNum] .. qualityDisplayNames[qualityKey])
		qualityCheckboxes[qualityKey]:SetChecked(self.db.ignoreQuality[qualityKey])
		qualityCheckboxes[qualityKey]:SetScript("OnClick", function(self)
			IM.db.ignoreQuality[qualityKey] = self:GetChecked() and true or false
			IM:SaveConfig()
			IM:RefreshUI()
		end)
	end
    
    -- Item type settings
	local typeTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	typeTitle:SetPoint("TOPLEFT", 200, -90)
	typeTitle:SetText("Ignore Items by Type:")
	
	local itemTypes = {"Quest", "Recipe", "Consumable"}
	local typeCheckboxes = {}
	
	for i, typeName in ipairs(itemTypes) do
		typeCheckboxes[typeName] = CreateFrame("CheckButton", "IM_Type_"..typeName, scrollChild, "OptionsCheckButtonTemplate")
		typeCheckboxes[typeName]:SetPoint("TOPLEFT", 210, -120 - ((i-1) * 30))
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
	local tradeGoodsTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tradeGoodsTitle:SetPoint("TOPLEFT", 350, -90)
	tradeGoodsTitle:SetText("Ignore Trade Goods:")
	
	local tradeGoodsCategories = {"Cloth", "Leather", "Metal", "Stone", "Meat", "Fish", "Herb", "Elemental", "Enchanting", "Jewelcrafting", "Gem", "Parts", "Other"}
	local tradeGoodsCheckboxes = {}
	
	for i, category in ipairs(tradeGoodsCategories) do
		-- Create a container frame for each checkbox
		local container = CreateFrame("Frame", nil, scrollChild)
		container:SetSize(120, 25)
		
		-- Position the container
		if i <= 6 then
			container:SetPoint("TOPLEFT", 360, -120 - ((i-1) * 30))
		else
			container:SetPoint("TOPLEFT", 460, -120 - ((i-7) * 30))
		end
		
		-- Create checkbox manually
		local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
		checkbox:SetSize(25, 25)
		checkbox:SetPoint("LEFT", 0, 0)
		
		-- Create text label
		local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
		text:SetText(category)
		
		-- Store reference
		tradeGoodsCheckboxes[category] = checkbox
		
		-- Set initial state
		local isChecked = self.db.ignoreTradeGoodsTypes[category] and true or false
		checkbox:SetChecked(isChecked)
		
		-- Set click handler
		checkbox:SetScript("OnClick", function(self)
			local checked = self:GetChecked()
			IM.db.ignoreTradeGoodsTypes[category] = checked
			IM:SaveConfig()
			IM:RefreshUI()
		end)
	end
    
    -- Stack value setting - converted to sliders
    local stackLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackLabel:SetPoint("TOPLEFT", 20, -330)
    stackLabel:SetText("Ignore items worth more than (per item):")
    stackLabel:SetTextColor(1, 1, 1)
    
    -- Gold slider for min item value
    local stackGoldSlider = CreateFrame("Slider", "IM_StackValueGold", scrollChild, "OptionsSliderTemplate")
    stackGoldSlider:SetPoint("TOPLEFT", 20, -355)
    stackGoldSlider:SetWidth(150)
    stackGoldSlider:SetHeight(17)
    stackGoldSlider:SetMinMaxValues(0, 50)
    stackGoldSlider:SetValueStep(1)
    stackGoldSlider:SetValue(math.floor(self.db.minItemValue))
    _G[stackGoldSlider:GetName().."Text"]:SetText(string.format("%dg", math.floor(self.db.minItemValue)))
    _G[stackGoldSlider:GetName().."Low"]:SetText("0g")
    _G[stackGoldSlider:GetName().."High"]:SetText("50g")
    
    local stackGoldLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackGoldLabel:SetPoint("TOPLEFT", 180, -355)
    stackGoldLabel:SetText("Gold")
    stackGoldLabel:SetTextColor(1, 1, 0)
    
    -- Silver slider for min item value
    local stackSilverSlider = CreateFrame("Slider", "IM_StackValueSilver", scrollChild, "OptionsSliderTemplate")
    stackSilverSlider:SetPoint("TOPLEFT", 20, -385)
    stackSilverSlider:SetWidth(150)
    stackSilverSlider:SetHeight(17)
    stackSilverSlider:SetMinMaxValues(0, 99)
    stackSilverSlider:SetValueStep(1)
    stackSilverSlider:SetValue(math.floor((self.db.minItemValue * 100) % 100))
    _G[stackSilverSlider:GetName().."Text"]:SetText(string.format("%ds", math.floor((self.db.minItemValue * 100) % 100)))
    _G[stackSilverSlider:GetName().."Low"]:SetText("0s")
    _G[stackSilverSlider:GetName().."High"]:SetText("99s")
    
    local stackSilverLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackSilverLabel:SetPoint("TOPLEFT", 180, -385)
    stackSilverLabel:SetText("Silver")
    stackSilverLabel:SetTextColor(0.75, 0.75, 0.75)
    
    -- Copper slider for min item value
    local stackCopperSlider = CreateFrame("Slider", "IM_StackValueCopper", scrollChild, "OptionsSliderTemplate")
    stackCopperSlider:SetPoint("TOPLEFT", 20, -415)
    stackCopperSlider:SetWidth(150)
    stackCopperSlider:SetHeight(17)
    stackCopperSlider:SetMinMaxValues(0, 99)
    stackCopperSlider:SetValueStep(1)
    stackCopperSlider:SetValue(math.floor((self.db.minItemValue * 10000) % 100))
    _G[stackCopperSlider:GetName().."Text"]:SetText(string.format("%dc", math.floor((self.db.minItemValue * 10000) % 100)))
    _G[stackCopperSlider:GetName().."Low"]:SetText("0c")
    _G[stackCopperSlider:GetName().."High"]:SetText("99c")
    
    local stackCopperLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    local gearValueCheckbox = CreateFrame("CheckButton", "IM_GearValueCheckbox", scrollChild, "OptionsCheckButtonTemplate")
    gearValueCheckbox:SetPoint("TOPLEFT", 280, -325)
    _G[gearValueCheckbox:GetName().."Text"]:SetText("Ignore Gear Value")
    gearValueCheckbox:SetChecked(self.db.ignoreGearValue)
    gearValueCheckbox:SetScript("OnClick", function(self)
        IM.db.ignoreGearValue = self:GetChecked()
        IM:SaveConfig()
        IM:RefreshUI()
    end)
	
	local autoDeleteCheckbox = CreateFrame("CheckButton", "IM_AutoDeleteCheckbox", scrollChild, "OptionsCheckButtonTemplate")
	autoDeleteCheckbox:SetPoint("TOPLEFT", 280, -350)
	_G[autoDeleteCheckbox:GetName().."Text"]:SetText("Enable Auto-Delete")
	autoDeleteCheckbox:SetChecked(self.db.autoDeleteEnabled)
	autoDeleteCheckbox:SetScript("OnClick", function(self)
		IM.db.autoDeleteEnabled = self:GetChecked()
		IM:SaveConfig()
	end)
	
    -- Auto-sell at vendor
    local autoSellCheckbox = CreateFrame("CheckButton", "IM_AutoSellCheckbox", scrollChild, "OptionsCheckButtonTemplate")
    autoSellCheckbox:SetPoint("TOPLEFT", 20, -450)
    _G[autoSellCheckbox:GetName().."Text"]:SetText("Automatically sell vendor list items at vendors")
    autoSellCheckbox:SetChecked(self.db.autoSellAtVendor)
    autoSellCheckbox:SetScript("OnClick", function(self)
        IM.db.autoSellAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Show sell list at vendor
    local showSellListCheckbox = CreateFrame("CheckButton", "IM_ShowSellListCheckbox", scrollChild, "OptionsCheckButtonTemplate")
    showSellListCheckbox:SetPoint("TOPLEFT", 20, -480)
    _G[showSellListCheckbox:GetName().."Text"]:SetText("Show sell list when vendor window opens")
    showSellListCheckbox:SetChecked(self.db.showSellListAtVendor)
    showSellListCheckbox:SetScript("OnClick", function(self)
        IM.db.showSellListAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
	
    -- Auto-open on low bag space
    local autoOpenCheckbox = CreateFrame("CheckButton", "IM_AutoOpenCheckbox", scrollChild, "OptionsCheckButtonTemplate")
    autoOpenCheckbox:SetPoint("TOPLEFT", 20, -510)
    _G[autoOpenCheckbox:GetName().."Text"]:SetText("Auto-open when bag space is low")
    autoOpenCheckbox:SetChecked(self.db.autoOpenOnLowSpace)
    autoOpenCheckbox:SetScript("OnClick", function(self)
        IM.db.autoOpenOnLowSpace = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Low space threshold slider 
    local thresholdLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thresholdLabel:SetPoint("TOPLEFT", 40, -540)
    thresholdLabel:SetText("Low space threshold:")
    thresholdLabel:SetTextColor(1, 1, 1)
    
    local thresholdSlider = CreateFrame("Slider", "IM_ThresholdSlider", scrollChild, "OptionsSliderTemplate")
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
	
	local deletionLogCheckbox = CreateFrame("CheckButton", "IM_DeletionLogCheckbox", scrollChild, "OptionsCheckButtonTemplate")
	deletionLogCheckbox:SetPoint("TOPLEFT", 20, -570) -- Adjust position as needed
	_G[deletionLogCheckbox:GetName().."Text"]:SetText("Enable Deletion Logging")
	deletionLogCheckbox:SetChecked(self.db.deletionLogEnabled)
	deletionLogCheckbox:SetScript("OnClick", function(self)
		IM.db.deletionLogEnabled = self:GetChecked()
		IM:SaveConfig()
	end)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("TOPLEFT", 20, -600)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("IM_CONFIRM_RESET")
    end)
    
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
    
    panel:SetScript("OnShow", function()
        -- Refresh all UI elements with current values
        enableCheckbox:SetChecked(IM.db.enabled)
        
        for i, qualityKey in ipairs(qualityOrder) do
            if qualityCheckboxes[qualityKey] then
                qualityCheckboxes[qualityKey]:SetChecked(IM.db.ignoreQuality[qualityKey])
            end
        end
        
        for i, typeName in ipairs(itemTypes) do
            if typeCheckboxes[typeName] then
                local isChecked = IM.db.ignoreItemTypes[typeName] and true or false
                typeCheckboxes[typeName]:SetChecked(isChecked)
            end
        end
        
        -- Refresh trade goods checkboxes
        for i, category in ipairs(tradeGoodsCategories) do
            if tradeGoodsCheckboxes[category] then
                local isChecked = IM.db.ignoreTradeGoodsTypes[category] and true or false
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
        
        scrollBar:SetMinMaxValues(0, math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight()))
    end)
    
    InterfaceOptions_AddCategory(panel)
end