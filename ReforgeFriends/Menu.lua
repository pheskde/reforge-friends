-- Hauptfenster (Linksklick auf das Minimap-Symbol, /rff): Einstellungen, Community, deine Charaktere und die Charaktere jedes Mitglieds.
-- Ein Klick auf einen Charakter oeffnet sein Questfenster, Rechtsklick auf einen von Hand eingetragenen entfernt ihn.
-- Der Inhalt der Liste kommt aus ns.BuildMenu (Core.lua).
local _, ns = ...

local ROW_H = 18
local frame
local rows = {}
local checks = {}

local GREEN, GREY = "|cff44dd66", "|cff888888"

local refresh

local function getRow(i)
  if rows[i] then return rows[i] end
  local row = CreateFrame("Button", nil, frame.content)
  row:SetHeight(ROW_H)
  row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
  row:SetPoint("RIGHT", frame.content, "RIGHT", 0, 0)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.text:SetPoint("LEFT")
  row.text:SetJustifyH("LEFT")
  row.hl = row:CreateTexture(nil, "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.hl:SetColorTexture(1, 1, 1, 0.12)
  row:SetScript("OnClick", function(self, mouse)
    local data = self.data
    if not data or data.kind ~= "char" then return end
    if mouse == "RightButton" then
      if data.manual then ns.RemoveMember(data.name) refresh() end
    elseif data.self then
      ns.ShowQuests(data.name, { quests = ns.GetQuestIDs() })
    else
      ns.AskQuests(data.name, ns.Now())
      ns.ShowQuests(data.name)
    end
  end)
  rows[i] = row
  return row
end

refresh = function()
  if not frame or not frame:IsShown() then return end
  local L = ns.L
  for _, c in ipairs(checks) do c.box:SetChecked(c.get() and true or false) end
  local data = ns.BuildMenu(ns.Now(), ns.OwnName())
  for i, d in ipairs(data) do
    local row = getRow(i)
    row.data = d
    local text
    if d.kind == "header" then
      text = "|cfff27a2c" .. d.text .. "|r"
    elseif d.kind == "member" then
      text = "|cffffffff" .. d.text .. "|r"
    elseif d.kind == "char" then
      text = "   " .. (d.online and (GREEN .. "*|r ") or (GREY .. "- |r")) .. (d.self and ("|cffffd100" .. d.name .. "|r") or d.name)
      if d.info then text = text .. "  " .. GREY .. d.info .. "|r" end
      if d.manual then text = text .. "  " .. GREY .. "(" .. L.menuRemove .. ")|r" end
    else
      text = "   " .. GREY .. d.text .. "|r"
    end
    row.text:SetText(text)
    row:EnableMouse(d.kind == "char")
    row:Show()
  end
  for i = #data + 1, #rows do rows[i]:Hide() end
  frame.content:SetHeight(#data * ROW_H + 8)
end

local function addCheck(label, x, y, get, set)
  local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  box:SetSize(24, 24)
  box:SetPoint("TOPLEFT", x, y)
  local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", box, "RIGHT", 2, 1)
  text:SetText(label)
  box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) refresh() end)
  checks[#checks + 1] = { box = box, get = get }
end

local function create()
  local L = ns.L
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "ReforgeFriendsMenu", UIParent, template)
  frame:SetSize(400, 560)
  frame:SetPoint("CENTER", -200, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetPoint("TOPLEFT", 6, -6)
  frame.bg:SetPoint("BOTTOMRIGHT", -6, 6)
  frame.bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
  end
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 20, -18)
  frame.title:SetText("|cfff27a2creforge|r Friends")
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Einstellungen (zwei Spalten)
  local head = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 22, -48)
  head:SetText(L.setHeader)
  addCheck(L.setShare, 18, -66, function() return ns.db.sharing end, function(on)
    ns.SetSharing(on, ns.Now())
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
  end)
  addCheck(L.setQuests, 200, -66, function() return ns.db.shareQuests end, function(on) ns.db.shareQuests = on end)
  addCheck(L.setPins, 18, -92, function() return ns.db.showPins end, function(on) ns.db.showPins = on ns.RefreshMap() end)
  addCheck(L.setMinimap, 200, -92, function() return ns.db.showMinimapButton end, function(on)
    ns.db.showMinimapButton = on
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
  end)
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.95, 0.48, 0.17, 0.6)
  line:SetPoint("TOPLEFT", 22, -122)
  line:SetPoint("TOPRIGHT", -22, -122)
  line:SetHeight(1)

  local scroll = CreateFrame("ScrollFrame", "ReforgeFriendsMenuScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 22, -130)
  scroll:SetPoint("BOTTOMRIGHT", -38, 56)
  frame.content = CreateFrame("Frame", nil, scroll)
  frame.content:SetSize(320, 10)
  scroll:SetScrollChild(frame.content)

  -- Charakter von Hand hinzufuegen
  local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  input:SetSize(220, 22)
  input:SetPoint("BOTTOMLEFT", 30, 22)
  input:SetAutoFocus(false)
  input:SetMaxLetters(24)
  local hint = input:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", 2, 0)
  hint:SetText(L.addHint)
  input:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" then hint:Show() else hint:Hide() end
  end)
  local function add()
    local name, err = ns.AddMember(input:GetText())
    if name and not err then ns.Print(L.added:format(name)) elseif err then ns.Print(L[err]:format(name or input:GetText())) end
    input:SetText("")
    input:ClearFocus()
    refresh()
  end
  input:SetScript("OnEnterPressed", add)
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetSize(100, 22)
  button:SetPoint("LEFT", input, "RIGHT", 8, 0)
  button:SetText(L.addButton)
  button:SetScript("OnClick", add)

  -- Online-Punkte aendern sich ohne Ereignis: einmal pro Sekunde auffrischen.
  local acc = 0
  frame:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc >= 1 then acc = 0 refresh() end
  end)
  frame:SetScript("OnShow", refresh)
  if UISpecialFrames then table.insert(UISpecialFrames, "ReforgeFriendsMenu") end
  frame:Hide()
end

function ns.ToggleMenu()
  if not ns.db then return end
  if not frame then create() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

local previous = ns.OnPeerChanged
function ns.OnPeerChanged(name)
  if previous then previous(name) end
  refresh()
end
