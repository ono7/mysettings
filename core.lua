-- 1. COLOR & LOGGING HELPERS
local setvarSuccess = 0
local setvarFailed = 0

local Colors = {
  green = "00ff00",
  blue = "00aaff",
  red = "ff0000",
  white = "ffffff",
  yellow = "ffff00",
}

local function Colorize(text, color)
  local hex = Colors[color] or Colors.white
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function Log(message, value)
  local prefix = Colorize("[MySettings]", "green")
  local suffix = value and (": " .. Colorize(value, "blue")) or ""
  print(prefix .. " " .. message .. suffix)
end

-- 2. SMART SETTER HELPER
local function SetAndVerifyCVar(cvar, wants)
  SetCVar(cvar, wants)

  local has = GetCVar(cvar)
  local hasNum = tonumber(has)
  local targetNum = tonumber(wants)

  -- Verification Logic
  local match = false
  if hasNum and targetNum then
    -- Float tolerance
    if math.abs(hasNum - targetNum) < 0.001 then
      match = true
    end
  elseif tostring(has) == tostring(wants) then
    match = true
  end

  if not match then
    local errMsg = string.format("%s Failed! Has: %s | Wants: %s", cvar, tostring(has), tostring(wants))

    -- FIX: Colorize the string first, and do not pass a second argument
    Log(Colorize(errMsg, "red"))
    setvarFailed = setvarFailed + 1
  end
  setvarSuccess = setvarSuccess + 1
end -- 3. INITIALIZATION & PVP OPTIMIZATIONS

Log("Loading MySettings... Happy Hunting!")

-- Original GUI Settings
SetAndVerifyCVar("nameplateOverlapV", "0.28")

-- New Advantageous PvP Settings
SetAndVerifyCVar("cameraDistanceMaxZoomFactor", 2.6) -- Maximize FOV
SetAndVerifyCVar("ActionButtonUseKeyDown", 1) -- Faster inputs
SetAndVerifyCVar("ffxglow", 0) -- Remove screen flash/clutter

-- LOSS OF CONTROL: Shows the big CC icons in the middle of your screen
SetAndVerifyCVar("lossOfControl", 1)

-- TARGET HIGHLIGHT: Increases the scale of your current target slightly
SetAndVerifyCVar("nameplateSelectedScale", 1.65)

-- SHOW ALL DEBUFFS: Ensures you see all your dots/CC on the target
SetAndVerifyCVar("noBuffDebuffFilterOnTarget", 1)

SetAndVerifyCVar("cameraSmoothStyle", 0) -- Disable auto-camera adjust
SetAndVerifyCVar("violenceLevel", 5) -- Maximize blood (helps visual hit confirmation)
SetAndVerifyCVar("UberTooltips", 1) -- Show full spell info in combat
-- Stop nameplates from scaling based on distance (keep them consistent)
SetAndVerifyCVar("nameplateMinScale", 1)
SetAndVerifyCVar("nameplateMaxScale", 1)

-- This speed up is subtle but noticeable over thousands of mobs
SetAndVerifyCVar("autoLootDefault", 1)

-- retail setting
SetAndVerifyCVar("nameplateMaxDistance", 60)

-- 4. OPTIMIZATION LOGIC
local function OptimizeSettings(triggerSource)
  local _, _, _, worldLag = GetNetStats()
  if worldLag < 20 then
    worldLag = 20
  end

  -- For PvP maps, we use a tighter, more predictable window
  local isPvPInstance = C_PvP.IsPVPMap()
  local tolerance = isPvPInstance and 80 or 100
  -- local tolerance = 80
  local tolerance = 100
  local newSQW = worldLag + tolerance

  if newSQW >= 300 then
    newSQW = 400
    local errMsg = string.format(">> HIGH LATENCY DETECTED << max SQW is now %s", tostring(newSQW))
    Log(Colorize(errMsg, "red"))
  end

  SetCVar("SpellQueueWindow", newSQW)
  local actualSQW = GetCVar("SpellQueueWindow")

  local pvpStatusText = isPvPInstance and Colorize("[PvP-Targetting]", "red") or Colorize("[PvE-Targetting]", "blue")
  SetCVar("TargetPriorityPvp", isPvPInstance and 3 or 1)
  -- SetAndVerifyCVar("TargetPriorityPVP", isPvPInstance and 3 or 1)

  -- Final Report
  Log(
    pvpStatusText .. " (Src: " .. triggerSource .. ") | Latency: " .. worldLag .. "ms",
    "Queue: " .. actualSQW .. "ms"
  )
end

-- 5. EVENT LISTENER
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
  C_Timer.After(5, function()
    OptimizeSettings("Auto")
  end)
end)

-- 6. SLASH COMMAND
SLASH_AUTOSQW1 = "/sqw"
SlashCmdList["AUTOSQW"] = function()
  OptimizeSettings("Manual")
end

-- 7. AUTO MERCHANT (Repair + Sell Greys)
local m = CreateFrame("Frame")
m:RegisterEvent("MERCHANT_SHOW")
m:SetScript("OnEvent", function()
  if CanMerchantRepair() then
    local cost = GetRepairAllCost()
    if cost > 0 then
      RepairAllItems()
      Log("Repaired", GetCoinTextureString(cost))
    end
  end

  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == 0 and not info.hasNoValue then
        C_Container.UseContainerItem(bag, slot)
      end
    end
  end
end)

local q = CreateFrame("Frame")
q:RegisterEvent("GOSSIP_SHOW")
q:RegisterEvent("QUEST_DETAIL")
q:RegisterEvent("QUEST_PROGRESS")

q:SetScript("OnEvent", function(self, event)
  if IsShiftKeyDown() then
    return
  end -- Bypass with Shift

  if event == "GOSSIP_SHOW" then
    local options = C_GossipInfo.GetOptions()
    if #options == 1 then
      C_GossipInfo.SelectOption(options[1].gossipOptionID)
    end
  elseif event == "QUEST_DETAIL" then
    AcceptQuest()
  elseif event == "QUEST_PROGRESS" and IsQuestCompletable() then
    CompleteQuest()
    -- elseif event == "QUEST_COMPLETE" then
    --   GetQuestReward(1) -- Selects first reward if multiple; careful with this
    -- end
  end
end)

local done = string.format("Set %s settings Successfully!, with %s errors", setvarSuccess, setvarFailed)

Log(Colorize(done, "yellow"))

-- 8. COMBAT UI HIDER
local combatFade = CreateFrame("Frame")
combatFade:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFade:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Frames to toggle. Verified for Dragonflight/War Within (Retail).
local framesToHide = {
  MinimapCluster, -- Minimap and Zone Text
  -- ObjectiveTrackerFrame, -- Quest Tracker
  -- MicroMenuContainer, -- Micro Menu (Character, Spellbook, etc.)
  -- BagsBar, -- Bag Buttons
}

-- 8. OBJECTIVE TRACKER MANAGER
local obs = CreateFrame("Frame")
obs:RegisterEvent("PLAYER_ENTERING_WORLD")
obs:RegisterEvent("PLAYER_REGEN_DISABLED")
obs:RegisterEvent("PLAYER_REGEN_ENABLED")

local function UpdateObjectiveTracker(event)
  if not ObjectiveTrackerFrame then
    return
  end

  local inCombat = InCombatLockdown() or (event == "PLAYER_REGEN_DISABLED")
  local _, instanceType = GetInstanceInfo()
  local isPvP = (instanceType == "arena" or instanceType == "pvp")

  -- Logic: Collapse if in combat OR if in a PvP zone.
  -- Expand only if out of combat AND in a PvE zone.
  if inCombat or isPvP then
    if not ObjectiveTrackerFrame.isCollapsed then
      ObjectiveTrackerFrame:SetCollapsed(true)
    end
  else
    if ObjectiveTrackerFrame.isCollapsed then
      ObjectiveTrackerFrame:SetCollapsed(false)
    end
  end
end

obs:SetScript("OnEvent", function(self, event)
  -- Small delay on zone change to ensure GetInstanceInfo() is accurate
  if event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(1, function()
      UpdateObjectiveTracker(event)
    end)
  else
    UpdateObjectiveTracker(event)
  end
end)

combatFade:SetScript("OnEvent", function(self, event)
  local inCombat = (event == "PLAYER_REGEN_DISABLED")

  for _, frame in ipairs(framesToHide) do
    if frame then
      -- SetShown(false) is idiomatic for Hide(), SetShown(true) for Show()
      frame:SetShown(not inCombat)
    end
  end
end)

-- 9. SECURE KEYBLOCKER
-- We use a SecureHandlerStateTemplate to legally rebind keys during combat lockdown.
local blocker = CreateFrame("Button", "MyCombatBlocker", UIParent, "SecureHandlerStateTemplate")

-- 1. Register the "combat" condition driver
RegisterStateDriver(blocker, "combatState", "[combat] 1; 0")

-- 2. Define the handler script that runs when combat starts (1) or ends (0)
blocker:SetAttribute(
  "_onstate-combatState",
  [[
    if newstate == 1 then
        -- IN COMBAT: Steal the keys.
        -- "true" = priority override.
        -- "self:GetName()" means clicking the key triggers this hidden button (doing nothing).
        self:SetBindingClick(true, "ESCAPE", self:GetName())

        -- To add more keys, duplicate the line above:
        -- self:SetBindingClick(true, "C", self:GetName())
    else
        -- OUT OF COMBAT: Release the keys back to normal.
        self:ClearBindings()
    end
]]
)
