-- Chatbefehle: /rff (oder /reforgefriends)
local _, ns = ...

local function flag(arg)
  if arg == "on" or arg == "an" or arg == "1" then return true end
  if arg == "off" or arg == "aus" or arg == "0" then return false end
  return nil
end

function ns.Slash(input)
  local L = ns.L
  local cmd, arg = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  arg = arg or ""

  if cmd == "share" then
    local on = flag(arg:lower())
    if on == nil then return ns.Print(L.help) end
    ns.SetSharing(on, ns.Now())
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    ns.Print(on and L.sharingOn:format(#ns.MemberList()) or L.sharingOff)
  elseif cmd == "quests" then
    local on = flag(arg:lower())
    if on == nil then return ns.Print(L.help) end
    ns.db.shareQuests = on
    ns.Print(on and L.questsOn or L.questsOff)
  elseif cmd == "pins" then
    local on = flag(arg:lower())
    if on == nil then return ns.Print(L.help) end
    ns.db.showPins = on
    ns.RefreshMap()
    ns.Print(on and L.pinsOn or L.pinsOff)
  elseif cmd == "minimap" then
    local on = flag(arg:lower())
    if on == nil then return ns.Print(L.help) end
    ns.db.showMinimapButton = on
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    ns.Print(on and L.minimapOn or L.minimapOff)
  elseif cmd == "add" then
    local name, err = ns.AddMember(arg)
    ns.Print(err and L[err]:format(name or arg) or L.added:format(name))
  elseif cmd == "remove" then
    local name, err = ns.RemoveMember(arg)
    ns.Print(err and L[err]:format(name or arg) or L.removed:format(name))
  elseif cmd == "" or cmd == "window" or cmd == "fenster" then
    if ns.ToggleOverview then ns.ToggleOverview() else ns.Print(L.help) end
  elseif cmd == "communities" then
    for _, line in ipairs(ns.BuildOverview(ns.Now())) do ns.Print(line) end
  elseif cmd == "help" or cmd == "hilfe" then
    ns.Print(L.help)
  elseif cmd == "list" then
    local members, now = ns.MemberList(), ns.Now()
    if #members == 0 then return ns.Print(L.listEmpty) end
    ns.Print(L.listHead:format(#members))
    for _, name in ipairs(members) do
      local peer = ns.peers[name]
      local where = L.offline
      if ns.PeerOnline(name, now) then
        where = peer.instance and L.inInstance or (peer.map and L.onMap or L.elsewhere)
      end
      ns.Print("  " .. name .. " - " .. where)
    end
  elseif cmd == "status" then
    local function word(v) return v and L.on or L.off end
    ns.Print(L.status:format(word(ns.db.sharing), word(ns.db.shareQuests), word(ns.db.showPins)))
  else
    ns.Print(L.help)
  end
end

SLASH_REFORGEFRIENDS1 = "/rff"
SLASH_REFORGEFRIENDS2 = "/reforgefriends"
SlashCmdList["REFORGEFRIENDS"] = function(input) ns.Slash(input) end
