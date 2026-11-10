-- Questfenster: die komplette Questliste eines Charakters (Klick auf seinen Pin), scrollbar und alphabetisch sortiert.
local _, ns = ...

local frame
local current   -- { name = ..., peer = ... }, peer ist bei fremden Spielern ns.peers[name]

local function lines()
  local peer = current.peer or ns.peers[current.name]
  if not peer then return { ns.L.questsNone } end
  if peer.questsPrivate then return { "|cff888888" .. ns.L.questsPrivate .. "|r" } end
  if not peer.quests then return { "|cff888888" .. ns.L.questsAsk .. "|r" } end
  local titles = {}
  for _, id in ipairs(peer.quests) do titles[#titles + 1] = ns.QuestTitle(id) end
  table.sort(titles)
  for i, t in ipairs(titles) do titles[i] = ("|cff888888%2d|r  %s"):format(i, t) end
  return titles
end

local function refresh()
  if not frame or not frame:IsShown() or not current then return end
  local peer = current.peer or ns.peers[current.name]
  local count = peer and peer.quests and #peer.quests or 0
  frame.title:SetText(("|cfff27a2c%s|r  %s"):format(current.name, count > 0 and ns.L.quests:format(count) or ""))
  frame.text:SetText(table.concat(lines(), "\n"))
  frame.content:SetHeight(math.max(frame.text:GetStringHeight() + 8, 10))
end

local function create()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "ReforgeFriendsQuests", UIParent, template)
  frame:SetSize(360, 440)
  frame:SetPoint("CENTER", 200, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  -- Eigener Hintergrund: Nicht jeder Client liefert BackdropTemplate, dann waere das Fenster durchsichtig.
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
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOPLEFT", 20, -18)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  local scroll = CreateFrame("ScrollFrame", "ReforgeFriendsQuestsScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 20, -46)
  scroll:SetPoint("BOTTOMRIGHT", -36, 20)
  frame.content = CreateFrame("Frame", nil, scroll)
  frame.content:SetSize(290, 10)
  scroll:SetScrollChild(frame.content)
  frame.text = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.text:SetPoint("TOPLEFT", 0, 0)
  frame.text:SetWidth(290)
  frame.text:SetJustifyH("LEFT")
  frame.text:SetJustifyV("TOP")
  frame:SetScript("OnShow", refresh)
  if UISpecialFrames then table.insert(UISpecialFrames, "ReforgeFriendsQuests") end
  frame:Hide()
end

-- peer nur fuer den Debug-Pin (eigene Daten); sonst aus ns.peers.
function ns.ShowQuests(name, peer)
  if not frame then create() end
  current = { name = name, peer = peer }
  frame:Show()
  refresh()
end

local previous = ns.OnPeerChanged
function ns.OnPeerChanged(name)
  if previous then previous(name) end
  refresh()
end
