-- Minimap-Symbol: Linksklick oeffnet das Community-Fenster, Rechtsklick schaltet das Teilen, Shift+Rechtsklick die Pins, Ziehen verschiebt es um die Minimap.
local _, ns = ...

-- Versatz des Symbols vom Minimap-Mittelpunkt fuer einen Winkel in Grad (0 = rechts, gegen den Uhrzeigersinn).
function ns.MinimapOffset(angle, radius)
  local rad = math.rad(angle)
  return math.cos(rad) * radius, math.sin(rad) * radius
end

-- Winkel in Grad (0..360) aus einem Mauspunkt relativ zum Mittelpunkt.
function ns.MinimapAngle(dx, dy)
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then angle = angle + 360 end
  return angle
end

local button

local function tooltip(self)
  local L = ns.L
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("reforge Friends", 0.95, 0.48, 0.17)
  GameTooltip:AddLine(L.tipShare:format(ns.db.sharing and L.on or L.off), 1, 1, 1)
  local members, characters, seen = ns.CommunityStats(ns.Now())
  GameTooltip:AddLine(L.tipMembers:format(members, characters), 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L.tipSeen:format(seen), seen > 0 and 0.27 or 0.6, seen > 0 and 0.87 or 0.6, seen > 0 and 0.4 or 0.6)
  GameTooltip:AddLine(L.tipOverview, 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L.tipLeft, 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L.tipRight, 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L.tipDrag, 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function place()
  if not button then return end
  local radius = (Minimap:GetWidth() / 2) + 5
  local x, y = ns.MinimapOffset(ns.db.minimapAngle or 210, radius)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Aussehen: ohne Teilen grau, damit man den Zustand auch ohne Tooltip sieht.
function ns.UpdateMinimapButton()
  if not button then return end
  if not ns.db.showMinimapButton then button:Hide() return end
  button:Show()
  button.icon:SetDesaturated(not ns.db.sharing)
  place()
end

local function create()
  button = CreateFrame("Button", "ReforgeFriendsMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button.icon = button:CreateTexture(nil, "BACKGROUND")
  button.icon:SetSize(20, 20)
  button.icon:SetPoint("CENTER", 0, 1)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnClick", function(self, mouse)
    if mouse == "LeftButton" then
      if ns.ToggleMenu then ns.ToggleMenu() end
    elseif IsShiftKeyDown() then
      ns.db.showPins = not ns.db.showPins
      ns.RefreshMap()
      ns.Print(ns.db.showPins and ns.L.pinsOn or ns.L.pinsOff)
    else
      ns.SetSharing(not ns.db.sharing, ns.Now())
      ns.Print(ns.db.sharing and ns.L.sharingOn:format(#ns.MemberList()) or ns.L.sharingOff)
      ns.UpdateMinimapButton()
    end
    if GameTooltip:IsOwned(self) then tooltip(self) end
  end)
  button:SetScript("OnEnter", tooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.db.minimapAngle = ns.MinimapAngle(cx / scale - mx, cy / scale - my)
      place()
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  if not Minimap then return end
  create()
  ns.UpdateMinimapButton()
end)
