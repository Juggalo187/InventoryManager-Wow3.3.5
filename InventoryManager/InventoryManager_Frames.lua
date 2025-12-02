if not InventoryManager then return end
local IM = InventoryManager

function IM:EnsureToggleIconOnTop()
    if IM_ToggleIcon then
        IM_ToggleIcon:SetFrameStrata("HIGH")
        IM_ToggleIcon:SetFrameLevel(100)
    end
end

function IM:CreateToggleIcon()
    -- Check if frame already exists
    if IM_ToggleIcon then
		IM:EnsureToggleIconOnTop()
        return IM_ToggleIcon
    end
    
    local frame = CreateFrame("Button", "IM_ToggleIcon", UIParent)
    frame:SetSize(29, 29)
    frame:SetPoint("CENTER", UIParent, "CENTER", -400, 0) -- Position on left side
    
    -- Set frame to stay on top of other frames
    frame:SetFrameStrata("HIGH")  -- Makes it appear above most UI elements
    frame:SetFrameLevel(100)      -- High level within its strata to ensure it's on top
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.6)
    
    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(25, 25)
    frame.icon:SetPoint("CENTER")
    frame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Fix for icon borders
    
    -- Border (using simple color instead of texture for compatibility)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Set initial icon
    self:UpdateToggleIcon()
    
    -- Make it draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        IM.db.toggleIconPosition = {point = point, relativePoint = relativePoint, x = x, y = y}
        IM:SaveConfig()
    end)
    
    -- Click handler - Simple version
    frame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Toggle main window
            if IM_MainFrame and IM_MainFrame:IsShown() then
                IM_MainFrame:Hide()
            else
                IM:CreateFrames()
                IM:ShowSuggestions()
            end
        end
    end)
    
    -- Right-click handler (separate script)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- Right click to open simple settings
            if not IM_SimpleSettingsFrame then
                IM:CreateSimpleSettingsFrame()
            end
            
            if IM_SimpleSettingsFrame:IsShown() then
                IM_SimpleSettingsFrame:Hide()
            else
                -- Update checkbox states before showing
                IM_SimpleSettingsFrame.enableCheckbox:SetChecked(IM.db.enabled)
                IM_SimpleSettingsFrame.autoSellCheckbox:SetChecked(IM.db.autoSellAtVendor)
                IM_SimpleSettingsFrame.autoOpenCheckbox:SetChecked(IM.db.autoOpenOnLowSpace)
                IM_SimpleSettingsFrame.enableAutoDeleteCheckbox:SetChecked(IM.db.autoDeleteEnabled)
                
                IM_SimpleSettingsFrame:Show()
            end
        end
    end)
    
    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Inventory Manager")
        GameTooltip:AddLine("Left-click: Toggle main window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Quick settings", 1, 1, 1)
        GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Restore saved position if exists
    if self.db.toggleIconPosition then
        frame:ClearAllPoints()
        frame:SetPoint(self.db.toggleIconPosition.point, UIParent, self.db.toggleIconPosition.relativePoint, self.db.toggleIconPosition.x, self.db.toggleIconPosition.y)
    end
    
    IM_ToggleIcon = frame
    return frame
end

function IM:UpdateToggleIcon()
    if not IM_ToggleIcon then return end
    
    -- Get current date (compatible with 3.3.5)
    local dateTable = date("*t")
    local month = dateTable.month
    local iconPath
    
    -- Seasonal icons that exist in 3.3.5
    if month == 10 then -- October (Halloween)
        iconPath = "Interface\\Icons\\inv_misc_bag_28_halloween" -- Pumpkin Bag
    elseif month == 12 then -- December (Winter Veil)
        iconPath = "Interface\\Icons\\Inv_holiday_christmas_present_01" -- Red Winter Veil Bag
    elseif month == 2 then -- February (Love is in the Air)
        iconPath = "Interface\\Icons\\INV_ValentinesCard01" -- Love Token
    elseif month == 4 then -- April (Noblegarden)
        iconPath = "Interface\\Icons\\INV_Egg_02" -- Brightly Colored Egg
    elseif month == 11 then -- November (Pilgrim's Bounty)
        iconPath = "Interface\\Icons\\INV_Thanksgiving_Turkey" -- Turkey
    elseif month == 1 then -- January (New Year)
        iconPath = "Interface\\Icons\\inv_misc_coin_02" -- Gold Coin
    else
        -- Default bag icons that exist in 3.3.5
        local defaultBags = {
            "Interface\\Icons\\INV_Misc_Bag_07", -- Red Mageweave Bag
            "Interface\\Icons\\INV_Misc_Bag_09", -- Black Mageweave Bag
            "Interface\\Icons\\INV_Misc_Bag_08", -- Spider Silk Bag
            "Interface\\Icons\\inv_misc_bag_felclothbag", -- Felcloth Bag
            "Interface\\Icons\\inv_misc_bag_25_mooncloth", -- Green Winter Veil Bag
            "Interface\\Icons\\INV_Misc_Bag_EnchantedMageweave", -- Enchanted Mageweave Pouch
        }
        local bagIndex = ((month - 1) % #defaultBags) + 1
        iconPath = defaultBags[bagIndex]
    end
    
    -- Safe set texture with fallback
    if iconPath then
        IM_ToggleIcon.icon:SetTexture(iconPath)
    else
        -- Fallback to a basic bag icon
        IM_ToggleIcon.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
    end
end

function IM:CreateSimpleSettingsFrame()
    if IM_SimpleSettingsFrame then
        return IM_SimpleSettingsFrame
    end
    
    local frame = CreateFrame("Frame", "IM_SimpleSettingsFrame", UIParent)
    frame:SetSize(300, 200)
    
    -- Set frame strata to be on top of everything
    frame:SetFrameStrata("DIALOG")  -- This makes it appear above most other frames
    frame:SetToplevel(true)         -- Ensures it stays on top when clicked
    
    -- Restore saved position or use default
    self:RestoreFramePosition(frame, "CENTER", 0, 0)
    
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
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Inventory Manager Settings")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Enable/Disable checkbox
    frame.enableCheckbox = CreateFrame("CheckButton", "IM_SimpleEnableCheckbox", frame, "OptionsCheckButtonTemplate")
    frame.enableCheckbox:SetPoint("TOPLEFT", 20, -40)
    _G[frame.enableCheckbox:GetName().."Text"]:SetText("Enable Inventory Manager")
    frame.enableCheckbox:SetChecked(self.db.enabled)
    frame.enableCheckbox:SetScript("OnClick", function(self)
        IM.db.enabled = self:GetChecked()
        IM:SaveConfig()
        IM:RefreshUI()
    end)
    
    -- Auto-sell checkbox
    frame.showSellListCheckbox = CreateFrame("CheckButton", "IM_SimpleShowSellListCheckbox", frame, "OptionsCheckButtonTemplate")
    frame.showSellListCheckbox:SetPoint("TOPLEFT", 20, -60)
    _G[frame.showSellListCheckbox:GetName().."Text"]:SetText("Show sell list when vendor window opens")
    frame.showSellListCheckbox:SetChecked(self.db.showSellListAtVendor)
    frame.showSellListCheckbox:SetScript("OnClick", function(self)
        IM.db.showSellListAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Auto-sell checkbox
    frame.autoSellCheckbox = CreateFrame("CheckButton", "IM_SimpleAutoSellCheckbox", frame, "OptionsCheckButtonTemplate")
    frame.autoSellCheckbox:SetPoint("TOPLEFT", 20, -80)
    _G[frame.autoSellCheckbox:GetName().."Text"]:SetText("Auto-sell at vendors")
    frame.autoSellCheckbox:SetChecked(self.db.autoSellAtVendor)
    frame.autoSellCheckbox:SetScript("OnClick", function(self)
        IM.db.autoSellAtVendor = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Auto-open checkbox
    frame.autoOpenCheckbox = CreateFrame("CheckButton", "IM_SimpleAutoOpenCheckbox", frame, "OptionsCheckButtonTemplate")
    frame.autoOpenCheckbox:SetPoint("TOPLEFT", 20, -100)
    _G[frame.autoOpenCheckbox:GetName().."Text"]:SetText("Auto-open on low space")
    frame.autoOpenCheckbox:SetChecked(self.db.autoOpenOnLowSpace)
    frame.autoOpenCheckbox:SetScript("OnClick", function(self)
        IM.db.autoOpenOnLowSpace = self:GetChecked()
        IM:SaveConfig()
    end)
    
    -- Enable Auto-Delete checkbox
    frame.enableAutoDeleteCheckbox = CreateFrame("CheckButton", "IM_SimpleEnableAutoDeleteCheckbox", frame, "OptionsCheckButtonTemplate")
    frame.enableAutoDeleteCheckbox:SetPoint("TOPLEFT", 20, -120)
    _G[frame.enableAutoDeleteCheckbox:GetName().."Text"]:SetText("Enable Auto-Delete")
    frame.enableAutoDeleteCheckbox:SetChecked(self.db.autoDeleteEnabled)
    frame.enableAutoDeleteCheckbox:SetScript("OnClick", function(self)
        IM.db.autoDeleteEnabled = self:GetChecked()
        IM:SaveConfig()
    end)
	
    
	frame.fullSettingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.fullSettingsBtn:SetSize(100, 25)
	frame.fullSettingsBtn:SetPoint("BOTTOMLEFT", 50, 10)
	frame.fullSettingsBtn:SetText("Full Settings")
	frame.fullSettingsBtn:SetScript("OnClick", function()
		if IM_ConfigFrame and IM_ConfigFrame:IsShown() then
			IM_ConfigFrame:Hide()
		else
			IM:ShowConfigFrame()
		end
	end)
	
	frame.deletionLogBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.deletionLogBtn:SetSize(100, 25)
	frame.deletionLogBtn:SetPoint("LEFT", frame.fullSettingsBtn, "RIGHT", 0, 0)
	frame.deletionLogBtn:SetText("Deletion Log")
	frame.deletionLogBtn:SetScript("OnClick", function()
		if IM_DeletionLogFrame and IM_DeletionLogFrame:IsShown() then
			IM_DeletionLogFrame:Hide()
		else
			IM:ShowDeletionLogFrame()
		end
	end)
    
    -- Hide by default
    frame:Hide()
    
    IM_SimpleSettingsFrame = frame
    return frame
end

function IM:ShowDeletionLogFrame()
    if not IM_DeletionLogFrame then
        self:CreateDeletionLogFrame()
    end
    
    if IM_DeletionLogFrame.tabs and IM_DeletionLogFrame.tabs[1] then
        for _, tab in ipairs(IM_DeletionLogFrame.tabs) do
            tab:Enable()
        end
        IM_DeletionLogFrame.tabs[1]:Disable()
    end
    
    self:UpdateDeletionLogFrame(12)
    IM_DeletionLogFrame:Show()
end

function IM:ClearDeletionLog()
    self.deletionLog = {
        sessions = {},
        lastCleanup = time()
    }
    self:StartNewSession()
    self:SaveDeletionLog()
    
    if IM_DeletionLogFrame and IM_DeletionLogFrame:IsShown() then
        self:UpdateDeletionLogFrame(0) -- Refresh to show empty
    end
end

function IM:UpdateDeletionLogFrame(hours)
    if not IM_DeletionLogFrame then return end
    
    local deletions = self:GetDeletionsForTimeRange(hours)
    
    local groupedDeletions = {}
	for _, deletion in ipairs(deletions) do
		-- Skip entries with nil itemID and log only once per unique issue
		if not deletion or not deletion.itemID then
			-- Only print the warning once to avoid spam
			if not groupedDeletions._nilWarningShown then
				print("Inventory Manager: Skipping deletion entry with nil itemID")
				groupedDeletions._nilWarningShown = true
			end
		else
			local key = deletion.itemID .. "_" .. (deletion.deletionType or "manual")
				
			if not groupedDeletions[key] then
				-- Create a new grouped entry
				groupedDeletions[key] = {
					itemLink = deletion.itemLink,
					itemID = deletion.itemID,
					itemCount = deletion.itemCount,
					deletionType = deletion.deletionType or "manual",
					timestamp = deletion.timestamp, -- Keep the most recent timestamp
					instances = 1 -- Count how many times this item was deleted
				}
			else
				-- Combine with existing grouped entry
				groupedDeletions[key].itemCount = groupedDeletions[key].itemCount + deletion.itemCount
				groupedDeletions[key].instances = groupedDeletions[key].instances + 1
				-- Update to the most recent timestamp
				if deletion.timestamp > groupedDeletions[key].timestamp then
					groupedDeletions[key].timestamp = deletion.timestamp
				end
			end
		end
	end
    
    local displayDeletions = {}
    for _, groupedDeletion in pairs(groupedDeletions) do
        table.insert(displayDeletions, groupedDeletion)
    end
    
    table.sort(displayDeletions, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    self:ClearFrameContent(IM_DeletionLogFrame.content, "IM_DeletionLogItem_")
    
    local totalItems = 0
    local totalDeletions = 0
    local contentHeight = math.max(400, #displayDeletions * 35 + 10)
    IM_DeletionLogFrame.content:SetHeight(contentHeight)
    
    for i, deletion in ipairs(displayDeletions) do
        local widget = _G["IM_DeletionLogItem_"..i] or CreateFrame("Button", "IM_DeletionLogItem_"..i, IM_DeletionLogFrame.content)
        widget:SetSize(450, 30)
        
        if not widget.initialized then
            widget:SetPoint("TOPLEFT", 5, -(i-1)*35)
            widget.bg = widget:CreateTexture(nil, "BACKGROUND")
            widget.bg:SetAllPoints(true)
            widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            widget.icon = widget:CreateTexture(nil, "ARTWORK")
            widget.icon:SetSize(20, 20)
            widget.icon:SetPoint("LEFT", 5, 0)
            widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            widget.text = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.text:SetPoint("LEFT", 30, 0)
            widget.text:SetSize(350, 20)
            widget.text:SetJustifyH("LEFT")
            widget.time = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.time:SetPoint("RIGHT", -5, 0)
            widget.time:SetSize(100, 20)
            widget.time:SetJustifyH("RIGHT")
            widget.initialized = true
        end
        
        local texture = GetItemIcon(deletion.itemLink) or "Interface\\Icons\\INV_Misc_QuestionMark"
        widget.icon:SetTexture(texture)
        
        local countText = deletion.itemCount > 1 and string.format("x%d", deletion.itemCount) or ""
        local typeText = deletion.deletionType == "auto" and "|cFFFF0000[Auto]|r" or "|cFF00FF00[Manual]|r"
        local instancesText = deletion.instances > 1 and string.format(" (%d times)", deletion.instances) or ""
        
        widget.text:SetText(string.format("%s %s %s%s", deletion.itemLink, countText, typeText, instancesText))
        widget.time:SetText(self:FormatDeletionTime(deletion.timestamp))
        
        totalItems = totalItems + deletion.itemCount
        totalDeletions = totalDeletions + deletion.instances
        
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(deletion.itemLink)
            GameTooltip:AddLine("Deleted: " .. self.time:GetText(), 1, 1, 1)
            GameTooltip:AddLine("Type: " .. (deletion.deletionType == "auto" and "Auto-delete" or "Manual delete"), 1, 1, 1)
            GameTooltip:AddLine("Total Items: " .. deletion.itemCount, 1, 1, 1)
            if deletion.instances > 1 then
                GameTooltip:AddLine("Deleted " .. deletion.instances .. " separate times", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        widget:Show()
    end
    
    -- Update summary to show both total items and deletion instances
    IM_DeletionLogFrame.summary:SetText(string.format("Total: %d items (%d deletions)", totalItems, totalDeletions))
    
    IM_DeletionLogFrame.scroll:UpdateScrollChildRect()
end

function IM:CreateDeletionLogFrame()
    if IM_DeletionLogFrame then
        return IM_DeletionLogFrame
    end
    
    local frame = CreateFrame("Frame", "IM_DeletionLogFrame", UIParent)
    frame:SetSize(500, 500)
    self:RestoreFramePosition(frame, "CENTER", 150, 0)
    
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
    frame.bg:SetTexture(0, 0, 0, 0.8)
    
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Log")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Time filter tabs - using proper WoW 3.3.5 tab templates
    frame.tabs = {}
    local tabTimes = {
		{label = "12h", hours = 12},
		{label = "24 Hours", hours = 24},
		{label = "7 Days", hours = 168},
		{label = "30 Days", hours = 720}
	}
    
        frame.tabs = {}
    local tabTimes = {
        {label = "Session (12h)", hours = 12},
        {label = "24 Hours", hours = 24},
        {label = "7 Days", hours = 168},
        {label = "30 Days", hours = 720}
    }
    
    for i, tabInfo in ipairs(tabTimes) do
        local tab = CreateFrame("Button", "IM_DeletionLogTab_"..i, frame, "OptionsFrameTabButtonTemplate")
        tab:SetText(tabInfo.label)
        tab:SetWidth(90)  -- Slightly wider to fit "Session (12h)"
        
        if i == 1 then
            tab:SetPoint("TOPLEFT", 10, -30)
        else
            tab:SetPoint("LEFT", frame.tabs[i-1], "RIGHT", -15, 0)
        end
        
        PanelTemplates_TabResize(tab, 0)
        
        -- Store the hours value and index for this tab
        tab.hours = tabInfo.hours
        tab.index = i
        
        tab:SetScript("OnClick", function(self)
            -- Enable all tabs first
            for _, otherTab in ipairs(frame.tabs) do
                otherTab:Enable()
            end
            -- Disable the clicked tab to show it's active
            self:Disable()
            -- Update the content
            IM:UpdateDeletionLogFrame(self.hours)
        end)
        
        frame.tabs[i] = tab
    end
    
    -- Set first tab as active by default
    if frame.tabs[1] then
        frame.tabs[1]:Disable()
    end
    
    -- Scroll frame
    frame.scroll = CreateFrame("ScrollFrame", "IM_DeletionLogScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -60)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(frame.scroll:GetWidth() - 20, 400)
    frame.scroll:SetScrollChild(frame.content)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_DeletionLogScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Summary text
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("BOTTOMLEFT", 10, 10)
    frame.summary:SetText("Total: 0 items")
    
    -- Clear button
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(80, 25)
    frame.clearBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.clearBtn:SetText("Clear Log")
    frame.clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("IM_CONFIRM_CLEAR_LOG")
    end)
    
    -- Clear confirmation dialog
    StaticPopupDialogs["IM_CONFIRM_CLEAR_LOG"] = {
        text = "Are you sure you want to clear the entire deletion log? This cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            IM:ClearDeletionLog()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    IM_DeletionLogFrame = frame
    return frame
end

function IM:CreateMainFrame()
    -- Check if frame already exists
    if IM_MainFrame then
        return IM_MainFrame
    end
    
    local frame = CreateFrame("Frame", "IM_MainFrame", UIParent)
    frame:SetSize(500, 500)
    self:RestoreFramePosition(frame, "CENTER", 0, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IM:SaveFramePosition(self)
    end)
	
	frame:SetScript("OnShow", function(self)
		-- Ensure frame is at its saved position when shown
		IM:RestoreFramePosition(self, "CENTER", 0, 0)
	end)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.8)
    
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Inventory Manager")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Delete suggestions title
    frame.deleteTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.deleteTitle:SetPoint("TOPLEFT", 10, -30)
    frame.deleteTitle:SetText("Delete Suggestions:")
    
    -- Delete suggestions scroll frame - make it taller to use more space
    frame.deleteScroll = CreateFrame("ScrollFrame", "IM_DeleteScroll", frame, "UIPanelScrollFrameTemplate")
    frame.deleteScroll:SetPoint("TOPLEFT", 10, -50)
    frame.deleteScroll:SetPoint("BOTTOMRIGHT", -32, 40) -- Extend to near bottom buttons
    
    frame.deleteContent = CreateFrame("Frame", nil, frame.deleteScroll)
    frame.deleteContent:SetSize(frame.deleteScroll:GetWidth() - 20, 400) -- Dynamic width
    frame.deleteScroll:SetScrollChild(frame.deleteContent)
	
	frame.slotsFreedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.slotsFreedText:SetPoint("BOTTOMLEFT", 5, 15)
    frame.slotsFreedText:SetSize(300, 20)
    frame.slotsFreedText:SetJustifyH("LEFT")
    frame.slotsFreedText:SetText("Slots freed: 0")
    
    frame.valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.valueText:SetPoint("BOTTOMLEFT", 5, 0)
    frame.valueText:SetSize(300, 20)
    frame.valueText:SetJustifyH("LEFT")
    frame.valueText:SetText("Value: 0g 0s 0c")
    
    -- Position the scroll bar properly inside the frame
    local scrollBar = _G["IM_DeleteScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.deleteScroll, "TOPRIGHT", 15, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.deleteScroll, "BOTTOMRIGHT", 15, 16)
    end
	
	frame.autoDeleteListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.autoDeleteListBtn:SetSize(90, 25)
	frame.autoDeleteListBtn:SetPoint("BOTTOMLEFT", 140, 5)
	frame.autoDeleteListBtn:SetText("Auto-Delete")
	frame.autoDeleteListBtn:SetScript("OnClick", function()
		if IM_AutoDeleteListFrame and IM_AutoDeleteListFrame:IsShown() then
			IM_AutoDeleteListFrame:Hide()
		else
			IM:ShowAutoDeleteListFrame()
		end
	end)
	
	-- Delete All button
    frame.deleteAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.deleteAllBtn:SetSize(90, 25)
	frame.deleteAllBtn:SetPoint("LEFT", frame.autoDeleteListBtn, "RIGHT", 0, 0)
    frame.deleteAllBtn:SetText("Delete All")
    frame.deleteAllBtn:SetScript("OnClick", function()
        IM:ConfirmDeleteAll()
    end)
    
    -- Sell List button
    frame.sellListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.sellListBtn:SetSize(80, 25)
	frame.sellListBtn:SetPoint("LEFT", frame.deleteAllBtn, "RIGHT", 0, 0)
    frame.sellListBtn:SetText("Sell List")
    frame.sellListBtn:SetScript("OnClick", function()
		if IM_SellListFrame and IM_SellListFrame:IsShown() then
			IM_SellListFrame:Hide()
		else
			IM:ShowSellListFrame()
		end
    end)
    
    -- Ignored Items button
    frame.ignoredListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.ignoredListBtn:SetSize(100, 25)
    --frame.ignoredListBtn:SetPoint("BOTTOMRIGHT", -10, 10)
	frame.ignoredListBtn:SetPoint("LEFT", frame.sellListBtn, "RIGHT", 0, 0)
    frame.ignoredListBtn:SetText("Ignored Items")
    frame.ignoredListBtn:SetScript("OnClick", function()
		if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
			IM_IgnoredListFrame:Hide()
		else
			IM:ShowIgnoredListFrame()
		end
    end)

    IM_MainFrame = frame
end

function IM:CreateFrames()
    -- Don't create frames if they already exist
    if not IM_MainFrame then
        self:CreateMainFrame()
    end
end

function IM:CreateSellListFrame()
    -- Check if frame already exists
    if IM_SellListFrame then
        return IM_SellListFrame
    end
    
    local frame = CreateFrame("Frame", "IM_SellListFrame", UIParent)
    frame:SetSize(400, 500)
    self:RestoreFramePosition(frame, "CENTER", 100, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IM:SaveFramePosition(self)
    end)
	
	frame:SetScript("OnShow", function(self)
		-- Ensure frame is at its saved position when shown
		IM:RestoreFramePosition(self, "CENTER", 0, 0)
	end)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.8)
    
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Sell List")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame - make it taller
    frame.scroll = CreateFrame("ScrollFrame", "IM_SellListScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -40)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 80) -- More space for buttons and total value
    
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(frame.scroll:GetWidth() - 20, 400)
    frame.scroll:SetScrollChild(frame.content)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_SellListScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Total value display
    frame.totalValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.totalValue:SetPoint("BOTTOMLEFT", 10, 40)
    frame.totalValue:SetText("Total Value: 0g 0s 0c")
    
    -- Sell All button
    frame.sellBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.sellBtn:SetSize(100, 25)
    frame.sellBtn:SetPoint("BOTTOMLEFT", 10, 10)
    frame.sellBtn:SetText("Sell All")
    frame.sellBtn:SetScript("OnClick", function()
        IM:SellVendorItems()
    end)
    
    -- Clear List button
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(100, 25)
    frame.clearBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.clearBtn:SetText("Clear List")
    frame.clearBtn:SetScript("OnClick", function()
        IM:ClearVendorList()
        IM:UpdateSellListFrame()
    end)
    
    IM_SellListFrame = frame
end

function IM:CreateIgnoredListFrame()
    -- Check if frame already exists
    if IM_IgnoredListFrame then
        return IM_IgnoredListFrame
    end
    
    local frame = CreateFrame("Frame", "IM_IgnoredListFrame", UIParent)
    frame:SetSize(400, 500)
    self:RestoreFramePosition(frame, "CENTER", -100, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IM:SaveFramePosition(self)
    end)
	
	frame:SetScript("OnShow", function(self)
		-- Ensure frame is at its saved position when shown
		IM:RestoreFramePosition(self, "CENTER", 0, 0)
	end)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.8)
    
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Ignored Items")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame - make it taller
    frame.scroll = CreateFrame("ScrollFrame", "IM_IgnoredListScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -40)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 40) -- More space for button
    
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(frame.scroll:GetWidth() - 20, 400)
    frame.scroll:SetScrollChild(frame.content)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_IgnoredListScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Clear All button
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(100, 25)
    frame.clearBtn:SetPoint("BOTTOM", 0, 10)
    frame.clearBtn:SetText("Clear All")
    frame.clearBtn:SetScript("OnClick", function()
        IM:ClearIgnoredList()
    end)
    
    IM_IgnoredListFrame = frame
end

function IM:CreateExportFrame()
    if IM_ExportFrame then
        return IM_ExportFrame
    end
    
    local frame = CreateFrame("Frame", "IM_ExportFrame", UIParent)
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER", 0, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Export")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Instructions
    frame.instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.instructions:SetPoint("TOP", 0, -30)
    frame.instructions:SetText("Select and copy the text below:")
    
    -- Scroll frame for export text
    frame.scroll = CreateFrame("ScrollFrame", "IM_ExportScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -55)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    
    -- Edit box for text (read-only)
    frame.exportText = CreateFrame("EditBox", nil, frame.scroll)
    frame.exportText:SetMultiLine(true)
    frame.exportText:SetFontObject("GameFontHighlight")
    frame.exportText:SetWidth(frame.scroll:GetWidth() - 20)
    frame.exportText:SetHeight(200)
    frame.exportText:SetAutoFocus(false)
    frame.exportText:SetTextInsets(5, 5, 5, 5)
    frame.exportText:EnableMouse(true)
    frame.exportText:SetScript("OnEscapePressed", function() frame:Hide() end)
    
    -- Make it read-only but selectable
    frame.exportText:SetScript("OnTextChanged", function(self)
        -- Prevent modification but allow selection
        if self.originalText then
            self:SetText(self.originalText)
        end
    end)
    
    frame.scroll:SetScrollChild(frame.exportText)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_ExportScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Select All button
    frame.selectAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.selectAllBtn:SetSize(100, 25)
    frame.selectAllBtn:SetPoint("BOTTOMLEFT", 10, 10)
    frame.selectAllBtn:SetText("Select All")
    frame.selectAllBtn:SetScript("OnClick", function()
        frame.exportText:HighlightText()
        frame.exportText:SetFocus()
    end)
    
    -- Copy button (for convenience, though user can just Ctrl+C)
    frame.copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.copyBtn:SetSize(80, 25)
    frame.copyBtn:SetPoint("BOTTOM", 0, 10)
    frame.copyBtn:SetText("Copy")
    frame.copyBtn:SetScript("OnClick", function()
        frame.exportText:HighlightText()
        frame.exportText:SetFocus()
        -- Just select the text - user can press Ctrl+C to copy
        print("Inventory Manager: Text selected. Press Ctrl+C to copy.")
    end)
    
    -- Close button at bottom
    frame.closeBottomBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.closeBottomBtn:SetSize(80, 25)
    frame.closeBottomBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.closeBottomBtn:SetText("Close")
    frame.closeBottomBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Info text
    frame.infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.infoText:SetPoint("BOTTOM", 0, 35)
    frame.infoText:SetText("Press Ctrl+A to select all, then Ctrl+C to copy")
    frame.infoText:SetTextColor(0.8, 0.8, 0.8)
    
    IM_ExportFrame = frame
    return frame
end

function IM:CreateAutoDeleteListFrame()
    -- Check if frame already exists
    if IM_AutoDeleteListFrame then
        return IM_AutoDeleteListFrame
    end
    
    local frame = CreateFrame("Frame", "IM_AutoDeleteListFrame", UIParent)
    frame:SetSize(400, 550) -- Increased height to accommodate new buttons
    self:RestoreFramePosition(frame, "CENTER", 200, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IM:SaveFramePosition(self)
    end)
    
    frame:SetScript("OnShow", function(self)
        IM:RestoreFramePosition(self, "CENTER", 200, 0)
    end)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.8)
    
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
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Auto-Delete List")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame - adjusted for new buttons
    frame.scroll = CreateFrame("ScrollFrame", "IM_AutoDeleteListScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -40)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 90) -- More space for buttons
    
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(frame.scroll:GetWidth() - 20, 400)
    frame.scroll:SetScrollChild(frame.content)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_AutoDeleteListScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Button container frame
    frame.buttonContainer = CreateFrame("Frame", nil, frame)
    frame.buttonContainer:SetSize(380, 70)
    frame.buttonContainer:SetPoint("BOTTOM", 0, 10)
    
    -- Export button
    frame.exportBtn = CreateFrame("Button", nil, frame.buttonContainer, "UIPanelButtonTemplate")
    frame.exportBtn:SetSize(80, 25)
    frame.exportBtn:SetPoint("BOTTOM", -45, 20)
    frame.exportBtn:SetText("Export")
    frame.exportBtn:SetScript("OnClick", function()
        IM:ExportAutoDeleteList()
    end)
	
    -- Import button
    frame.importBtn = CreateFrame("Button", nil, frame.buttonContainer, "UIPanelButtonTemplate")
    frame.importBtn:SetSize(80, 25)
	frame.importBtn:SetPoint("LEFT", frame.exportBtn, "RIGHT", 0, 0)
    frame.importBtn:SetText("Import")
    frame.importBtn:SetScript("OnClick", function()
        IM:ShowImportAutoDeleteDialog()
    end)
    
    -- Clear All button
    frame.clearBtn = CreateFrame("Button", nil, frame.buttonContainer, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(100, 20)
    frame.clearBtn:SetPoint("BOTTOM", 0, 0)
    frame.clearBtn:SetText("Clear All")
    frame.clearBtn:SetScript("OnClick", function()
        IM:ClearAutoDeleteList()
    end)
    
    -- Info text
    frame.infoText = frame.buttonContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.infoText:SetPoint("TOP", 0, -5)
    frame.infoText:SetText("Export/Import your auto-delete list to share with other characters")
    frame.infoText:SetTextColor(0.8, 0.8, 0.8)
    
    IM_AutoDeleteListFrame = frame
    return frame
end

function IM:ShowSuggestions()
    if not self.db.enabled then
        if IM_MainFrame then
            IM_MainFrame:Hide()
        end
        return
    end
    
    -- Don't create frames here - they should be created by CreateFrames()
    if not IM_MainFrame then
        self:CreateFrames()
    end
    
    local suggestions, totalSlots, usedSlots = self:ScanInventory()
    
    if IM_MainFrame then
        self:UpdateMainFrame(suggestions, totalSlots, usedSlots)
        IM_MainFrame:Show()
    else
        print("Inventory Manager: Main frame not properly initialized")
    end
end

function IM:ShowSellListFrame()
    if not IM_SellListFrame then
        self:CreateSellListFrame()
    end
    self:RefreshVendorListLocations()
    self:UpdateSellListFrame()
    IM_SellListFrame:Show()
end

function IM:ShowIgnoredListFrame()
    if not IM_IgnoredListFrame then
        self:CreateIgnoredListFrame()
    end
    self:UpdateIgnoredListFrame()
    IM_IgnoredListFrame:Show()
end

function IM:ShowAutoDeleteListFrame()
    if not IM_AutoDeleteListFrame then
        self:CreateAutoDeleteListFrame()
    end
    self:UpdateAutoDeleteListFrame()
    IM_AutoDeleteListFrame:Show()
end

function IM:UpdateAutoDeleteListFrame()
    if not IM_AutoDeleteListFrame then return end
    
    -- Ensure autoDeleteList exists and is valid
    if not self.autoDeleteList then
        self.autoDeleteList = {}
    end
    
    -- Clean up invalid entries before displaying
    self:ValidateAutoDeleteList()
    
    local contentHeight = math.max(400, #self.autoDeleteList * 45 + 10)
    IM_AutoDeleteListFrame.content:SetHeight(contentHeight)
    
    -- Update title to show count
    IM_AutoDeleteListFrame.title:SetText(string.format("Auto-Delete List (%d items)", #self.autoDeleteList))
    
    -- Clear existing widgets first
    self:ClearFrameContent(IM_AutoDeleteListFrame.content, "IM_AutoDeleteItem_")
    
    for i, autoDeleteItem in ipairs(self.autoDeleteList) do
        -- Double-check that itemID exists to prevent errors
        if not autoDeleteItem or not autoDeleteItem.itemID then
            print("Inventory Manager: Skipping invalid auto-delete item at index " .. i)
        else
            local widget = _G["IM_AutoDeleteItem_"..i] or CreateFrame("Button", "IM_AutoDeleteItem_"..i, IM_AutoDeleteListFrame.content)
            widget:SetSize(350, 40)
            
            if not widget.initialized then
                widget:SetPoint("TOPLEFT", 5, -(i-1)*45)
                widget.bg = widget:CreateTexture(nil, "BACKGROUND")
                widget.bg:SetAllPoints(true)
                widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
                widget.icon = widget:CreateTexture(nil, "ARTWORK")
                widget.icon:SetSize(30, 30)
                widget.icon:SetPoint("LEFT", 5, 0)
                widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                widget.name = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                widget.name:SetPoint("TOPLEFT", 40, -5)
                widget.name:SetSize(200, 20)
                widget.name:SetJustifyH("LEFT")
                widget.status = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                widget.status:SetPoint("BOTTOMLEFT", 40, 5)
                widget.status:SetSize(200, 20)
                widget.status:SetJustifyH("LEFT")
                widget.removeBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
                widget.removeBtn:SetSize(60, 20)
                widget.removeBtn:SetPoint("RIGHT", -5, 0)
                widget.removeBtn:SetText("Remove")
                widget.initialized = true
            end
            
            -- Safe texture loading
            local texture = GetItemIcon(autoDeleteItem.itemID)
            if not texture then
                texture = "Interface\\Icons\\INV_Misc_QuestionMark"
            end
            widget.icon:SetTexture(texture)
            
            local qualityColor = self.qualityColors[autoDeleteItem.quality] or "|cFFFFFFFF"
            local displayName = autoDeleteItem.displayName or autoDeleteItem.name or "Unknown Item"
            
            widget.name:SetText(qualityColor .. displayName .. "|r")
            widget.status:SetText("Auto-delete when looted")
            
            -- Safe quality color application
            if autoDeleteItem.quality and self.qualityColors[autoDeleteItem.quality] then
                local color = self.qualityColors[autoDeleteItem.quality]
                local hex = color:sub(3)
                local r = tonumber(hex:sub(1, 2), 16) / 255
                local g = tonumber(hex:sub(3, 4), 16) / 255
                local b = tonumber(hex:sub(5, 6), 16) / 255
                widget.bg:SetTexture(r * 0.1, g * 0.1, b * 0.1, 0.3)
            else
                widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            end
            
            widget:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if autoDeleteItem.link then
                    GameTooltip:SetHyperlink(autoDeleteItem.link)
                else
                    GameTooltip:SetText(displayName)
                end
                GameTooltip:AddLine("This item will be automatically deleted when looted", 1, 0.5, 0.5)
                GameTooltip:AddLine("Item ID: " .. autoDeleteItem.itemID, 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- FIXED: Proper remove button handler that refreshes the frame
            widget.removeBtn:SetScript("OnClick", function()
                -- Store the item ID before removing
                local itemIDToRemove = autoDeleteItem.itemID
                
                -- Remove from the list
                if IM:RemoveFromAutoDeleteList(itemIDToRemove) then
                    -- The frame will be automatically refreshed by RemoveFromAutoDeleteList
                    print(string.format("Inventory Manager: Removed %s from auto-delete list", displayName))
                else
                    print("Inventory Manager: Failed to remove item from auto-delete list")
                end
            end)
            
            widget:Show()
            widget.autoDeleteItem = autoDeleteItem
        end
    end
    
    IM_AutoDeleteListFrame.scroll:UpdateScrollChildRect()
end

function IM:UpdateMainFrame(suggestions, totalSlots, usedSlots)
    if not IM_MainFrame then return end
    self:ClearFrameContent(IM_MainFrame.deleteContent, "IM_DeleteItem_")
    local playerName = UnitName("player")
    IM_MainFrame.title:SetText(string.format("Inventory Manager - %s - %d/%d Slots - %d Suggestions", 
      playerName, usedSlots, totalSlots, #suggestions))
    
    -- Calculate total slots that would be freed and total value
    local totalSlotsFreed = 0
    local totalValue = 0
    
    for _, suggestion in ipairs(suggestions) do
		totalValue = totalValue + (suggestion.stackValue or 0)
		-- Count each unique bag/slot location as one slot
		if suggestion.locations then
			for _, location in ipairs(suggestion.locations) do
				if location and location.bag and location.slot then
					totalSlotsFreed = totalSlotsFreed + 1
				end
			end
		end
	end
    
    -- Update summary text
    local totalCopper = math.floor(totalValue * 10000 + 0.5)
    local valueText = self:FormatMoneyWithIcons(totalCopper)
    IM_MainFrame.slotsFreedText:SetText(string.format("Slots freed: %d", totalSlotsFreed))
    IM_MainFrame.valueText:SetText(string.format("Value: %s", valueText))
    
    -- Calculate content height based on number of suggestions
    local contentHeight = math.max(IM_MainFrame.deleteScroll:GetHeight(), #suggestions * 45 + 10)
    IM_MainFrame.deleteContent:SetHeight(contentHeight)
    IM_MainFrame.deleteContent:SetWidth(IM_MainFrame.deleteScroll:GetWidth() - 20)
    
    for i, suggestion in ipairs(suggestions) do
        self:CreateDeleteSuggestionWidget(suggestion, i)
    end
    IM_MainFrame.deleteScroll:UpdateScrollChildRect()
    
    -- Update Delete All button visibility
    if IM_MainFrame.deleteAllBtn and IM_MainFrame.deleteAllBtn.SetShown then
        IM_MainFrame.deleteAllBtn:SetShown(#suggestions > 0)
    end
end

function IM:UpdateSellListFrame()
    if not IM_SellListFrame then return end
    
    self:ClearFrameContent(IM_SellListFrame.content, "IM_SellListItem_")
    
    local totalValue = 0
    local itemsInInventory = 0
    local contentHeight = math.max(400, #self.vendorList * 45 + 10)
    IM_SellListFrame.content:SetHeight(contentHeight)
    
    for i, vendorItem in ipairs(self.vendorList) do
        local widget = _G["IM_SellListItem_"..i] or CreateFrame("Button", "IM_SellListItem_"..i, IM_SellListFrame.content)
        widget:SetSize(350, 40)
        
        if not widget.initialized then
            widget:SetPoint("TOPLEFT", 5, -(i-1)*45)
            widget.bg = widget:CreateTexture(nil, "BACKGROUND")
            widget.bg:SetAllPoints(true)
            widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            widget.icon = widget:CreateTexture(nil, "ARTWORK")
            widget.icon:SetSize(30, 30)
            widget.icon:SetPoint("LEFT", 5, 0)
            widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            widget.name = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            widget.name:SetPoint("TOPLEFT", 40, -5)
            widget.name:SetSize(200, 20)
            widget.name:SetJustifyH("LEFT")
            widget.value = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            widget.value:SetPoint("BOTTOMLEFT", 40, 5)
            widget.value:SetSize(150, 20)
            widget.value:SetJustifyH("LEFT")
            widget.value:SetTextColor(1, 1, 0)
            
            -- Add status text
            widget.status = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.status:SetPoint("TOPLEFT", 40, -20)
            widget.status:SetSize(200, 20)
            widget.status:SetJustifyH("LEFT")
            widget.status:SetTextColor(1, 0.5, 0.5) -- Reddish color for warnings
            
            widget.removeBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
            widget.removeBtn:SetSize(60, 20)
            widget.removeBtn:SetPoint("RIGHT", -5, 0)
            widget.removeBtn:SetText("Remove")
            widget.initialized = true
        end
        
        local texture = GetItemIcon(vendorItem.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
        widget.icon:SetTexture(texture)
        local qualityColor = self.qualityColors[vendorItem.quality] or "|cFFFFFFFF"
        
        -- Check if item is CURRENTLY in inventory (using refreshed data)
        local inInventory = vendorItem.totalCount > 0
        if inInventory then
            itemsInInventory = itemsInInventory + 1
        end
        local countText = inInventory and string.format("(|cFFFFFFFFx%d|r)", vendorItem.totalCount) or ""
        
        widget.name:SetText(qualityColor .. (vendorItem.displayName or vendorItem.name) .. "|r " .. countText)
        
        -- Set status and appearance based on current inventory presence
        if inInventory then
            widget.status:SetText("") -- Clear status
            local totalCopper = math.floor(vendorItem.stackValue * 10000 + 0.5)
            local valueText = self:FormatMoneyWithIcons(totalCopper)
            widget.value:SetText("|cFFFFFF00" .. valueText .. "|r")
            totalValue = totalValue + vendorItem.stackValue
            widget.icon:SetAlpha(1.0) -- Full opacity
            widget.name:SetAlpha(1.0)
            widget.value:SetAlpha(1.0)
        else
            widget.status:SetText("|cFFFF0000Not in inventory|r")
            widget.value:SetText("|cFF8080800g 0s 0c|r")
            widget.icon:SetAlpha(0.4) -- Semi-transparent
            widget.name:SetAlpha(0.6)
            widget.value:SetAlpha(0.6)
        end
        
        -- Set background color based on inventory presence
        if inInventory then
            if vendorItem.quality and self.qualityColors[vendorItem.quality] then
                local color = self.qualityColors[vendorItem.quality]
                local hex = color:sub(3)
                local r = tonumber(hex:sub(1, 2), 16) / 255
                local g = tonumber(hex:sub(3, 4), 16) / 255
                local b = tonumber(hex:sub(5, 6), 16) / 255
                widget.bg:SetTexture(r * 0.1, g * 0.1, b * 0.1, 0.3)
            else
                widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            end
        else
            -- Grey background for items not in inventory
            widget.bg:SetTexture(0.3, 0.3, 0.3, 0.3)
        end
        
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if vendorItem.link then
                GameTooltip:SetHyperlink(vendorItem.link)
            else
                GameTooltip:SetText(vendorItem.name)
            end
            local totalCopper = vendorItem.stackValue * 10000
            local valueText = IM:FormatMoneyWithIcons(totalCopper)
            GameTooltip:AddLine("Total Value: " .. valueText, 1, 1, 1)
            if vendorItem.totalCount > 1 then
                local perItemCopper = (vendorItem.sellPrice or 0)
                local perItemText = IM:FormatMoneyWithIcons(perItemCopper)
                GameTooltip:AddLine("Per Item: " .. perItemText, 0.8, 0.8, 0.8)
            end
            if vendorItem.totalCount == 0 then
                GameTooltip:AddLine("|cFFFF0000Item not currently in inventory|r", 1, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        widget.removeBtn:SetScript("OnClick", function()
            IM:RemoveFromVendorList(vendorItem.itemID)
        end)
        
        widget:Show()
        widget.vendorItem = vendorItem
    end
    
    -- Update total value and title to show current state
    local totalCopper = math.floor(totalValue * 10000 + 0.5)
    local formattedValue = self:FormatMoneyWithIcons(totalCopper)
    IM_SellListFrame.totalValue:SetText(string.format("Total Value: %s (%d/%d items in inventory)", 
        formattedValue, itemsInInventory, #self.vendorList))
    
    IM_SellListFrame.scroll:UpdateScrollChildRect()
end

function IM:UpdateIgnoredListFrame()
    if not IM_IgnoredListFrame then return end
    
    self:ClearFrameContent(IM_IgnoredListFrame.content, "IM_IgnoredItem_")
    
    self.ignoredItems = self.ignoredItems or {}
    local contentHeight = math.max(400, #self.ignoredItems * 45 + 10)
    IM_IgnoredListFrame.content:SetHeight(contentHeight)
    
    for i, ignoredItem in ipairs(self.ignoredItems) do
        local widget = _G["IM_IgnoredItem_"..i] or CreateFrame("Button", "IM_IgnoredItem_"..i, IM_IgnoredListFrame.content)
        widget:SetSize(350, 40)
        
        if not widget.initialized then
            widget:SetPoint("TOPLEFT", 5, -(i-1)*45)
            widget.bg = widget:CreateTexture(nil, "BACKGROUND")
            widget.bg:SetAllPoints(true)
            widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            widget.icon = widget:CreateTexture(nil, "ARTWORK")
            widget.icon:SetSize(30, 30)
            widget.icon:SetPoint("LEFT", 5, 0)
            widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            widget.name = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            widget.name:SetPoint("TOPLEFT", 40, -5)
            widget.name:SetSize(200, 20)
            widget.name:SetJustifyH("LEFT")
            widget.reason = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.reason:SetPoint("BOTTOMLEFT", 40, 5)
            widget.reason:SetSize(200, 20)
            widget.reason:SetJustifyH("LEFT")
            widget.removeBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
            widget.removeBtn:SetSize(60, 20)
            widget.removeBtn:SetPoint("RIGHT", -5, 0)
            widget.removeBtn:SetText("Remove")
            widget.initialized = true
        end
        
        local texture = GetItemIcon(ignoredItem.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
        widget.icon:SetTexture(texture)
        local qualityColor = self.qualityColors[ignoredItem.quality] or "|cFFFFFFFF"
        local countText = ignoredItem.totalCount > 1 and string.format("(|cFFFFFFFFx%d|r)", ignoredItem.totalCount) or ""
        widget.name:SetText(qualityColor .. (ignoredItem.displayName or ignoredItem.name) .. "|r " .. countText)
        widget.reason:SetText(ignoredItem.reason or "Manually ignored")
        
        if ignoredItem.quality and self.qualityColors[ignoredItem.quality] then
            local color = self.qualityColors[ignoredItem.quality]
            local hex = color:sub(3)
            local r = tonumber(hex:sub(1, 2), 16) / 255
            local g = tonumber(hex:sub(3, 4), 16) / 255
            local b = tonumber(hex:sub(5, 6), 16) / 255
            widget.bg:SetTexture(r * 0.1, g * 0.1, b * 0.1, 0.3)
        else
            widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
        end
        
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if ignoredItem.link then
                GameTooltip:SetHyperlink(ignoredItem.link)
            else
                GameTooltip:SetText(ignoredItem.name)
            end
            GameTooltip:AddLine("Reason: " .. (ignoredItem.reason or "Manually ignored"), 1, 1, 1)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        widget.removeBtn:SetScript("OnClick", function()
            IM:RemoveFromIgnoredList(ignoredItem.itemID)
        end)
        
        widget:Show()
        widget.ignoredItem = ignoredItem
    end
    
    IM_IgnoredListFrame.scroll:UpdateScrollChildRect()
end

-- Utility functions for frame management
function IM:ClearFrameContent(frame, prefix)
    for i = 1, 100 do  -- Increased from 50 to be safe
        local child = _G[prefix..i]
        if child then
            child:Hide()
            -- Optional: Clear scripts to prevent memory leaks
            child:SetScript("OnClick", nil)
            child:SetScript("OnEnter", nil)
            child:SetScript("OnLeave", nil)
        else
            -- Stop when we run out of widgets
            break
        end
    end
end

function IM:CreateDeleteSuggestionWidget(suggestion, index)
    if not suggestion or not suggestion.itemID then
        print("Inventory Manager: Cannot create widget for invalid suggestion")
        return
    end
    
    local parent = IM_MainFrame.deleteContent
    local widget = _G["IM_DeleteItem_"..index] or CreateFrame("Button", "IM_DeleteItem_"..index, parent)
    widget:SetSize(450, 40)
    
    if not widget.initialized then
        widget:SetPoint("TOPLEFT", 0, -(index-1)*45)
        widget.bg = widget:CreateTexture(nil, "BACKGROUND")
        widget.bg:SetAllPoints(true)
        widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
        widget.icon = widget:CreateTexture(nil, "ARTWORK")
        widget.icon:SetSize(25, 25)
        widget.icon:SetPoint("LEFT", 5, 0)
        widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        widget.name = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        widget.name:SetPoint("TOPLEFT", 40, -5)
        widget.name:SetSize(350, 20)
        widget.name:SetJustifyH("LEFT")
        widget.value = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        widget.value:SetPoint("BOTTOMLEFT", 40, 5)
        widget.value:SetSize(150, 20)
        widget.value:SetJustifyH("LEFT")
        widget.reason = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        widget.reason:SetPoint("BOTTOMLEFT", 40, -5)
        widget.reason:SetSize(350, 20)
        widget.reason:SetJustifyH("LEFT")
        
        -- Action buttons
        widget.vendorBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
        widget.vendorBtn:SetSize(30, 20)
        widget.vendorBtn:SetPoint("RIGHT", -5, 0)
        widget.vendorBtn:SetText("Sell")
        
        widget.deleteBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
        widget.deleteBtn:SetSize(45, 20)
        widget.deleteBtn:SetPoint("RIGHT", widget.vendorBtn, "LEFT", 0, 0)
        widget.deleteBtn:SetText("Delete")
        
        widget.ignoreBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
        widget.ignoreBtn:SetSize(45, 20)
        widget.ignoreBtn:SetPoint("RIGHT", widget.deleteBtn, "LEFT", 0, 0)
        widget.ignoreBtn:SetText("Ignore")
        
        widget.autoDeleteBtn = CreateFrame("Button", nil, widget, "UIPanelButtonTemplate")
        widget.autoDeleteBtn:SetSize(35, 20)
        widget.autoDeleteBtn:SetPoint("RIGHT", widget.ignoreBtn, "LEFT", 0, 0)
        widget.autoDeleteBtn:SetText("Auto")
        
        widget.initialized = true
    end
    
    -- Safe field access with fallbacks
    local texture = GetItemIcon(suggestion.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
    widget.icon:SetTexture(texture)
    
    local qualityColor = self.qualityColors[suggestion.quality or 1] or "|cFFFFFFFF"
    local countText = (suggestion.totalCount or 1) > 1 and string.format("(|cFFFFFFFFx%d|r)", suggestion.totalCount) or ""
    local displayName = suggestion.displayName or suggestion.name or "Unknown Item"
    widget.name:SetText(qualityColor .. displayName .. "|r " .. countText)
    
    local totalCopper = math.floor((suggestion.stackValue or 0) * 10000 + 0.5)
    local valueText = self:FormatMoneyWithIcons(totalCopper)
    widget.value:SetText("|cFFFFFF00" .. valueText .. "|r")
    widget.reason:SetText(suggestion.reason or "Unknown reason")
    
    -- Safe quality color application
    if suggestion.quality and self.qualityColors[suggestion.quality] then
        local color = self.qualityColors[suggestion.quality]
        local hex = color:sub(3)
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        widget.bg:SetTexture(r * 0.1, g * 0.1, b * 0.1, 0.3)
    else
        widget.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
    end
    
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if suggestion.link then
            GameTooltip:SetHyperlink(suggestion.link)
        else
            GameTooltip:SetText(displayName)
        end
        GameTooltip:AddLine("Reason: " .. (suggestion.reason or "Unknown reason"), 1, 1, 1)
        local totalCopper = (suggestion.stackValue or 0) * 10000
        local valueText = IM:FormatMoneyWithIcons(totalCopper)
        GameTooltip:AddLine("Total Value: " .. valueText, 1, 1, 1)
        if (suggestion.totalCount or 1) > 1 then
            local perItemCopper = (suggestion.sellPrice or 0)
            local perItemText = IM:FormatMoneyWithIcons(perItemCopper)
            GameTooltip:AddLine("Per Item: " .. perItemText, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Button handlers with safety checks (you already have these)
    widget.vendorBtn:SetScript("OnClick", function()
        if suggestion and suggestion.itemID then
            IM:AddToVendorList(suggestion)
            IM:RefreshUI()
        else
            print("Inventory Manager: Cannot add invalid item to vendor list")
        end
    end)
    
    widget.deleteBtn:SetScript("OnClick", function()
        if suggestion and suggestion.itemID then
            IM:ConfirmDeleteSuggestion(suggestion)
        else
            print("Inventory Manager: Cannot delete invalid item")
        end
    end)
    
    widget.ignoreBtn:SetScript("OnClick", function()
        if suggestion and suggestion.itemID then
            IM:AddToIgnoredList(suggestion)
            IM:RefreshUI()
        else
            print("Inventory Manager: Cannot ignore invalid item")
        end
    end)
    
    widget.autoDeleteBtn:SetScript("OnClick", function()
        if suggestion and suggestion.itemID then
            IM:AddToAutoDeleteList(suggestion)
            IM:RefreshUI()
        else
            print("Inventory Manager: Cannot auto-delete invalid item")
        end
    end)
    
    widget:Show()
    widget.suggestion = suggestion
end