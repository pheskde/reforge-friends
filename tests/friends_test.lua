-- Prueft die Logik von Friends gegen eine nachgebaute WoW-API. Ob das Spiel die API wirklich so anbietet, zeigt nur der Test im Spiel.
-- Aufruf aus dem Repo-Wurzelordner: lua tests/friends_test.lua
local ROOT = "ReforgeFriends/"
local failures, checks = 0, 0

local function check(name, condition)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    print("FEHLER: " .. name)
  end
end

-- Globale Stubs. Alles Spielabhaengige in den Addon-Dateien ist ueber ns.* ersetzbar, darum reichen einfache Stubs.
local function frame()
  -- Jede Methode liefert wieder so ein Objekt (CreateFontString, CreateTexture usw.), damit Fensteraufbau ohne Spiel durchlaeuft.
  return setmetatable({}, { __index = function() return function() return frame() end end })
end
function GetLocale() return "enUS" end
function GetTime() return 0 end
function CreateFrame() return frame() end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."

-- Ein "Spielclient": eigener Namensraum, eigene Datenbank, Nachrichten landen im Postausgang.
local function newGame(name, opts)
  opts = opts or {}
  local ns = {}
  for _, file in ipairs({ "Core.lua", "Comm.lua", "Minimap.lua", "Overview.lua", "Slash.lua" }) do
    local chunk = assert(loadfile(ROOT .. file))
    chunk("ReforgeFriends", ns)
  end
  local game = { name = name, ns = ns, now = 1000, outbox = {}, printed = {}, pos = opts.pos, quests = opts.quests or {} }
  ns.InitDB(opts.saved, opts.roster)
  -- Die Tests gehen vom ausgeschalteten Teilen aus; der Standard "an" wird unten eigens geprueft.
  ns.db.sharing = opts.sharing or false
  ns.Now = function() return game.now end
  ns.SendAddon = function(text, target) game.outbox[#game.outbox + 1] = { text = text, target = target } end
  ns.GetPosition = function()
    if game.pos then return game.pos[1], game.pos[2], game.pos[3] end
    return nil
  end
  ns.GetQuestIDs = function() return game.quests end
  ns.Print = function(text) game.printed[#game.printed + 1] = text end
  ns.RefreshMap = function() end
  return game
end

-- Stellt alles zu, was `from` an `to` geschickt hat.
local function deliver(from, to)
  local out = from.outbox
  from.outbox = {}
  local count = 0
  for _, m in ipairs(out) do
    if m.target == to.name then
      to.ns.OnMessage(from.name, m.text, to.now)
      count = count + 1
    end
  end
  return count
end

local function advance(seconds, ...)
  for _, g in ipairs({ ... }) do g.now = g.now + seconds end
end

-- Protokoll -------------------------------------------------------------------------
do
  local g = newGame("Anna")
  local ns = g.ns
  local p = ns.Decode(ns.EncodePosition(1429, 0.5, 0.25))
  check("Position: Hin und zurueck", p and p.kind == "P" and p.map == 1429 and p.x == 0.5 and p.y == 0.25)
  check("Position: ausserhalb 0..1 wird geklemmt", ns.Decode(ns.EncodePosition(1, 1.7, -0.2)).x == 1)
  check("Decode: Muell", ns.Decode("hallo") == nil and ns.Decode("") == nil and ns.Decode(nil) == nil)
  check("Decode: Position ueber Bereich", ns.Decode("P|1|10001|5") == nil)
  check("Decode: Position unvollstaendig", ns.Decode("P|1|5") == nil)
  check("Decode: zu lang", ns.Decode("I" .. string.rep("x", 300)) == nil)
  check("Decode: Quest-Teil ausser Reihe", ns.Decode("Q|3|2|1,2") == nil)
  check("Decode: Quest-Teil mit Buchstaben", ns.Decode("Q|1|1|1,x") == nil)
  check("Decode: Instanz", ns.Decode("I").kind == "I")
  local ids = {}
  for i = 1, 45 do ids[i] = 1000 + i end
  local parts = ns.EncodeQuests(ids)
  check("Quests: 45 Eintraege in 3 Teilen", #parts == 3)
  local longest = 0
  for _, t in ipairs(parts) do longest = math.max(longest, #t) end
  check("Quests: jeder Teil passt in eine Nachricht (255)", longest <= 255)
  check("Quests: leere Liste ist ein gueltiger Teil", ns.Decode(ns.EncodeQuests({})[1]).total == 1)
  check("Name: Realm und Schreibweise", ns.NormName("bERT-Realm") == "Bert")
end

-- Mitglieder ------------------------------------------------------------------------
do
  local g = newGame("Anna", { roster = { "karl" } })
  local ns = g.ns
  check("Roster-Eintrag ist Mitglied", ns.IsMember("Karl-Irgendwo"))
  check("Fremder ist kein Mitglied", not ns.IsMember("Fremder"))
  check("Hinzufuegen", ns.AddMember("bert") == "Bert" and ns.IsMember("Bert"))
  local _, err = ns.AddMember("BERT")
  check("Doppelt hinzufuegen meldet 'already'", err == "already")
  local _, err2 = ns.RemoveMember("Karl")
  check("Roster-Eintrag laesst sich nicht von Hand entfernen", err2 == "unknown" and ns.IsMember("Karl"))
  ns.RemoveMember("Bert")
  check("Entfernen", not ns.IsMember("Bert"))
  check("Liste sortiert", table.concat(ns.MemberList(), ",") == "Karl")
  check("Offline-Meldung nur fuer Mitglieder", ns.IsOfflineNotice("No player named 'Karl' is currently playing.")
    and not ns.IsOfflineNotice("No player named 'Fremder' is currently playing.")
    and not ns.IsOfflineNotice("etwas anderes"))
end

-- Zusammenspiel zweier Clients --------------------------------------------------------
do
  local a = newGame("Anna", { roster = { "Bert" }, pos = { 1429, 0.4, 0.6 } })
  local b = newGame("Bert", { roster = { "Anna" } })

  a.ns.Tick(a.now)
  check("Teilen aus: nichts wird gesendet", #a.outbox == 0)

  a.ns.SetSharing(true, a.now)
  check("Teilen an: Hallo an das Mitglied", #a.outbox == 1 and a.outbox[1].text == "H|1" and a.outbox[1].target == "Bert")

  deliver(a, b)
  check("Bert (teilt nicht) antwortet mit 'A'", #b.outbox == 1 and b.outbox[1].text == "A")
  check("Bert sieht Anna als online", b.ns.PeerOnline("Anna", b.now))
  deliver(b, a)
  check("Anna sieht Bert als online", a.ns.PeerOnline("Bert", a.now))
  check("Anna sendet die Position sofort an Bert", #a.outbox == 1 and a.outbox[1].text == "P|1429|4000|6000")
  deliver(a, b)
  local peers = b.ns.VisiblePeers(b.now)
  check("Bert zeigt Annas Pin", #peers == 1 and peers[1] == "Anna" and b.ns.peers.Anna.map == 1429 and b.ns.peers.Anna.x == 0.4)

  advance(5, a, b)
  a.ns.Tick(a.now)
  check("Ohne Bewegung kein erneutes Senden vor dem Herzschlag", #a.outbox == 0)
  a.pos = { 1429, 0.41, 0.6 }
  advance(5, a, b)
  a.ns.Tick(a.now)
  check("Bewegung wird gesendet", #a.outbox == 1)
  deliver(a, b)

  advance(30, a, b)
  a.ns.Tick(a.now)
  check("Herzschlag nach 30 Sekunden ohne Bewegung", #a.outbox == 1)
  deliver(a, b)

  a.pos = nil
  advance(5, a, b)
  a.ns.Tick(a.now)
  deliver(a, b)
  check("Instanz: Pin verschwindet, Status bleibt", #b.ns.VisiblePeers(b.now) == 0 and b.ns.peers.Anna.instance == true)

  a.pos = { 1429, 0.5, 0.5 }
  advance(5, a, b)
  a.ns.Tick(a.now)
  deliver(a, b)
  check("Zurueck in der Welt: Pin wieder da", #b.ns.VisiblePeers(b.now) == 1)

  advance(80, b)
  check("Ohne Nachricht laeuft der Pin nach 75 Sekunden ab", #b.ns.VisiblePeers(b.now) == 0)

  -- Bert schaut nur zu und meldet sich per Herzschlag; Anna haelt ihn dadurch online.
  a.now = b.now
  for _ = 1, 4 do
    advance(30, a, b)
    b.ns.Tick(b.now)
    deliver(b, a)
    a.ns.Tick(a.now)
    deliver(a, b)
  end
  check("Zuschauer bleibt beim Sender online", a.ns.PeerOnline("Bert", a.now))
  check("Neue Position holt den Pin zurueck", #b.ns.VisiblePeers(b.now) == 1)

  a.ns.SetSharing(false, a.now)
  deliver(a, b)
  check("Teilen aus: Pin verschwindet sofort", #b.ns.VisiblePeers(b.now) == 0)

  -- Quests
  a.ns.SetSharing(true, a.now)
  a.quests = {}
  for i = 1, 45 do a.quests[i] = 5000 + i end
  deliver(a, b)
  deliver(b, a)
  advance(5, a, b)
  check("Bert fragt Quests an", b.ns.AskQuests("Anna", b.now) == true)
  deliver(b, a)
  deliver(a, b)
  check("Quests aus: Anna antwortet 'nicht geteilt'", b.ns.peers.Anna.questsPrivate == true and b.ns.peers.Anna.quests == nil)

  a.ns.db.shareQuests = true
  advance(11, a, b)
  check("Anfrage nach der Pause erlaubt", b.ns.AskQuests("Anna", b.now) == true)
  deliver(b, a)
  local sent = #a.outbox
  deliver(a, b)
  check("Quests an: drei Teile", sent == 3)
  check("Quests werden zusammengesetzt", b.ns.peers.Anna.quests and #b.ns.peers.Anna.quests == 45 and b.ns.peers.Anna.quests[45] == 5045)
  check("Anfragen sind begrenzt", b.ns.AskQuests("Anna", b.now) == false)
  check("Nicht-Mitglied wird nicht angefragt", b.ns.AskQuests("Fremder", b.now) == false)
end

-- Fremde -------------------------------------------------------------------------------
do
  local a = newGame("Anna", { roster = { "Bert" }, pos = { 1, 0.1, 0.1 } })
  a.ns.db.sharing = true
  a.ns.OnMessage("Fremder", "H|1", a.now)
  check("Fremder bekommt keine Antwort", #a.outbox == 0)
  a.ns.OnMessage("Fremder", "P|1|5|5", a.now)
  check("Fremder erzeugt keinen Pin", #a.ns.VisiblePeers(a.now) == 0 and a.ns.peers.Fremder == nil)
  a.ns.OnMessage("Fremder", "QR", a.now)
  check("Fremder bekommt keine Quests", #a.outbox == 0)
  a.ns.OnMessage("Bert", "muell", a.now)
  check("Muell von einem Mitglied wird ignoriert", a.ns.peers.Bert == nil)
  a.ns.OnMessage("Bert", "QR", a.now)
  check("Quest-Anfrage bei geschlossenen Quests: 'QN'", #a.outbox == 1 and a.outbox[1].text == "QN")
end

-- Chatbefehle ---------------------------------------------------------------------------
do
  local g = newGame("Anna")
  g.ns.Slash("add karl")
  check("/rff add", g.ns.IsMember("Karl"))
  g.ns.Slash("share on")
  check("/rff share on", g.ns.db.sharing == true)
  g.ns.Slash("share off")
  check("/rff share off", g.ns.db.sharing == false)
  g.ns.Slash("quests on")
  check("/rff quests on", g.ns.db.shareQuests == true)
  g.ns.Slash("share vielleicht")
  check("Ungueltiger Wert aendert nichts", g.ns.db.sharing == false)
  g.ns.Slash("remove karl")
  check("/rff remove", not g.ns.IsMember("Karl"))
  g.ns.Slash("hilfe")
  check("Hilfe wird gezeigt", g.printed[#g.printed] == g.ns.L.help)
  local opened
  g.ns.ToggleOverview = function() opened = true end
  g.ns.Slash("")
  check("/rff ohne Argument oeffnet das Fenster", opened == true)
end

-- Standardwerte und Minimap-Symbol --------------------------------------------------------
do
  local ns = newGame("X").ns
  local db = ns.InitDB(nil, nil)
  check("Teilen ist standardmaessig an", db.sharing == true)
  check("Questliste ist standardmaessig privat", db.shareQuests == false)
  check("Minimap-Symbol ist standardmaessig sichtbar", db.showMinimapButton == true)

  local old = ns.InitDB({ sharing = false, members = { Karl = true } }, nil)
  check("Alter Stand ohne schema: Teilen wird einmalig auf an gehoben", old.sharing == true and old.members.Karl == true)
  local chosen = ns.InitDB({ schema = 1, sharing = false }, nil)
  check("Bewusst ausgeschaltetes Teilen bleibt aus", chosen.sharing == false)

  local x, y = ns.MinimapOffset(0, 100)
  check("Minimap: Winkel 0 liegt rechts", math.abs(x - 100) < 1e-9 and math.abs(y) < 1e-9)
  x, y = ns.MinimapOffset(90, 100)
  check("Minimap: Winkel 90 liegt oben", math.abs(x) < 1e-9 and math.abs(y - 100) < 1e-9)
  check("Minimap: Winkel aus Mauspunkt", math.abs(ns.MinimapAngle(0, -5) - 270) < 1e-9 and math.abs(ns.MinimapAngle(-3, 0) - 180) < 1e-9)

  local g = newGame("Y")
  g.ns.Slash("minimap off")
  check("/rff minimap off", g.ns.db.showMinimapButton == false)
end

-- Uebersicht ---------------------------------------------------------------------------------
do
  local function text(g) return table.concat(g.ns.BuildOverview(g.now), "\n") end
  local function has(haystack, needle) return haystack:find(needle, 1, true) ~= nil end

  local g = newGame("Anna")
  check("Ohne Community-Daten: Hinweis auf den Client", has(text(g), g.ns.L.ovNoData))

  g.ns.InitDB(nil, nil, {})
  check("Keine Community: eigener Hinweis", has(text(g), g.ns.L.ovNoCommunities))

  local communities = {
    { name = "Raidgruppe", members = {
      { account = "Thomas", you = true, characters = { "Emiri", "Timo" } },
      { account = "Gast", you = false, characters = { "Gerda" } },
      { account = "Leer", you = false, characters = {} },
    } },
    { name = "Zweite", members = {} },
  }
  g.ns.InitDB(nil, { "Gerda" }, communities)
  g.ns.db.sharing = false
  local out = text(g)
  check("Uebersicht: Community-Anzahl", has(out, g.ns.L.ovCommunities:format(2)))
  check("Uebersicht: Community und Mitglieder", has(out, "Raidgruppe") and has(out, "Thomas (" .. g.ns.L.ovYou .. ")") and has(out, "Gast:"))
  check("Uebersicht: Charaktere stehen da", has(out, "Emiri") and has(out, "Timo") and has(out, "Gerda"))
  check("Uebersicht: Mitglied ohne Charaktere", has(out, g.ns.L.ovNoChars))
  check("Uebersicht: niemand online -> keine gruenen Punkte", not has(out, "|cff44dd66*"))

  g.ns.db.members.Karl = true
  check("Uebersicht: von Hand eingetragene Namen", has(text(g), "Karl"))

  g.ns.Receive("Gerda", "I", g.now)
  check("Uebersicht: online gesehener Charakter bekommt den gruenen Punkt", has(text(g), "|cff44dd66*|r Gerda"))
  advance(80, g)
  check("Uebersicht: nach Ablauf wieder grau", not has(text(g), "|cff44dd66*|r Gerda"))

  -- Namen mit Sonderzeichen duerfen die Uebersicht nicht zerbrechen (sie werden als Text behandelt).
  g.ns.InitDB(nil, nil, { { name = "A|cffff0000B", members = {} } })
  check("Uebersicht: Community-Name unveraendert uebernommen", has(text(g), "A|cffff0000B"))

  g.ns.Slash("communities")
  check("/rff communities schreibt in den Chat", #g.printed > 0)
  g.ns.Slash("help")
  check("/rff help zeigt die Hilfe", g.printed[#g.printed] == g.ns.L.help)
end

print(("%d Pruefungen, %d Fehler"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
