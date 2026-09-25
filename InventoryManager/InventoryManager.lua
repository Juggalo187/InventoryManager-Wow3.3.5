local addonName, IM = ...
_G["InventoryManager"] = IM
IM_ADDON_LOADED = false

local function MergeDefaults(target, defaults)
    target = target or {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function IM:InitDB()
    -- Load existing SavedVariables or start fresh
    self.db = IM_ConfigDB or {}
    
    -- Merge default configuration into self.db without overwriting custom settings
    if IM.defaultConfig then
        self.db = MergeDefaults(self.db, IM.defaultConfig)
    end
    
    -- Ensure dynamic user tables exist
    self.db.ignoredItems     = self.db.ignoredItems or {}
    self.db.autoDeleteList   = self.db.autoDeleteList or {}
    self.db.vendorList       = self.db.vendorList or {}
    self.db.framePositions   = self.db.framePositions or {}
    
    -- Align shorthand references on IM
    self.ignoredItems          = self.db.ignoredItems
    self.autoDeleteList        = self.db.autoDeleteList
    self.vendorList            = self.db.vendorList
    self.ignoreItemTypes       = self.db.ignoreItemTypes
    self.ignoreTradeGoodsTypes = self.db.ignoreTradeGoodsTypes
    self.ignoreQuality         = self.db.ignoreQuality
    self.alwaysignore          = self.db.alwaysignore
    
    -- Sync global SavedVariable variable
    IM_ConfigDB = self.db
end

function IM:SaveConfig()
    IM_ConfigDB = self.db
end

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
    alwaysignore = {
        ["Containers"] = true,
        ["Container"] = true,
        ["Currency"] = true,
        ["Keys"] = true,
        ["Glyphs"] = true,
        ["Quivers"] = true,
        ["Projectile"] = true,
    },
    minItemValue = 0.25,
    autoSellAtVendor = false,
    showSellListAtVendor = false,
    autoOpenOnLowSpace = false,
    ignoreGearValue = false,
    freeSlotsThreshold = 1,
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

function IM:ScheduleRefresh()
    if not self.refreshTimer then
        self.refreshTimer = CreateFrame("Frame")
        self.refreshTimer:SetScript("OnUpdate", function(f, elapsed)
            f.elapsed = (f.elapsed or 0) + elapsed
            if f.elapsed >= 0.2 then
                f:SetScript("OnUpdate", nil)
                f.elapsed = 0
                IM:RefreshUI()
            end
        end)
    end
end

function IM:IsValidItemData(itemData)
    if not itemData then
        return false
    end
    
    if not itemData.itemID or type(itemData.itemID) ~= "number" or itemData.itemID <= 0 then
        return false
    end
    
    if not itemData.name and not itemData.displayName then
        return false
    end
    
    return true
end

function IM:ValidateAutoDeleteList()
    self:InitDB()
    local removedCount = 0
    for itemID, item in pairs(self.db.autoDeleteList) do
        if not self:IsValidItemData(item) then
            self.db.autoDeleteList[itemID] = nil
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        print(string.format("Inventory Manager: Removed %d invalid entries from auto-delete list", removedCount))
        self:SaveConfig()
    end
    
    return removedCount
end

-- Export/Import functions for Auto-Delete list
function IM:ExportAutoDeleteList()
    self:InitDB()
    if next(self.db.autoDeleteList) == nil then
        print("Inventory Manager: Auto-delete list is empty, nothing to export.")
        return
    end
    
    local exportData = {
        version = 1,
        timestamp = time(),
        items = {}
    }
    
    for _, item in pairs(self.db.autoDeleteList) do
        table.insert(exportData.items, {
            itemID = item.itemID,
            name = item.name or item.displayName or "Unknown Item",
        })
    end
    
    local exportString = "IM_AutoDelete_Export:" .. self:TableToString(exportData)
    self:ShowExportFrame(exportString, "Auto-Delete List Export")
end

function IM:ShowExportFrame(text, title)
    if not IM_ExportFrame then
        self:CreateExportFrame()
    end
    
    IM_ExportFrame.exportText.originalText = text
    IM_ExportFrame.exportText:SetText(text)
    IM_ExportFrame.exportText:SetCursorPosition(0)
    
    if title then
        IM_ExportFrame.title:SetText(title)
    end
    
    IM_ExportFrame.exportText:HighlightText()
    IM_ExportFrame.exportText:SetFocus()
    
    IM_ExportFrame:Show()
    print("Inventory Manager: Export window opened. Press Ctrl+C to copy the text.")
end

function IM:CreateExportFrame()
    if IM_ExportFrame then return IM_ExportFrame end
    
    local frame = CreateFrame("Frame", "IM_ExportFrame", UIParent)
    frame:SetSize(500, 350)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.9)
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Export Auto-Delete List")
    
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    frame.scroll = CreateFrame("ScrollFrame", "IM_ExportScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 15, -40)
    frame.scroll:SetPoint("BOTTOMRIGHT", -35, 45)
    
    frame.exportText = CreateFrame("EditBox", nil, frame.scroll)
    frame.exportText:SetMultiLine(true)
    frame.exportText:SetFontObject("GameFontHighlight")
    frame.exportText:SetWidth(440)
    frame.exportText:SetHeight(200)
    frame.exportText:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.scroll:SetScrollChild(frame.exportText)
    
    local closeBottomBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBottomBtn:SetSize(90, 22)
    closeBottomBtn:SetPoint("BOTTOM", 0, 12)
    closeBottomBtn:SetText("Close")
    closeBottomBtn:SetScript("OnClick", function() frame:Hide() end)
    
    IM_ExportFrame = frame
    return frame
end

function IM:ImportAutoDeleteList(importString)
    if not importString or importString == "" then
        self:ShowImportMessage("No import data provided.", true)
        return false
    end
    
    if not strfind(importString, "IM_AutoDelete_Export:") then
        self:ShowImportMessage("Invalid import format. Please use a valid export string.", true)
        return false
    end
    
    local dataString = strsub(importString, 21)
    local success, importData = pcall(self.StringToTable, self, dataString)
    
    if not success or not importData or not importData.items then
        self:ShowImportMessage("Failed to parse import data. The string may be corrupted.", true)
        return false
    end
    
    self:InitDB()
    local importedCount = 0
    local skippedCount = 0
    
    for _, itemData in ipairs(importData.items) do
        if itemData.itemID then
            if not self.db.autoDeleteList[itemData.itemID] then
                self.db.autoDeleteList[itemData.itemID] = {
                    itemID = itemData.itemID,
                    name = itemData.name or "Unknown Item",
                    quality = 1,
                    texture = "Interface\\Icons\\INV_Misc_QuestionMark"
                }
                importedCount = importedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end
    
    self:SaveConfig()
    self:RefreshUI()
    if IM_AutoListFrame and IM_AutoListFrame:IsShown() then
        IM:UpdateAutoListFrame()
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
    
    if IM_ImportFrame and IM_ImportFrame.infoText then
        IM_ImportFrame.infoText:SetText(message)
        if isError then
            IM_ImportFrame.infoText:SetTextColor(1, 0.5, 0.5)
        else
            IM_ImportFrame.infoText:SetTextColor(0.5, 1, 0.5)
        end
    end
end

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
    if IM_ImportFrame then return IM_ImportFrame end
    
    local frame = CreateFrame("Frame", "IM_ImportFrame", UIParent)
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(true)
    frame.bg:SetTexture(0, 0, 0, 0.9)
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("Import Auto-Delete List")
    
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(32, 32)
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    frame.instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.instructions:SetPoint("TOP", 0, -30)
    frame.instructions:SetText("Paste your auto-delete list export string below:")
    
    frame.scroll = CreateFrame("ScrollFrame", "IM_ImportScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -55)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 80)
    
    frame.importText = CreateFrame("EditBox", nil, frame.scroll)
    frame.importText:SetMultiLine(true)
    frame.importText:SetFontObject("GameFontHighlight")
    frame.importText:SetWidth(440)
    frame.importText:SetHeight(200)
    frame.importText:SetAutoFocus(true)
    frame.importText:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.scroll:SetScrollChild(frame.importText)
    
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
    
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(80, 25)
    frame.clearBtn:SetPoint("BOTTOM", 0, 10)
    frame.clearBtn:SetText("Clear")
    frame.clearBtn:SetScript("OnClick", function()
        frame.importText:SetText("")
        frame.importText:SetFocus()
    end)
    
    frame.closeBottomBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.closeBottomBtn:SetSize(80, 25)
    frame.closeBottomBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    closeBottomBtn:SetText("Close")
    closeBottomBtn:SetScript("OnClick", function() frame:Hide() end)
    
    frame.infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.infoText:SetPoint("BOTTOM", 0, 35)
    frame.infoText:SetText("Paste your export string and click Import")
    frame.infoText:SetTextColor(0.8, 0.8, 0.8)
    
    IM_ImportFrame = frame
    return frame
end

function IM:TableToString(tbl)
    local parts = {}
    if tbl.version then table.insert(parts, "v=" .. tbl.version) end
    if tbl.timestamp then table.insert(parts, "t=" .. tbl.timestamp) end
    
    if tbl.items then
        local itemParts = {}
        for _, item in ipairs(tbl.items) do
            if item.itemID then
                local escapedName = string.gsub(item.name or "", ":", "\\:")
                table.insert(itemParts, item.itemID .. ":" .. escapedName)
            end
        end
        table.insert(parts, "i=" .. table.concat(itemParts, ","))
    end
    
    return table.concat(parts, "|")
end

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
    local cleanupThreshold = 300
    
    for itemID, timestamp in pairs(self.pendingItemsProcessed) do
        if now - timestamp > cleanupThreshold then
            self.pendingItemsProcessed[itemID] = nil
        end
    end
    
    local stillPending = {}
    for _, itemData in ipairs(self.pendingItems) do
        if now - (itemData.addedTime or 0) < cleanupThreshold then
            table.insert(stillPending, itemData)
        end
    end
    self.pendingItems = stillPending
end

function IM:CleanupAutoDeleteList()
    self:InitDB()
    self:ValidateAutoDeleteList()
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
        ["Cloth"] = "Cloth",
        ["Bolt of Cloth"] = "Cloth",
        ["Leather"] = "Leather",
        ["Hide"] = "Leather",
        ["Scale"] = "Leather",
        ["Ore"] = "Metal",
        ["Bar"] = "Metal",
        ["Metal"] = "Metal",
        ["Stone"] = "Stone",
        ["Meat"] = "Meat",
        ["Mutton"] = "Meat",
        ["Pork"] = "Meat",
        ["Beef"] = "Meat",
        ["Chicken"] = "Meat",
        ["Herb"] = "Herb",
        ["Flower"] = "Herb",
        ["Elemental"] = "Elemental",
        ["Fire"] = "Elemental",
        ["Water"] = "Elemental",
        ["Air"] = "Elemental",
        ["Earth"] = "Elemental",
        ["Enchanting"] = "Enchanting",
        ["Dust"] = "Enchanting",
        ["Essence"] = "Enchanting",
        ["Shard"] = "Enchanting",
        ["Jewelcrafting"] = "Jewelcrafting",
        ["Gem"] = "Jewelcrafting",
        ["Inscription"] = "Inscription",
        ["Pigment"] = "Inscription",
        ["Ink"] = "Inscription",
        ["Scroll"] = "Inscription",
        ["Glyph"] = "Inscription",
        ["Item Enhancement"] = "Inscription",
        ["Parts"] = "Parts",
        ["Explosives"] = "Parts",
        ["Devices"] = "Parts",
    }
    
    if subType == "Metal & Stone" then
        if itemName then
            local lowerName = itemName:lower()
            if string.find(lowerName, "stone") or string.find(lowerName, "rock") or string.find(lowerName, "pebble") then
                return "Stone"
            elseif string.find(lowerName, "ore") or string.find(lowerName, "bar") or string.find(lowerName, "ingot") or 
                   string.find(lowerName, "copper") or string.find(lowerName, "tin") or string.find(lowerName, "iron") or
                   string.find(lowerName, "mithril") or string.find(lowerName, "thorium") or string.find(lowerName, "fel iron") or
                   string.find(lowerName, "cobalt") or string.find(lowerName, "saronite") then
                return "Metal"
            end
        end
        return "Stone"
    end
    
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
    local oneMonthAgo = now - (30 * 24 * 60 * 60)
    
    for sessionId, sessionData in pairs(self.deletionLog.sessions) do
        if sessionData.startTime < oneMonthAgo then
            self.deletionLog.sessions[sessionId] = nil
        end
    end
    
    self.deletionLog.lastCleanup = now
end

function IM:LogDeletion(itemLink, itemCount, deletionType)
    if not self.db.deletionLogEnabled then return end
    
    if not self.deletionLog then
        self.deletionLog = { sessions = {}, allTime = {}, lastCleanup = time() }
        self:StartNewSession()
    end
    
    local itemID = self:GetItemIDFromLink(itemLink)
    if not itemID then 
        return 
    end
    
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
    
    local currentSession = self.deletionLog.sessions[self.deletionLog.currentSession]
    if currentSession then
        local foundExisting = false
        for _, existingDeletion in ipairs(currentSession.deletions) do
            if existingDeletion.itemID == itemID and existingDeletion.deletionType == deletionType then
                if deletionEntry.timestamp - existingDeletion.timestamp < 300 then
                    existingDeletion.itemCount = existingDeletion.itemCount + itemCount
                    existingDeletion.timestamp = deletionEntry.timestamp
                    foundExisting = true
                    break
                end
            end
        end
        
        if not foundExisting then
            table.insert(currentSession.deletions, deletionEntry)
        end
    end
    
    if not self.deletionLog.allTime then
        self.deletionLog.allTime = {}
    end
    
    local foundExistingAllTime = false
    for _, existingDeletion in ipairs(self.deletionLog.allTime) do
        if existingDeletion.itemID == itemID and existingDeletion.deletionType == deletionType then
            if deletionEntry.timestamp - existingDeletion.timestamp < 300 then
                existingDeletion.itemCount = existingDeletion.itemCount + itemCount
                existingDeletion.timestamp = deletionEntry.timestamp
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

function IM:CheckBagSpaceAndOpen()
    self:InitDB()
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
    
    local freeSlots = totalBagSlots - usedBagSlots
    if freeSlots <= (self.db.freeSlotsThreshold or 1) then
        local merchantShowing = MerchantFrame and MerchantFrame:IsShown()
        if not (IM_MainFrame and IM_MainFrame:IsShown()) and not merchantShowing then
            self:CreateFrames()
            self:ShowSuggestions()
            print(string.format("Inventory Manager: Auto-opened (only %d free slots)", freeSlots))
        end
    end
end

function IM:RefreshUI()
    if IM_MainFrame and IM_MainFrame:IsShown() then
        self:ShowSuggestions()
    end

    if IM_SellListFrame and IM_SellListFrame:IsShown() then
        self:UpdateSellListFrame()
    end

    if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
        self:UpdateIgnoredListFrame()
    end

    if IM_AutoListFrame and IM_AutoListFrame:IsShown() then
        self:UpdateAutoListFrame()
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
    local itemID = string.match(link, "item:(%d+):") or string.match(link, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

function IM:GetItemLocations(itemID)
    local locations = {}
    local totalCount = 0
    local stackValue = 0

    local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(itemID)
    local sellPrice = price or 0

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link then
                local id = self:GetItemIDFromLink(link)
                if id == itemID then
                    table.insert(locations, {bag = bag, slot = slot, count = count})
                    totalCount = totalCount + count
                    stackValue = stackValue + (sellPrice * count / 10000)
                end
            end
        end
    end

    return locations, totalCount, stackValue
end

function IM:ScanInventory()
    self:CleanupPendingItems()
    self:InitDB()

    local suggestions = {}
    local totalBagSlots = 0
    local usedBagSlots = 0
    local playerGold = GetMoney() / 10000
    local playerLevel = UnitLevel("player")
    local _, playerClass = UnitClass("player")
    local itemsByID = {}
    
    self.pendingItems = {}
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        totalBagSlots = totalBagSlots + slots
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link then
                usedBagSlots = usedBagSlots + 1
                local itemID = self:GetItemIDFromLink(link)
                
                if itemID then
                    -- Direct map lookup for items in Sell, Ignore, or Auto lists
                    local isInAnyList = self.db.vendorList[itemID] 
                                     or self.db.ignoredItems[itemID] 
                                     or self.db.autoDeleteList[itemID]
                    
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
        local priceA = a.sellPrice or 0
        local priceB = b.sellPrice or 0
        if priceA == priceB then
            return (a.name or "") < (b.name or "")
        end
        return priceA < priceB
    end)
    
    return suggestions, totalBagSlots, usedBagSlots
end

function IM:AnalyzeItem(bag, slot, itemID, count, quality, link, playerGold, playerLevel, playerClass)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID or link)
    
    local usingFallbackData = false
    if not itemName or not itemType or itemType == "" then
        usingFallbackData = true
        itemName = string.match(link or "", "%[(.-)%]") or "Unknown Item"
        itemType = itemType or "Unknown"
        itemSubType = itemSubType or "Unknown"
        
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
        displayName = string.match(link or "", "%[(.-)%]") or itemName,
        usingFallbackData = usingFallbackData
    }
    
    if usingFallbackData then
        itemInfo.shouldSuggestDelete = false
        itemInfo.reason = "Incomplete item data - waiting for full info"
        return itemInfo
    end
	
    if actualQuality >= 3 then
        return nil
    end
	
    local importantItems = {
        "Hearthstone", "Astral Recall", "Innkeeper's Daughter", "Insignia of the", "Medallion of the",
        "Battlemaster's", "Gladiator's", "Key to", "Key of", "Skeleton Key", "Mining Pick", "Skinning Knife",
        "Blacksmith Hammer", "Runed Copper Rod", "Arclight Spanner", "Fishing Pole", "Aquadynamic Fish",
        "Bright Baubles", "Shiny Baubles", "Soul Shard", "Ankh", "Symbol of", "Rune of", "Totem of",
        "Libram of", "Idol of", "Sigil of", "Argent Dawn Commission", "Seal of Ascension", "Scepter of Celebras",
        "Mallet of Zul'Farrak", "Staff of Escorte", "Attuned Crystal", "The Master's Key", "Key to the Focusing Iris",
        "Heroic Key", "Dragon Eye", "Scarab", "Scepter of the Shifting Sands", "Gnomish Army Knife",
        "Goblin Rocket Boots", "Jeeves", "MOLL-E", "Wormhole Generator", "Blingtron", "Elixir of Giant Growth",
        "Noggenfogger Elixir", "Savory Deviate Delight", "Gnomish Mind Control Cap", "Piccolo of the Flaming Fire",
        "World Enlarger", "Time-Lost Figurine", "Orb of Deception", "Badge of Justice", "Emblem of",
        "Honor Points", "Arena Points", "Guild Charter",
    }
    
    local isConsumableTradeGood = false
    if itemInfo.type == "Trade Goods" and (itemInfo.subType == "Meat" or itemInfo.subType == "Fish") then
        local hasUseEffect = false
        local tooltip = CreateFrame("GameTooltip", "IMTempTooltip", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetHyperlink(itemInfo.link or link)
        
        for i = 2, 4 do
            local text = _G["IMTempTooltipTextLeft"..i] and _G["IMTempTooltipTextLeft"..i]:GetText()
            if text and (string.find(text, "Use:") or string.find(text, "Restores") or string.find(text, "Consumable")) then
                hasUseEffect = true
                break
            end
        end
        
        tooltip:Hide()
        
        if hasUseEffect then
            isConsumableTradeGood = true
            itemInfo.type = "Consumable"
        end
    end
	
    if self.db.ignoreItemTypes[itemInfo.type] then
        return nil
    end
	
    if self.db.alwaysignore and self.db.alwaysignore[itemInfo.type] then
        return nil
    end
	
    local isGear = gearSlots[itemEquipLoc]
    local minItemValueCopper = (self.db.minItemValue or 0) * 10000
    local itemValueCopper = (itemInfo.sellPrice or 0)

    if isGear then
        local qualityKey = self:GetQualityKey(actualQuality)
        
        if self.db.ignoreQuality[qualityKey] then
            return nil
        end
        
        if self.db.ignoreGearValue then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 2
            itemInfo.reason = "Gear (value ignored)"
        else
            if itemValueCopper < minItemValueCopper then
                itemInfo.shouldSuggestDelete = true
                itemInfo.priority = 2
                itemInfo.reason = "Low value gear"
            else
                itemInfo.shouldSuggestDelete = false
            end
        end
    end
	
    if actualQuality == 0 and not isGear then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 1
            itemInfo.reason = "Vendor trash"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
	
    if itemInfo.type == "Trade Goods" and not isConsumableTradeGood then
        local tradeGoodsCategory = self:GetTradeGoodsCategory(itemInfo.subType, itemInfo.name)
        
        if itemInfo.subType == "Other" then
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
    
    if itemInfo.type == "Recipe" then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 4
            itemInfo.reason = "Low value Recipe"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
    
    if itemInfo.type == "Consumable" or isConsumableTradeGood then
        if itemValueCopper < minItemValueCopper then
            itemInfo.shouldSuggestDelete = true
            itemInfo.priority = 5
            itemInfo.reason = "Low value consumable"
        else
            itemInfo.shouldSuggestDelete = false
        end
    end
	
    if itemInfo.type == "Miscellaneous" then
        if actualQuality == 0 then
            if itemValueCopper < minItemValueCopper then
                itemInfo.shouldSuggestDelete = true
                itemInfo.priority = 6
                itemInfo.reason = "Low value Misc Item"
            else
                itemInfo.shouldSuggestDelete = false
            end
        else
            return nil
        end
    end
	
    for _, importantName in ipairs(importantItems) do
        if itemInfo.name and string.find(itemInfo.name, importantName) then
            itemInfo.shouldSuggestDelete = false
            itemInfo.reason = "Important item - never delete"
            break
        end
    end

    if not itemInfo.shouldSuggestDelete and itemInfo.type ~= "Quest" then
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

-- Persistent List Data Handlers
function IM:AddToAutoDeleteList(item)
    self:InitDB()
    local itemID = type(item) == "table" and item.itemID or item
    if itemID then
        local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        self.db.autoDeleteList[itemID] = {
            itemID = itemID,
            name = (type(item) == "table" and (item.displayName or item.name)) or name or ("Item #" .. itemID),
            quality = (type(item) == "table" and item.quality) or quality or 1,
            texture = (type(item) == "table" and item.texture) or texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        }
        self:RemoveFromVendorList(itemID)
        self:RemoveFromIgnoredList(itemID)
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:RemoveFromAutoDeleteList(itemID)
    self:InitDB()
    if type(itemID) == "table" then itemID = itemID.itemID end
    if itemID and self.db.autoDeleteList[itemID] then
        self.db.autoDeleteList[itemID] = nil
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:ClearAutoDeleteList()
    self:InitDB()
    self.db.autoDeleteList = {}
    self.autoDeleteList = self.db.autoDeleteList
    self:SaveConfig()
    self:RefreshUI()
    if IM_AutoListFrame and IM_AutoListFrame:IsShown() then
        IM:UpdateAutoListFrame()
    end
    print("Inventory Manager: Auto-delete list cleared")
end

function IM:AddToIgnoredList(item)
    self:InitDB()
    local itemID = type(item) == "table" and item.itemID or item
    if itemID then
        local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        self.db.ignoredItems[itemID] = {
            itemID = itemID,
            name = (type(item) == "table" and (item.displayName or item.name)) or name or ("Item #" .. itemID),
            quality = (type(item) == "table" and item.quality) or quality or 1,
            texture = (type(item) == "table" and item.texture) or texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        }
        self:RemoveFromVendorList(itemID)
        self:RemoveFromAutoDeleteList(itemID)
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:RemoveFromIgnoredList(itemID)
    self:InitDB()
    if type(itemID) == "table" then itemID = itemID.itemID end
    if itemID and self.db.ignoredItems[itemID] then
        self.db.ignoredItems[itemID] = nil
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:ClearIgnoredList()
    self:InitDB()
    self.db.ignoredItems = {}
    self.ignoredItems = self.db.ignoredItems
    self:SaveConfig()
    self:RefreshUI()
    if IM_IgnoredListFrame and IM_IgnoredListFrame:IsShown() then
        self:UpdateIgnoredListFrame()
    end
end

function IM:AddToVendorList(item)
    self:InitDB()
    local itemID = type(item) == "table" and item.itemID or item
    if itemID then
        local name, link, quality, _, _, _, _, _, _, texture, sellPrice = GetItemInfo(itemID)
        
        -- Fallback to passed table data if GetItemInfo is uncached at the moment
        self.db.vendorList[itemID] = {
            itemID = itemID,
            name = (type(item) == "table" and (item.displayName or item.name)) or name or ("Item #" .. itemID),
            link = (type(item) == "table" and item.link) or link,
            quality = (type(item) == "table" and item.quality) or quality or 1,
            texture = (type(item) == "table" and item.texture) or texture or "Interface\\Icons\\INV_Misc_QuestionMark",
            sellPrice = (type(item) == "table" and item.sellPrice) or sellPrice or 0,
            totalCount = (type(item) == "table" and item.totalCount) or 1,
            stackValue = (type(item) == "table" and item.stackValue) or 0,
            bag = type(item) == "table" and item.bag,
            slot = type(item) == "table" and item.slot,
        }
        self:RemoveFromIgnoredList(itemID)
        self:RemoveFromAutoDeleteList(itemID)
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:RemoveFromVendorList(itemID)
    self:InitDB()
    if type(itemID) == "table" then itemID = itemID.itemID end
    if itemID and self.db.vendorList[itemID] then
        self.db.vendorList[itemID] = nil
        self:SaveConfig()
        self:RefreshUI()
    end
end

function IM:ClearVendorList()
    self:InitDB()
    self.db.vendorList = {}
    self.vendorList = self.db.vendorList
    self:SaveConfig()
    self:RefreshUI()
    if IM_SellListFrame and IM_SellListFrame:IsShown() then
        self:UpdateSellListFrame()
    end
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
        self:LogDeletion(suggestion.link or suggestion.name, totalItems, "manual")
        self:ScheduleRefresh()
    end
end

function IM:ProcessAutoDeleteItems()
    self:InitDB()
    if not self.db.autoDeleteEnabled or not next(self.db.autoDeleteList) then
        return
    end
    
    local deletedSlots = 0
    local deletedItems = {}
    
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and link and not locked then
                local itemID = self:GetItemIDFromLink(link)
                if itemID and self.db.autoDeleteList[itemID] then
                    PickupContainerItem(bag, slot)
                    DeleteCursorItem()
                    deletedSlots = deletedSlots + 1
                    
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
                local success = pcall(function()
                    PickupContainerItem(location.bag, location.slot)
                    DeleteCursorItem()
                    deletedCount = deletedCount + 1
                    totalItems = totalItems + count
                end)
                if success then
                    self:LogDeletion(suggestion.link or suggestion.name, count, "manual")
                end
            end
        end
    end
    
    if deletedCount > 0 then
        print(string.format("Inventory Manager: Deleted %d items (%d Bag Slots)", totalItems, deletedCount))
        self:ScheduleRefresh()
    else
        print("Inventory Manager: No items could be deleted.")
    end
end

function IM:RefreshVendorListLocations()
    self:InitDB()
    local vendorItemsByID = {}
    for _, vendorItem in pairs(self.db.vendorList) do
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
                
                local vendorItem = vendorItemsByID[itemID]
                if vendorItem then
                    vendorItem.totalCount = vendorItem.totalCount + count
                    local sellPrice = vendorItem.sellPrice or 0
                    vendorItem.stackValue = vendorItem.stackValue + (sellPrice * count / 10000)
                    table.insert(vendorItem.locations, {bag = bag, slot = slot, count = count})
                end
            end
        end
    end
end

function IM:SellVendorItems()
    self:RefreshVendorListLocations()
    
    local totalValue = 0
    local itemsSold = 0
    local stacksSold = 0

    local function SellSlot(bag, slot, sellPrice, count)
        local texture, countInSlot, locked = GetContainerItemInfo(bag, slot)
        if texture and not locked then
            UseContainerItem(bag, slot)
            local value = (sellPrice or 0) * (countInSlot or count or 1) / 10000
            totalValue = totalValue + value
            itemsSold = itemsSold + (countInSlot or count or 1)
            stacksSold = stacksSold + 1
            return true
        end
        return false
    end

    for _, vendorItem in pairs(self.db.vendorList) do
        if vendorItem.locations then
            for _, location in ipairs(vendorItem.locations) do
                SellSlot(location.bag, location.slot, vendorItem.sellPrice, vendorItem.totalCount)
            end
        end
    end

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, count, locked, qualityFromLink, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if texture and not locked and link then
                local itemID = self:GetItemIDFromLink(link)
                if itemID then
                    local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                    if itemQuality == 0 and sellPrice and sellPrice > 0 then
                        SellSlot(bag, slot, sellPrice, count)
                    end
                end
            end
        end
    end

    if stacksSold > 0 then
        local totalCopper = math.floor(totalValue * 10000 + 0.5)
        local formattedValue = self:FormatMoneyWithIcons(totalCopper)
        print(string.format("Inventory Manager: Sold %d items (%d slots) for %s", itemsSold, stacksSold, formattedValue))

        self:RefreshVendorListLocations()
        IM:RefreshUI()
        if IM_SellListFrame and IM_SellListFrame:IsShown() then
            self:UpdateSellListFrame()
        end
    else
        print("Inventory Manager: No items to sell.")
    end
end

function IM:SaveFramePosition(frame, frameKey)
    if not frame then return end
    
    local name = frameKey or (frame:GetName() and string.gsub(frame:GetName(), "IM_", ""))
    if not name then return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    self:InitDB()
    self.db.framePositions = self.db.framePositions or {}
    self.db.framePositions[name] = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0
    }
    self:SaveConfig()
end

function IM:RestoreFramePosition(frame, defaultPoint, defaultX, defaultY)
    if not frame then return end
    
    self:InitDB()
    defaultPoint = defaultPoint or "CENTER"
    defaultX = defaultX or 0
    defaultY = defaultY or 0
    
    local frameName = frame:GetName()
    local frameKey = frameName and string.gsub(frameName, "IM_", "")
    
    if frameKey and self.db.framePositions and self.db.framePositions[frameKey] then
        local pos = self.db.framePositions[frameKey]
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or defaultPoint, UIParent, pos.relativePoint or defaultPoint, pos.x or defaultX, pos.y or defaultY)
    else
        frame:ClearAllPoints()
        frame:SetPoint(defaultPoint, UIParent, defaultPoint, defaultX, defaultY)
    end
end

---------------------------------------------------------
-- Slash Command Handling (/im, /inventorymanager)
---------------------------------------------------------
SLASH_INVENTORYMANAGER1 = "/im"
SLASH_INVENTORYMANAGER2 = "/inventorymanager"

SlashCmdList["INVENTORYMANAGER"] = function(msg)
    local command = msg and string.lower(string.trim(msg)) or ""
    
    -- Ensure DB is initialized before scanning or showing UI
    if not IM.db then
        IM:InitDB()
    end

    if command == "config" or command == "options" then
        IM:ShowConfigFrame()
    elseif command == "settings" then
        IM:ShowSimpleSettings()
    else
        if IM_MainFrame and IM_MainFrame:IsShown() then
            IM_MainFrame:Hide()
        else
            IM:CreateFrames()
            IM:ShowSuggestions()
        end
    end
end

---------------------------------------------------------
-- Event Loading & Minimap/Screen Toggle Icon Setup
---------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE")
-- Add merchant events:
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        IM:InitDB()
        if IM_DeletionLogDB then
            IM.deletionLog = IM_DeletionLogDB
        end
        IM_ADDON_LOADED = true
        self:UnregisterEvent("ADDON_LOADED")
        
    elseif event == "PLAYER_LOGIN" then
        if IM.CreateToggleIcon then
            local icon = IM:CreateToggleIcon()
            if icon then icon:Show() end
        end
        if IM.ScheduleCleanup then IM:ScheduleCleanup() end
        if IM.ScheduleRefresh then IM:ScheduleRefresh() end
        
    elseif event == "BAG_UPDATE" then
        if IM_ADDON_LOADED and IM.db then
            if IM.CheckBagSpaceAndOpen then IM:CheckBagSpaceAndOpen() end
            if IM.ProcessAutoDeleteItems then IM:ProcessAutoDeleteItems() end
        end

    -- Add vendor event handling:
    elseif event == "MERCHANT_SHOW" then
        if IM_ADDON_LOADED and IM.db and IM.db.enabled then
            -- Auto-sell configured items if enabled
            if IM.db.autoSellAtVendor then
                IM:SellVendorItems()
            end
            
            -- Show Sell List panel if enabled
            if IM.db.showSellListAtVendor then
                IM:ShowSellListFrame()
            end
        end

    elseif event == "MERCHANT_CLOSED" then
        if IM_SellListFrame and IM_SellListFrame:IsShown() then
            IM_SellListFrame:Hide()
        end
    end
end)