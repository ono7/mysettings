--[[

/etrace

For addon debugging: Open an in-game window containing a live-updating event log of all events happening in your game (clicks, movement, mouseovers, chats, combatevents, players running in and out of render distance, etc.:

/fstack

For UI debugging. Type this command to mouseover any UI element to highlight its length/width, layer, name and parent element.

]]
local addonName, ns = ...
local setvarSuccess, setvarFailed = 0, 0

local Colors = { green = "00ff00", blue = "00aaff", red = "ff0000", white = "ffffff" }

local function Colorize(text, color)
  return string.format("|cff%s%s|r", Colors[color] or Colors.white, tostring(text))
end

local function Log(message, value)
  local prefix = Colorize("[MySettings]", "green")
  local suffix = value and (": " .. Colorize(value, "blue")) or ""
  print(prefix .. " " .. message .. suffix)
end

local function SetAndVerifyCVar(cvar, wants)
  C_CVar.SetCVar(cvar, wants)
  local has = C_CVar.GetCVar(cvar)

  -- FAIL FAST: CVar does not exist (Retail client check)
  if has == nil then
    Log(Colorize(string.format("Failed! CVar '%s' does not exist", cvar), "red"))
    setvarFailed = setvarFailed + 1
    return
  end

  -- VERIFY: Compare values
  local match = false
  local hasNum, wantsNum = tonumber(has), tonumber(wants)

  if hasNum and wantsNum then
    -- Numeric Tolerance
    if math.abs(hasNum - wantsNum) < 0.001 then
      match = true
    end
  else
    -- String Exact Match
    if tostring(has) == tostring(wants) then
      match = true
    end
  end

  if not match then
    Log(Colorize(string.format("%s Failed! Has: %s | Wants: %s", cvar, tostring(has), tostring(wants)), "red"))
    setvarFailed = setvarFailed + 1
  else
    setvarSuccess = setvarSuccess + 1
  end
end

-- 2. INITIALIZATION (CVARS)
Log("Loading MySettings...")

local cvars = {
  nameplateOverlapV = "0.28",
  cameraDistanceMaxZoomFactor = "2.6",
  CameraReduceUnexpectedMovement = "1",
  ActionButtonUseKeyDown = "1",
  ffxglow = "0",
  lossOfControl = "1", -- show when im stunned
  nameplateSelectedScale = "1.75", -- target nameplate size
  -- noBuffDebuffFilterOnTarget = "1", -- does not apply important filter to target frame
  cameraSmoothStyle = "0", -- more responsive camara instead of smoothing and following behind
  violenceLevel = "5", -- more blood
  UberTooltips = "1", -- additional details
  nameplateMinScale = "1",
  nameplateMaxScale = "1",
  Sound_EnableErrorSpeech = "0",
  autoLootDefault = "1",
  nameplateMaxDistance = "60",
  AutoPushSpellToActionBar = 0, -- dont automatically add new spells to castbars
  UnitNamePlayerGuild = "0", -- remove guild names
  UnitNamePlayerPVPTitle = "0", -- remove pvp titles
  countdownForCooldowns = "1", -- NUMBERS: Shows "3, 2, 1" on icons instead of just a clock swipe
  pvpFramesDisplayClassColor = "1", -- shows class colors
  nameplateShowOnlyNameForFriendlyPlayerUnits = "1", -- only show name for friendies
  softTargetEnemy = "1", -- automatically targets enemies you face if you have no target
  softTargetIconEnemy = "1", -- Show a distinct icon over the "Soft Target" so you know who you will hit
}

-- change audio output device automatically when it changes
SetAndVerifyCVar("Sound_OutputDriverIndex", "0")
local event = CreateFrame("FRAME")
event:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
event:SetScript("OnEvent", function()
  if not CinematicFrame:IsShown() and not MovieFrame:IsShown() then -- Dont restart sound system during cinematic
    SetCVar("Sound_OutputDriverIndex", "0")
    Sound_GameSystem_RestartSoundSystem()
  end
end)

local current = C_CVar.GetCVar("ResampleAlwaysSharpen")
if current ~= "1" then
  SetAndVerifyCVar("ResampleAlwaysSharpen", "1")
end

local desired = "0.999"
-- GetCVar returns a string, comparison must be exact
if C_CVar.GetCVar("renderscale") ~= desired then
  SetAndVerifyCVar("renderscale", desired)
end

for cvar, val in pairs(cvars) do
  SetAndVerifyCVar(cvar, val)
end

-- Permanently disable red error text
UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")

Log(Colorize(string.format("Setup Complete: %d success, %d errors", setvarSuccess, setvarFailed), "blue"))

-- 3. LOGIC MODULES (SMART POLLING)
local retryCount = 0
local MAX_RETRIES = 30

local function OptimizeConnection(source)
  local _, _, _, worldLag = GetNetStats()

  -- SMART POLLING:
  -- If lag is 0, the client hasn't calculated it yet. Wait and retry.
  if (worldLag <= 0) and (source == "Auto") and (retryCount < MAX_RETRIES) then
    retryCount = retryCount + 1
    C_Timer.After(1, function()
      OptimizeConnection("Auto")
    end)
    return
  end

  -- Reset counter for next time
  if source == "Auto" then
    retryCount = 0
  end

  -- Sanity check: If it's STILL 0 after retries, assume low latency (20ms)
  worldLag = math.max(20, worldLag)

  -- SQW Calculation
  local tolerance = 100
  local newSQW = math.min(400, worldLag + tolerance)

  if newSQW >= 400 then
    Log(Colorize("High Latency (" .. worldLag .. ") - Capping SQW at 400", "red"))
  end

  SetAndVerifyCVar("SpellQueueWindow", newSQW)

  local isPvP = C_PvP.IsPVPMap()
  SetAndVerifyCVar("TargetPriorityPvp", isPvP and 3 or 1)

  Log(
    string.format(
      "%s (Src: %s) | Latency: %dms",
      isPvP and Colorize("[PvP]", "red") or Colorize("[PvE]", "blue"),
      source,
      worldLag
    ),
    "SQW: " .. newSQW
  )
end

-- 4. UNIFIED EVENT HANDLER
local Events = CreateFrame("Frame")
Events:RegisterEvent("PLAYER_ENTERING_WORLD")
Events:RegisterEvent("MERCHANT_SHOW")
Events:RegisterEvent("GOSSIP_SHOW")
Events:RegisterEvent("QUEST_DETAIL")
Events:RegisterEvent("QUEST_PROGRESS")
Events:RegisterEvent("PLAYER_REGEN_DISABLED")
Events:RegisterEvent("PLAYER_REGEN_ENABLED")

Events:SetScript("OnEvent", function(self, event, ...)
  -- A. Connection Optimization (Polls for valid latency)
  if event == "PLAYER_ENTERING_WORLD" then
    OptimizeConnection("Auto")

    -- Delayed UI check for ObjectiveTracker
    C_Timer.After(1, function()
      if ObjectiveTrackerFrame and not InCombatLockdown() then
        ObjectiveTrackerFrame:SetCollapsed(C_PvP.IsPVPMap())
      end
    end)

  -- B. Auto Merchant (Retail C_Container API)
  elseif event == "MERCHANT_SHOW" then
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
        -- quality 0 is Poor (Grey)
        if info and info.quality == 0 and not info.hasNoValue then
          C_Container.UseContainerItem(bag, slot)
        end
      end
    end

  -- C. Auto Quest (Retail C_GossipInfo API)
  elseif event == "GOSSIP_SHOW" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" then
    if IsShiftKeyDown() then
      return
    end

    if event == "GOSSIP_SHOW" then
      local options = C_GossipInfo.GetOptions()
      if #options == 1 then
        C_GossipInfo.SelectOption(options[1].gossipOptionID)
      end
    elseif event == "QUEST_DETAIL" then
      AcceptQuest()
    elseif event == "QUEST_PROGRESS" and IsQuestCompletable() then
      CompleteQuest()
    end

  -- D. Combat UI Toggles
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    local inCombat = (event == "PLAYER_REGEN_DISABLED")

    -- Toggle Circle Highlight
    C_CVar.SetCVar("findYourSelfAnywhere", inCombat and "1" or "0")
    C_CVar.SetCVar("findYourSelfModeCircle", inCombat and "1" or "0")

    -- Hide Minimap Cluster
    if MinimapCluster then
      MinimapCluster:SetShown(not inCombat)
    end

    -- Manage Objective Tracker
    if ObjectiveTrackerFrame then
      if inCombat then
        if not ObjectiveTrackerFrame.isCollapsed then
          ObjectiveTrackerFrame:SetCollapsed(true)
        end
      else
        if not C_PvP.IsPVPMap() and ObjectiveTrackerFrame.isCollapsed then
          ObjectiveTrackerFrame:SetCollapsed(false)
        end
      end
    end
  end
end)

-- 5. SLASH COMMANDS
SLASH_AUTOSQW1 = "/sqw"
SlashCmdList["AUTOSQW"] = function()
  OptimizeConnection("Manual")
end

-- 6. SECURE KEYBLOCKER
local blocker = CreateFrame("Button", "MyCombatBlocker", UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(blocker, "combatState", "[combat] 1; 0")
blocker:SetAttribute(
  "_onstate-combatState",
  [[
    if newstate == 1 then
        self:SetBindingClick(true, "ESCAPE", self:GetName())
    else
        self:ClearBindings()
    end
]]
)
