local addonName, IM = ...

function IM:StyleFrame(frame, width, height, titleText)
    frame:SetSize(width, height)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if IM.SaveFramePosition then
            IM:SaveFramePosition(self)
        end
    end)

    -- Background & Border
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)

    -- Header Bar
    if titleText then
        frame.header = frame:CreateTexture(nil, "ARTWORK")
        frame.header:SetPoint("TOPLEFT", 4, -4)
        frame.header:SetPoint("TOPRIGHT", -4, -4)
        frame.header:SetHeight(24)
        frame.header:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.header:SetGradientAlpha("VERTICAL", 0.15, 0.15, 0.20, 1, 0.10, 0.10, 0.12, 1)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("LEFT", frame.header, "LEFT", 10, 0)
        frame.title:SetText(titleText)
        frame.title:SetTextColor(0.9, 0.9, 0.9)
    end

    -- Close Button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetSize(26, 26)
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -3)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
end

function IM:CreateDivider(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 15, yOffset)
    line:SetPoint("TOPRIGHT", -15, yOffset)
    line:SetHeight(1)
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(0.2, 0.2, 0.25, 0.8)
    return line
end