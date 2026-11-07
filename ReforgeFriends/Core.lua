-- Logik von Friends: Einstellungen, Mitgliederliste, Protokoll und Gegenstellen. Senden/Empfangen liegt in Comm.lua, die Karte in Map.lua.
local _, ns = ...

ns.PREFIX = "RFFR"
ns.PROTOCOL = 1

-- Teilen ist standardmaessig an: es geht ohnehin nur an Mitglieder der eigenen Liste. Die Questliste bleibt privat.
local DEFAULTS = { sharing = true, shareQuests = false, showPins = true, showMinimapButton = true, minimapAngle = 210, members = {} }

local LOCALES = {
  enUS = {
    help = "/rff share on|off | quests on|off | pins on|off | minimap on|off | add <name> | remove <name> | list | status",
    sharingOn = "Sharing your position with %d community member(s).", sharingOff = "Sharing is off. Nobody receives your position.",
    questsOn = "Others may now ask for your quest list.", questsOff = "Your quest list is private.",
    pinsOn = "Friend pins shown on the map.", pinsOff = "Friend pins hidden.",
    added = "%s added.", removed = "%s removed.", already = "%s is already on the list.", unknown = "%s is not on the list.",
    listHead = "Community members (%d):", listEmpty = "No community members yet. /rff add <name>",
    onMap = "on the map", elsewhere = "elsewhere", inInstance = "in an instance", offline = "not seen",
    status = "Sharing: %s, quests: %s, pins: %s", on = "on", off = "off",
    minimapOn = "Minimap button shown.", minimapOff = "Minimap button hidden. /rff minimap on brings it back.",
    tipShare = "Sharing: %s", tipOnline = "%d of %d members seen", tipLeft = "Left click: sharing on or off", tipRight = "Right click: map pins on or off", tipDrag = "Drag: move the button",
    quests = "Open quests (%d):", questsAsk = "Asking for quests...", questsPrivate = "does not share quests", questsNone = "No quests received.",
    unknownQuest = "Quest %d", noName = "Give a character name.",
  },
  deDE = {
    help = "/rff share on|off | quests on|off | pins on|off | minimap on|off | add <Name> | remove <Name> | list | status",
    sharingOn = "Deine Position geht an %d Community-Mitglied(er).", sharingOff = "Teilen ist aus. Niemand erhält deine Position.",
    questsOn = "Andere dürfen jetzt deine Questliste abfragen.", questsOff = "Deine Questliste ist privat.",
    pinsOn = "Freunde-Pins auf der Karte angezeigt.", pinsOff = "Freunde-Pins ausgeblendet.",
    added = "%s hinzugefügt.", removed = "%s entfernt.", already = "%s steht schon in der Liste.", unknown = "%s steht nicht in der Liste.",
    listHead = "Community-Mitglieder (%d):", listEmpty = "Noch keine Community-Mitglieder. /rff add <Name>",
    onMap = "auf der Karte", elsewhere = "woanders", inInstance = "in einer Instanz", offline = "nicht gesehen",
    status = "Teilen: %s, Quests: %s, Pins: %s", on = "an", off = "aus",
    minimapOn = "Minimap-Symbol angezeigt.", minimapOff = "Minimap-Symbol ausgeblendet. /rff minimap on holt es zurück.",
    tipShare = "Teilen: %s", tipOnline = "%d von %d Mitgliedern gesehen", tipLeft = "Linksklick: Teilen an oder aus", tipRight = "Rechtsklick: Karten-Pins an oder aus", tipDrag = "Ziehen: Symbol verschieben",
    quests = "Offene Quests (%d):", questsAsk = "Frage Quests an...", questsPrivate = "teilt keine Quests", questsNone = "Keine Quests erhalten.",
    unknownQuest = "Quest %d", noName = "Gib einen Charakternamen an.",
  },
}
ns.L = LOCALES[GetLocale()] or LOCALES.enUS

function ns.Print(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cfff27a2reforge:|r " .. text)
end

-- Namen vergleichen wir ohne Realm und ohne Gross-/Kleinschreibung.
function ns.NormName(name)
  if type(name) ~= "string" then return nil end
  name = name:match("^[^-]+") or name
  if name == "" then return nil end
  return name:sub(1, 1):upper() .. name:sub(2):lower()
end

-- Einstellungen und Mitglieder -------------------------------------------------

ns.db = nil
ns.peers = {}

-- `roster` sind Mitglieder, die der Reforge-Client ins Addon schreibt (Roster.lua, Tabelle ReforgeFriendsRoster = { "Name", ... }).
-- Sie kommen zu den von Hand eingetragenen.
function ns.InitDB(saved, roster)
  ns.db = saved or {}
  -- Aeltere Staende (Prototyp) hatten Teilen aus als Voreinstellung: einmalig auf den neuen Standard heben.
  if saved and saved.schema == nil then saved.sharing = nil end
  ns.db.schema = 1
  for key, value in pairs(DEFAULTS) do
    if ns.db[key] == nil then
      ns.db[key] = type(value) == "table" and {} or value
    end
  end
  ns.roster = {}
  for _, name in ipairs(roster or {}) do
    local n = ns.NormName(name)
    if n then ns.roster[n] = true end
  end
  return ns.db
end

function ns.IsMember(name)
  local n = ns.NormName(name)
  if not n then return false end
  return ns.roster[n] == true or ns.db.members[n] == true
end

function ns.MemberList()
  local seen, out = {}, {}
  for n in pairs(ns.roster) do seen[n] = true end
  for n in pairs(ns.db.members) do seen[n] = true end
  for n in pairs(seen) do out[#out + 1] = n end
  table.sort(out)
  return out
end

-- Gibt Name und ggf. einen Fehlerschluessel zurueck.
function ns.AddMember(name)
  local n = ns.NormName(name)
  if not n then return nil, "noName" end
  if ns.IsMember(n) then return n, "already" end
  ns.db.members[n] = true
  return n
end

function ns.RemoveMember(name)
  local n = ns.NormName(name)
  if not n or not ns.db.members[n] then return n, "unknown" end
  ns.db.members[n] = nil
  ns.peers[n] = nil
  return n
end

-- Protokoll ----------------------------------------------------------------------
-- H|v            Hallo (Version), Antwort ist sofort eine Position
-- P|map|x|y      Position, x und y als Ganzzahl 0..10000
-- I              Position unbekannt (Instanz, Schlachtfeld)
-- O              Teilen beendet, Pin entfernen
-- A              Hier, teilt aber nicht (Antwort auf H); der andere darf dann seine Position schicken
-- QR             Questliste angefragt
-- Q|i|n|id,id    Questliste, Teil i von n
-- QN             Questliste wird nicht geteilt

ns.QUESTS_PER_MESSAGE = 20

function ns.EncodePosition(mapID, x, y)
  local function q(v) return math.max(0, math.min(10000, math.floor(v * 10000 + 0.5))) end
  return ("P|%d|%d|%d"):format(mapID, q(x), q(y))
end

function ns.EncodeQuests(ids)
  local out, total = {}, math.max(1, math.ceil(#ids / ns.QUESTS_PER_MESSAGE))
  for part = 1, total do
    local chunk = {}
    for i = (part - 1) * ns.QUESTS_PER_MESSAGE + 1, math.min(#ids, part * ns.QUESTS_PER_MESSAGE) do
      chunk[#chunk + 1] = ids[i]
    end
    out[part] = ("Q|%d|%d|%s"):format(part, total, table.concat(chunk, ","))
  end
  return out
end

-- Liefert eine Tabelle { kind = ... } oder nil bei Muell. Fremde Eingaben werden nie ungeprueft uebernommen.
function ns.Decode(text)
  if type(text) ~= "string" or #text > 255 then return nil end
  local kind, rest = text:match("^(%u+)|?(.*)$")
  if kind == "H" then
    return { kind = "H", version = tonumber(rest) or 0 }
  elseif kind == "P" then
    local map, x, y = rest:match("^(%d+)|(%d+)|(%d+)$")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not map or x > 10000 or y > 10000 then return nil end
    return { kind = "P", map = map, x = x / 10000, y = y / 10000 }
  elseif kind == "I" or kind == "O" or kind == "A" or kind == "QR" or kind == "QN" then
    return { kind = kind }
  elseif kind == "Q" then
    local part, total, list = rest:match("^(%d+)|(%d+)|([%d,]*)$")
    part, total = tonumber(part), tonumber(total)
    if not part or part < 1 or total < 1 or part > total or total > 50 then return nil end
    local ids = {}
    for id in list:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
    return { kind = "Q", part = part, total = total, ids = ids }
  end
  return nil
end

-- Gegenstellen --------------------------------------------------------------------

ns.PEER_TTL = 75

-- Merkt eine empfangene Nachricht. Gibt Gegenstelle, Nachricht und Name zurueck, nil wenn der Absender kein Mitglied ist oder Muell schickt.
function ns.Receive(sender, text, now)
  local name = ns.NormName(sender)
  if not name or not ns.IsMember(name) then return nil end
  local msg = ns.Decode(text)
  if not msg then return nil end
  local peer = ns.peers[name] or {}
  ns.peers[name] = peer
  peer.seen = now
  if msg.kind == "P" then
    peer.map, peer.x, peer.y, peer.instance = msg.map, msg.x, msg.y, false
  elseif msg.kind == "I" then
    peer.map, peer.x, peer.y, peer.instance = nil, nil, nil, true
  elseif msg.kind == "O" then
    peer.map, peer.x, peer.y, peer.instance = nil, nil, nil, false
    peer.seen = nil
  elseif msg.kind == "QN" then
    peer.questsPrivate, peer.quests, peer.questParts = true, nil, nil
  elseif msg.kind == "Q" then
    peer.questsPrivate = false
    if msg.part == 1 or not peer.questParts then peer.questParts = {} end
    peer.questParts[msg.part] = msg.ids
    local all = {}
    for i = 1, msg.total do
      if not peer.questParts[i] then all = nil break end
      for _, id in ipairs(peer.questParts[i]) do all[#all + 1] = id end
    end
    if all then peer.quests, peer.questParts = all, nil end
  end
  return peer, msg, name
end

function ns.PeerOnline(name, now)
  local peer = ns.peers[name]
  return peer ~= nil and peer.seen ~= nil and now - peer.seen <= ns.PEER_TTL
end

-- Pins nur fuer frische Positionen: abgelaufene Gegenstellen verschwinden von der Karte.
function ns.VisiblePeers(now)
  local out = {}
  for name, peer in pairs(ns.peers) do
    if peer.map and ns.PeerOnline(name, now) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end
