-- Logik von Friends: Einstellungen, Mitgliederliste, Protokoll und Gegenstellen. Senden/Empfangen liegt in Comm.lua, die Karte in Map.lua.
local _, ns = ...

ns.PREFIX = "RFFR"
ns.PROTOCOL = 1

-- Teilen und Questliste sind standardmaessig an: es geht ohnehin nur an Mitglieder der eigenen Liste (und nur auf Anfrage).
local DEFAULTS = { sharing = true, shareQuests = true, showPins = true, showMinimapButton = true, minimapAngle = 210, members = {} }

local LOCALES = {
  enUS = {
    help = "/rff (window) | communities | share on|off | quests on|off | pins on|off | minimap on|off | add <name> | remove <name> | list | status | help",
    sharingOn = "Sharing your position with %d community member(s).", sharingOff = "Sharing is off. Nobody receives your position.",
    questsOn = "Others may now ask for your quest list.", questsOff = "Your quest list is private.",
    pinsOn = "Friend pins shown on the map.", pinsOff = "Friend pins hidden.",
    added = "%s added.", removed = "%s removed.", already = "%s is already on the list.", unknown = "%s is not on the list.",
    listHead = "Community members (%d):", listEmpty = "No community members yet. /rff add <name>",
    onMap = "on the map", elsewhere = "elsewhere", inInstance = "in an instance", offline = "not seen",
    status = "Sharing: %s, quests: %s, pins: %s", on = "on", off = "off",
    minimapOn = "Minimap button shown.", minimapOff = "Minimap button hidden. /rff minimap on brings it back.",
    tipShare = "Sharing: %s", tipOnline = "%d of %d members seen", tipLeft = "Right click: sharing on or off", tipRight = "Shift+right click: map pins on or off", tipDrag = "Drag: move the button",
    quests = "Open quests (%d):", questsAsk = "Asking for quests...", questsPrivate = "does not share quests", questsNone = "No quests received.",
    unknownQuest = "Quest %d", questsMore = "Click for the full list", noName = "Give a character name.",
    tipMembers = "%d other member(s), %d character(s)", tipSeen = "%d character(s) seen online",
    ovTitle = "reforge Friends", ovCommunities = "Your communities (%d)", ovNoData = "No community data yet. The reforge client writes it every 10 minutes and after login; then log in again or /reload. It needs client 0.1.7 or newer.",
    ovNoCommunities = "You are not in a community yet. Create or join one in the reforge client.",
    ovYou = "you", ovNoChars = "no characters reported", ovManual = "Added by hand: %s", ovHint = "Green dot: seen online. Characters appear when the member's reforge client has reported them.",
    menuManual = "Added by hand", menuRemove = "right click: remove", setHeader = "Settings", setShare = "Share my position", setQuests = "Share my quest list", setPins = "Friend pins on map", setMinimap = "Minimap button", addHint = "Add character...", addButton = "Add", menuMembers = "Members", menuHint = "Click a character: open quests", ovSharing = "Sharing: %s  |  Quests: %s", ovWindow = "Overview window", tipOverview = "Left click: community window",
  },
  deDE = {
    help = "/rff (window) | communities | share on|off | quests on|off | pins on|off | minimap on|off | add <Name> | remove <Name> | list | status | help",
    sharingOn = "Deine Position geht an %d Community-Mitglied(er).", sharingOff = "Teilen ist aus. Niemand erhält deine Position.",
    questsOn = "Andere dürfen jetzt deine Questliste abfragen.", questsOff = "Deine Questliste ist privat.",
    pinsOn = "Freunde-Pins auf der Karte angezeigt.", pinsOff = "Freunde-Pins ausgeblendet.",
    added = "%s hinzugefügt.", removed = "%s entfernt.", already = "%s steht schon in der Liste.", unknown = "%s steht nicht in der Liste.",
    listHead = "Community-Mitglieder (%d):", listEmpty = "Noch keine Community-Mitglieder. /rff add <Name>",
    onMap = "auf der Karte", elsewhere = "woanders", inInstance = "in einer Instanz", offline = "nicht gesehen",
    status = "Teilen: %s, Quests: %s, Pins: %s", on = "an", off = "aus",
    minimapOn = "Minimap-Symbol angezeigt.", minimapOff = "Minimap-Symbol ausgeblendet. /rff minimap on holt es zurück.",
    tipShare = "Teilen: %s", tipOnline = "%d von %d Mitgliedern gesehen", tipLeft = "Rechtsklick: Teilen an oder aus", tipRight = "Shift+Rechtsklick: Karten-Pins an oder aus", tipDrag = "Ziehen: Symbol verschieben",
    quests = "Offene Quests (%d):", questsAsk = "Frage Quests an...", questsPrivate = "teilt keine Quests", questsNone = "Keine Quests erhalten.",
    unknownQuest = "Quest %d", questsMore = "Klick für die ganze Liste", noName = "Gib einen Charakternamen an.",
    tipMembers = "%d weitere(s) Mitglied(er), %d Charakter(e)", tipSeen = "%d Charakter(e) online gesehen",
    ovTitle = "reforge Friends", ovCommunities = "Deine Communities (%d)", ovNoData = "Noch keine Community-Daten. Der reforge-Client schreibt sie alle 10 Minuten und nach dem Login; danach neu einloggen oder /reload. Nötig ist Client 0.1.7 oder neuer.",
    ovNoCommunities = "Du bist noch in keiner Community. Lege im reforge-Client eine an oder tritt einer bei.",
    ovYou = "du", ovNoChars = "keine Charaktere gemeldet", ovManual = "Von Hand eingetragen: %s", ovHint = "Grüner Punkt: online gesehen. Charaktere erscheinen, sobald der reforge-Client des Mitglieds sie gemeldet hat.",
    menuManual = "Von Hand eingetragen", menuRemove = "Rechtsklick: entfernen", setHeader = "Einstellungen", setShare = "Meine Position teilen", setQuests = "Meine Questliste teilen", setPins = "Freunde-Pins auf der Karte", setMinimap = "Minimap-Symbol", addHint = "Charakter hinzufügen...", addButton = "Hinzufügen", menuMembers = "Mitglieder", menuHint = "Charakter anklicken: Quests öffnen", ovSharing = "Teilen: %s  |  Quests: %s", ovWindow = "Übersichtsfenster", tipOverview = "Linksklick: Community-Fenster",
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
-- Sie kommen zu den von Hand eingetragenen. `communities` (ReforgeFriendsCommunities) sind dieselben Mitglieder nach Community gegliedert, nur zur Anzeige.
function ns.InitDB(saved, roster, communities)
  ns.db = saved or {}
  ns.communities = communities
  -- Aeltere Staende (Prototyp) hatten Teilen aus als Voreinstellung: einmalig auf den neuen Standard heben.
  -- Schema 2: die Questliste ist jetzt ebenfalls standardmaessig an, auch bei Staenden, die den alten Standard "aus" gespeichert haben.
  if saved and saved.schema == nil then saved.sharing = nil end
  if saved and (saved.schema or 0) < 2 then saved.shareQuests = nil end
  ns.db.schema = 2
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
-- S|KLASSE|lvl|%  Klasse (Token), Stufe und Erfahrung in Prozent (leer auf Hoechststufe), geht mit jeder Position raus
-- QR             Questliste angefragt
-- Q|i|n|id,id    Questliste, Teil i von n
-- QN             Questliste wird nicht geteilt

ns.QUESTS_PER_MESSAGE = 20

function ns.EncodePosition(mapID, x, y)
  local function q(v) return math.max(0, math.min(10000, math.floor(v * 10000 + 0.5))) end
  return ("P|%d|%d|%d"):format(mapID, q(x), q(y))
end

function ns.EncodeStatus(class, level, pct)
  return ("S|%s|%d|%s"):format(class, level, pct and tostring(pct) or "")
end

-- "Krieger - lvl 32 - 22%" (ohne Prozent auf Hoechststufe). nil, wenn nichts bekannt ist.
function ns.StatusText(info)
  if not info or not info.level then return nil end
  local names = LOCALIZED_CLASS_NAMES_MALE
  local class = info.class and ((names and names[info.class]) or info.class) or "?"
  local text = ("%s - lvl %d"):format(class, info.level)
  if info.pct then text = text .. (" - %d%%"):format(info.pct) end
  return text
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
  elseif kind == "S" then
    local class, level, pct = rest:match("^(%u+)|(%d+)|(%d*)$")
    level, pct = tonumber(level), tonumber(pct)
    if not class or not level or level < 1 or level > 200 or (pct and pct > 100) then return nil end
    return { kind = "S", class = class, level = level, pct = pct }
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
  -- Absender mit Realm ("Name-Realm") merken: Antworten gehen an genau diesen Namen, sonst erreicht man Spieler von verbundenen Realms nicht.
  if sender:find("-", 1, true) then peer.target = sender end
  if msg.kind == "P" then
    peer.map, peer.x, peer.y, peer.instance = msg.map, msg.x, msg.y, false
  elseif msg.kind == "I" then
    peer.map, peer.x, peer.y, peer.instance = nil, nil, nil, true
  elseif msg.kind == "O" then
    peer.map, peer.x, peer.y, peer.instance = nil, nil, nil, false
    peer.seen = nil
  elseif msg.kind == "S" then
    peer.class, peer.level, peer.pct = msg.class, msg.level, msg.pct
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

-- Uebersicht ------------------------------------------------------------------------------------
-- Baut die Zeilen der Uebersicht (Fenster und /rff communities). Farbcodes sind WoW-Textfarben.

local GREEN, GREY, ORANGE = "|cff44dd66", "|cff888888", "|cfff27a2c"

local function charLine(name, now)
  local dot = ns.PeerOnline(name, now) and (GREEN .. "*|r ") or (GREY .. "- |r")
  return dot .. name
end

function ns.BuildOverview(now)
  local L = ns.L
  local lines = {}
  local communities = ns.communities
  if type(communities) ~= "table" then
    lines[#lines + 1] = GREY .. L.ovNoData .. "|r"
  elseif #communities == 0 then
    lines[#lines + 1] = GREY .. L.ovNoCommunities .. "|r"
  else
    lines[#lines + 1] = ORANGE .. L.ovCommunities:format(#communities) .. "|r"
    for _, community in ipairs(communities) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = "|cffffffff" .. tostring(community.name) .. "|r"
      for _, member in ipairs(community.members or {}) do
        local label = tostring(member.account)
        if member.you then label = label .. " (" .. L.ovYou .. ")" end
        local chars = {}
        for _, c in ipairs(member.characters or {}) do chars[#chars + 1] = charLine(c, now) end
        if #chars == 0 then
          lines[#lines + 1] = "  " .. label .. ": " .. GREY .. L.ovNoChars .. "|r"
        else
          lines[#lines + 1] = "  " .. label .. ": " .. table.concat(chars, ", ")
        end
      end
    end
  end
  local manual = {}
  for name in pairs(ns.db.members) do manual[#manual + 1] = charLine(name, now) end
  table.sort(manual)
  if #manual > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = L.ovManual:format(table.concat(manual, ", "))
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = L.ovSharing:format(ns.db.sharing and L.on or L.off, ns.db.shareQuests and L.on or L.off)
  lines[#lines + 1] = GREY .. L.ovHint .. "|r"
  return lines
end

-- Zeilen des Minimap-Menues: Community, deine Charaktere, die Charaktere aller Mitglieder. `me` ist der aktuelle Charakter.
-- kind: header | member | char | text. Char-Zeilen tragen name, online und self (eigener Charakter).
function ns.BuildMenu(now, me)
  local L = ns.L
  local rows = {}
  local function add(row) rows[#rows + 1] = row end
  me = ns.NormName(me)
  local communities = type(ns.communities) == "table" and ns.communities or {}
  for _, community in ipairs(communities) do
    add({ kind = "header", text = tostring(community.name) })
    -- Eigene Charaktere zuerst.
    local ordered = {}
    for _, member in ipairs(community.members or {}) do
      if member.you then table.insert(ordered, 1, member) else ordered[#ordered + 1] = member end
    end
    for _, member in ipairs(ordered) do
      local label = tostring(member.account)
      if member.you then label = label .. " (" .. L.ovYou .. ")" end
      add({ kind = "member", text = label })
      local chars = member.characters or {}
      if #chars == 0 then add({ kind = "text", text = L.ovNoChars }) end
      for _, c in ipairs(chars) do
        local mine = member.you and ns.NormName(c) == me
        local info = mine and ns.GetStatus and ns.StatusText(ns.OwnInfo()) or ns.StatusText(ns.peers[ns.NormName(c) or ""])
        add({ kind = "char", name = c, self = mine and true or false, info = info, online = mine or ns.PeerOnline(ns.NormName(c) or "", now) })
      end
    end
  end
  if #communities == 0 then
    local list = ns.MemberList()
    add({ kind = "header", text = L.menuMembers })
    if #list == 0 then add({ kind = "text", text = L.ovNoData }) end
    for _, name in ipairs(list) do add({ kind = "char", name = name, self = false, manual = ns.db.members[name] == true, info = ns.StatusText(ns.peers[name]), online = ns.PeerOnline(name, now) }) end
  else
    local manual = {}
    for name in pairs(ns.db.members) do manual[#manual + 1] = name end
    table.sort(manual)
    if #manual > 0 then
      add({ kind = "header", text = L.menuManual })
      for _, name in ipairs(manual) do add({ kind = "char", name = name, self = false, manual = true, info = ns.StatusText(ns.peers[name]), online = ns.PeerOnline(name, now) }) end
    end
  end
  return rows
end

-- Zahlen fuer den Tooltip: andere Mitglieder (ohne dich, ueber alle Communities), deren Charaktere und wie viele davon gerade online gesehen wurden.
-- Ohne Community-Daten zaehlen nur die Namen der Liste (von Hand eingetragene und Roster), dann gibt es keine Mitgliederzahl.
function ns.CommunityStats(now)
  local members, seenMember = 0, {}
  for _, community in ipairs(type(ns.communities) == "table" and ns.communities or {}) do
    for _, member in ipairs(community.members or {}) do
      if not member.you and not seenMember[member.account] then
        seenMember[member.account] = true
        members = members + 1
      end
    end
  end
  local characters, seen = ns.MemberList(), 0
  for _, name in ipairs(characters) do
    if ns.PeerOnline(name, now) then seen = seen + 1 end
  end
  return members, #characters, seen
end
