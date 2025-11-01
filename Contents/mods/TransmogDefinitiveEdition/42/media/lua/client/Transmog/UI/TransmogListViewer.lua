-- TransmogListViewer.lua
-- Build 42.x
--
-- Standalone, safe transmog picker UI.
-- Goal: look/behave similarly to the admin Items List Viewer, BUT:
--   - Only shows valid cosmetic targets (respect sandbox same-slot if enabled)
--   - Lets you preview+apply on double-click
--   - Has sortable-style columns, filter widgets, total count, footer Close.
--
-- Columns:
--   Type | Name | Category | DisplayCategory
--
-- NOTE: requires TransmogDE.isTransmoggable(), TransmogDE.immersiveModeItemCheck(),
--       TransmogDE.setItemTransmog(), TransmogDE.forceUpdateClothing()
--
-- All DebugLog/log spam removed for final polish.
--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"

---------------------------------
-- helpers
---------------------------------

local function _safeStr(x)
    if x == nil then return "" end
    return tostring(x)
end

local function _lower(s)
    if not s then return "" end
    return string.lower(tostring(s))
end

-- vanilla-style text clamp (we can't assume drawTextClamped exists in B42)
local function _drawClampedText(el, txt, x, y, maxW, r,g,b,a, font)
    txt = _safeStr(txt)

    local tm = getTextManager()
    local w = tm:MeasureStringX(font, txt)

    if w <= maxW then
        el:drawText(txt, x, y, r,g,b,a, font)
        return
    end

    local ell = "…"
    local cut = txt
    while #cut > 0 do
        cut = string.sub(cut, 1, #cut - 1)
        local test = cut .. ell
        local tw = tm:MeasureStringX(font, test)
        if tw <= maxW then
            el:drawText(test, x, y, r,g,b,a, font)
            return
        end
    end
    el:drawText("…", x, y, r,g,b,a, font)
end

-- convert a set {["Clothing"]=true,...} → sorted array
local function _sortedListFromSet(setTbl)
    local arr = {}
    for k,_ in pairs(setTbl) do
        table.insert(arr, k)
    end
    table.sort(arr, function(a,b) return a < b end)
    return arr
end

-- sort rows by prettyName ascending; fallback to typeStr
local function _sortRowsByName(rows)
    table.sort(rows, function(a,b)
        local an = a.prettyName or a.typeStr or ""
        local bn = b.prettyName or b.typeStr or ""
        -- lowercase compare so case doesn't bounce items around
        an = string.lower(an)
        bn = string.lower(bn)
        if an == bn then
            -- stable tie-break by full type
            local at = a.typeStr or ""
            local bt = b.typeStr or ""
            return string.lower(at) < string.lower(bt)
        end
        return an < bn
    end)
end

---------------------------------
-- column layout config
---------------------------------
local COLS = {
    { id="typeStr",    label="Type",            w=230 },
    { id="prettyName", label="Name",            w=260 },
    { id="cat",        label="Category",        w=210 },
    { id="dispCat",    label="DisplayCategory", w=240 },
}

---------------------------------
-- scrolling list widget
---------------------------------
TransmogListViewer_List = ISScrollingListBox:derive("TransmogListViewer_List")

function TransmogListViewer_List:new(x, y, w, h)
    local o = ISScrollingListBox.new(self, x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.font = UIFont.Small
    local fontH = getTextManager():getFontHeight(o.font)
    o.itemheight = fontH + 4
    o.drawBorder = true
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.doDrawItem = TransmogListViewer_List.doDrawItem
    return o
end

-- vanilla-y row draw (alt line shading, vertical grid lines, bottom border)
function TransmogListViewer_List:doDrawItem(y, item, alt)
    local row = item.item
    local r,g,b,a = 1,1,1,1

    if self.selected == item.index then
        -- selected (brown-ish highlight, like admin viewer)
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.6, 0.5,0.3,0.25)
    elseif alt then
        -- alternating subtle dark wash
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.2,0.2,0.2,0.10)
    end

    local padX  = 6
    local curX  = padX
    local textY = y + 2
    local font  = self.font

    -- col 1
    _drawClampedText(self, row.typeStr,    curX, textY, COLS[1].w - padX, r,g,b,a, font)
    curX = curX + COLS[1].w
    self:drawRect(curX-1, y, 1, self.itemheight, 1, 0.25,0.25,0.25)

    -- col 2
    _drawClampedText(self, row.prettyName, curX + padX, textY, COLS[2].w - padX, r,g,b,a, font)
    curX = curX + COLS[2].w
    self:drawRect(curX-1, y, 1, self.itemheight, 1, 0.25,0.25,0.25)

    -- col 3
    _drawClampedText(self, row.cat,        curX + padX, textY, COLS[3].w - padX, r,g,b,a, font)
    curX = curX + COLS[3].w
    self:drawRect(curX-1, y, 1, self.itemheight, 1, 0.25,0.25,0.25)

    -- col 4
    _drawClampedText(self, row.dispCat,    curX + padX, textY, COLS[4].w - padX, r,g,b,a, font)

    -- bottom rule
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight, 0.5, 0.4,0.4,0.4)

    return y + self.itemheight
end

function TransmogListViewer_List:onMouseDoubleClick(x, y)
    if not self.parentViewer or not self.parentViewer.applyTransmogFromRow then return end
    local row = self.items[self.selected]
    if not row or not row.item then return end
    self.parentViewer:applyTransmogFromRow(row.item)
end

---------------------------------
-- header strip ("Type | Name | ...")
---------------------------------
local TransmogListViewer_Header = ISPanel:derive("TransmogListViewer_Header")

function TransmogListViewer_Header:new(x,y,w,h)
    local o = ISPanel.new(self, x,y,w,h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function TransmogListViewer_Header:prerender()
    ISPanel.prerender(self)

    -- brown-ish bar like admin viewer
    self:drawRect(0, 0, self.width, self.height, 1, 0.15,0.10,0.05)
    self:drawRectBorder(0, 0, self.width, self.height, 0.9, 0.5,0.4,0.3)

    local font  = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local textY = math.floor((self.height - fontH) / 2)
    local curX  = 6
    local r,g,b,a = 1,1,1,1

    for _,col in ipairs(COLS) do
        self:drawText(col.label, curX, textY, r,g,b,a, font)
        curX = curX + col.w
        -- column divider
        self:drawRect(curX-1, 0, 1, self.height, 1, 0.35,0.3,0.25)
    end
end

---------------------------------
-- FiltersPanel
-- Matches admin-style behavior:
-- one horizontal row of widgets (2 text boxes + 2 combos),
-- Medium font, tall enough so text isn't clipped,
-- and live refilter on any change.
---------------------------------
local FiltersPanel = ISPanel:derive("TransmogDE_FiltersPanel")

function FiltersPanel:new(x, y, w, h, parentViewer)
    local o = ISPanel.new(self, x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.viewer = parentViewer
    o.background = false -- we DO NOT custom-draw a black strip like before
    return o
end

-- internal helper: called when any filter widget changes text
local function _onFilterTextChanged(viewer)
    if viewer and viewer.refilter then
        viewer:refilter()
    end
end

function FiltersPanel:createChildren()
    ISPanel.createChildren(self)

    -- Match admin viewer: filter row uses Medium font + (fontH + 6) height
    local fontMediumH = getTextManager():getFontHeight(UIFont.Medium)
    local rowH        = fontMediumH + 6

    -- Force this panel's height to rowH so children fully fit and don't get visually "sliced"
    self:setHeight(rowH)

    local curX = 0

    -------------------------------------------------
    -- TYPE text filter (column 1)
    -------------------------------------------------
    self.typeBox = ISTextEntryBox:new(
        "",
        curX,
        0,
        COLS[1].w,
        rowH
    )
    self.typeBox.font = UIFont.Medium
    self.typeBox:initialise()
    self.typeBox:instantiate()
    self:addChild(self.typeBox)

    -- Wire vanilla-style live refilter:
    -- B42 ISTextEntryBox:onTextChange() calls self.onTextChangeFunction(self.target, self)
    self.typeBox.onTextChangeFunction = function(target, widget)
        -- target will be self (FiltersPanel) because we set target below
        if target and target.viewer then
            _onFilterTextChanged(target.viewer)
        end
    end
    self.typeBox.target = self
    -- TAB cycling support (optional)
    self.typeBox.onOtherKey = function(entry, key)
        -- not strictly needed for us; admin uses this to TAB between columns
    end

    curX = curX + COLS[1].w

    -------------------------------------------------
    -- NAME text filter (column 2)
    -------------------------------------------------
    self.nameBox = ISTextEntryBox:new(
        "",
        curX,
        0,
        COLS[2].w,
        rowH
    )
    self.nameBox.font = UIFont.Medium
    self.nameBox:initialise()
    self.nameBox:instantiate()
    self:addChild(self.nameBox)

    self.nameBox.onTextChangeFunction = function(target, widget)
        if target and target.viewer then
            _onFilterTextChanged(target.viewer)
        end
    end
    self.nameBox.target = self
    self.nameBox.onOtherKey = function(entry, key)
        -- optional TAB cycling, skipped for now
    end

    curX = curX + COLS[2].w

    -------------------------------------------------
    -- CATEGORY combo (column 3)
    -------------------------------------------------
    self.catCombo = ISComboBox:new(
        curX,
        0,
        COLS[3].w,
        rowH,
        self,
        self.onCatChanged
    )
    self.catCombo.font = UIFont.Medium
    self.catCombo:initialise()
    self.catCombo:instantiate()
    self.catCombo:setEditable(false)
    self.catCombo.parentFilters = self
    self:addChild(self.catCombo)

    curX = curX + COLS[3].w

    -------------------------------------------------
    -- DISPLAY CATEGORY combo (column 4)
    -------------------------------------------------
    self.dispCombo = ISComboBox:new(
        curX,
        0,
        COLS[4].w,
        rowH,
        self,
        self.onDispChanged
    )
    self.dispCombo.font = UIFont.Medium
    self.dispCombo:initialise()
    self.dispCombo:instantiate()
    self.dispCombo:setEditable(false)
    self.dispCombo.parentFilters = self
    self:addChild(self.dispCombo)

    -- backrefs so viewer can read values
    self.typeBox.parent   = self
    self.nameBox.parent   = self
    self.catCombo.parent  = self
    self.dispCombo.parent = self

    -- Also expose us to parentViewer (safety belt if InfoPanel didn't yet)
    if self.viewer then
        self.viewer._filters = self
    end
end

-- IMPORTANT:
-- We STOP custom drawing background/borders here.
-- Vanilla doesn't paint a separate black strip behind the filters row.
-- The ISTextEntryBox/ISComboBox already draw their own bg + borders.
function FiltersPanel:prerender()
    ISPanel.prerender(self)
    -- no extra drawRect(), no custom borders, no per-col shading
end

function FiltersPanel:onCatChanged(combo, optionText, optionIndex)
    if self.viewer then
        self.viewer:refilter()
    end
end

function FiltersPanel:onDispChanged(combo, optionText, optionIndex)
    if self.viewer then
        self.viewer:refilter()
    end
end

---------------------------------
-- infoPanel
-- Sits under the scrolling list.
-- Responsible for:
--   - Total Results
--   - short help text
--   - "Filters" label + FiltersPanel child
---------------------------------
local InfoPanel = ISPanel:derive("TransmogDE_InfoPanel")

function InfoPanel:new(x,y,w,h, parentViewer)
    local o = ISPanel.new(self, x,y,w,h)
    setmetatable(o, self)
    self.__index = self
    o.viewer = parentViewer
    o.background = false
    o.resultsLabel = nil
    o.filtersPanel = nil
    return o
end

function InfoPanel:createChildren()
    ISPanel.createChildren(self)

    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local lineH = fontH + 4

    local curY = 0

    -- Total Results label (will be updated by viewer)
    self.resultsLabel = ISLabel:new(
        0, curY,
        fontH,
        "Total Results: 0",
        1,1,1,1,
        UIFont.Small,
        true
    )
    self:addChild(self.resultsLabel)

    curY = curY + lineH

    -- Small instructions text (2 lines max, like admin viewer)
    self.help1 = ISLabel:new(
        0, curY,
        fontH,
        "Double-click an item to apply its appearance.",
        1,1,1,1,
        UIFont.Small,
        true
    )
    self:addChild(self.help1)

    curY = curY + lineH

    self.help2 = ISLabel:new(
        0, curY,
        fontH,
        "Icons may not match final look.",
        1,1,1,1,
        UIFont.Small,
        true
    )
    self:addChild(self.help2)

    curY = curY + lineH + 4

    -- "Filters" title (like admin 'Filters')
    self.filtersTitle = ISLabel:new(
        0, curY,
        fontH,
        "Filters",
        1,1,1,1,
        UIFont.Small,
        true
    )
    self:addChild(self.filtersTitle)

    curY = curY + lineH

    -- Filters row panel
    -- Match admin viewer: row height is based on Medium font, not Small.
    local filterH = getTextManager():getFontHeight(UIFont.Medium) + 6

    self.filtersPanel = FiltersPanel:new(
        0,
        curY,
        self.width,
        filterH,
        self.viewer
    )

    self.filtersPanel:initialise()
    self.filtersPanel:instantiate()
    self:addChild(self.filtersPanel)

    -- Expose it to the parent viewer so refilter() can read the boxes.
    self.viewer._filters = self.filtersPanel
end

function InfoPanel:prerender()
    ISPanel.prerender(self)
    -- draw nothing special behind (admin viewer uses black bg of parent)
end

---------------------------------
-- main window
---------------------------------
TransmogListViewer = ISPanel:derive("TransmogListViewer")

-- gather + build master row list
local function _collectRowsForTransmog(playerItem)
    local rows = {}
    local uniqueCats = {}
    local uniqueDisp = {}

    local allItems = getAllItems()
    if not allItems then
        return rows, uniqueCats, uniqueDisp
    end

    local restrictSameSlot =
        SandboxVars.TransmogDE
        and SandboxVars.TransmogDE.LimitTransmogToSameBodyLocation

    local tgtLoc = nil
    if restrictSameSlot and playerItem and playerItem.getBodyLocation then
        tgtLoc = playerItem:getBodyLocation()
    end

    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)

        if TransmogDE.isTransmoggable(scriptItem)
        and TransmogDE.immersiveModeItemCheck(scriptItem) then

            local okSlot = true
            if restrictSameSlot and tgtLoc ~= nil then
                okSlot = (scriptItem:getBodyLocation() == tgtLoc)
            end

            if okSlot then
                local fullName   = scriptItem:getFullName() or ""
                local prettyName = getItemNameFromFullType(fullName)
                local cat        = scriptItem:getTypeString() or scriptItem:getType() or ""
                local dispCat    = scriptItem:getDisplayCategory() or ""

                table.insert(rows, {
                    scriptItem = scriptItem,
                    typeStr    = fullName,
                    prettyName = prettyName,
                    cat        = cat,
                    dispCat    = dispCat,
                })

                uniqueCats[cat] = true
                uniqueDisp[dispCat] = true
            end
        end
    end

    return rows, uniqueCats, uniqueDisp
end

function TransmogListViewer:new(playerItem)
    local w = 1000
    local h = 740  -- final total height
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = screenW/2 - w/2
    local y = screenH/2 - h/2

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.borderColor     = { r = 0.4, g = 0.4, b = 0.4, a = 1.0 }
    o.backgroundColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.8 }
    o.moveWithMouse   = true

    o.playerItem = playerItem

    local rows, cats, dispCats = _collectRowsForTransmog(playerItem)
    _sortRowsByName(rows)

    o.allRows       = rows -- master
    o.rows          = rows -- filtered subset (starts same)
    o.uniqueCats    = _sortedListFromSet(cats)
    o.uniqueDispCat = _sortedListFromSet(dispCats)

    -- runtime refs:
    o.headerPanel   = nil
    o.listBox       = nil
    o.infoPanel     = nil
    o.closeBtn      = nil
    o._filters      = nil -- gets filled when infoPanel builds filtersPanel
    return o
end

function TransmogListViewer:createChildren()
    ISPanel.createChildren(self)

    -- layout metrics
    local pad        = 30
    local titleH     = 40  -- vertical space for centered title text
    local headerH    = 28  -- brown header bar height
    local closeH     = 30  -- Close button height
    local infoBlockH = 140 -- space under the list for total results / help / filters
    local footerGap  = 30  -- visual breathing room between filters row and Close

    local listX = pad
    local listW = self.width - (pad * 2)  -- must match COLS total (940 with width=1000)

    -- y of header row
    local headerY = pad + titleH

    -- y of list top (just under header)
    local listY = headerY + headerH

    -- height for list:
    -- totalHeight
    --  - pad at bottom
    --  - closeH (close button strip)
    --  - footerGap (space above close)
    --  - infoBlockH (results/help/filters)
    --  - listY (everything above the list)
    local listH = self.height - pad - closeH - footerGap - infoBlockH - listY
    if listH < 50 then listH = 50 end

    -- info panel (results/help/filters) sits right under the list
    local infoY = listY + listH
    local infoW = listW
    local infoH = infoBlockH

    -- close button sits at the bottom, below that gap
    local closeY = self.height - pad - closeH

    -------------------------------------------------
    -- header row (column labels)
    -------------------------------------------------
    self.headerPanel = TransmogListViewer_Header:new(
        listX,
        headerY,
        listW,
        headerH
    )
    self:addChild(self.headerPanel)

    -------------------------------------------------
    -- scrolling list
    -------------------------------------------------
    self.listBox = TransmogListViewer_List:new(listX, listY, listW, listH)
    self.listBox:initialise()
    self.listBox:instantiate()
    self.listBox.parentViewer = self
    self:addChild(self.listBox)

    for _, row in ipairs(self.rows) do
        self.listBox:addItem(row.prettyName, row)
    end

    -------------------------------------------------
    -- info block (results/help/filters)
    -------------------------------------------------
    self.infoPanel = InfoPanel:new(
        listX,
        infoY,
        infoW,
        infoH,
        self
    )
    self.infoPanel:initialise()
    self.infoPanel:instantiate()
    self:addChild(self.infoPanel)

    -- populate filter combo options now that filtersPanel exists
    local fp = self._filters
    fp.catCombo:addOption("<Any>")
    for _,cat in ipairs(self.uniqueCats) do
        if cat ~= "" then
            fp.catCombo:addOption(cat)
        end
    end
    fp.dispCombo:addOption("<Any>")
    for _,dc in ipairs(self.uniqueDispCat) do
        if dc ~= "" then
            fp.dispCombo:addOption(dc)
        end
    end

    -------------------------------------------------
    -- Close button in footer area (left-aligned)
    -------------------------------------------------
    self.closeBtn = ISButton:new(
        pad,
        closeY,
        120,
        closeH,
        getText("UI_Close") or "Close",
        self,
        TransmogListViewer.onCloseButton
    )
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.borderColor = {r=0.4,g=0.0,b=0.0,a=1.0}
    self.closeBtn.backgroundColor = {r=0.4,g=0.0,b=0.0,a=0.5}
    self.closeBtn.backgroundColorMouseOver = {r=0.6,g=0.0,b=0.0,a=0.7}
    self:addChild(self.closeBtn)

    -- final initial label update
    self:_updateResultsLabel()
end

-- internal: update "Total Results: N" label
function TransmogListViewer:_updateResultsLabel()
    if self.infoPanel and self.infoPanel.resultsLabel then
        local nRaw = #self.rows
        local n = tonumber(nRaw) or 0
        self.infoPanel.resultsLabel.name = "Total Results: " .. tostring(n)
    end
end

---------------------------------
-- filtering logic
---------------------------------
function TransmogListViewer:refilter()
    if not self._filters then return end
    if not self.listBox then return end

    local fp = self._filters

    local typeNeed = _lower(fp.typeBox:getText() or "")
    local nameNeed = _lower(fp.nameBox:getText() or "")

    local catSel = fp.catCombo:getOptionText(fp.catCombo.selected)
    if not catSel then catSel = "<Any>" end

    local dispSel = fp.dispCombo:getOptionText(fp.dispCombo.selected)
    if not dispSel then dispSel = "<Any>" end

    local out = {}

    for _, row in ipairs(self.allRows) do
        local keep = true

        if typeNeed ~= "" then
            local hay = _lower(row.typeStr)
            if not string.find(hay, typeNeed, 1, true) then
                keep = false
            end
        end

        if keep and nameNeed ~= "" then
            local hay2 = _lower(row.prettyName)
            if not string.find(hay2, nameNeed, 1, true) then
                keep = false
            end
        end

        if keep and catSel ~= "<Any>" then
            if row.cat ~= catSel then
                keep = false
            end
        end

        if keep and dispSel ~= "<Any>" then
            if row.dispCat ~= dispSel then
                keep = false
            end
        end

        if keep then
            table.insert(out, row)
        end
    end

    -- sort filtered rows by name (so list is always Name A->Z)
    _sortRowsByName(out)
    self.rows = out

    self.listBox:clear()
    for _, row in ipairs(self.rows) do
        self.listBox:addItem(row.prettyName, row)
    end

    self:_updateResultsLabel()
end

---------------------------------
-- Close
---------------------------------
function TransmogListViewer:onCloseButton()
    self:removeFromUIManager()
    TransmogListViewer.instance = nil
end

---------------------------------
-- Applying the cosmetic
---------------------------------
function TransmogListViewer:applyTransmogFromRow(row)
    if not row or not row.scriptItem or not self.playerItem then return end

    local prettyName = row.prettyName or row.typeStr or "???"
    local haloText = getText("IGUI_TransmogDE_Text_TransmoggedTo", prettyName)

    HaloTextHelper.addGoodText(getPlayer(), haloText)

    TransmogDE.setItemTransmog(self.playerItem, row.scriptItem)
    TransmogDE.forceUpdateClothing(self.playerItem)
end

---------------------------------
-- prerender (window bg, border, title)
---------------------------------
function TransmogListViewer:prerender()
    ISPanel.prerender(self)

    -- panel bg + border
    self:drawRect(
        0, 0, self.width, self.height,
        self.backgroundColor.a,
        self.backgroundColor.r,
        self.backgroundColor.g,
        self.backgroundColor.b
    )
    self:drawRectBorder(
        0, 0, self.width, self.height,
        self.borderColor.a,
        self.borderColor.r,
        self.borderColor.g,
        self.borderColor.b
    )

    local title = "Transmog List - Standard Mode"
    local tw = getTextManager():MeasureStringX(UIFont.Medium, title)
    self:drawText(
        title,
        self.width/2 - (tw/2),
        20,
        1,1,1,1,
        UIFont.Medium
    )
end

---------------------------------
-- public opener
---------------------------------
function TransmogListViewer.Open(playerItem)
    if TransmogListViewer.instance then
        TransmogListViewer.instance:removeFromUIManager()
        TransmogListViewer.instance = nil
    end

    local ui = TransmogListViewer:new(playerItem)
    TransmogListViewer.instance = ui
    ui:initialise()
    ui:addToUIManager()
    ui:setAlwaysOnTop(true)
end
