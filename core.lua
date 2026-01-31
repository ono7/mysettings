-- 1. DEFINE THE LOGIC FUNCTION
print("Loading MySettings... have a wonderful time hunting")

local nameplateOverlapV = "0.28"
SetCVar("nameplateOverlapV", nameplateOverlapV)
print("|cff00ff00[MySettings][GUI]|r nameplateOverlapV: " .. nameplateOverlapV)
SetCVar("nameplateShowFriends", 0)
print("|cff00ff00[MySettings][GUI]|r ShowFriedlyPlates: " .. "0")
SetCVar("nameplateShowFriendlyNPCs", 0)
print("|cff00ff00[MySettings][GUI]|r ShowFriendlyNPC: " .. "0")
SetCVar("floatingCombatTextCombatHealing", 0)
print("|cff00ff00[MySettings][GUI]|r HideCombatHealing: " .. "0")

local function OptimizeSettings(triggerSource)
  local _, _, _, worldLag = GetNetStats()

  -- Safety checks
  if worldLag < 20 then
    worldLag = 20
  end

  -- Calculate Queue Window
  local tolerance = 100
  local newSQW = worldLag + tolerance
  SetCVar("SpellQueueWindow", newSQW)

  -- PvP Check
  local isPvPInstance = C_PvP.IsPVPMap()
  local pvpStatusText = ""

  if isPvPInstance then
    SetCVar("TargetPriorityPVP", 3)
    pvpStatusText = "|cffFF0000[PvP-Targetting]|r"
  else
    SetCVar("TargetPriorityPVP", 1)
    pvpStatusText = "|cff00AAFF[PvE-Targetting]|r"
  end

  -- Output
  print(
    "|cff00ff00[MySettings]|r "
      .. pvpStatusText
      .. " (Src: "
      .. triggerSource
      .. ") | Latency: "
      .. worldLag
      .. "ms | Queue: "
      .. newSQW
      .. "ms"
  )
end

-- 2. EVENT LISTENER (Automated: Login / Zone / Reload)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function()
  -- We still need the delay on zone/reload to let the network jitter settle
  C_Timer.After(5, function()
    OptimizeSettings("Auto")
  end)
end)

-- 3. SLASH COMMAND (Manual: Force Run)
SLASH_AUTOSQW1 = "/sqw"
SlashCmdList["AUTOSQW"] = function()
  -- No delay needed for manual trigger
  OptimizeSettings("Manual")
end

-- 4. AUTO MERCHANT (Repair + Sell Greys)
local m = CreateFrame("Frame")
m:RegisterEvent("MERCHANT_SHOW")

m:SetScript("OnEvent", function()
  -- Auto Repair
  if CanMerchantRepair() then
    local cost = GetRepairAllCost()
    if cost > 0 then
      -- Try to use Guild Bank first, then Personal
      -- if CanGuildBankRepair() and cost <= GetGuildBankWithdrawMoney() then
      --     RepairAllItems(true)
      --     print("|cff00ff00[MySettings]|r Guild Repaired: " .. GetCoinTextureString(cost))
      -- elseif GetMoney() >= cost then
      RepairAllItems()
      print("|cff00ff00[MySettings]|r Repaired: " .. GetCoinTextureString(cost))
      -- end
    end
  end

  -- Auto Sell Greys
  local bag, slot
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == 0 and not info.hasNoValue then
        C_Container.UseContainerItem(bag, slot)
      end
    end
  end
end)
