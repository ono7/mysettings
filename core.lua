-- 1. COLOR & LOGGING HELPERS
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
-- Sets the CVar, then retrieves it to verify the engine accepted it
local function SetAndVerifyCVar(cvar, value)
  SetCVar(cvar, value)
  Log("Setting: " .. cvar, value)
  local actualValue = GetCVar(cvar)
  Log("Actual: " .. cvar, actualValue)
end

-- 3. INITIALIZATION & PVP OPTIMIZATIONS
Log("Loading MySettings... have a wonderful time hunting")

-- Original GUI Settings
SetAndVerifyCVar("nameplateOverlapV", "0.28")
SetAndVerifyCVar("floatingCombatTextCombatHealing", 0)

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

-- 4. OPTIMIZATION LOGIC
local function OptimizeSettings(triggerSource)
  local _, _, _, worldLag = GetNetStats()
  if worldLag < 20 then
    worldLag = 20
  end

  -- For PvP maps, we use a tighter, more predictable window
  local isPvPInstance = C_PvP.IsPVPMap()
  local tolerance = isPvPInstance and 80 or 100
  local newSQW = worldLag + tolerance

  SetCVar("SpellQueueWindow", newSQW)
  local actualSQW = GetCVar("SpellQueueWindow")

  local pvpStatusText = isPvPInstance and Colorize("[PvP-Targetting]", "red") or Colorize("[PvE-Targetting]", "blue")
  SetCVar("TargetPriorityPVP", isPvPInstance and 3 or 1)

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
