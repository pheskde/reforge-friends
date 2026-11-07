-- Pins auf der Weltkarte. Die Pins haengen direkt an der Kartenflaeche, ohne die Blizzard-Pin-Vorlagen (die sich zwischen Clients unterscheiden).
local _, ns = ...

local PIN_SIZE = 16
local pins = {}
local shown = {}   -- Name -> Pin, nur fuer die aktuell sichtbaren

-- Rechnet die Position einer Gegenstelle auf die angezeigte Karte um. Gleiche Karte: unveraendert; sonst ueber Weltkoordinaten
-- (zeigt einen Freund aus einem Unterbereich auf der Kontinentkarte). nil, wenn er auf dieser Karte nicht liegt.
function ns.ProjectToMap(peer, displayed)
  if not peer.map or not displayed then return nil end
  if peer.map == displayed then return peer.x, peer.y end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local ok, x, y = pcall(function()
    local continent, world = C_Map.GetWorldPosFromMapPos(peer.map, CreateVector2D(peer.x, peer.y))
    if not continent or not world then return nil end
    local pos = C_Map.GetMapPosFromWorldPos(continent, world, displayed)
    if not pos then return nil end
    return pos:GetXY()
  end)
  if not ok or not x or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x, y
end

local function showTooltip(pin)
  local name = pin.name
  local peer = ns.peers[name]
  if not peer then return end
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:AddLine(name, 1, 1, 1)
  local info = peer.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(peer.map)
  if info and info.name then GameTooltip:AddLine(info.name, 0.8, 0.8, 0.8) end
  if peer.questsPrivate then
    GameTooltip:AddLine(ns.L.questsPrivate, 0.6, 0.6, 0.6)
  elseif peer.quests then
    GameTooltip:AddLine(ns.L.quests:format(#peer.quests), 0.95, 0.48, 0.17)
    for i, id in ipairs(peer.quests) do
      if i > 25 then GameTooltip:AddLine("...", 0.6, 0.6, 0.6) break end
      GameTooltip:AddLine(ns.QuestTitle(id), 0.9, 0.9, 0.9)
    end
  elseif pin.asked then
    GameTooltip:AddLine(ns.L.questsAsk, 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

local function getPin(canvas, index)
  local pin = pins[index]
  if pin then return pin end
  pin = CreateFrame("Button", nil, canvas)
  pin:SetSize(PIN_SIZE, PIN_SIZE)
  pin:SetFrameLevel(canvas:GetFrameLevel() + 50)
  pin.tex = pin:CreateTexture(nil, "OVERLAY")
  pin.tex:SetAllPoints()
  pin.tex:SetTexture("Interface\\COMMON\\Indicator-Green")
  pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pin.label:SetPoint("TOP", pin, "BOTTOM", 0, 0)
  local function ask(self)
    self.asked = ns.AskQuests(self.name, ns.Now()) or self.asked
  end
  pin:SetScript("OnEnter", function(self)
    if IsShiftKeyDown() then ask(self) end
    showTooltip(self)
  end)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pin:SetScript("OnClick", function(self) ask(self) showTooltip(self) end)
  pins[index] = pin
  return pin
end

function ns.RefreshMap()
  for _, pin in pairs(shown) do pin:Hide() end
  shown = {}
  if not WorldMapFrame or not WorldMapFrame:IsShown() or not ns.db or not ns.db.showPins then return end
  local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or WorldMapFrame.ScrollContainer
  local displayed = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if not canvas or not displayed then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvas.GetScale and canvas:GetScale() or 1
  if scale <= 0 then scale = 1 end
  local used = 0
  for _, name in ipairs(ns.VisiblePeers(ns.Now())) do
    local x, y = ns.ProjectToMap(ns.peers[name], displayed)
    if x then
      used = used + 1
      local pin = getPin(canvas, used)
      pin.name = name
      pin.label:SetText(name)
      pin:SetScale(1 / scale)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
      pin:Show()
      shown[name] = pin
    end
  end
end

-- Aus Comm.lua: eine Gegenstelle hat sich geaendert. Offenen Tooltip aktualisieren.
function ns.OnPeerChanged(name)
  ns.RefreshMap()
  local pin = shown[name]
  if pin and GameTooltip:IsOwned(pin) then showTooltip(pin) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  if not WorldMapFrame then return end
  WorldMapFrame:HookScript("OnShow", ns.RefreshMap)
  WorldMapFrame:HookScript("OnHide", ns.RefreshMap)
  if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.RefreshMap) end
  -- Gegenstellen laufen nach 75 Sekunden ab, auch ohne neue Nachricht: einmal pro Sekunde neu zeichnen, solange die Karte offen ist.
  local acc = 0
  WorldMapFrame:HookScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc >= 1 then acc = 0 ns.RefreshMap() end
  end)
end)
