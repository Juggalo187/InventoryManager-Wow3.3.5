local addonName, IM = ...
if _G["InventoryManager"] then
    return
end
_G["InventoryManager"] = IM
IM_ADDON_LOADED = false

IM.detectedTypes = {}

-- Default configuration
IM.defaultConfig = {
    enabled = true,
      ignoreQuality = {
        ["POOR"] = false,
        ["COMMON"] = true,
        ["UNCOMMON"] = true,
        ["RARE"] = true,
        ["EPIC"] = true,
        ["LEGENDARY"] = true,
        ["ARTIFACT"] = true,
    },
    ignoreItemTypes = {
		["Weapon"] = false,
        ["Armor"] = false,
		["Consumable"] = true,
		["Miscellaneous"] = false,
        ["Quest"] = true,
        ["Recipe"] = true,
    },
	ignoreTradeGoodsTypes = {
		["Cloth"] = true,
		["Leather"] = true,
		["Metal"] = true,
		["Stone"] = true,
		["Gem"] = true,
		["Meat"] = true,
		["Herb"] = true,
		["Elemental"] = true,
		["Enchanting"] = true,
		["Jewelcrafting"] = true,
		["Inscription"] = true, 
		["Parts"] = true,
		["Other"] = true,
	},
	alawaysignore = {
		["Containers"] = true,
		["Container"] = true,
        ["Currency"] = true,
        ["Keys"] = true,
		["Glyphs"] = true,
		["Quivers"] = true,
		["Projectile"] = true,
    },
    minItemValue = 1,
    autoSellAtVendor = false,
    showSellListAtVendor = false,
	autoOpenOnLowSpace = false,
	ignoreGearValue = false,
    lowSpaceThreshold = 0.9,
	autoDeleteEnabled = false,
	toggleIconPosition = nil,
	deletionLogEnabled = true,
}

-- Initialize frame positions table
IM.framePositions = {
    main = nil,
    sellList = nil,
    ignoredList = nil,
	autoDeleteList = nil,
	simpleSettings = nil
}

-- Quality data
IM.qualityNames = {
    [0] = "Poor (Grey)",
    [1] = "Common (White)",
    [2] = "Uncommon (Green)", 
    [3] = "Rare (Blue)",
    [4] = "Epic (Purple)",
    [5] = "Legendary (Orange)",
    [6] = "Artifact (Gold)",
}

IM.qualityColors = {
    [0] = "|cFF9D9D9D",
    [1] = "|cFFFFFFFF",
    [2] = "|cFF1EFF00",
    [3] = "|cFF0070DD",
    [4] = "|cFFA335EE",
    [5] = "|cFFFF8000",
    [6] = "|cFFE6CC80",
}

-- Profession items that should be considered valuable
IM.professionItems = {
    ["Bolt of Linen Cloth"] = true,
    ["Bolt of Woolen Cloth"] = true,
    ["Bolt of Silk Cloth"] = true,
    ["Bolt of Mageweave"] = true,
    ["Bolt of Runecloth"] = true,
    ["Bolt of Netherweave"] = true,
    ["Bolt of Frostweave"] = true,
    ["Light Leather"] = true,
    ["Medium Leather"] = true,
    ["Heavy Leather"] = true,
    ["Thick Leather"] = true,
    ["Rugged Leather"] = true,
    ["Knothide Leather"] = true,
    ["Borean Leather"] = true,
    ["Copper Bar"] = true,
    ["Tin Bar"] = true,
    ["Iron Bar"] = true,
    ["Mithril Bar"] = true,
    ["Thorium Bar"] = true,
    ["Fel Iron Bar"] = true,
    ["Cobalt Bar"] = true,
    ["Saronite Bar"] = true,
}

local gearSlots = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_BODY = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_THROWN = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_RELIC = true
}

IM.pendingItems = {}
IM.pendingItemsProcessed = {}
IM.vendorList = {}
IM.ignoredItems = {}
IM.autoDeleteList = {}
IM_AutoDeleteListDB = IM.autoDeleteList

-- Utility functions
function IM:ScheduleCleanup()
    if not self.cleanupTimer then
        self.cleanupTimer = CreateFrame("Frame")
        self.cleanupTimer:SetScript("OnUpdate", function(self, elapsed)
            self.timeSinceLastCleanup = (self.timeSinceLastCleanup or 0) + elapsed
            if self.timeSinceLastCleanup > 300 then -- Every 5 minutes
                IM:CleanupPendingItems()
                IM:ValidateAutoDeleteList() -- Regular validation
                self.timeSinceLastCleanup = 0
            end
        end)
    end
end

function IM:IsValidItemData(itemData)
    if not itemData then
        return false
    end
    
    -- Check for required fields
    if not itemData.itemID or type(itemData.itemID) ~= "number" then
        return false
    end
    
    -- Basic sanity checks
    if itemData.itemID <= 0 then
        return false
    end
    
    -- Ensure we have at least some display information
    if not itemData.name and not itemData.displayName then
        return false
    end
    
    return true
end

function IM:ValidateAutoDeleteList()
    if not self.autoDeleteList then 
        self.autoDeleteList = {}
        return 0
    end
    
    local validCount = 0
    local removedCount = 0
    
    for i = #self.autoDeleteList, 1, -1 do
        local item = self.autoDeleteList[i]
        
        if self:IsValidItemData(item) then
            validCount = validCount + 1
        else
            table.remove(self.autoDeleteList, i)
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        print(string.format("Inventory Manager: Removed %d invalid entries from auto-delete list", removedCount))
        self:SaveAutoDeleteList()
    end
    
    return removedCount
end

-- Export/Import functions for Auto-Delete list
function IM:ExportAutoDeleteList()
    if not self.autoDeleteList or #self.autoDeleteList == 0 then
        print("Inventory Manager: Auto-delete list is empty, nothing to export.")
        return
    end
    
    -- Create export data structure
    local exportData = {
        version = 1,
        timestamp = time(),
        items = {}
    }
    
    -- Add items to export data
    for _, item in ipairs(self.autoDeleteList) do
        table.insert(exportData.items, {
            itemID = item.itemID,
            name = item.name,
        })
    end
    
    -- Convert to JSON-like string (simplified for WoW)
    local exportString = "IM_AutoDelete_Export:" .. self:TableToString(exportData)
    
    -- Show export frame instead of trying to copy to clipboard
    self:ShowExportFrame(exportString, "Auto-Delete List Export")
end

function IM:ShowExportFrame(text, title)
    if not IM_ExportFrame then
        self:CreateExportFrame()
    end
    
    -- Store the original text and set it
    IM_ExportFrame.exportText.originalText = text
    IM_ExportFrame.exportText:SetText(text)
    IM_ExportFrame.exportText:SetCursorPosition(0) -- Scroll to top
    
    if title then
        IM_ExportFrame.title:SetText(title)
    end
    
    -- Auto-select all text
    IM_ExportFrame.exportText:HighlightText()
    IM_ExportFrame.exportText:SetFocus()
    
    IM_ExportFrame:Show()
    
    print("Inventory Manager: Export window opened. Press Ctrl+C to copy the text.")
end

function IM:ImportAutoDeleteList(importString)
    if not importString or importString == "" then
        self:ShowImportMessage("No import data provided.", true)
        return false
    end
    
    -- Check if it's our export format
    if not strfind(importString, "IM_AutoDelete_Export:") then
        self:ShowImportMessage("Invalid import format. Please use a valid export string.", true)
        return false
    end
    
    -- Extract the data part
    local dataString = strsub(importString, 21) -- Remove "IM_AutoDelete_Export:"
    local success, importData = pcall(self.StringToTable, self, dataString)
    
    if not success or not importData or not importData.items then
        self:ShowImportMessage("Failed to parse import data. The string may be corrupted.", true)
        return false
    end
    
    local importedCount = 0
    local skippedCount = 0
    
    -- Import items
    for _, itemData in ipairs(importData.items) do
        if itemData.itemID then
            -- Check if item already exists in auto-delete list
            local exists = false
            for _, existingItem in ipairs(self.autoDeleteList) do
                if existingItem.itemID == itemData.itemID then
                    exists = true
                    break
                end
            end
            
            if not exists then
                -- Add to auto-delete list
                local itemInfo = {
                    itemID = itemData.itemID,
                    name = itemData.name or "Unknown Item",
                    displayName = itemData.name or "Unknown Item",
                    quality = 1, -- Default quality
                    link = "item:" .. itemData.itemID -- Basic item link
                }
                
                table.insert(self.autoDeleteList, itemInfo)
                importedCount = importedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end
    
    -- Save the updated list
    self:SaveAutoDeleteList()
    
    -- Refresh UI
    self:RefreshUI()
    if IM_AutoDeleteListFrame and IM_AutoDeleteListFrame:IsShown() then
        self:UpdateAutoDeleteListFrame()
    end
    
    local message = string.format("Successfully imported %d items", importedCount)
    if skippedCount > 0 then
        message = message .. string.format(", skipped %d duplicates", skippedCount)
    end
    message = message .. "."
    
    self:ShowImportMessage(message, false)
    return importedCount > 0
end

function IM:ShowImportMessage(message, isError)
    local color = isError and "|cFFFF0000" or "|cFF00FF00"
    print("Inventory Manager: " .. color .. message .. "|r")
    
    -- You could also show this in the import frame itself if you want
    if IM_ImportFrame and IM_ImportFrame.infoText then
        IM_ImportFrame.infoText:SetText(message)
        if isError then
            IM_ImportFrame.infoText:SetTextColor(1, 0.5, 0.5) -- Reddish for errors
        else
            IM_ImportFrame.infoText:SetTextColor(0.5, 1, 0.5) -- Greenish for success
        end
    end
end

-- Replace the ShowImportAutoDeleteDialog function with a frame-based approach
function IM:ShowImportAutoDeleteDialog()
    if not IM_ImportFrame then
        self:CreateImportFrame()
    end
    
    IM_ImportFrame.importText:SetText("")
    IM_ImportFrame.importText:SetFocus()
    IM_ImportFrame:Show()
    
    print("Inventory Manager: Import window opened. Paste your export string and click Import.")
end

function IM:CreateImportFrame()
    if IM_ImportFrame then
        return IM_ImportFrame
    end
    
    local frame = CreateFrame("Frame", "IM_ImportFrame", UIParent)
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
    frame.title:SetText("Import Auto-Delete List")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Instructions
    frame.instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.instructions:SetPoint("TOP", 0, -30)
    frame.instructions:SetText("Paste your auto-delete list export string below:")
    
    -- Scroll frame for import text
    frame.scroll = CreateFrame("ScrollFrame", "IM_ImportScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -55)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 80) -- More space for buttons
    
    -- Edit box for text
    frame.importText = CreateFrame("EditBox", nil, frame.scroll)
    frame.importText:SetMultiLine(true)
    frame.importText:SetFontObject("GameFontHighlight")
    frame.importText:SetWidth(frame.scroll:GetWidth() - 20)
    frame.importText:SetHeight(200)
    frame.importText:SetAutoFocus(true)
    frame.importText:SetTextInsets(5, 5, 5, 5)
    frame.importText:EnableMouse(true)
    frame.importText:SetScript("OnEscapePressed", function() frame:Hide() end)
    
    frame.scroll:SetScrollChild(frame.importText)
    
    -- Position the scroll bar properly
    local scrollBar = _G["IM_ImportScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 0, 16)
    end
    
    -- Import button
    frame.importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.importBtn:SetSize(100, 25)
    frame.importBtn:SetPoint("BOTTOMLEFT", 10, 10)
    frame.importBtn:SetText("Import")
    frame.importBtn:SetScript("OnClick", function()
        local importString = frame.importText:GetText()
        if IM:ImportAutoDeleteList(importString) then
            frame:Hide()
        end
    end)
    
    -- Clear button
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(80, 25)
    frame.clearBtn:SetPoint("BOTTOM", 0, 10)
    frame.clearBtn:SetText("Clear")
    frame.clearBtn:SetScript("OnClick", function()
        frame.importText:SetText("")
        frame.importText:SetFocus()
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
    frame.infoText:SetText("Paste your export string and click Import")
    frame.infoText:SetTextColor(0.8, 0.8, 0.8)
    
    IM_ImportFrame = frame
    return frame
end

-- Utility function to convert table to string (simplified serialization)
function IM:TableToString(tbl)
    local parts = {}
    
    if tbl.version then
        table.insert(parts, "v=" .. tbl.version)
    end
    
    if tbl.timestamp then
        table.insert(parts, "t=" .. tbl.timestamp)
    end
    
    if tbl.items then
        local itemParts = {}
        for _, item in ipairs(tbl.items) do
            if item.itemID then
                -- Escape colons in names
                local escapedName = string.gsub(item.name or "", ":", "\\:")
                table.insert(itemParts, item.itemID .. ":" .. escapedName)
            end
        end
        table.insert(parts, "i=" .. table.concat(itemParts, ","))
    end
    
    return table.concat(parts, "|")
end

-- Utility function to convert string back to table
function IM:StringToTable(str)
    local tbl = {}
    local parts = {strsplit("|", str)}
    
    for _, part in ipairs(parts) do
        local key, value = strsplit("=", part, 2)
        if key == "v" then
            tbl.version = tonumber(value)
        elseif key == "t" then
            tbl.timestamp = tonumber(value)
        elseif key == "i" then
            tbl.items = {}
            if value and value ~= "" then
                local itemParts = {strsplit(",", value)}
                for _, itemStr in ipairs(itemParts) do
                    local itemID, name = strsplit(":", itemStr, 2)
                    if itemID then
                        -- Unescape colons in names
                        local unescapedName = string.gsub(name or "", "\\:", ":")
                        table.insert(tbl.items, {
                            itemID = tonumber(itemID),
                            name = unescapedName or "Unknown Item"
                        })
                    end
                end
            end
        end
    end
    
    return tbl
end

-- Clipboard function for WoW 3.3.5 compatibility
function IM:SetClipboard(text)
    -- Try to use modern method first (if available in your WoW version)
    if C_ChatInfo and C_ChatInfo.SetClipboardText then
        return C_ChatInfo.SetClipboardText(text)
    end
    
    -- Fallback for older clients - just return true and let user copy manually
    return true
end

function IM:CopyTable(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

function IM:CleanupPendingItems()
    local now = GetTime()
    local cleanupThreshold = 300 -- 5 minutes
    
    -- Clean up old processed items
    for itemID, timestamp in pairs(self.pendingItemsProcessed) do
        if now - timestamp > cleanupThreshold then
            self.pendingItemsProcessed[itemID] = nil
        end
    end
    
    -- Clean up pending items list
    local stillPending = {}
    for _, itemData in ipairs(self.pendingItems) do
        if now - (itemData.addedTime or 0) < cleanupThreshold then
            table.insert(stillPending, itemData)
        end
    end
    self.pendingItems = stillPending
end

function IM:CleanupAutoDeleteList()
    if not self.autoDeleteList then return end
    
    local initialCount = #self.autoDeleteList
    self:ValidateAutoDeleteList()
    local finalCount = #self.autoDeleteList
    
    if initialCount ~= finalCount then
        print(string.format("Inventory Manager: Cleaned auto-delete list (%d invalid entries removed)", 
              initialCount - finalCount))
        self:SaveAutoDeleteList()
    end
end

function IM:GetQualityKey(quality)
    local qualityMap = {
        [0] = "POOR",
        [1] = "COMMON", 
        [2] = "UNCOMMON",
        [3] = "RARE",
        [4] = "EPIC", 
        [5] = "LEGENDARY",
        [6] = "ARTIFACT"
    }
    return qualityMap[quality] or "COMMON"
end

function IM:GetTradeGoodsCategory(subType, itemName)
    local categoryMap = {
        -- Cloth
        ["Cloth"] = "Cloth",
        ["Bolt of Cloth"] = "Cloth",
        
        -- Leather
        ["Leather"] = "Leather",
        ["Hide"] = "Leather",
        ["Scale"] = "Leather",
        
        -- Metal
        ["Ore"] = "Metal",
        ["Bar"] = "Metal",
        ["Metal"] = "Metal",
        
        -- Stone
        ["Stone"] = "Stone",
        
        -- Meat
        ["Meat"] = "Meat",
        ["Mutton"] = "Meat",
        ["Pork"] = "Meat",
        ["Beef"] = "Meat",
        ["Chicken"] = "Meat",
        
        -- Herbs
        ["Herb"] = "Herb",
        ["Flower"] = "Herb",
        
        -- Elemental
        ["Elemental"] = "Elemental",
        ["Fire"] = "Elemental",
        ["Water"] = "Elemental",
        ["Air"] = "Elemental",
        ["Earth"] = "Elemental",
        
        -- Enchanting
        ["Enchanting"] = "Enchanting",
        ["Dust"] = "Enchanting",
        ["Essence"] = "Enchanting",
        ["Shard"] = "Enchanting",
        
        -- Jewelcrafting
        ["Jewelcrafting"] = "Jewelcrafting",
        ["Gem"] = "Jewelcrafting",
        
        -- Inscription
        ["Inscription"] = "Inscription",
        ["Pigment"] = "Inscription",
        ["Ink"] = "Inscription",
        ["Scroll"] = "Inscription",
        ["Glyph"] = "Inscription",
        ["Item Enhancement"] = "Inscription",
        
        -- Parts
        ["Parts"] = "Parts",
        ["Explosives"] = "Parts",
        ["Devices"] = "Parts",
    }
    
    -- Special handling for "Metal & Stone" - check the item name
    if subType == "Metal & Stone" then
        if itemName then
            local lowerName = itemName:lower()
            -- Stone items
            if string.find(lowerName, "stone") or string.find(lowerName, "rock") or string.find(lowerName, "pebble") then
                return "Stone"
            -- Metal items (ores, bars, etc.)
            elseif string.find(lowerName, "ore") or string.find(lowerName, "bar") or string.find(lowerName, "ingot") or 
                   string.find(lowerName, "copper") or string.find(lowerName, "tin") or string.find(lowerName, "iron") or
                   string.find(lowerName, "mithril") or string.find(lowerName, "thorium") or string.find(lowerName, "fel iron") or
                   string.find(lowerName, "cobalt") or string.find(lowerName, "saronite") then
                return "Metal"
            end
        end
        -- Default to Stone for ambiguous "Metal & Stone" items
        return "Stone"
    end
    
    -- For "Other" subType, we need to check the item name to categorize properly
    if subType == "Other" then
        return "Other"
    end
    
    return categoryMap[subType] or "Other"
end

-- Deletion Log Functions
function IM:SaveDeletionLog()
    if not self.deletionLog then
        self.deletionLog = {
            sessions = {},
            allTime = {},
            lastCleanup = time()
        }
    end
    
    if not self.deletionLog.sessions then
        self.deletionLog.sessions = {}
    end
    
    if not self.deletionLog.allTime then
        self.deletionLog.allTime = {}
    end
    
    if not self.deletionLog.currentSession or not self.deletionLog.sessions[self.deletionLog.currentSession] then
        self:StartNewSession()
    end
    
    -- Save to global variable
    IM_DeletionLogDB = self.deletionLog
end

function IM:StartNewSession()
    local sessionId = date("%Y-%m-%d %H:%M:%S")
    self.deletionLog.currentSession = sessionId
    
    if not self.deletionLog.sessions then
        self.deletionLog.sessions = {}
    end
    
    if not self.deletionLog.sessions[sessionId] then
        self.deletionLog.sessions[sessionId] = {
            startTime = time(),
            deletions = {}
        }
    end
    
    self:CleanupOldSessions()
    self:SaveDeletionLog()
end

function IM:CleanupOldSessions()
    local now = time()
    local oneMonthAgo = now - (30 * 24 * 60 * 60) -- 30 days in seconds
    
    for sessionId, sessionData in pairs(self.deletionLog.sessions) do
        if sessionData.startTime < oneMonthAgo then
            self.deletionLog.sessions[sessionId] = nil
        end
    end
    
    self.deletionLog.lastCleanup = now
end

function IM:LogDeletion(itemLink, itemCount, deletionType)
    if not self.db.deletionLogEnabled then return end
    
    -- Ensure deletion log is initialized
    if not self.deletionLog then
        self:InitializeDeletionLog()
        return
    end
    
    local itemID = self:GetItemIDFromLink(itemLink)
    if not itemID then 
        print("Inventory Manager: Cannot log deletion - invalid item link: " .. (itemLink or "nil"))
        return 
    end
    
    -- Ensure we have valid data
    if not itemCount or itemCount < 1 then
        itemCount = 1
    end
    
    local deletionEntry = {
        timestamp = time(),
        itemLink = itemLink,
        itemID = itemID,
        itemCount = itemCount,
        deletionType = deletionType or "manual"
    }
    -- Add to current session
    local currentSession = self.deletionLog.sessions[self.deletionLog.currentSession]
    if currentSession then
        -- Check if we already have this item in the current session and combine if found
        local foundExisting = false
        for i, existingDeletion in ipairs(currentSession.deletions) do
            if existingDeletion.itemID == itemID and existingDeletion.deletionType == deletionType then
                -- Combine with existing entry (within a reasonable time window - 5 minutes)
                if deletionEntry.timestamp - existingDeletion.timestamp < 300 then
                    existingDeletion.itemCount = existingDeletion.itemCount + itemCount
                    existingDeletion.timestamp = deletionEntry.timestamp -- Update to most recent time
                    foundExisting = true
                    break
                end
            end
        end
        
        if not foundExisting then
            table.insert(currentSession.deletions, deletionEntry)
        end
    end
    
    -- Also add to all-time log
    if not self.deletionLog.allTime then
        self.deletionLog.allTime = {}
    end
    
    -- Check if we already have this item in the all-time log and combine if found
    local foundExistingAllTime = false
    for i, existingDeletion in ipairs(self.deletionLog.allTime) do
        if existingDeletion.itemID == itemID and existingDeletion.deletionType == deletionType then
            -- Combine with existing entry (within a reasonable time window - 5 minutes)
            if deletionEntry.timestamp - existingDeletion.timestamp < 300 then
                existingDeletion.itemCount = existingDeletion.itemCount + itemCount
                existingDeletion.timestamp = deletionEntry.timestamp -- Update to most recent time
                foundExistingAllTime = true
                break
            end
        end
    end
    
    if not foundExistingAllTime then
        table.insert(self.deletionLog.allTime, deletionEntry)
    end
    
    self:SaveDeletionLog()
end

function IM:GetDeletionsForTimeRange(hours)
    -- Define proper time ranges for each tab
    local cutoffTime
    if hours == 0 then
        -- Session tab = last 12 hours
        cutoffTime = time() - (12 * 60 * 60)
    else
        -- Other tabs use their specified hours
        cutoffTime = time() - (hours * 60 * 60)
    end
    
    local results = {}
    
    -- Filter deletions from all sessions by time
    for _, sessionData in pairs(self.deletionLog.sessions) do
        for _, deletion in ipairs(sessionData.deletions) do
            -- Additional safety check for valid deletion entries
            if deletion and deletion.timestamp and deletion.timestamp >= cutoffTime then
                table.insert(results, deletion)
            end
        end
    end
    
    return results
end

function IM:FormatDeletionTime(timestamp)
    local now = time()
    local diff = now - timestamp
    
    if diff < 60 then
        return string.format("%d seconds ago", diff)
    elseif diff < 3600 then
        return string.format("%d minutes ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d hours ago", math.floor(diff / 3600))
    else
        return string.format("%d days ago", math.floor(diff / 86400))
    end
end

function IM:CheckBagSpaceAndOpen()
    if not self.db.autoOpenOnLowSpace then
        return
    end
    
    local totalBagSlots = 0
    local usedBagSlots = 0
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        totalBagSlots = totalBagSlots + slots
        for slot = 1, slots do
            local texture = GetContainerItemInfo(bag, slot)
            if texture then
                usedBagSlots = usedBagSlots + 1
            end
        end
    end
    
    if totalBagSlots > 0 then
        local fillPercentage = usedBagSlots / totalBagSlots
        if fillPercentage >= self.db.lowSpaceThreshold then
            -- Only open if not already showing and not at vendor (to avoid overlap)
            if not (IM_MainFrame and IM_MainFrame:IsShown()) and not MerchantFrame:IsShown() then
                self:CreateFrames()
                self:ShowSuggestions()
                print(string.format("Inventory Manager: Auto-opened (bags %.1f%% full)", fillPercentage * 100))
            end
        end
    end
end

function IM:RefreshUI()
    -- Only refresh if the main frame is visible
    if IM_MainFrame and IM_MainFrame:IsShown() then
        self:ShowSuggestions()
    end
    
    -- Refresh sell list frame if visible
    if IM_SellListFrame and IM_SellListFrame:IsShown() then
        self:UpdateSellListFrame()
    end
    
    -- Refresh ignored list frame if visible
    if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
        self:UpdateIgnoredListFrame()
    end
    
    -- Refresh auto-delete list frame if visible
    if IM_AutoDeleteListFrame and IM_AutoDeleteListFrame:IsShown() then
        self:UpdateAutoDeleteListFrame()
    end
end

function IM:FormatMoneyWithIcons(copperAmount)
    local copper = math.floor(copperAmount + 0.5)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRemainder = copper % 100
    local result = ""
    if gold > 0 then
        result = result .. gold .. " |TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    end
    if silver > 0 then
        if result ~= "" then result = result .. " " end
        result = result .. silver .. " |TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
    end
    if copperRemainder > 0 or (gold == 0 and silver == 0) then
        if result ~= "" then result = result .. " " end
        result = result .. copperRemainder .. " |TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    end
    return result
end

function IM:GetItemIDFromLink(link)
    if not link then return nil end
    local itemID = string.match(link, "item:(%d+):")
    return itemID and tonumber(itemID) or nil
end

function IM:ScanInventory()
    self:CleanupPendingItems()
    local suggestions = {}
    local totalBagSlots = 0
    local usedBagSlots = 0
    local playerGold = GetMoney() / 10000
    local playerLevel = UnitLevel("player")
    local _, playerClass = UnitClass("player")
    local itemsByID = {}
    
    -- Clear pending items at start of scan
    self.pendingItems = {}
    
    -- Build lookup tables for faster checking
    local vendorListLookup = {}
    for _, vendorItem in ipairs(self.vendorList) do
        vendorListLookup[vendorItem.itemID] = true
    end
    
    local ignoredListLookup = {}
    for _, ignoredItem in ipairs(self.ignoredItems) do
        ignoredListLookup[ignoredItem.itemID] = true
    end
    
    local autoDeleteListLookup = {}
    for _, autoDeleteItem in ipairs(self.autoDeleteList) do
        autoDeleteListLookup[autoDeleteItem.itemID] = true
    end
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        totalBagSlots = totalBagSlots + slots
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link then
                usedBagSlots = usedBagSlots + 1
                local itemID = self:GetItemIDFromLink(link)
                
                if not itemID then
                    -- Try to extract itemID from link if GetItemIDFromLink failed
                    itemID = string.match(link, "item:(%d+):") or string.match(link, "item:(%d+)")
                    if itemID then itemID = tonumber(itemID) end
                end
                
                if itemID then
                    -- Check if item is in ANY list (vendor, ignored, or auto-delete)
                    local isInAnyList = vendorListLookup[itemID] or ignoredListLookup[itemID] or autoDeleteListLookup[itemID]
                    
                    if not isInAnyList then
                        local itemInfo = self:AnalyzeItem(bag, slot, itemID, count, quality, link, playerGold, playerLevel, playerClass)
                        if itemInfo and itemInfo.shouldSuggestDelete then
                            if not itemsByID[itemID] then
                                itemsByID[itemID] = {
                                    itemID = itemID,
                                    name = itemInfo.name,
                                    link = itemInfo.link,
                                    quality = itemInfo.quality,
                                    type = itemInfo.type,
                                    subType = itemInfo.subType,
                                    sellPrice = itemInfo.sellPrice,
                                    totalCount = 0,
                                    stackValue = 0,
                                    locations = {},
                                    shouldSuggestDelete = true,
                                    priority = itemInfo.priority,
                                    reason = itemInfo.reason,
                                    stackSize = itemInfo.stackSize,
                                    displayName = itemInfo.displayName
                                }
                            end
                            itemsByID[itemID].totalCount = itemsByID[itemID].totalCount + count
                            itemsByID[itemID].stackValue = itemsByID[itemID].stackValue + itemInfo.stackValue
                            table.insert(itemsByID[itemID].locations, {bag = bag, slot = slot, count = count})
                            if itemInfo.priority < itemsByID[itemID].priority then
                                itemsByID[itemID].priority = itemInfo.priority
                                itemsByID[itemID].reason = itemInfo.reason
                            end
                        elseif not itemInfo then
                            -- Item data not available yet, add to pending list
                            table.insert(self.pendingItems, {bag = bag, slot = slot, itemID = itemID, link = link})
                        end
                    end
                end
            end
        end
    end
    
    for itemID, itemInfo in pairs(itemsByID) do
        table.insert(suggestions, itemInfo)
    end
    
    table.sort(suggestions, function(a, b) 
        if a.priority == b.priority then
            return a.stackValue < b.stackValue
        end
        return a.priority < b.priority
    end)
    
    return suggestions, totalBagSlots, usedBagSlots
end

function IM:AnalyzeItem(bag, slot, itemID, count, quality, link, playerGold, playerLevel, playerClass)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID or link)
    
    -- Use link data as fallback when full item info isn't available
    local usingFallbackData = false
    if not itemName or not itemType or itemType == "" then
        usingFallbackData = true
        itemName = string.match(link, "%[(.-)%]") or "Unknown Item"
        itemType = itemType or "Unknown"
        itemSubType = itemSubType or "Unknown"
        
        -- Mark for reprocessing but don't skip analysis entirely
        if itemID and not self.pendingItemsProcessed[itemID] then
            table.insert(self.pendingItems, {
                bag = bag, 
                slot = slot, 
                itemID = itemID, 
                link = link,
                addedTime = GetTime()
            })
            self.pendingItemsProcessed[itemID] = GetTime()
        end
    end

    local actualQuality = quality
    if actualQuality == -1 or actualQuality == nil then
        actualQuality = itemRarity or 1
    end
    
    local actualSellPrice = itemSellPrice or 0
    
    local itemInfo = {
        bag = bag,
        slot = slot,
        itemID = itemID,
        name = itemName,
        link = link or itemLink,
        quality = actualQuality,
        count = count or 1,
        type = itemType or "Unknown",
        subType = itemSubType or "Unknown",
        sellPrice = actualSellPrice,
        stackValue = (actualSellPrice or 0) * (count or 1) / 10000,
        shouldSuggestDelete = false,
        priority = 0,
        reason = "",
        stackSize = itemStackCount or 1,
        displayName = string.match(link, "%[(.-)%]") or itemName,
        usingFallbackData = usingFallbackData  -- Track if we're using incomplete data
    }
    
    -- If we're using fallback data, be more conservative with deletions
    if usingFallbackData then
        itemInfo.shouldSuggestDelete = false
        itemInfo.reason = "Incomplete item data - waiting for full info"
        return itemInfo
    end
	
    -- Never suggest deleting these important items, regardless of type
    local importantItems = {
        "Hearthstone",
        "Astral Recall",
        "Innkeeper's Daughter",
        "Insignia of the",
        "Medallion of the",
        "Battlemaster's",
        "Gladiator's",
        "Key to",
        "Key of",
        "Skeleton Key",
        "Mining Pick",
        "Skinning Knife",
        "Blacksmith Hammer",
        "Runed Copper Rod",
        "Arclight Spanner",
        "Fishing Pole",
        "Aquadynamic Fish",
        "Bright Baubles",
        "Shiny Baubles",
        "Soul Shard",
        "Ankh",
        "Symbol of",
        "Rune of",
        "Totem of",
        "Libram of",
        "Idol of",
        "Sigil of",
        "Argent Dawn Commission",
        "Seal of Ascension",
        "Scepter of Celebras",
        "Mallet of Zul'Farrak",
        "Staff of Escorte",
        "Attuned Crystal",
        "The Master's Key",
        "Key to the Focusing Iris",
        "Heroic Key",
        "Dragon Eye",
        "Scarab",
        "Scepter of the Shifting Sands",
        "Gnomish Army Knife",
        "Goblin Rocket Boots",
        "Jeeves",
        "MOLL-E",
        "Wormhole Generator",
        "Blingtron",
        "Elixir of Giant Growth",
        "Noggenfogger Elixir",
        "Savory Deviate Delight",
        "Gnomish Mind Control Cap",
        "Piccolo of the Flaming Fire",
        "World Enlarger",
        "Time-Lost Figurine",
        "Orb of Deception",
        "Badge of Justice",
        "Emblem of",
        "Honor Points",
        "Arena Points",
        "Guild Charter",
    }
    
    -- Check if this is a consumable trade good (meat/fish that can be eaten)
    local isConsumableTradeGood = false
    if itemInfo.type == "Trade Goods" and (itemInfo.subType == "Meat" or itemInfo.subType == "Fish") then
        -- Check if this item has a use effect (can be consumed)
        local hasUseEffect = false
        
        -- Try to determine if it's consumable by checking tooltip
        local tooltip = CreateFrame("GameTooltip", "IMTempTooltip", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetHyperlink(itemInfo.link or link)
        
        for i = 2, 4 do  -- Check lines 2-4 for use effects
            local text = _G["IMTempTooltipTextLeft"..i]:GetText()
            if text and (string.find(text, "Use:") or string.find(text, "Restores") or string.find(text, "Consumable")) then
                hasUseEffect = true
                break
            end
        end
        
        tooltip:Hide()
        
        if hasUseEffect then
            isConsumableTradeGood = true
            itemInfo.type = "Consumable"  -- Reclassify as consumable
        end
    end
	
    -- CHECK ITEM TYPE FILTERING FIRST
    if self.db.ignoreItemTypes[itemInfo.type] then
        return nil
    end
	
	if self.db.alawaysignore[itemInfo.type] then
		return nil
	end
	
    -- Check if this is gear (has an equip location)
	local isGear = gearSlots[itemEquipLoc]

    local minItemValueCopper = (self.db.minItemValue or 0) * 10000
    local itemValueCopper = (itemInfo.sellPrice or 0)

    -- Revised gear analysis with proper logic flow
    if isGear then
        local qualityKey = self:GetQualityKey(actualQuality)
        
        -- First check if we should ignore based on quality
        if self.db.ignoreQuality[qualityKey] then
            return nil
        end
        
        -- Then check gear value settings
        if self.db.ignoreGearValue then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 2
            itemInfo.reason = "Gear (value ignored)"
        else
            -- Only suggest deletion if below value threshold
            if itemValueCopper < minItemValueCopper then
                itemInfo.shouldSuggestDelete = true
                itemInfo.priority = 2
                itemInfo.reason = "Low value gear"
            else
                itemInfo.shouldSuggestDelete = false
            end
        end
    end
	
    -- Grey quality items (non-gear)
	if actualQuality == 0 and not isGear then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 1
            itemInfo.reason = "Vendor trash"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
	
    -- Trade goods analysis (now excludes consumable meat/fish)
    if itemInfo.type == "Trade Goods" and not isConsumableTradeGood then
        local tradeGoodsCategory = self:GetTradeGoodsCategory(itemInfo.subType, itemInfo.name)
        
        -- Special handling for "Other" subType - check if it's actually an inscription item
        if itemInfo.subType == "Other" then
            -- Check if this is an inscription-related item by name
            if itemInfo.name and (string.find(itemInfo.name:lower(), "pigment") or 
                                  string.find(itemInfo.name:lower(), "ink") or
                                  string.find(itemInfo.name:lower(), "scroll") or
                                  string.find(itemInfo.name:lower(), "glyph") or
                                  string.find(itemInfo.name:lower(), "vellum")) then
                tradeGoodsCategory = "Inscription"
            end
        end
        
        if self.db.ignoreTradeGoodsTypes[tradeGoodsCategory] then
            return nil
        end
        
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 3
            itemInfo.reason = "Low value " .. tradeGoodsCategory:lower()
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
    
    if itemInfo.type == "Gem" then
        if self.db.ignoreTradeGoodsTypes["Gem"] then
            return nil
        end
        
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 3.5
            itemInfo.reason = "Low value gem"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
    
    -- Recipe analysis
    if itemInfo.type == "Recipe" then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 4
            itemInfo.reason = "Low value Recipe"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
    
    -- Consumable analysis (now includes consumable meat/fish)
    if itemInfo.type == "Consumable" or isConsumableTradeGood then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 5
            itemInfo.reason = "Low value consumable"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
	
	-- Miscellaneous analysis
    if itemInfo.type == "Miscellaneous" then
    -- Only suggest deletion for poor (0) uality miscellaneous items
    if actualQuality == 0 then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 6
            itemInfo.reason = "Low value Misc Item"
        else
            itemInfo.shouldSuggestDelete = false
        end
    else
        -- For higher quality misc items return nil to skip entirely
        return nil
    end
end
	
    -- Check against important items list
    for _, importantName in ipairs(importantItems) do
        if itemInfo.name and string.find(itemInfo.name, importantName) then
            itemInfo.shouldSuggestDelete = false
            itemInfo.reason = "Important item - never delete"
            break
        end
    end

    -- Catch-all for any item type not specifically handled above
    if not itemInfo.shouldSuggestDelete and itemInfo.type ~= "Quest" then
        -- Check if this item is in the important items list
        local isImportantItem = false
        for _, importantName in ipairs(importantItems) do
            if itemInfo.name and string.find(itemInfo.name, importantName) then
                isImportantItem = true
                break
            end
        end
        
        if itemValueCopper < minItemValueCopper and not isImportantItem then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 7
            itemInfo.reason = "Low value " .. (itemInfo.type:lower() or "item")
            
            if not self.detectedTypes[itemInfo.type] then
                self.detectedTypes[itemInfo.type] = true
                print(string.format("Inventory Manager: Now suggesting %s items based on your value threshold", itemInfo.type))
            end
        end
    end

    return itemInfo
end

function IM:SaveAutoDeleteList()
    IM_AutoDeleteListDB = self.autoDeleteList
end

function IM:AddToAutoDeleteList(suggestion)
    if not suggestion or not suggestion.itemID then
        print("Inventory Manager: Cannot add invalid item to auto-delete list")
        return false
    end
    
    -- Ensure autoDeleteList exists
    if not self.autoDeleteList then
        self.autoDeleteList = {}
    end
    
    -- Check if item already exists
    local found = false
    for i, autoDeleteItem in ipairs(self.autoDeleteList) do
        if autoDeleteItem and autoDeleteItem.itemID == suggestion.itemID then
            found = true
            break
        end
    end
    
    if not found then
        -- SAFER: Provide comprehensive fallbacks for all fields
        local autoDeleteEntry = {
            itemID = suggestion.itemID,
            name = suggestion.name or "Unknown Item",
            link = suggestion.link or ("item:" .. suggestion.itemID),
            quality = suggestion.quality or 1,
            displayName = suggestion.displayName or suggestion.name or "Unknown Item",
            -- Add timestamp for tracking
            addedTime = time()
        }
        
        -- Validate the entry before adding
        if self:IsValidItemData(autoDeleteEntry) then
            table.insert(self.autoDeleteList, autoDeleteEntry)
            self:RemoveFromVendorList(suggestion.itemID)
            self:RemoveFromIgnoredList(suggestion.itemID)
            self:SaveAutoDeleteList()
            IM:RefreshUI()
            return true
        else
            print("Inventory Manager: Failed to create valid auto-delete entry")
            return false
        end
    end
    
    return false
end

function IM:RemoveFromAutoDeleteList(itemID)
    if not itemID then
        print("Inventory Manager: Cannot remove item with nil itemID from auto-delete list")
        return false
    end
    
    if not self.autoDeleteList then
        self.autoDeleteList = {}
        return false
    end
    
    local removed = false
    for i = #self.autoDeleteList, 1, -1 do
        local autoDeleteItem = self.autoDeleteList[i]
        if autoDeleteItem and autoDeleteItem.itemID == itemID then
            table.remove(self.autoDeleteList, i)
            removed = true
            break
        end
    end
    
    if removed then
        self:SaveAutoDeleteList()
        
        -- Force immediate UI refresh
        if IM_AutoDeleteListFrame and IM_AutoDeleteListFrame:IsShown() then
            self:UpdateAutoDeleteListFrame() -- This will refresh the display
        end
        
        -- Also refresh main UI if it's showing
        self:RefreshUI()
        return true
    end
    
    return false
end

function IM:ClearAutoDeleteList()
    if not self.autoDeleteList then
        self.autoDeleteList = {}
    else
        -- Clear the table properly
        for i = #self.autoDeleteList, 1, -1 do
            table.remove(self.autoDeleteList, i)
        end
    end
    
    self:SaveAutoDeleteList()
    IM:RefreshUI()
    
    if IM_AutoDeleteListFrame and IM_AutoDeleteListFrame:IsShown() then
        self:UpdateAutoDeleteListFrame()
    end
    
    print("Inventory Manager: Auto-delete list cleared")
end

function IM:SaveIgnoredList()
    IM_IgnoredListDB = self.ignoredItems
end

function IM:AddToIgnoredList(suggestion)
	if not suggestion or not suggestion.itemID then
        print("Inventory Manager: Cannot add invalid item to ignored list")
        return
    end
    self.ignoredItems = self.ignoredItems or {}
    
    local found = false
    for i, ignoredItem in ipairs(self.ignoredItems) do
        if ignoredItem.itemID == suggestion.itemID then
            found = true
            break
        end
    end
    
    if not found then
        local ignoredEntry = self:CopyTable(suggestion)
        self.ignoredItems[#self.ignoredItems + 1] = ignoredEntry
        self:RemoveFromVendorList(suggestion.itemID)
        self:RemoveFromAutoDeleteList(suggestion.itemID)
    end
    
    self:SaveIgnoredList()
    IM:RefreshUI()

    if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
        self:UpdateIgnoredListFrame()
    end
end

function IM:RemoveFromIgnoredList(itemID)
    for i, ignoredItem in ipairs(self.ignoredItems) do
        if ignoredItem.itemID == itemID then
            table.remove(self.ignoredItems, i)
            self:SaveIgnoredList()
            IM:RefreshUI()
            if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
                self:UpdateIgnoredListFrame()
            end
            break
        end
    end
end

function IM:ClearIgnoredList()
    self.ignoredItems = {}
    self:SaveIgnoredList()
    IM:RefreshUI()
    if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
        self:UpdateIgnoredListFrame()
    end
end

function IM:SaveVendorList()
    IM_VendorListDB = self.vendorList
end

function IM:AddToVendorList(suggestion)
	if not suggestion or not suggestion.itemID then
        print("Inventory Manager: Cannot add invalid item to vendor list")
        return
    end
    local found = false
    for i, vendorItem in ipairs(self.vendorList) do
        if vendorItem.itemID == suggestion.itemID then
            -- Item already in vendor list, just update the locations
            for _, loc in ipairs(suggestion.locations) do
                local locationExists = false
                for _, existingLoc in ipairs(vendorItem.locations) do
                    if existingLoc.bag == loc.bag and existingLoc.slot == loc.slot then
                        locationExists = true
                        break
                    end
                end
                if not locationExists then
                    table.insert(vendorItem.locations, loc)
                end
            end
            vendorItem.totalCount = vendorItem.totalCount + suggestion.totalCount
            vendorItem.stackValue = vendorItem.stackValue + suggestion.stackValue
            found = true
            break
        end
    end
    
    if not found then
        local vendorEntry = self:CopyTable(suggestion)
        self.vendorList[#self.vendorList + 1] = vendorEntry
        self:RemoveFromAutoDeleteList(suggestion.itemID)
        self:RemoveFromIgnoredList(suggestion.itemID)
    end
   
    IM:RefreshUI()
    
    -- Update sell list frame if it's open
    if IM_SellListFrame and IM_SellListFrame:IsShown() then
        self:UpdateSellListFrame()
    end
    
    self:SaveVendorList()
end

function IM:RemoveFromVendorList(itemID)
    for i, vendorItem in ipairs(self.vendorList) do
        if vendorItem.itemID == itemID then
            table.remove(self.vendorList, i)
			IM:RefreshUI()
            if IM_SellListFrame and IM_SellListFrame:IsShown() then
                self:UpdateSellListFrame()
            end
            break
        end
    end
	self:SaveVendorList()
end

function IM:ClearVendorList()
    self.vendorList = {}
	IM:RefreshUI()
    if IM_SellListFrame and IM_SellListFrame:IsShown() then
        self:UpdateSellListFrame()
    end
	self:SaveVendorList()
end

function IM:ConfirmDeleteSuggestion(suggestion)
    StaticPopupDialogs["IM_CONFIRM_DELETE_SINGLE"] = {
        text = string.format("Are you sure you want to delete %s? This action cannot be undone!", suggestion.displayName or suggestion.name),
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            IM:DeleteSuggestion(suggestion)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("IM_CONFIRM_DELETE_SINGLE")
end

function IM:DeleteSuggestion(suggestion)
    if InCombatLockdown() then
        print("Inventory Manager: Cannot delete items during combat")
        return
    end
    
    local deletedCount = 0
    local totalItems = 0
    
    for _, location in ipairs(suggestion.locations) do
        local texture, count, locked = GetContainerItemInfo(location.bag, location.slot)
        if texture and not locked then
            local success = pcall(function()
                PickupContainerItem(location.bag, location.slot)
                DeleteCursorItem()
                deletedCount = deletedCount + 1
                totalItems = totalItems + count
            end)
            if not success then
                print("Inventory Manager: Failed to delete item - protected action")
            end
        end
    end
    
    if deletedCount > 0 then
        print(string.format("Inventory Manager: Deleted %s (%d items)", suggestion.displayName or suggestion.name, totalItems))
        -- Log the deletion
        self:LogDeletion(suggestion.link or suggestion.name, totalItems, "manual")
        self:ScheduleRefresh()
    end
end

function IM:ProcessAutoDeleteItems()
    if not self.db.autoDeleteEnabled or #self.autoDeleteList == 0 then
        return
    end
    
    local autoDeleteItemsByID = {}
    for _, item in ipairs(self.autoDeleteList) do
        autoDeleteItemsByID[item.itemID] = item
    end
    
    local deletedSlots = 0
    local deletedItems = {}
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link and not locked then
                local itemID = self:GetItemIDFromLink(link)
                if itemID and autoDeleteItemsByID[itemID] then
                    -- Delete the item
                    PickupContainerItem(bag, slot)
                    DeleteCursorItem()
                    deletedSlots = deletedSlots + 1
                    
                    -- Track deleted items with their links and counts
                    if not deletedItems[link] then
                        deletedItems[link] = 0
                    end
                    deletedItems[link] = deletedItems[link] + count
                end
            end
        end
    end
    
    if deletedSlots > 0 then
        local message = "Inventory Manager: Auto-deleted "
        local firstItem = true
        
        for itemLink, itemCount in pairs(deletedItems) do
            if not firstItem then
                message = message .. ", "
            end
            message = message .. itemLink .. " x" .. itemCount
            firstItem = false
            
            -- Log each auto-deletion
            self:LogDeletion(itemLink, itemCount, "auto")
        end
        
        message = message .. string.format(" (%d slots)", deletedSlots)
        print(message)
    end
end

function IM:ConfirmDeleteAll()
    local suggestions = self:ScanInventory()
    if #suggestions == 0 then
        print("Inventory Manager: No items to delete.")
        return
    end
    
    local totalItems = 0
    for _, suggestion in ipairs(suggestions) do
        totalItems = totalItems + suggestion.totalCount
    end
    
    StaticPopupDialogs["IM_CONFIRM_DELETE_ALL"] = {
        text = string.format("Are you sure you want to delete ALL %d suggested items (%d individual items)? This action cannot be undone!", #suggestions, totalItems),
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            IM:DeleteAllSuggestions()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("IM_CONFIRM_DELETE_ALL")
end

function IM:DeleteAllSuggestions()
    local suggestions = self:ScanInventory()
    local deletedCount = 0
    local totalItems = 0
    
    for _, suggestion in ipairs(suggestions) do
        for _, location in ipairs(suggestion.locations) do
            local texture, count, locked = GetContainerItemInfo(location.bag, location.slot)
            if texture and not locked then
                PickupContainerItem(location.bag, location.slot)
                DeleteCursorItem()
                deletedCount = deletedCount + 1
                totalItems = totalItems + count
            end
        end
    end
    
    if deletedCount > 0 then
        print(string.format("Inventory Manager: Deleted %d items (%d Bag Slots)", totalItems, deletedCount))
        IM:ScheduleRefresh()
    else
        print("Inventory Manager: No items could be deleted.")
    end
end

function IM:RefreshVendorListLocations()
    local vendorItemsByID = {}
    for _, vendorItem in ipairs(self.vendorList) do
        vendorItemsByID[vendorItem.itemID] = vendorItem
        vendorItem.locations = {}
        vendorItem.totalCount = 0
        vendorItem.stackValue = 0
    end
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link and not locked then
                local itemID = self:GetItemIDFromLink(link)
                
                -- Check if this item is in our vendor list
                local vendorItem = vendorItemsByID[itemID]
                if vendorItem then
                    vendorItem.totalCount = vendorItem.totalCount + count
                    -- Recalculate stack value using current sell price
                    local sellPrice = vendorItem.sellPrice or 0
                    vendorItem.stackValue = vendorItem.stackValue + (sellPrice * count / 10000)
                    table.insert(vendorItem.locations, {bag = bag, slot = slot, count = count})
                end
            end
        end
    end
end

function IM:SellVendorItems()
    if #self.vendorList == 0 then
        return
    end
    local totalValue = 0
    local itemsSold = 0
    local stacksSold = 0
    
    -- Track which items were actually sold
    local soldItems = {}
    
    for _, vendorItem in ipairs(self.vendorList) do
        local itemSoldCount = 0
        local itemStackCount = 0
        
        for _, location in ipairs(vendorItem.locations) do
            local texture, count, locked = GetContainerItemInfo(location.bag, location.slot)
            if texture and not locked then
                UseContainerItem(location.bag, location.slot)
                totalValue = totalValue + ((vendorItem.sellPrice or 0) * count / 10000)
                itemsSold = itemsSold + count
                stacksSold = stacksSold + 1
                itemSoldCount = itemSoldCount + count
                itemStackCount = itemStackCount + 1
            end
        end
        
        -- Record if any of this item was sold
        if itemSoldCount > 0 then
            soldItems[vendorItem.itemID] = true
        end
    end
    
    if stacksSold > 0 then
        local totalCopper = math.floor(totalValue * 10000 + 0.5)
        local formattedValue = self:FormatMoneyWithIcons(totalCopper)
        print(string.format("Inventory Manager: Sold %d items (%d slots) for %s", itemsSold, stacksSold, formattedValue))
        
        -- Don't clear the vendor list - keep items for future sales
        -- Just update the locations since we sold some items
        self:RefreshVendorListLocations()
        
        IM:RefreshUI()
        if IM_SellListFrame and IM_SellListFrame:IsShown() then
            self:UpdateSellListFrame()
        end
    end
end

function IM:SaveFramePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    local frameName = frame:GetName()
    
    if frameName == "IM_MainFrame" then
        self.framePositions.main = {point = point, relativePoint = relativePoint, x = x, y = y}
    elseif frameName == "IM_SellListFrame" then
        self.framePositions.sellList = {point = point, relativePoint = relativePoint, x = x, y = y}
    elseif frameName == "IM_IgnoredListFrame" then
        self.framePositions.ignoredList = {point = point, relativePoint = relativePoint, x = x, y = y}
    elseif frameName == "IM_AutoDeleteListFrame" then
        self.framePositions.autoDeleteList = {point = point, relativePoint = relativePoint, x = x, y = y}
    elseif frameName == "IM_SimpleSettingsFrame" then
        self.framePositions.simpleSettings = {point = point, relativePoint = relativePoint, x = x, y = y}
    elseif frameName == "IM_ConfigFrame" then
        self.framePositions.config = {point = point, relativePoint = relativePoint, x = x, y = y}
    end
    
    -- Save to per-character SavedVariables
    IM_FramePositions = self.framePositions
end

function IM:RestoreFramePosition(frame, defaultPoint, defaultX, defaultY)
    local frameName = frame:GetName()
    local position
    
    if frameName == "IM_MainFrame" then
        position = self.framePositions.main
    elseif frameName == "IM_SellListFrame" then
        position = self.framePositions.sellList
    elseif frameName == "IM_IgnoredListFrame" then
        position = self.framePositions.ignoredList
    elseif frameName == "IM_AutoDeleteListFrame" then
        position = self.framePositions.autoDeleteList
    elseif frameName == "IM_SimpleSettingsFrame" then
        position = self.framePositions.simpleSettings
    elseif frameName == "IM_ConfigFrame" then
        position = self.framePositions.config
    end
    
    if position then
        frame:ClearAllPoints()
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        frame:ClearAllPoints()
        frame:SetPoint(defaultPoint, defaultX, defaultY)
    end
end

SLASH_INVENTORYMANAGER1 = "/im"
SLASH_INVENTORYMANAGER2 = "/inventorymanager"

SlashCmdList["INVENTORYMANAGER"] = function(msg)
    -- Only create frames when explicitly commanded
    IM:CreateFrames()
    IM:ShowSuggestions()
end

SLASH_IMSELL1 = "/imsell"
SlashCmdList["IMSELL"] = function(msg)
    if MerchantFrame:IsShown() then
        IM:SellVendorItems()
    else
        print("Inventory Manager: You must be at a vendor to sell items.")
    end
end

SLASH_IMCONFIG1 = "/imconfig"

SlashCmdList["IMCONFIG"] = function(msg)
	IM:ShowConfigFrame()
end

function IM:ForceRefreshItemData()
    -- Clear pending items and reprocess
    self.pendingItems = {}
    self.pendingItemsProcessed = {}
    
    -- Force a complete rescan
    self:RefreshUI()
    
    print("Inventory Manager: Force refreshed item data")
end

-- Add a slash command for manual refresh
SLASH_IMREFRESH1 = "/imrefresh"
SlashCmdList["IMREFRESH"] = function(msg)
    IM:ForceRefreshItemData()
end

function IM:ImproveCheckPendingItems()
    if #self.pendingItems > 0 then
        local stillPending = {}
        local foundItems = false
        
        for _, itemData in ipairs(self.pendingItems) do
            local bag, slot, itemID, link = itemData.bag, itemData.slot, itemData.itemID, itemData.link
            local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
            
            if texture then
                -- Try to get item info again
                local itemName, itemLink, itemRarity = GetItemInfo(itemID or link)
                if itemName and itemName ~= "Unknown Item" then
                    -- Item data is now available, mark for rescan
                    foundItems = true
                    self.pendingItemsProcessed[itemID] = nil
                else
                    table.insert(stillPending, itemData)
                end
            end
        end
        
        self.pendingItems = stillPending
        
        -- If we found items with data now available, force a refresh
        if foundItems then
            IM:ScheduleRefresh()
        end
    end
end

function IM:ScheduleRefresh()
    if not self.refreshTimer then
        self.refreshTimer = CreateFrame("Frame")
        self.refreshTimer:Hide()
        self.refreshTimer:SetScript("OnUpdate", function(self, elapsed)
            self.timeElapsed = (self.timeElapsed or 0) + elapsed
            if self.timeElapsed >= 0.5 then
                -- Check pending items first
				  IM:CleanupPendingItems()
                if IM.pendingItems and #IM.pendingItems > 0 then
                    IM:ImproveCheckPendingItems()
                end
                
                -- Then refresh UI
                IM:RefreshUI()
                
                self.timeElapsed = 0
                self:Hide()
            end
        end)
    end
    
    -- Reset and start timer
    self.refreshTimer.timeElapsed = 0
    self.refreshTimer:Show()
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "InventoryManager" then
            if not IM_ADDON_LOADED then
                IM_ADDON_LOADED = true
                IM:OnInitialize()
                print("Inventory Manager: Initialized successfully")
            end
        end
    elseif event == "MERCHANT_SHOW" then
        if IM and IM.db and IM.db.autoSellAtVendor then
            IM:SellVendorItems()
        end
        if IM and IM.db and IM.db.showSellListAtVendor then
            IM:RefreshVendorListLocations()
            IM:ShowSellListFrame()
        end
    elseif event == "MERCHANT_CLOSED" then
        if IM_SellListFrame and IM_SellListFrame:IsShown() then
            IM_SellListFrame:Hide()
        end
        IM:ScheduleRefresh()
    elseif event == "LOOT_CLOSED" then
        if IM and IM.db and IM.db.autoOpenOnLowSpace then
            IM:CheckBagSpaceAndOpen()
        end
		IM:ProcessAutoDeleteItems()
        IM:ScheduleRefresh()
    elseif event == "BAG_UPDATE" then
        local bagID = ...
        if bagID and bagID >= 0 and bagID <= 4 then
            IM:ScheduleRefresh()
        end
	elseif event == "PLAYER_LOGIN" then
        if IM and IM.UpdateToggleIcon then
            IM:UpdateToggleIcon()
        end
    end
end)

function IM:OnInitialize()
    -- Load configuration first
    if IM_ConfigDB then
        self.db = IM_ConfigDB
        print("Inventory Manager: Loading existing config")
        
        -- Ensure all default config values exist
        for k, v in pairs(self.defaultConfig) do
            if self.db[k] == nil then
                self.db[k] = v
            end
        end
        
        -- FIXED: Ensure ALL trade goods categories exist in the database
        for category, defaultValue in pairs(self.defaultConfig.ignoreTradeGoodsTypes) do
            if self.db.ignoreTradeGoodsTypes[category] == nil then
                self.db.ignoreTradeGoodsTypes[category] = defaultValue
                print(string.format("Inventory Manager: Initializing missing trade goods category: %s = %s", category, tostring(defaultValue)))
            end
        end
        
        -- Ensure quality settings exist
        local qualityKeys = {"POOR", "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "ARTIFACT"}
        for _, qualityKey in ipairs(qualityKeys) do
            if self.db.ignoreQuality[qualityKey] == nil then
                self.db.ignoreQuality[qualityKey] = self.defaultConfig.ignoreQuality[qualityKey] or false
            end
        end
        
        -- Ensure item type settings exist
        for typeName, defaultValue in pairs(self.defaultConfig.ignoreItemTypes) do
            if self.db.ignoreItemTypes[typeName] == nil then
                self.db.ignoreItemTypes[typeName] = defaultValue
            end
        end
		-- Ensure Always  Ignore exist
        for typeName, defaultValue in pairs(self.defaultConfig.alawaysignore) do
            if self.db.alawaysignore[typeName] == nil then
                self.db.alawaysignore[typeName] = defaultValue
            end
        end
		self.db.alawaysignore["Miscellaneous"] = false
        
        -- Ensure trade goods settings exist
        for typeName, defaultValue in pairs(self.defaultConfig.ignoreTradeGoodsTypes) do
            if self.db.ignoreTradeGoodsTypes[typeName] == nil then
                self.db.ignoreTradeGoodsTypes[typeName] = defaultValue
            end
        end
    else
        self.db = self:CopyTable(self.defaultConfig)
        IM_ConfigDB = self.db
    end
    
    self:InitializeDeletionLog()
    
    self:CreateToggleIcon()
    self:CreateSimpleSettingsFrame()
    
    if IM_VendorListDB then
        self.vendorList = IM_VendorListDB
    else
        self.vendorList = self.vendorList or {}
        IM_VendorListDB = self.vendorList
    end
    
    if IM_IgnoredListDB then
        self.ignoredItems = IM_IgnoredListDB
    else
        self.ignoredItems = self.ignoredItems or {}
        IM_IgnoredListDB = self.ignoredItems
    end
    
    if IM_AutoDeleteListDB then
        self.autoDeleteList = IM_AutoDeleteListDB
    else
        self.autoDeleteList = self.autoDeleteList or {}
        IM_AutoDeleteListDB = self.autoDeleteList
    end
	
	self:ValidateAutoDeleteList()
    self:CleanupAutoDeleteList()
    
    if IM_FramePositions then
        for frameName, position in pairs(IM_FramePositions) do
            self.framePositions[frameName] = position
        end
    end
    IM_FramePositions = self.framePositions
    self:ScheduleCleanup()
	
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    print(string.format("Inventory Manager loaded for %s-%s. Use /im or /imconfig.", playerName, realmName))

end

function IM:InitializeDeletionLog()
    if IM_DeletionLogDB then
        self.deletionLog = IM_DeletionLogDB
        
        -- Ensure the deletion log has the proper structure
        if not self.deletionLog.sessions then
            self.deletionLog.sessions = {}
        end
        
        if not self.deletionLog.allTime then
            self.deletionLog.allTime = {}
        end
        
        -- Ensure we have a current session
        if not self.deletionLog.currentSession or not self.deletionLog.sessions[self.deletionLog.currentSession] then
            self:StartNewSession()
        end
        
        -- Clean up old sessions
        self:CleanupOldSessions()
    else
        -- Initialize fresh deletion log
        self.deletionLog = {
            sessions = {},
            allTime = {},
            lastCleanup = time()
        }
        IM_DeletionLogDB = self.deletionLog
        self:StartNewSession()
    end
    
    -- Force a save to ensure the structure is persisted
    self:SaveDeletionLog()
end