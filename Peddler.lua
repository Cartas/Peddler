local _, Peddler = ...

-- Assign global functions to locals for optimisation.
local C_Container = C_Container
local GetItemInfo = GetItemInfo
local GetQuestLogItemLink = GetQuestLogItemLink
local PickupMerchantItem = PickupMerchantItem
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsAltKeyDown = IsAltKeyDown
local UnitClass = UnitClass
local Baggins = Baggins

local ARMOUR = Peddler.ARMOUR
local WEAPON = Peddler.WEAPON
local WANTED_ITEMS = Peddler.WANTED_ITEMS

local BAG_COUNT = 5
local BUYBACK_COUNT = 12
local _, PLAYERS_CLASS = UnitClass('player')

-- The typical life-cycle of the addon goes as follows:
--   1. Initially delays for 400ms before attempting to mark wares for the first time.
--   2. We look for and get the item buttons for every item (differs per bag addon).
--   3. Check if this item's ItemID is in our ItemsToSell.
--   4. If 'tis, draw some lovely coins on the itemButton!
--   5. a. Remove the OnUpdate (prev. used for 400ms delay).
--      b. If using the default WoW bags, keep a 30ms timer for re-marking.
--   6. Listen for BagUpdates to refresh the markings (moving an item, etc.).
--        PS: Baggins needs to also listen to the bags being opened!

-- Turns an integer value into the format "Xg Ys Zc".
local function priceToGold(price)
  local gold = price / 10000
  local silver = (price % 10000) / 100
  local copper = (price % 10000) % 100

  return math.floor(gold) .. "|cFFFFCC33g|r " .. math.floor(silver) .. "|cFFC9C9C9s|r " .. math.floor(copper) .. "|cFFCC8890c|r"
end

local peddler = CreateFrame("Frame", nil, UIParent)
local salesDelay = CreateFrame("Frame")
local usingDefaultBags = false
local markCounter = 1
local countLimit = 1

peddler:RegisterEvent("PLAYER_ENTERING_WORLD")
peddler:RegisterEvent("ADDON_LOADED")
peddler:RegisterEvent("MERCHANT_SHOW")

local function getIsItemSoulbound(bagNumber, slotNumber)
  local item = Item:CreateFromBagAndSlot(bagNumber, slotNumber)
  local location = item:GetItemLocation()

  return C_Item.DoesItemExist(location) and C_Item.IsBound(location)
end

-- Serves to get the item's itemID + suffixID.
local function parseItemString(itemString)
  if not itemString then
    return
  end

  local _, itemID, _, _, _, _, _, suffixID = strsplit(":", itemString)
  itemID = tonumber(itemID)
  suffixID = tonumber(suffixID)

  if not itemID then
    return
  end

  local uniqueItemID = itemID
  if suffixID and suffixID ~= 0 then
    uniqueItemID = itemID .. suffixID
  end

  return itemID, uniqueItemID
end

local function getUniqueItemID(bagNumber, slotNumber)
  local itemString = C_Container.GetContainerItemLink(bagNumber, slotNumber)
  local itemID, uniqueItemID = parseItemString(itemString)
  local isSoulbound = getIsItemSoulbound(bagNumber, slotNumber)

  return itemID, uniqueItemID, isSoulbound, itemString
end

local function isUnwantedItem(itemType, subType, equipSlot)
  local unwantedItem = false

  -- Of course we never want to sell cloaks!
  local isCloak = equipSlot == 'INVTYPE_CLOAK'
  if AutoSellUnwantedItems and (itemType == WEAPON or itemType == ARMOUR) and not isCloak then
    unwantedItem = true
    for key, value in pairs(WANTED_ITEMS[PLAYERS_CLASS][itemType]) do
      if subType == value then
        unwantedItem = false
        break
      end
    end
  end

  return unwantedItem
end

function Peddler.itemIsToBeSold(itemID, uniqueItemID, isSoulbound)
  local _, link, quality, itemLevel, _, itemType, subType, _, equipSlot, _, price = GetItemInfo(itemID)

  -- No price?  No sale!
  if not price or price <= 0 then
    return
  end

  local unmarkedItem = UnmarkedItems[uniqueItemID]

  local unwantedGrey = quality == 0 and AutoSellGreyItems and not unmarkedItem
  local unwantedWhite = quality == 1 and AutoSellWhiteItems and not unmarkedItem
  local unwantedGreen = quality == 2 and AutoSellGreenItems and not unmarkedItem
  local unwantedBlue = quality == 3 and AutoSellBlueItems and not unmarkedItem
  local unwantedPurple = quality == 4 and AutoSellPurpleItems and not unmarkedItem

  local unwantedItem = isUnwantedItem(itemType, subType, equipSlot) and not unmarkedItem

  local autoSellable = (unwantedGrey or unwantedWhite or unwantedGreen or unwantedBlue or unwantedPurple or unwantedItem)

  if autoSellable then
    if SoulboundOnly and not unwantedGrey then
      autoSellable = isSoulbound
    end
  end

  return ItemsToSell[uniqueItemID] or autoSellable
end

local function peddleGoods()
  local total = 0
  local sellCount = 0
  local sellDelay = 0

  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemID, uniqueItemID, isSoulbound, itemLink = getUniqueItemID(bagNumber, slotNumber)

      if uniqueItemID and Peddler.itemIsToBeSold(itemID, uniqueItemID, isSoulbound) then
        local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]

        if itemButton.coins then
          itemButton.coins:Hide()
        end

        local itemInfo = C_Container.GetContainerItemInfo(bagNumber, slotNumber)
        local amount = itemInfo.stackCount

        local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(itemLink)

        if price and price > 0 then
          price = price * amount

          if total == 0 and (not Silent or not SilenceSaleSummary) then
            print("Peddler sold:")
          end

          total = total + price

          if not Silent then
            local output = "    " .. sellCount + 1 .. '. ' .. itemLink

            if amount > 1 then
              output = output .. "x" .. amount
            end

            output = output .. " for " .. priceToGold(price)
            print(output)
          end
        end

        -- Actually sell the item!
        if (sellDelay > 0) then
          local waitAnimationGroup = salesDelay:CreateAnimationGroup("sellDelay" .. sellCount)
          local waitAnimation = waitAnimationGroup:CreateAnimation("Translation")
          waitAnimation:SetDuration(sellDelay)
          waitAnimation:SetSmoothing("OUT")
          waitAnimationGroup:Play()

          waitAnimationGroup:SetScript("OnFinished", function()
            C_Container.PickupContainerItem(bagNumber, slotNumber)
            PickupMerchantItem()
          end)
        else
          C_Container.PickupContainerItem(bagNumber, slotNumber)
          PickupMerchantItem()
        end

        sellCount = sellCount + 1
        sellDelay = math.floor(sellCount / 6)
        if (SellLimit and sellCount >= BUYBACK_COUNT) then
          break
        end
      end

      if (SellLimit and sellCount >= BUYBACK_COUNT) then
        break
      end
    end
  end

  if total > 0 and not SilenceSaleSummary then
    print("For a total of " .. priceToGold(total))
  end
end

local function showCoinTexture(itemButton)
  if not itemButton.coins then
    local texture = itemButton:CreateTexture(nil, "OVERLAY")
    texture:SetTexture("Interface\\AddOns\\Peddler\\coins")

    -- Default padding for making bottom-right look great.
    local paddingX, paddingY = -3, 1
    if string.find(IconPlacement, "TOP") then
      paddingY = -3
    end
    if string.find(IconPlacement, "LEFT") then
      paddingX = 1
    end

    texture:SetPoint(IconPlacement, paddingX, paddingY)

    itemButton.coins = texture
  end

  itemButton.coins:Show()

  if not usingDefaultBags then
    peddler:SetScript("OnUpdate", nil)
  end
  markCounter = 0

  if usingDefaultBags or IsAddOnLoaded("Baggins") or IsAddOnLoaded("AdiBags") then
    -- Baggins/AdiBag update slower than the others, so we have to account for that.
    -- Default WoW bags need to constantly be updating, due to opening of individual bags.
    countLimit = 30
  else
    countLimit = 5
  end
end

local function displayCoins(itemID, uniqueItemID, itemButton, isSoulbound)
  if uniqueItemID then
    if Peddler.itemIsToBeSold(itemID, uniqueItemID, isSoulbound) then
      showCoinTexture(itemButton)
    elseif itemButton.coins then
      itemButton.coins:Hide()
    end
  elseif itemButton.coins then
    itemButton.coins:Hide()
  end
end

local function checkItem(bagNumber, slotNumber, itemButton)
  local itemID, uniqueItemID, isSoulbound = getUniqueItemID(bagNumber, slotNumber)
  displayCoins(itemID, uniqueItemID, itemButton, isSoulbound)
end

local function markBagginsBags()
  for bagid, bag in ipairs(Baggins.bagframes) do
    for sectionid, section in ipairs(bag.sections) do
      for buttonid, itemButton in ipairs(section.items) do
        local itemsBagNumber = itemButton:GetParent():GetID()
        local itemsSlotNumber = itemButton:GetID()

        checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
      end
    end
  end
end

-- Also works for Bagnon.
local function markCombuctorBags()
  for bagNumber = 0, BAG_COUNT do
    for slotNumber = 1, 36 do
      local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. slotNumber]

      local itemButtonParent = itemButton:GetParent()
      if itemButtonParent then
        local itemsBagNumber = itemButtonParent:GetID()
        local itemsSlotNumber = itemButton:GetID()
        checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
      end
    end
  end
end

local function markOneBagBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["OneBagFrameBag" .. bagNumber .. "Item" .. bagsSlotCount - slotNumber + 1]

      if itemButton then
        local itemsBagNumber = itemButton:GetParent():GetID()
        local itemsSlotNumber = itemButton:GetID()
        checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
      end
    end
  end
end

local function markBaudBagBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["BaudBagSubBag" .. bagNumber .. "Item" .. slotNumber]
      checkItem(bagNumber, slotNumber, itemButton)
    end
  end
end

local function markAdiBagBags()
  -- For some reason, AdiBags can have way more buttons than the actual amount of bag slots... not sure how or why.
  for slotNumber = 1, 1000 do
    local itemButton = _G["AdiBagsItemButton" .. slotNumber]
    if itemButton then
      local _, bag, slot = strsplit('-', tostring(itemButton))

      bag = tonumber(bag)
      slot = tonumber(slot)

      if bag and slot then
        checkItem(bag, slot, itemButton)
      end
    end
  end
end

local function markArkInventoryBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["ARKINV_Frame1ScrollContainerBag" .. bagNumber + 1 .. "Item" .. slotNumber]
      -- Required to check for itemButton because ArkInventory changed when it builds the item objects so only the first slot of each bag is available prior to the first time its opened, causing Peddler to get a nil obj for itemButton. /vincentSDSH
      if itemButton then checkItem(bagNumber, slotNumber, itemButton) end
    end
  end
end

local function markCargBagsNivayaBags()
  local totalSlotCount = 0
  for bagNumber = 0, BAG_COUNT do
    totalSlotCount = totalSlotCount + C_Container.GetContainerNumSlots(bagNumber)
  end

  -- Somehow, Nivaya can have higher slot-numbers than actual bag slots exist...
  totalSlotCount = totalSlotCount * 5

  for slotNumber = 1, totalSlotCount do
    local itemButton = _G["NivayaSlot" .. slotNumber]
    if itemButton then
      local itemsBag = itemButton:GetParent()

      if itemsBag then
        local itemsBagNumber = itemsBag:GetID()
        local itemsSlotNumber = itemButton:GetID()
        checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
      end
    end
    slotNumber = slotNumber + 1
  end
end

local function markMonoBags()
  local totalSlotCount = 0
  for bagNumber = 0, BAG_COUNT do
    totalSlotCount = totalSlotCount + C_Container.GetContainerNumSlots(bagNumber)
  end

  for slotNumber = 1, totalSlotCount do
    local itemButton = _G["m_BagsSlot" .. slotNumber]
    if itemButton then
      local itemsBagNumber = itemButton:GetParent():GetID()
      local itemsSlotNumber = itemButton:GetID()
      checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
    end
    slotNumber = slotNumber + 1
  end
end

local function markDerpyBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["StuffingBag" .. bagNumber .. "_" .. slotNumber]
      checkItem(bagNumber, slotNumber, itemButton)
    end
  end
end

local function markElvUIBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["ElvUI_ContainerFrameBag" .. bagNumber .. "Slot" .. slotNumber]
      checkItem(bagNumber, slotNumber, itemButton)
    end
  end
end

local function markInventorianBags()
  for bagNumber = 0, NUM_CONTAINER_FRAMES do
    for slotNumber = 1, 36 do
      local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. slotNumber]

      if itemButton then
        local itemButtonParent = itemButton:GetParent()
        if itemButtonParent then
          local itemsBagNumber = itemButtonParent:GetID()
          local itemsSlotNumber = itemButton:GetID()
          checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
        end
      end
    end
  end
end

-- Special thanks to both Xodiv & Theroxis of Curse for this one.
local function markLiteBagBags()
  for i = 1, LiteBagInventoryPanel.size do
    local button = LiteBagInventoryPanel.itemButtons[i]
    local itemsBagNumber = button:GetParent():GetID()
    local itemsSlotNumber = button:GetID()
    checkItem(itemsBagNumber, itemsSlotNumber, button)
  end
end

-- Special thanks to Tymesink from WowInterface for this one.
local function markfamBagsBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["famBagsButton_" .. bagNumber .. "_" .. slotNumber]
      checkItem(bagNumber, slotNumber, itemButton)
    end
  end
end

local function markLUIBags()
  for bagNumber = 0, BAG_COUNT do
    local bagsSlotCount = C_Container.GetContainerNumSlots(bagNumber)
    for slotNumber = 1, bagsSlotCount do
      local itemButton = _G["LUIBags_Item" .. bagNumber .. "_" .. slotNumber]
      checkItem(bagNumber, slotNumber, itemButton)
    end
  end
end

local function markRealUIBags()
  local totalSlotCount = 0
  for bagNumber = 0, BAG_COUNT do
    totalSlotCount = totalSlotCount + C_Container.GetContainerNumSlots(bagNumber)
  end

  -- Somehow, this can have higher slot-numbers than actual bag slots exist...
  totalSlotCount = totalSlotCount * 5

  for slotNumber = 1, totalSlotCount do
    local itemButton = _G["RealUIInventory_Slot" .. slotNumber]
    if itemButton then
      local itemsBag = itemButton:GetParent()

      if itemsBag then
        local itemsBagNumber = itemsBag:GetID()
        local itemsSlotNumber = itemButton:GetID()
        checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
      end
    end
    slotNumber = slotNumber + 1
  end
end

-- Also works for bBag.
local function markNormalBags()
  for containerNumber = 0, BAG_COUNT do
    local container = _G["ContainerFrame" .. containerNumber + 1]
    local combinedBags = _G["ContainerFrameCombinedBags"]
    if (container:IsShown()) then
      local bagsSlotCount = C_Container.GetContainerNumSlots(containerNumber)
      for slotNumber = 1, bagsSlotCount do
        -- It appears there are two ways of finding items!
        --   Accessing via _G means that bagNumbers are 1-based indices and
        --   slot numbers start from the bottom-right rather than top-left!
        -- Additionally, as only a couple of the bags may be visible at any
        --   given time, we may be looking at items whose buttons don't
        --   currently exist, and mark the wrong ones, so get the actual
        --   bag & slot number from the itemButton.
        local itemButton = _G["ContainerFrame" .. containerNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]

        local bagNumber = itemButton:GetParent():GetID()
        local actualSlotNumber = itemButton:GetID()

        checkItem(bagNumber, actualSlotNumber, itemButton)
      end
    elseif (combinedBags:IsShown()) then
      local bagsSlotCount = C_Container.GetContainerNumSlots(containerNumber)
      for slotNumber = 1, bagsSlotCount do
        local itemButton = _G["ContainerFrame" .. containerNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]
        local actualSlotNumber = itemButton:GetID()

        checkItem(containerNumber, actualSlotNumber, itemButton)
      end
    end
  end
end

local overridenItemClickFunction = false

-- TODO: Split these into separate, well-coded things already.
local function markWares()
  if IsAddOnLoaded("Baggins") then
    markBagginsBags()
  elseif IsAddOnLoaded("Combuctor") or IsAddOnLoaded("Bagnon") then
    markCombuctorBags()
  elseif IsAddOnLoaded("OneBag3") then
    markOneBagBags()
  elseif IsAddOnLoaded("BaudBag") then
    markBaudBagBags()
  elseif IsAddOnLoaded("AdiBags") then
    markAdiBagBags()
  elseif IsAddOnLoaded("ArkInventory") then
    markArkInventoryBags()
  elseif IsAddOnLoaded("famBags") then
    markfamBagsBags()
  elseif IsAddOnLoaded("cargBags_Nivaya") then
    markCargBagsNivayaBags()
  elseif IsAddOnLoaded("m_Bags") then
    markMonoBags()
  elseif IsAddOnLoaded("DerpyStuffing") then
    markDerpyBags()
  elseif IsAddOnLoaded("Inventorian") then
    markInventorianBags()
  elseif IsAddOnLoaded("LiteBag") then
    markLiteBagBags()
  elseif IsAddOnLoaded("ElvUI") and _G["ElvUI_ContainerFrame"] then
    markElvUIBags()
  elseif IsAddOnLoaded("LUI") and _G["LUIBags_Item0_1"] then
    markLUIBags()
  elseif IsAddOnLoaded("RealUI_Inventory") then
    markRealUIBags()
  else
    usingDefaultBags = true
    markNormalBags()
  end
end

Peddler.markWares = markWares

local function onUpdate()
  markCounter = markCounter + 1
  if markCounter <= countLimit then
    return
  else
    markCounter = 0
    markWares()
  end
end

local function handleBagginsOpened()
  if markCounter == 0 then
    peddler:SetScript("OnUpdate", onUpdate)
  end
end

local function setupDefaults()
  -- Setup default settings.
  if not ItemsToSell then
    ItemsToSell = {}
  end

  if not UnmarkedItems then
    UnmarkedItems = {}
  end

  if not ModifierKey then
    ModifierKey = "CTRL"
  end

  if not IconPlacement then
    IconPlacement = "BOTTOMLEFT"
  end

  if AutoSellGreyItems == nil then
    AutoSellGreyItems = true
  end
end

local function overrideItemClickFunction()
  _HandleModifiedItemClick = HandleModifiedItemClick
  HandleModifiedItemClick = function(link, item) 
    _HandleModifiedItemClick(link, item)

    if item then
      handlePeddlerItemClick(link, item)
    end
  end
end

local function handleEvent(self, event, addonName)
  if event == "ADDON_LOADED" and addonName == "Peddler" then
    peddler:UnregisterEvent("ADDON_LOADED")

    setupDefaults()
    overrideItemClickFunction()

    countLimit = 400
    peddler:SetScript("OnUpdate", onUpdate)

    if IsAddOnLoaded("Baggins") then
      Baggins:RegisterSignal("Baggins_BagOpened", handleBagginsOpened, Baggins)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    peddler:RegisterEvent("BAG_UPDATE")
  elseif event == "BAG_UPDATE" then
    if markCounter == 0 then
      peddler:SetScript("OnUpdate", onUpdate)
    end
  elseif event == "MERCHANT_SHOW" then
    peddleGoods()
  end
end

peddler:SetScript("OnEvent", handleEvent)

local function toggleItemPeddling(itemID, uniqueItemID, isSoulbound)
  local _, link, quality, _, _, itemType, subType, _, equipSlot, _, price = GetItemInfo(itemID)
  if price == 0 then
    return
  end

  local unwantedGrey = quality == 0 and AutoSellGreyItems
  local unwantedWhite = quality == 1 and AutoSellWhiteItems
  local unwantedGreen = quality == 2 and AutoSellGreenItems
  local unwantedBlue = quality == 3 and AutoSellBlueItems
  local unwantedPurple = quality == 4 and AutoSellPurpleItems

  local unwantedItem = isUnwantedItem(itemType, subType, equipSlot)

  local autoSellable = (unwantedGrey or unwantedWhite or unwantedGreen or unwantedBlue or unwantedPurple or unwantedItem)

  if autoSellable then
    if SoulboundOnly and not unwantedGrey then
      autoSellable = isSoulbound
    end
  end

  if autoSellable then
    if UnmarkedItems[uniqueItemID] then
      UnmarkedItems[uniqueItemID] = nil
    else
      UnmarkedItems[uniqueItemID] = 1
      ItemsToSell[uniqueItemID] = nil
    end
  elseif ItemsToSell[uniqueItemID] then
    ItemsToSell[uniqueItemID] = nil
  else
    ItemsToSell[uniqueItemID] = 1
  end
end

function clickedWithPeddlerCombo()
  local ctrlKeyDown = IsControlKeyDown()
  local shiftKeyDown = IsShiftKeyDown()
  local altKeyDown = IsAltKeyDown()
  local mouseButtonPressed = GetMouseButtonClicked()

  local modifierDown = (ModifierKey == 'CTRL' and ctrlKeyDown or (ModifierKey == 'SHIFT' and shiftKeyDown or (ModifierKey == 'ALT' and altKeyDown or (ModifierKey == 'CTRL-SHIFT' and ctrlKeyDown and shiftKeyDown or (ModifierKey == 'CTRL-ALT' and ctrlKeyDown and altKeyDown or (ModifierKey == 'ALT-SHIFT' and altKeyDown and shiftKeyDown))))))
  local usingPeddler = (modifierDown and mouseButtonPressed == 'RightButton')

  return usingPeddler
end

function handlePeddlerItemClick(self, item)
  if not clickedWithPeddlerCombo() then
    return
  end

  local bagNumber, slotNumber = item:GetBagAndSlot()
  local itemID, uniqueItemID, isSoulbound = getUniqueItemID(bagNumber, slotNumber)

  -- Empty bag slots cannot be sold, silly!
  if not itemID then
    return
  end

  toggleItemPeddling(itemID, uniqueItemID, isSoulbound)

  markWares()
end

-- Quest Reward handling.
local listeningToRewards = {}
local function checkQuestReward(itemButton, toggle)
  local rewardIndex = itemButton:GetID()

  local testReward = function(itemString)
    if not itemString then
      return
    end

    local itemID, uniqueItemID = parseItemString(itemString)

    if toggle then
      toggleItemPeddling(itemID, uniqueItemID)
    end

    displayCoins(itemID, uniqueItemID, itemButton)
  end

  testReward(GetQuestLogItemLink("reward", rewardIndex))
  testReward(GetQuestLogItemLink("choice", rewardIndex))
end

local function handleQuestFrameItemClick(self, button)
  if not clickedWithPeddlerCombo() then
    return
  end

  checkQuestReward(self, true)

  markWares()
end

local function setupQuestFrame(frameBaseName)
  for i = 1, 6 do
    local frameName = frameBaseName .. i
    local itemButton = _G[frameName]
    if itemButton then
      checkQuestReward(itemButton, false)

      if not listeningToRewards[frameName] then
        listeningToRewards[frameName] = true
        itemButton:HookScript("OnClick", handleQuestFrameItemClick)
      end
    end
  end
end

local function onQuestRewardsShow()
  setupQuestFrame("QuestInfoRewardsFrameQuestInfoItem")
end

local function onMapQuestRewardsShow()
  setupQuestFrame("MapQuestInfoRewardsFrameQuestInfoItem")
end

MapQuestInfoRewardsFrame:HookScript("OnShow", onMapQuestRewardsShow)
QuestInfoRewardsFrame:HookScript("OnShow", onQuestRewardsShow)
