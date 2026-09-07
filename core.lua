local addonName, ns = ...

local setvarSuccess, setvarFailed = 0, 0

local Colors = {
  green = "00ff00",
  blue = "00aaff",
  red = "ff0000",
  white = "ffffff",
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

local function SetAndVerifyCVar(cvar, wants)
  C_CVar.SetCVar(cvar, wants)
  local has = C_CVar.GetCVar(cvar)

  if has == nil then
    Log(Colorize(string.format("Failed! CVar '%s' does not exist", cvar), "red"))
    setvarFailed = setvarFailed + 1
    return
  end

  local match = false
  local hasNum, wantsNum = tonumber(has), tonumber(wants)

  if hasNum and wantsNum then
    match = math.abs(hasNum - wantsNum) < 0.001
  else
    match = tostring(has) == tostring(wants)
  end

  if not match then
    Log(Colorize(string.format("%s Failed! Has: %s | Wants: %s", cvar, tostring(has), tostring(wants)), "red"))
    setvarFailed = setvarFailed + 1
  else
    setvarSuccess = setvarSuccess + 1
  end
end

-- TRACKER TOGGLE STATE
local autoHideTracker = true
SLASH_MYSETTINGS_TRACKER1 = "/tracker"
SlashCmdList["MYSETTINGS_TRACKER"] = function()
  autoHideTracker = not autoHideTracker
  Log("Combat Tracker Auto-Hide", autoHideTracker and "ON" or "OFF")
end

-- BASE CVARS
local baseCVars = {
  -- GUI: Options -> Gameplay -> Interface -> Display -> "Tutorials"
  showTutorials = "0",

  -- GUI: Options -> Gameplay -> Interface -> Display -> "Always Compare Items"
  alwaysCompareItems = "1",

  -- GUI: Options -> Gameplay -> Interface -> Display -> "Loss of Control Alerts"
  lossOfControl = "1",

  -- GUI: Options -> Gameplay -> Interface -> Display -> "Spell Activation Overlay" / Highlight
  assistedCombatHighlight = "1",

  -- GUI: Options -> Gameplay -> Interface -> Display -> "Bank Clean Up Confirmation"
  bankConfirmTabCleanUp = "0",

  -- GUI: Options -> Gameplay -> Interface -> Action Bars -> "Show Numbers for Cooldowns"
  countdownForCooldowns = "1",

  -- GUI: Options -> Gameplay -> Interface -> Names -> "Guild Names"
  UnitNamePlayerGuild = "0",

  -- GUI: Options -> Gameplay -> Interface -> Names -> "Titles"
  UnitNamePlayerPVPTitle = "0",

  -- GUI: Options -> Gameplay -> Controls -> "Auto Loot"
  autoLootDefault = "1",

  -- GUI: Options -> Gameplay -> Controls -> "Press and Hold Casting"
  -- NOTE(jlima): Disabled to prevent unintended repeat casts in low-latency spell queues.
  ActionButtonUseKeyHeldSpell = "0",

  -- GUI: Options -> Gameplay -> Controls -> "Deselect on Click"
  deselectOnClick = "0",

  -- GUI: Options -> Gameplay -> Controls -> "Target Priority"
  TargetPriorityPvp = "3",

  -- GUI: Options -> Gameplay -> Combat -> "Key Down Action"
  ActionButtonUseKeyDown = "1",

  -- GUI: Options -> Gameplay -> Combat -> "PvP Notify AFK"
  enablePVPNotifyAFK = "0",

  -- GUI: Options -> Gameplay -> Combat -> "Soft Target Icon"
  softTargetIconEnemy = "1",

  -- GUI: Options -> Gameplay -> Combat -> "PvP Frames Display Class Color"
  pvpFramesDisplayClassColor = "1",

  -- GUI: Options -> Audio -> "Error Speech"
  Sound_EnableErrorSpeech = "0",

  -- GUI: Options -> Audio -> "Output Device" (0 = System Default)
  Sound_OutputDriverIndex = "0",

  -- GUI: Options -> Accessibility -> General -> "Motion Sickness" -> "Reduce Camera Motion"
  CameraReduceUnexpectedMovement = "1",

  -- GUI: Options -> Accessibility -> General -> "Camera Shake" -> Set to None
  -- NOTE(jlima): Eliminates full-screen disorientation from boss ground slams and earthquakes.
  ShakeStrengthCamera = "0",

  -- GUI: Options -> Accessibility -> General -> "Skyriding Pitch Effects / Dynamic FOV"
  -- NOTE(jlima): Disables fish-eye perspective warping at high mount speeds to stabilize screen edges.
  AdvFlyingDynamicFOVEnabled = "0",

  -- GUI: Options -> Network -> "Advanced Combat Logging"
  -- NOTE(jlima): Streams player positions, gear, and combat states directly to disk for Warcraft Logs/Details.
  advancedCombatLogging = "1",

  -- GUI: Options -> Gameplay -> Interface -> Names -> "Nameplate Motion Type" (1 = Stacking)
  -- NOTE(jlima): Prevents nameplates from overlapping into an unclickable stack in large packs.
  nameplateMotion = "1",

  -- --- ENGINE/HIDDEN CVARS (No standard GUI menu toggle) ---

  -- NOTE(jlima): Maximize physical camera pullout beyond standard slider limits.
  cameraDistanceMaxZoomFactor = "2.6",

  -- NOTE(jlima): Disables instant upward camera pitching when the view frustum collides with low geometry.
  cameraPivot = "0",

  -- NOTE(jlima): Eliminates camera follow acceleration/deceleration smoothing for 1:1 mouse tracking.
  cameraSmoothStyle = "0",

  -- NOTE(jlima): Forces the modern cone-based raycast priority algorithm for tab targeting.
  TargetNearestUseNew = "1",

  -- NOTE(jlima): Dims nameplate opacity by 50% when line-of-sight is broken behind terrain or pillars.
  nameplateOccludedMult = "0.5",

  -- NOTE(jlima): Clamps nameplates to the visible viewport edges so high or airborne units do not slide off-screen.
  nameplateOtherTopInset = "0.08",
  nameplateOtherBottomInset = "0.1",

  -- NOTE(jlima): Max render distance for enemy nameplates (60 yards is the engine hardcap).
  nameplateMaxDistance = "60",

  -- NOTE(jlima): Nameplate sizing, scale bounding, and hit-box dimensions.
  nameplateSize = "2",
  nameplateSelectedScale = "1",
  nameplateMaxScale = "0.7",
  nameplateMinScale = "0.4",
  nameplateOverlapH = "1",
  nameplateOverlapV = "0.35",

  -- NOTE(jlima): Disables the desaturated black-and-white blur overlay while dead to maintain clear tactical awareness.
  ffxDeath = "0",

  -- NOTE(jlima): Disables the edge-swirl distortion shader during Stealth, Invisibility, and Phase transitions.
  ffxNetherWorld = "0",

  -- NOTE(jlima): Increases impact gore and hit-spark particle limits.
  violenceLevel = "5",

  -- NOTE(jlima): Forces rich tooltip data including raw spell IDs and item levels.
  UberTooltips = "1",
}

for cvar, val in pairs(baseCVars) do
  SetAndVerifyCVar(cvar, val)
end

-- PERMANENTLY SUPPRESS RED UI ERRORS
UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")

-- CONNECTION OPTIMIZATION (SQW)
local retryCount = 0
local MAX_RETRIES = 30

local function OptimizeConnection(source)
  local _, _, _, worldLag = GetNetStats()

  if (worldLag <= 0) and (source == "Auto") and (retryCount < MAX_RETRIES) then
    retryCount = retryCount + 1
    C_Timer.After(1, function()
      OptimizeConnection("Auto")
    end)
    return
  end

  if source == "Auto" then
    retryCount = 0
  end

  worldLag = math.max(20, worldLag)
  local tolerance = 100
  local newSQW = math.min(400, worldLag + tolerance)

  SetAndVerifyCVar("SpellQueueWindow", newSQW)
  Log(string.format("%s (Src: %s) | Latency: %dms", Colorize("SpellQueue"), source, worldLag), "SQW: " .. newSQW)
end

-- SECURE / EVENT-DRIVEN SUBSYSTEMS
local Core = CreateFrame("Frame")
Core:RegisterEvent("PLAYER_LOGIN")
Core:RegisterEvent("PLAYER_ENTERING_WORLD")
Core:RegisterEvent("MERCHANT_SHOW")
Core:RegisterEvent("PLAYER_REGEN_DISABLED")
Core:RegisterEvent("PLAYER_REGEN_ENABLED")
Core:RegisterEvent("PLAYER_DEAD")
Core:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")

Core:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    local graphicsSettings = {
      -- GUI: Options -> System -> Graphics -> "Render Scale"
      renderscale = IsMacClient() and "0.75" or "0.999",

      -- GUI: Options -> System -> Graphics -> "Compute Effects"
      graphicsComputeEffects = "0",
      RAIDgraphicsComputeEffects = "0",

      -- GUI: Options -> System -> Graphics -> "Particle Density"
      -- NOTE(jlima): High density (4) is mandatory to reliably resolve spell telegraphs (e.g. Ring of Frost).
      graphicsParticleDensity = "4",

      -- GUI: Options -> System -> Graphics -> "Projected Textures"
      -- NOTE(jlima): Mandatory to render decals and spell boundaries on the ground terrain.
      projectedTextures = "1",

      -- GUI: Options -> System -> Graphics -> "Depth Effects"
      graphicsDepthEffects = "0",

      -- GUI: Options -> System -> Graphics -> "Ambient Occlusion"
      graphicsSSAO = "0",

      -- GUI: Options -> System -> Graphics -> "Ground Clutter"
      graphicsGroundClutter = "0",

      -- GUI: Options -> System -> Graphics -> "Shadow Quality"
      graphicsShadowQuality = "0",

      -- GUI: Options -> System -> Graphics -> "Liquid Detail"
      graphicsLiquidDetail = "0",

      -- GUI: Options -> System -> Graphics -> "Brightness / Contrast"
      Contrast = "65",

      -- GUI: Options -> Audio -> "Sound Channels"
      Sound_NumChannels = "128",

      -- GUI: Options -> Gameplay -> Action Bars -> "Auto Add Spells to Action Bar"
      AutoPushSpellToActionBar = "0",

      -- --- HIDDEN GRAPHICS CVARS ---

      -- NOTE(jlima): Prevents flushing compiled pipeline shaders to disk cache; retains in unified memory.
      GxAllowCachelessShaderMode = "0",

      -- NOTE(jlima): Controls Metal render-queue pacing to prevent input stutter without hitching frame throughput.
      gxMaxFrameLatency = "2",

      -- NOTE(jlima): Strips the full-screen atmospheric fog layer.
      volumeFogLevel = "0",

      -- NOTE(jlima): Strips rain/snow occlusion layers to prioritize player/spell geometry visibility.
      weatherDensity = "0",

      -- NOTE(jlima): Disables full-screen bloom/haze to avoid blown-out lighting contrast.
      ffxGlow = "0",

      -- NOTE(jlima): Forces bilinear/bicubic sharpening pass across rendered UI surfaces.
      ResampleAlwaysSharpen = "1",
    }

    for cvar, desired in pairs(graphicsSettings) do
      if C_CVar.GetCVar(cvar) ~= desired then
        SetAndVerifyCVar(cvar, desired)
      end
    end

    local buildData = { GetBuildInfo() }
    Log(Colorize(string.format("Game Version: %s | TOC: %s", buildData[1], buildData[4]), "hunter"))
    Log(Colorize(string.format("Setup Complete: %d success, %d errors", setvarSuccess, setvarFailed), "hunter"))
  elseif event == "PLAYER_ENTERING_WORLD" then
    OptimizeConnection("Auto")

    C_Timer.After(1, function()
      if ObjectiveTrackerFrame and not InCombatLockdown() then
        ObjectiveTrackerFrame:SetCollapsed(C_PvP.IsPVPMap())
      end
    end)
  elseif event == "MERCHANT_SHOW" then
    if CanMerchantRepair() then
      local cost = GetRepairAllCost()
      if cost > 0 then
        RepairAllItems()
        Log("Repaired", C_CurrencyInfo.GetCoinTextureString(cost))
      end
    end

    -- NOTE(jlima): Process container sales across inventory and reagent storage.
    local maxBags = NUM_BAG_SLOTS + (NUM_REAGENTBAG_SLOTS or 0)
    for bag = 0, maxBags do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.quality == 0 and not info.hasNoValue then
          C_Container.UseContainerItem(bag, slot)
        end
      end
    end
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    local inCombat = (event == "PLAYER_REGEN_DISABLED")

    C_CVar.SetCVar("findYourSelfAnywhere", inCombat and "1" or "0")
    C_CVar.SetCVar("findYourSelfModeCircle", inCombat and "1" or "0")
    C_CVar.SetCVar("findYourSelfModeOutline", inCombat and "1" or "0")

    if ObjectiveTrackerFrame and not InCombatLockdown() then
      if inCombat then
        if autoHideTracker and not ObjectiveTrackerFrame.isCollapsed then
          ObjectiveTrackerFrame:SetCollapsed(true)
        end
      else
        if not C_PvP.IsPVPMap() and ObjectiveTrackerFrame.isCollapsed then
          ObjectiveTrackerFrame:SetCollapsed(false)
        end
      end
    end
  elseif event == "PLAYER_DEAD" then
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "pvp" or instanceType == "arena") then
      RepopMe()
      Log("Auto-Released", "PvP Instance")
    end
  elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" then
    if not CinematicFrame:IsShown() and not MovieFrame:IsShown() then
      C_CVar.SetCVar("Sound_OutputDriverIndex", "0")
      Log("Sound device reset to system default", "OK")
    end
  end
end)
