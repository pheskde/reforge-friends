-- Senden und Empfangen. Nachrichten gehen als Addon-Fluestern direkt an Community-Mitglieder, nie ueber einen Server und nie an Fremde.
local _, ns = ...

ns.POS_INTERVAL = 5       -- so oft wird die Position geprueft
ns.HEARTBEAT = 30         -- spaetestens so oft wird sie auch ohne Bewegung gesendet (haelt den Pin frisch)
ns.HELLO_INTERVAL = 60    -- so oft werden Mitglieder angesprochen, von denen wir nichts hoeren
ns.REPLY_COOLDOWN = 10    -- Antworten auf Quest-Anfragen je Gegenstelle

local state = { lastCheck = -1e9, lastSent = -1e9, lastHello = -1e9, lastPos = nil, questReply = {}, questAsk = {} }
ns.commState = state

-- Spiel-Schnittstellen. Alles, was die WoW-API braucht, liegt hier, damit die Logik darunter testbar bleibt.

function ns.Now()
  return GetTime()
end

function ns.SendAddon(text, target)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(ns.PREFIX, text, "WHISPER", target)
  elseif SendAddonMessage then
    SendAddonMessage(ns.PREFIX, text, "WHISPER", target)
  end
end

-- Karte und Koordinaten (0..1). nil, wenn das Spiel keine Position liefert (Instanz, Schlachtfeld, Ladebildschirm).
function ns.GetPosition()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  if not map or map == 0 then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if not x or (x == 0 and y == 0) then return nil end
  return map, x, y
end

-- IDs der offenen Quests im Questlog (ohne Ueberschriften).
function ns.GetQuestIDs()
  local ids = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local n = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then ids[#ids + 1] = info.questID end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries()
    for i = 1, n do
      local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
      if not isHeader and questID then ids[#ids + 1] = questID end
    end
  end
  return ids
end

function ns.QuestTitle(id)
  local title
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then title = C_QuestLog.GetTitleForQuestID(id) end
  return title or ns.L.unknownQuest:format(id)
end

-- Senden ----------------------------------------------------------------------------

-- Mitglieder, die zuletzt geantwortet haben.
local function onlinePeers(now)
  local out = {}
  for _, name in ipairs(ns.MemberList()) do
    if ns.PeerOnline(name, now) then out[#out + 1] = name end
  end
  return out
end

local function broadcast(text, now)
  for _, name in ipairs(onlinePeers(now)) do ns.SendAddon(text, name) end
end

local function positionMessage()
  local map, x, y = ns.GetPosition()
  if map then return ns.EncodePosition(map, x, y), map, x, y end
  return "I"
end

-- Wird bei jedem Takt aufgerufen (Map.lua/Comm-Frame). Rechnet selbst mit den Intervallen.
function ns.Tick(now)
  if not ns.db then return end
  if not ns.db.sharing then
    -- Wer nur zuschaut, meldet sich regelmaessig mit "A", sonst gilt er beim Sender nach 75 Sekunden als weg.
    if now - state.lastSent >= ns.HEARTBEAT then
      state.lastSent = now
      broadcast("A", now)
    end
    return
  end
  if now - state.lastHello >= ns.HELLO_INTERVAL then
    state.lastHello = now
    for _, name in ipairs(ns.MemberList()) do
      if not ns.PeerOnline(name, now) then ns.SendAddon("H|" .. ns.PROTOCOL, name) end
    end
  end
  if now - state.lastCheck < ns.POS_INTERVAL then return end
  state.lastCheck = now
  local text = positionMessage()
  if text ~= state.lastPos or now - state.lastSent >= ns.HEARTBEAT then
    state.lastPos, state.lastSent = text, now
    broadcast(text, now)
  end
end

-- Teilen an/aus. Beim Ausschalten bekommen alle bekannten Gegenstellen "O", damit der Pin sofort verschwindet.
function ns.SetSharing(on, now)
  on = on and true or false
  if ns.db.sharing == on then return end
  ns.db.sharing = on
  if on then
    state.lastCheck, state.lastSent, state.lastHello, state.lastPos = -1e9, -1e9, -1e9, nil
    ns.Tick(now)
  else
    broadcast("O", now)
  end
end

-- Quests einer Gegenstelle abfragen (hoechstens alle 10 Sekunden je Name).
function ns.AskQuests(name, now)
  name = ns.NormName(name)
  if not name or not ns.IsMember(name) then return false end
  if state.questAsk[name] and now - state.questAsk[name] < ns.REPLY_COOLDOWN then return false end
  state.questAsk[name] = now
  ns.SendAddon("QR", name)
  return true
end

-- Empfangen -------------------------------------------------------------------------

function ns.OnMessage(sender, text, now)
  local wasOnline = ns.PeerOnline(ns.NormName(sender) or "", now)
  local peer, msg, name = ns.Receive(sender, text, now)
  if not peer then return end
  if not wasOnline and ns.db.sharing and msg.kind ~= "H" and msg.kind ~= "O" and msg.kind ~= "QR" then
    -- Gegenstelle taucht gerade auf (Antwort auf unser Hallo): Position sofort schicken statt erst beim naechsten Takt.
    ns.SendAddon((positionMessage()), name)
  end
  if msg.kind == "H" then
    -- Antwort immer: wer nicht teilt, sagt wenigstens "hier", damit der andere seine Position schicken darf.
    if ns.db.sharing then
      ns.SendAddon((positionMessage()), name)
    else
      ns.SendAddon("A", name)
    end
  elseif msg.kind == "QR" then
    if state.questReply[name] and now - state.questReply[name] < ns.REPLY_COOLDOWN then return end
    state.questReply[name] = now
    if ns.db.sharing and ns.db.shareQuests then
      for _, part in ipairs(ns.EncodeQuests(ns.GetQuestIDs())) do ns.SendAddon(part, name) end
    else
      ns.SendAddon("QN", name)
    end
  end
  if ns.OnPeerChanged then ns.OnPeerChanged(name) end
end

-- Unterdrueckt die Systemmeldung "Kein Spieler namens X", wenn ein Hallo an einen Offline-Freund ging.
function ns.IsOfflineNotice(message)
  local template = ERR_CHAT_PLAYER_NOT_FOUND_S
  if type(template) ~= "string" or type(message) ~= "string" then return false end
  local pattern = "^" .. template:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
  local name = message:match(pattern)
  return name ~= nil and ns.IsMember(name)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGOUT")
local elapsed = 0
frame:SetScript("OnEvent", function(_, event, a, b, c, d)
  if event == "ADDON_LOADED" and a == "ReforgeFriends" then
    ReforgeFriendsDB = ns.InitDB(ReforgeFriendsDB, ReforgeFriendsRoster, ReforgeFriendsCommunities)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
    elseif RegisterAddonMessagePrefix then
      RegisterAddonMessagePrefix(ns.PREFIX)
    end
    if ChatFrame_AddMessageEventFilter then
      ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message) return ns.IsOfflineNotice(message) end)
    end
  elseif event == "CHAT_MSG_ADDON" then
    -- a = Praefix, b = Text, c = Kanal, d = Absender
    if a == ns.PREFIX and c == "WHISPER" and ns.db then ns.OnMessage(d, b, ns.Now()) end
  elseif event == "PLAYER_LOGOUT" and ns.db and ns.db.sharing then
    broadcast("O", ns.Now())
  end
end)
frame:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 1 then return end
  elapsed = 0
  ns.Tick(ns.Now())
end)
