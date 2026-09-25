local addonName, IM = ...

local function SetTextTooltip(frame, title, description)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if description then
            GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

if not IM.StyleFrame then
    IM.StyleFrame = function(self, frame, width, height, titleText)
        frame:SetSize(width, height)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        -- Solid dark background to prevent text bleed-through
        frame:SetBackdropColor(0.08, 0.08, 0.1, 0.98)
    end
end

---------------------------------------------------------
-- Helper: Anchor Secondary Frames & Bring to Front
---------------------------------------------------------
function IM:AnchorAndShowFrame(frame)
    -- Hide other open sub-list frames so they don't stack in the exact same spot
    local subFrames = { IM_SellListFrame, IM_IgnoredListFrame, IM_AutoListFrame, IM_SimpleSettingsFrame }
    for _, sub in ipairs(subFrames) do
        if sub and sub ~= frame and sub:IsShown() then
            sub:Hide()
        end
    end

    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)

    -- Boost frame level above main frame
    if IM_MainFrame and IM_MainFrame:IsShown() then
        frame:SetFrameLevel(IM_MainFrame:GetFrameLevel() + 5)
    end
    
    frame:SetScript("OnMouseDown", function(self)
        self:Raise()
    end)

    frame:ClearAllPoints()

    -- Dock to right side of Main Frame if open
    if IM_MainFrame and IM_MainFrame:IsShown() and frame ~= IM_MainFrame then
        frame:SetPoint("TOPLEFT", IM_MainFrame, "TOPRIGHT", 12, 0)
    elseif self.RestoreFramePosition then
        self:RestoreFramePosition(frame, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    frame:Show()
    frame:Raise()
end

---------------------------------------------------------
-- Free-Floating Draggable Icon
---------------------------------------------------------
function IM:CreateToggleIcon()
    if IM_ToggleIcon then return IM_ToggleIcon end

    local icon = CreateFrame("Button", "IM_ToggleIcon", UIParent)
    icon:SetSize(32, 32)
    icon:SetFrameStrata("HIGH")
    icon:SetFrameLevel(10)
    icon:EnableMouse(true)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)

    icon:RegisterForClicks("AnyUp")
    icon:RegisterForDrag("LeftButton")

    -- Background frame / Border
    local bg = icon:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    -- Icon Texture
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
    tex:SetSize(24, 24)
    tex:SetPoint("CENTER", 0, 0)
    icon.tex = tex

    -- Saved position restoration
    IM:InitDB()
    IM.db.iconPoint = IM.db.iconPoint or "CENTER"
    IM.db.iconX = IM.db.iconX or 0
    IM.db.iconY = IM.db.iconY or 0

    icon:ClearAllPoints()
    icon:SetPoint(IM.db.iconPoint, UIParent, IM.db.iconPoint, IM.db.iconX, IM.db.iconY)

    -- Free Movement Handlers
    icon:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        IM.db.iconPoint = point
        IM.db.iconX = x
        IM.db.iconY = y
        if IM.SaveConfig then IM:SaveConfig() end
    end)

    icon:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if IM_SimpleSettingsFrame and IM_SimpleSettingsFrame:IsShown() then
                IM_SimpleSettingsFrame:Hide()
            else
                IM:ShowSimpleSettings()
            end
        else
            if IM_MainFrame and IM_MainFrame:IsShown() then
                IM_MainFrame:Hide()
            else
                IM:CreateFrames()
                IM:ShowSuggestions()
            end
        end
    end)

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Inventory Manager", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFFFFFLeft-Click:|r Toggle Suggestion Window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFFFFRight-Click:|r Quick Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFFFFLeft-Drag:|r Move Icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    IM_ToggleIcon = icon
    return icon
end

function IM:UpdateToggleIcon()
    if IM_ToggleIcon and IM_ToggleIcon.tex then
        IM_ToggleIcon.tex:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
    end
end

---------------------------------------------------------
-- Quick Settings Popup
---------------------------------------------------------
function IM:CreateSimpleSettingsFrame()
    if IM_SimpleSettingsFrame then return IM_SimpleSettingsFrame end

    local frame = CreateFrame("Frame", "IM_SimpleSettingsFrame", UIParent)
    IM:StyleFrame(frame, 250, 220, "Quick Settings")

    IM:InitDB()

    -- Enable Addon
    local enableCB = CreateFrame("CheckButton", "IM_SimpleEnableCB", frame, "OptionsCheckButtonTemplate")
    enableCB:SetPoint("TOPLEFT", 15, -30)
    _G[enableCB:GetName().."Text"]:SetText("Enable Addon")
    enableCB:SetChecked(IM.db.enabled)
    enableCB:SetScript("OnClick", function(s)
        IM.db.enabled = s:GetChecked() and true or false
        if IM.SaveConfig then IM:SaveConfig() end
        if IM.RefreshUI then IM:RefreshUI() end
    end)

    -- Auto-sell Trash
    local autoSellCB = CreateFrame("CheckButton", "IM_SimpleAutoSellCB", frame, "OptionsCheckButtonTemplate")
    autoSellCB:SetPoint("TOPLEFT", 15, -58)
    _G[autoSellCB:GetName().."Text"]:SetText("Auto-sell Trash")
    autoSellCB:SetChecked(IM.db.autoSellAtVendor)
    autoSellCB:SetScript("OnClick", function(s)
        IM.db.autoSellAtVendor = s:GetChecked() and true or false
        if IM.SaveConfig then IM:SaveConfig() end
    end)

    -- Auto-open Low Bag Space Checkbox
    local autoOpenCB = CreateFrame("CheckButton", "IM_SimpleAutoOpenCB", frame, "OptionsCheckButtonTemplate")
    autoOpenCB:SetPoint("TOPLEFT", 15, -86)
    _G[autoOpenCB:GetName().."Text"]:SetText("Auto-open Low Bag Space")
    autoOpenCB:SetChecked(IM.db.autoOpenOnLowSpace)

    -- Free Slot Threshold Slider (unified to freeSlotsThreshold)
    IM.db.freeSlotsThreshold = IM.db.freeSlotsThreshold or 1

    local thresholdSlider = CreateFrame("Slider", "IM_LowSpaceThresholdSlider", frame, "OptionsSliderTemplate")
    thresholdSlider:SetPoint("TOPLEFT", 25, -130)
    thresholdSlider:SetSize(190, 16)
    thresholdSlider:SetMinMaxValues(0, 10)
    thresholdSlider:SetValueStep(1)
    thresholdSlider:SetValue(IM.db.freeSlotsThreshold)
    
    _G[thresholdSlider:GetName().."Text"]:SetText("Trigger at: " .. IM.db.freeSlotsThreshold .. " free slots")
    _G[thresholdSlider:GetName().."Low"]:SetText("0")
    _G[thresholdSlider:GetName().."High"]:SetText("10")

    local function ToggleSliderState(enabled)
        if enabled then
            thresholdSlider:Enable()
            _G[thresholdSlider:GetName().."Text"]:SetTextColor(1, 0.82, 0)
        else
            thresholdSlider:Disable()
            _G[thresholdSlider:GetName().."Text"]:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    autoOpenCB:SetScript("OnClick", function(s)
        IM.db.autoOpenOnLowSpace = s:GetChecked() and true or false
        ToggleSliderState(IM.db.autoOpenOnLowSpace)
        if IM.SaveConfig then IM:SaveConfig() end
    end)

    thresholdSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        IM.db.freeSlotsThreshold = val
        _G[self:GetName().."Text"]:SetText("Trigger at: " .. val .. " free slots")
        if IM.SaveConfig then IM:SaveConfig() end
    end)

    ToggleSliderState(IM.db.autoOpenOnLowSpace)

    -- Full Config Button
    local configBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    configBtn:SetSize(110, 22)
    configBtn:SetPoint("BOTTOM", 0, 12)
    configBtn:SetText("All Options")
    configBtn:SetScript("OnClick", function()
        frame:Hide()
        if IM.ShowConfigFrame then IM:ShowConfigFrame() end
    end)

    frame:Hide()
    IM_SimpleSettingsFrame = frame
    return frame
end

function IM:ShowSimpleSettings()
    local frame = self:CreateSimpleSettingsFrame()
    self:AnchorAndShowFrame(frame)
end

---------------------------------------------------------
-- Core Main Frame & Suggestion List
---------------------------------------------------------
function IM:CreateFrames()
    if IM_MainFrame then return end

    local frame = CreateFrame("Frame", "IM_MainFrame", UIParent)
    IM:StyleFrame(frame, 520, 480, "Inventory Manager — Recommendations")

    -- Bag Summary Header
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 12, -32)

    -- Scroll Area
    frame.scroll = CreateFrame("ScrollFrame", "IM_MainScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -50)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 45)

    frame.scrollChild = CreateFrame("Frame", "IM_MainScrollChild")
    frame.scrollChild:SetSize(370, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    ---------------------------------------------------------
    -- Bottom Action Bar Buttons
    ---------------------------------------------------------

    -- 1. DELETE ALL
    local deleteAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deleteAllBtn:SetSize(80, 22)
    deleteAllBtn:SetPoint("BOTTOMLEFT", 40, 12)
    deleteAllBtn:SetText("Delete All")
    deleteAllBtn:SetScript("OnClick", function() IM:ConfirmDeleteAll() end)
    SetTextTooltip(deleteAllBtn, "Delete All Flagged", "Permanently deletes all recommended items currently showing in the list.")

    -- 2. RESCAN
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(65, 22)
    refreshBtn:SetPoint("LEFT", deleteAllBtn, "RIGHT", 5, 0)
    refreshBtn:SetText("Rescan")
    refreshBtn:SetScript("OnClick", function() IM:ShowSuggestions() end)
    SetTextTooltip(refreshBtn, "Rescan Bags", "Re-scans your inventory to update suggestions.")

    -- 3. SELL LIST
    local sellListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sellListBtn:SetSize(75, 22)
    sellListBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 5, 0)
    sellListBtn:SetText("Sell List")
    sellListBtn:SetScript("OnClick", function()
        if IM_SellListFrame and IM_SellListFrame:IsShown() then
            IM_SellListFrame:Hide()
        elseif IM.ShowSellListFrame then
            IM:ShowSellListFrame()
        end
    end)
    SetTextTooltip(sellListBtn, "View Sell List", "Opens the vendor sell queue frame to view and manage items queued for sale.")

    -- 4. IGNORE LIST
    local ignoreListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ignoreListBtn:SetSize(80, 22)
    ignoreListBtn:SetPoint("LEFT", sellListBtn, "RIGHT", 5, 0)
    ignoreListBtn:SetText("Ignore List")
    ignoreListBtn:SetScript("OnClick", function()
        if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
            IM_IgnoredListFrame:Hide()
        else
            IM:ShowIgnoredListFrame()
        end
    end)
    SetTextTooltip(ignoreListBtn, "View Ignore List", "Opens the Ignore List frame to view or un-ignore saved items.")

    -- 5. AUTO LIST
    local autoListBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    autoListBtn:SetSize(75, 22)
    autoListBtn:SetPoint("LEFT", ignoreListBtn, "RIGHT", 5, 0)
    autoListBtn:SetText("Auto List")
    autoListBtn:SetScript("OnClick", function()
        if IM_AutoListFrame and IM_AutoListFrame:IsShown() then
            IM_AutoListFrame:Hide()
        else
            IM:ShowAutoListFrame()
        end
    end)
    SetTextTooltip(autoListBtn, "View Auto List", "Opens the Auto-Action List frame to view items configured for automatic deletion or selling.")

    IM_MainFrame = frame
end

function IM:ShowSuggestions()
    if not IM_MainFrame then IM:CreateFrames() end
	
	if IM_ConfigFrame and IM_ConfigFrame:IsShown() then
		IM_ConfigFrame:Hide()
	end

    local suggestions, totalSlots, usedSlots = IM:ScanInventory()
    local freeSlots = (totalSlots or 0) - (usedSlots or 0)
    
    IM_MainFrame.summary:SetText(string.format("Free Slots: %d / %d  |  Flagged Items: %d", freeSlots, totalSlots or 0, suggestions and #suggestions or 0))

    -- Clean old content rows
    local child = IM_MainFrame.scrollChild
    for _, childFrame in ipairs({child:GetChildren()}) do
        childFrame:Hide()
        childFrame:SetParent(nil)
    end

    if suggestions then
        local rowHeight = 36
        for i, item in ipairs(suggestions) do
            local row = CreateFrame("Frame", nil, child)
            row:SetSize(360, rowHeight)
            row:SetPoint("TOPLEFT", 0, -((i - 1) * (rowHeight + 2)))

            -- Row Background
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.12, 0.12, 0.15, 0.6)

            ---------------------------------------------------------
            -- 1. ITEM ICON (With WoW Item Tooltip)
            ---------------------------------------------------------
            local iconBtn = CreateFrame("Button", nil, row)
            iconBtn:SetSize(28, 28)
            iconBtn:SetPoint("LEFT", 2, 0)

            local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints(true)
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(item.itemID or item.link or 0)
            iconTex:SetTexture(item.texture or itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if item.bag and item.slot then
                    GameTooltip:SetBagItem(item.bag, item.slot)
                elseif item.link then
                    GameTooltip:SetHyperlink(item.link)
                elseif item.itemID then
                    GameTooltip:SetItemByID(item.itemID)
                end
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            ---------------------------------------------------------
            -- 2. ITEM NAME (With WoW Item Tooltip)
            ---------------------------------------------------------
            local titleBtn = CreateFrame("Button", nil, row)
            titleBtn:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 6, -2)
            titleBtn:SetSize(270, 14)

            local title = titleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetAllPoints(true)
            title:SetJustifyH("LEFT")
			local totalCopper = math.floor((item.sellPrice or 0) * (item.totalCount or 1) + 0.5)
            local qColor = (IM.qualityColors and IM.qualityColors[item.quality]) or "|cFFFFFFFF"
			
			if totalCopper > 0 then
				title:SetText(qColor .. (item.displayName or item.name or "Unknown") .. "|r x" .. (item.totalCount or 1) .. "|cFFFFFFFF  [" .. (IM:FormatMoneyWithIcons(totalCopper)) .. "]|r")
			else
				title:SetText(qColor .. (item.displayName or item.name or "Unknown") .. "|r x" .. (item.totalCount or 1) .. "|cFF808080 [No Value]|r")
			end

            titleBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if item.bag and item.slot then
                    GameTooltip:SetBagItem(item.bag, item.slot)
                elseif item.link then
                    GameTooltip:SetHyperlink(item.link)
                elseif item.itemID then
                    GameTooltip:SetItemByID(item.itemID)
                end
                GameTooltip:Show()
            end)
            titleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
			
            ---------------------------------------------------------
            -- 3. RECOMMENDATION REASON (With Subtext Tooltip)
            ---------------------------------------------------------
            local reasonFrame = CreateFrame("Frame", nil, row)
            reasonFrame:SetPoint("BOTTOMLEFT", iconBtn, "BOTTOMRIGHT", 6, 2)
            reasonFrame:SetSize(150, 12)

            local reason = reasonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            reason:SetAllPoints(true)
            reason:SetJustifyH("LEFT")
            reason:SetText("|cFF808080" .. (item.reason or "Low value item") .. "|r")

            SetTextTooltip(reasonFrame, "Recommendation Reason", item.reasonDetails or item.reason or "Flagged based on value, quality, or usage filters.")
			
			
            ---------------------------------------------------------
            -- 4. ACTION BUTTONS (Delete, Ignore, Auto, Sell)
            ---------------------------------------------------------
            -- DELETE BUTTON
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(42, 20)
            delBtn:SetPoint("RIGHT", 120, 0)
            delBtn:SetText("Delete")
            delBtn:SetScript("OnClick", function()
                IM:ConfirmDeleteSuggestion(item)
            end)
            SetTextTooltip(delBtn, "Delete Item", "Permanently destroys this item from your bags.")

            -- IGNORE BUTTON
            local ignBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            ignBtn:SetSize(42, 20)
            ignBtn:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
            ignBtn:SetText("Ignore")
            ignBtn:SetScript("OnClick", function()
                IM:AddToIgnoredList(item)
                IM:ShowSuggestions()
            end)
            SetTextTooltip(ignBtn, "Ignore Item", "Adds this item to your Ignore List so it won't be suggested again.")

            -- AUTO BUTTON
            local autoBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            autoBtn:SetSize(38, 20)
            autoBtn:SetPoint("RIGHT", ignBtn, "LEFT", -2, 0)
            autoBtn:SetText("Auto")
            autoBtn:SetScript("OnClick", function()
                IM:AddToAutoDeleteList(item)
                IM:ShowSuggestions()
            end)
            SetTextTooltip(autoBtn, "Auto Delete", "Marks this item type to be automatically deleted in future scans.")

            -- SELL BUTTON
            local sellBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            sellBtn:SetSize(38, 20)
            sellBtn:SetPoint("RIGHT", autoBtn, "LEFT", -2, 0)
            sellBtn:SetText("Sell")
            sellBtn:SetScript("OnClick", function()
                IM:AddToVendorList(item)
                IM:ShowSuggestions()
            end)
            SetTextTooltip(sellBtn, "Queue for Sale", "Adds this item to your vendor sell queue when visiting a merchant.")

        end

        child:SetHeight(#suggestions * (rowHeight + 2))
    end

    if IM.RestoreFramePosition then
        IM:RestoreFramePosition(IM_MainFrame, "CENTER", 0, 0)
    else
        IM_MainFrame:ClearAllPoints()
        IM_MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    IM_MainFrame:Show()
	IM_MainFrame:Raise()
end

---------------------------------------------------------
-- Vendor Sell List Frame
---------------------------------------------------------
function IM:CreateSellListFrame()
    if IM_SellListFrame then return IM_SellListFrame end

    local frame = CreateFrame("Frame", "IM_SellListFrame", UIParent)
    IM:StyleFrame(frame, 380, 420, "Inventory Manager — Vendor Sell List")

    -- Summary Header
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 12, -32)

    -- Scroll Area
    frame.scroll = CreateFrame("ScrollFrame", "IM_SellListScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -50)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 45)

    frame.scrollChild = CreateFrame("Frame", "IM_SellListScrollChild")
    frame.scrollChild:SetSize(330, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    -- Action Bar Bottom: Sell All Button
    local sellAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sellAllBtn:SetSize(120, 22)
    sellAllBtn:SetPoint("BOTTOMLEFT", 10, 12)
    sellAllBtn:SetText("Sell All Listed")
    sellAllBtn:SetScript("OnClick", function() IM:SellVendorItems() end)
    SetTextTooltip(sellAllBtn, "Sell All Listed", "Sells all queued items to the currently open vendor.")
    frame.sellAllBtn = sellAllBtn

    -- Action Bar Bottom: Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Dynamic event updates when vendor opens/closes
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" and self:IsShown() then
            IM:UpdateSellListFrame()
        end
    end)

    IM_SellListFrame = frame
    return frame
end

---------------------------------------------------------
-- Update Vendor Sell List Frame
---------------------------------------------------------
function IM:UpdateSellListFrame(filterMode)
    if not IM_SellListFrame then return end

    if MerchantFrame and MerchantFrame:IsShown() then
        IM_SellListFrame.sellAllBtn:Show()
    else
        IM_SellListFrame.sellAllBtn:Hide()
    end

    local child = IM_SellListFrame.scrollChild
    for _, childFrame in ipairs({child:GetChildren()}) do
        childFrame:Hide()
        childFrame:SetParent(nil)
    end

    local totalValue = 0
    local rowHeight = 32
    local count = 0
    IM:InitDB()

    for itemID, item in pairs(IM.db.vendorList) do
        count = count + 1
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(320, rowHeight)
        row:SetPoint("TOPLEFT", 0, -((count - 1) * (rowHeight + 2)))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.12, 0.12, 0.15, 0.6)

        -- Make title a Button to support OnEnter/OnLeave tooltips natively
        local titleBtn = CreateFrame("Button", nil, row)
        titleBtn:SetPoint("TOPLEFT", 6, -4)
        titleBtn:SetSize(220, 14)

        local title = titleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetAllPoints(true)
        title:SetJustifyH("LEFT")
        
        local qColor = (IM.qualityColors and IM.qualityColors[item.quality]) or "|cFFFFFFFF"
        title:SetText(qColor .. (item.name or "Unknown") .. "|r x" .. (item.totalCount or 1))

        -- Tooltip script handlers for the item name
        titleBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if item.bag and item.slot then
                GameTooltip:SetBagItem(item.bag, item.slot)
            elseif item.link then
                GameTooltip:SetHyperlink(item.link)
            elseif item.itemID then
                GameTooltip:SetItemByID(item.itemID)
            end
            GameTooltip:Show()
        end)
        titleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMLEFT", 6, 4)
        
        -- Use cached stackValue/sellPrice if available, otherwise compute from itemID
        local unitSellPrice = item.sellPrice or 0
        if unitSellPrice == 0 and item.itemID then
            _, _, _, _, _, _, _, _, _, _, unitSellPrice = GetItemInfo(item.itemID)
            unitSellPrice = unitSellPrice or 0
        end
        
        local currentStackVal = item.stackValue or ((unitSellPrice * (item.totalCount or 1)) / 10000)
        totalValue = totalValue + currentStackVal

        local copper = math.floor(currentStackVal * 10000 + 0.5)
        local formattedMoney = IM.FormatMoneyWithIcons and IM:FormatMoneyWithIcons(copper) or (copper .. "c")
        valueText:SetText(formattedMoney)

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 18)
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function()
            IM:RemoveFromVendorList(itemID)
            IM:UpdateSellListFrame()
        end)
        SetTextTooltip(removeBtn, "Remove Item", "Removes this item from the sell queue.")
    end

    local totalCopper = math.floor(totalValue * 10000 + 0.5)
    local formattedTotal = IM.FormatMoneyWithIcons and IM:FormatMoneyWithIcons(totalCopper) or (totalCopper .. "c")
    IM_SellListFrame.summary:SetText("Items queued: " .. count .. " | Total Value: " .. formattedTotal)
    child:SetHeight(math.max(1, count * (rowHeight + 2)))
end

function IM:ShowSellListFrame()
    local frame = self:CreateSellListFrame()
    self:UpdateSellListFrame()
    self:AnchorAndShowFrame(frame)
end

---------------------------------------------------------
-- Ignored List Frame
---------------------------------------------------------
function IM:CreateIgnoredListFrame()
    if IM_IgnoredListFrame then return IM_IgnoredListFrame end

    local frame = CreateFrame("Frame", "IM_IgnoredListFrame", UIParent)
    IM:StyleFrame(frame, 380, 420, "Inventory Manager — Ignored List")

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 12, -32)

    frame.scroll = CreateFrame("ScrollFrame", "IM_IgnoredListScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -50)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 45)

    frame.scrollChild = CreateFrame("Frame", "IM_IgnoredListScrollChild")
    frame.scrollChild:SetSize(330, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    IM_IgnoredListFrame = frame
    return frame
end

---------------------------------------------------------
-- Update Ignored List Frame
---------------------------------------------------------
function IM:UpdateIgnoredListFrame()
    if not IM_IgnoredListFrame then return end

    local child = IM_IgnoredListFrame.scrollChild
    for _, childFrame in ipairs({child:GetChildren()}) do
        childFrame:Hide()
        childFrame:SetParent(nil)
    end

    local rowHeight = 32
    local count = 0
    IM:InitDB()

    for itemID, item in pairs(IM.db.ignoredItems) do
        count = count + 1
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(320, rowHeight)
        row:SetPoint("TOPLEFT", 0, -((count - 1) * (rowHeight + 2)))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.12, 0.12, 0.15, 0.6)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        local qColor = (IM.qualityColors and IM.qualityColors[item.quality]) or "|cFFFFFFFF"
        title:SetText(qColor .. (item.name or ("Item #" .. tostring(itemID))) .. "|r")

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 18)
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function()
            IM:RemoveFromIgnoredList(itemID)
            IM:UpdateIgnoredListFrame()
            if IM.ShowSuggestions then IM:ShowSuggestions() end
        end)
        SetTextTooltip(removeBtn, "Remove Item", "Removes this item from the Ignore List.")
    end

    IM_IgnoredListFrame.summary:SetText("Total Ignored Items: " .. count)
    child:SetHeight(math.max(1, count * (rowHeight + 2)))
end

function IM:ShowIgnoredListFrame()
    local frame = self:CreateIgnoredListFrame()
    self:UpdateIgnoredListFrame()
    self:AnchorAndShowFrame(frame)
end

---------------------------------------------------------
-- Auto-Action List Frame
---------------------------------------------------------
function IM:CreateAutoListFrame()
    if IM_AutoListFrame then return IM_AutoListFrame end

    local frame = CreateFrame("Frame", "IM_AutoListFrame", UIParent)
    IM:StyleFrame(frame, 380, 420, "Inventory Manager — Auto-Action List")

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 12, -32)

    frame.scroll = CreateFrame("ScrollFrame", "IM_AutoListScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -50)
    frame.scroll:SetPoint("BOTTOMRIGHT", -30, 45)

    frame.scrollChild = CreateFrame("Frame", "IM_AutoListScrollChild")
    frame.scrollChild:SetSize(330, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    IM_AutoListFrame = frame
    return frame
end

---------------------------------------------------------
-- Update Auto-Action List Frame
---------------------------------------------------------
function IM:UpdateAutoListFrame()
    if not IM_AutoListFrame then return end

    local child = IM_AutoListFrame.scrollChild
    for _, childFrame in ipairs({child:GetChildren()}) do
        childFrame:Hide()
        childFrame:SetParent(nil)
    end

    local rowHeight = 32
    local count = 0
    IM:InitDB()

    for itemID, item in pairs(IM.db.autoDeleteList) do
        count = count + 1
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(320, rowHeight)
        row:SetPoint("TOPLEFT", 0, -((count - 1) * (rowHeight + 2)))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.12, 0.12, 0.15, 0.6)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        local qColor = (IM.qualityColors and IM.qualityColors[item.quality]) or "|cFFFFFFFF"
        title:SetText(qColor .. (item.name or ("Item #" .. tostring(itemID))) .. "|r")

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 18)
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function()
            IM:RemoveFromAutoDeleteList(itemID)
            IM:UpdateAutoListFrame()
            if IM.ShowSuggestions then IM:ShowSuggestions() end
        end)
        SetTextTooltip(removeBtn, "Remove Item", "Removes this item from the Auto-Action List.")
    end

    IM_AutoListFrame.summary:SetText("Total Auto-Action Items: " .. count)
    child:SetHeight(math.max(1, count * (rowHeight + 2)))
end

function IM:ShowAutoListFrame()
    local frame = self:CreateAutoListFrame()
    self:UpdateAutoListFrame()
    self:AnchorAndShowFrame(frame)
end