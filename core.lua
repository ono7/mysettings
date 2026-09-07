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
  nameplateOverlapH = "1",
  nameplateOverlapV = "0.35",
  nameplateSize = "2",
  nameplateSelectedScale = "1",
  nameplateMaxScale = "0.7",
  deselectOnClick = "0",
  nameplateMinScale = "0.4",
  nameplateMaxDistance = "60",
  showTutorials = "0",
  cameraDistanceMaxZoomFactor = "2.6",
  CameraReduceUnexpectedMovement = "1",
  assistedCombatHighlight = "1",
  TargetPriorityPvp = "3",
  bankConfirmTabCleanUp = "0",
  alwaysCompareItems = "1",
  enablePVPNotifyAFK = "0",
  ActionButtonUseKeyDown = "1",
  lossOfControl = "1",
  cameraSmoothStyle = "0",
  violenceLevel = "5",
  UberTooltips = "1",
  Sound_EnableErrorSpeech = "0",
  autoLootDefault = "1",
  UnitNamePlayerGuild = "0",
  UnitNamePlayerPVPTitle = "0",
  countdownForCooldowns = "1",
  pvpFramesDisplayClassColor = "1",
  softTargetIconEnemy = "1",
  Sound_OutputDriverIndex = "0",
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
      renderscale = IsMacClient() and "0.75" or "0.999",
      graphicsComputeEffects = "0",
      RAIDgraphicsComputeEffects = "0",
      graphicsParticleDensity = "4",
      projectedTextures = "1",
      GxAllowCachelessShaderMode = "0",
      graphicsDepthEffects = "0",
      graphicsSSAO = "0",
      Contrast = "65",
      graphicsGroundClutter = "0",
      graphicsShadowQuality = "0",
      volumeFogLevel = "0",
      Sound_NumChannels = "128",
      graphicsLiquidDetail = "0",
      weatherDensity = "0",
      ffxGlow = "0",
      AutoPushSpellToActionBar = "0",
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

    -- NOTE(jlima): Process container sales with a brief delay queue if inventory size exceeds 20 items to prevent server drop.
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
