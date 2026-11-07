-- Uebersichtsfenster: Communities, Mitglieder und ihre gemeldeten Charaktere. Der Inhalt kommt aus ns.BuildOverview (Core.lua).
local _, ns = ...

local frame

local function refresh()
  if not frame or not frame:IsShown() then return end
  frame.text:SetText(table.concat(ns.BuildOverview(ns.Now()), "\n"))
  frame.content:SetHeight(math.max(frame.text:GetStringHeight() + 8, 10))
end

local function create()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "ReforgeFriendsOverview", UIParent, template)
  frame:SetSize(460, 380)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
  end

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 20, -18)
  frame.title:SetText("|cfff27a2creforge|r Friends")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local scroll = CreateFrame("ScrollFrame", "ReforgeFriendsOverviewScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 20, -50)
  scroll:SetPoint("BOTTOMRIGHT", -36, 20)
  frame.content = CreateFrame("Frame", nil, scroll)
  frame.content:SetSize(390, 10)
  scroll:SetScrollChild(frame.content)

  frame.text = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.text:SetPoint("TOPLEFT", 0, 0)
  frame.text:SetWidth(390)
  frame.text:SetJustifyH("LEFT")
  frame.text:SetJustifyV("TOP")

  -- Online-Punkte aendern sich ohne Ereignis: einmal pro Sekunde auffrischen, solange das Fenster offen ist.
  local acc = 0
  frame:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc >= 1 then
      acc = 0
      refresh()
    end
  end)
  frame:SetScript("OnShow", refresh)

  -- ESC schliesst das Fenster.
  if UISpecialFrames then table.insert(UISpecialFrames, "ReforgeFriendsOverview") end
  frame:Hide()
end

function ns.ToggleOverview()
  if not frame then create() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Aus Comm.lua: ein Mitglied hat sich gemeldet. Das offene Fenster zeigt es sofort.
local previous = ns.OnPeerChanged
function ns.OnPeerChanged(name)
  if previous then previous(name) end
  refresh()
end
