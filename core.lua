--[[

/etrace

For addon debugging: Open an in-game window containing a live-updating event log of all events happening in your game (clicks, movement, mouseovers, chats, combatevents, players running in and out of render distance, etc.:

/fstack

For UI debugging. Type this command to mouseover any UI element to highlight its length/width, layer, name and parent element.

]]

local addonName, ns = ...
local setvarSuccess, setvarFailed = 0, 0

local Colors = {
  -- Basics
  green = "00ff00",
  blue = "00aaff",
  red = "ff0000",
  white = "ffffff",
  black = "000000",
  yellow = "ffff00",
  orange = "ffa500",
  pink = "ff69b4", -- Hot Pink
  cyan = "00ffff",

  -- WoW Quality Colors (Approximate)
  gray = "9d9d9d", -- Poor
  common = "ffffff", -- Common
  rare = "0070dd", -- Rare
  epic = "a335ee", -- Epic
  legend = "ff8000", -- Legendary
  heirloom = "e6cc80", -- Heirloom

  -- Class Colors (Examples)
  druid = "ff7d0a",
  mage = "69ccf0",
  paladin = "f58cba",
  hunter = "abd473",
}

local function Colorize(text, color)
  return string.format("|cff%s%s|r", Colors[color] or Colors.white, tostring(text))
end

local function Log(message, value)
  local prefix = Colorize("[MySettings]", "green")
  local suffix = value and (": " .. Colorize(value, "blue")) or ""
  print(prefix .. " " .. message .. suffix)
end

-- this returns 4 values, comma separated, adding {} will make them into a table
local buildData = { GetBuildInfo() }

Log(Colorize(string.format(">>> Game version: %s <<<", buildData[1]), "hunter"))
Log(Colorize(string.format(">>> Game released: %s <<<", buildData[3]), "hunter"))
Log(Colorize(string.format(">>> Game TOC: %s <<<", buildData[4]), "hunter"))

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
  -- nameplateOverlapV = "0.28",
  nameplateOverlapH = "0.38",
  nameplateOverlapV = "1",
  nameplateSize = "2",
  nameplateSelectedScale = "1.10", -- target nameplate size
  nameplateMaxScale = "0.7",
  nameplateMinScale = "0.4",
  nameplateMaxDistance = "60",
  showTutorials = "0", -- disable tutorials = 0, enable = 1
  nameplateShowOnlyNameForFriendlyPlayerUnits = "1", -- only show name for friendies
  cameraDistanceMaxZoomFactor = "2.6",
  CameraReduceUnexpectedMovement = "1",
  assistedCombatHighlight = "1", --- should highlight the next spell that should be sent in combat
  TargetPriorityPvp = "3", -- prioritize player over pet
  bankConfirmTabCleanUp = "0", -- no confirmation when autocleaning up bags
  alwaysCompareItems = "1", -- always compare items with tooltips
  -- cursorSizePreferred = "2", -- based on dpi, but maybe too small on high dpi values -1 (auto) - 4 (largest)
  enablePVPNotifyAFK = "0", -- ability to shutdown the afk notification system in pvp
  ActionButtonUseKeyDown = "1",
  ffxglow = "0",
  lossOfControl = "1", -- show when im stunned
  -- noBuffDebuffFilterOnTarget = "1", -- does not apply important filter to target frame
  cameraSmoothStyle = "0", -- more responsive camara instead of smoothing and following behind
  violenceLevel = "5", -- more blood
  UberTooltips = "1", -- additional details
  Sound_EnableErrorSpeech = "0",
  autoLootDefault = "1",
  UnitNamePlayerGuild = "0", -- remove guild names
  UnitNamePlayerPVPTitle = "0", -- remove pvp titles
  graphicsComputeEffects = "0", -- disabled
  countdownForCooldowns = "1", -- NUMBERS: Shows "3, 2, 1" on icons instead of just a clock swipe
  pvpFramesDisplayClassColor = "1", -- shows class colors
  -- softTargetEnemy = "1", -- automatically targets enemies you face if you have no target
  targetAutoLock = "1", -- clicking on the ground will not remove target
  softTargetIconEnemy = "1", -- Show a distinct icon over the "Soft Target" so you know who you will hit
  TargetPriorityCombatLock = "2", -- adds combat lock agains player enemies/pvp
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

--- this deals with graphics settings only applied at login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  -- 1. Define Configuration (OS-Separated)
  -- Value mapping: IsMacClient() and <MacValue> or <WindowsValue>
  local settings = {
    renderscale = IsMacClient() and "0.69" or "0.999",
    graphicsComputeEffects = IsMacClient() and "0" or "0", -- 0=Disabled (Mac), 4=Ultra (Win)
    RAIDgraphicsComputeEffects = "0", -- always disable this for better performance
    -- outlineMode = "3", -- High (Essential for spotting targets in chaos)
    graphicsParticleDensity = "4", -- High (MANDATORY: Never set Low, or you won't see Ring of Frost/Traps)
    projectedTextures = "1", -- Enabled (MANDATORY: Renders ground effects)

    -- [3. Visual Clarity & FPS Savings (Remove "Eye Candy")]
    -- gxTripleBuffer = "0", -- Disabled (Reduces input latency) -- TODO(jlima): fix
    GxAllowCachelessShaderMode = "0", -- dont use hdd/ssd for caching (use ram)
    graphicsDepthEffects = "0", -- Disabled (Removes blur/depth of field; improves clarity)
    graphicsSSAO = "0", -- Disabled (Ambient Occlusion; expensive shadow shading)
    Contrast = "70", -- better visuals
    graphicsGroundClutter = "0", -- less junk on the floor
    graphicsShadowQuality = "0",
    volumeFogLevel = "0",
    Sound_NumChannels = "128",
    graphicsLiquidDetail = "0", -- Low (Water quality; zero competitive value)
    weatherDensity = "0", -- Disabled (Rain/Snow distracts from spell cues)
    ffxGlow = "0", -- Disabled (Removes full-screen bloom/glare)
    AutoPushSpellToActionBar = "0", -- dont automatically add new spells to castbars
  }

  -- 2. Enforce Configuration
  for cvar, desired in pairs(settings) do
    if C_CVar.GetCVar(cvar) ~= desired then
      if SetAndVerifyCVar then
        SetAndVerifyCVar(cvar, desired)
      else
        C_CVar.SetCVar(cvar, desired)
      end
      print("|cff00ff00[MySettings]|r Set " .. cvar .. ": " .. desired)
    end
  end
end)

-- -- Default to Windows value
-- local desired = "0.999"
--
-- -- If on Mac, override to 0.69
-- if IsMacClient() then
--   desired = "0.69"
-- end
--
-- -- GetCVar returns a string, comparison must be exact
-- if C_CVar.GetCVar("renderscale") ~= desired then
--   SetAndVerifyCVar("renderscale", desired)
-- end

--- applies settings unconditionally on /reload
for cvar, val in pairs(cvars) do
  SetAndVerifyCVar(cvar, val)
end

-- Permanently disable red error text
UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")

Log(Colorize(string.format("Setup Complete: %d success, %d errors", setvarSuccess, setvarFailed), "hunter"))

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

  -- local isPvP = C_PvP.IsPVPMap()
  -- SetAndVerifyCVar("TargetPriorityPvp", isPvP and 3 or 1)

  Log(
    string.format(
      "%s (Src: %s) | Latency: %dms",
      -- isPvP and Colorize("[PvP]", "red") or Colorize("[PvE]", "blue"),
      Colorize("SpellQueue"),
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
-- Events:RegisterEvent("QUEST_DETAIL")
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
        Log("Repaired", C_CurrencyInfo.GetCoinTextureString(cost))
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

  -- D. Combat UI Toggles
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    local inCombat = (event == "PLAYER_REGEN_DISABLED")

    -- Toggle Circle Highlight
    C_CVar.SetCVar("findYourSelfAnywhere", inCombat and "1" or "0")
    -- C_CVar.SetCVar("findYourselfAnywhereOnlyInCombat", 1)
    C_CVar.SetCVar("findYourSelfModeCircle", inCombat and "1" or "0")
    C_CVar.SetCVar("findYourSelfModeOutline", inCombat and "1" or "0")

    -- we need minimap turns out... specially in some bgs
    -- Hide Minimap Cluster
    -- if C_PvP.IsPVPMap() then
    --   if MinimapCluster then
    --     MinimapCluster:SetShown(not inCombat)
    --   end
    -- end

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
