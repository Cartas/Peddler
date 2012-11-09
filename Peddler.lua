-- Assign global functions to locals for optimisation.
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemID = GetContainerItemID
local GetItemInfo = GetItemInfo
local GetItemCount = GetItemCount
local GetContainerItemInfo = GetContainerItemInfo
local UseContainerItem = UseContainerItem
local IsControlKeyDown = IsControlKeyDown
local next = next
local Baggins = Baggins

local BUYBACK_COUNT = 12

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
local usingDefaultBags = false
local markCounter = 1
local countLimit = 1

peddler:RegisterEvent("PLAYER_ENTERING_WORLD")
peddler:RegisterEvent("ADDON_LOADED")
peddler:RegisterEvent("MERCHANT_SHOW")

local function itemIsToBeSold(itemID)
	local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(itemID)

	if price <= 0 then
		return
	end

	local unmarkedItem = UnmarkedItems[itemID]

	local unwantedGray = quality == 0 and AutoSellGreyItems and not unmarkedItem
	local unwantedWhite = quality == 1 and AutoSellWhiteItems and not unmarkedItem
	local unwantedGreen = quality == 2 and AutoSellGreenItems and not unmarkedItem

	return (ItemsToSell[itemID] or unwantedGray or unwantedWhite or unwantedGreen)
end

local function peddleGoods()
	local total = 0
	local sellCount = 0

	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			if itemID and itemIsToBeSold(itemID) then
				local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]

				if itemButton.coins then
					itemButton.coins:Hide()
				end

				local _, amount = GetContainerItemInfo(bagNumber, slotNumber)

				if price > 0 and not Silent then
					price = price * amount

					if total == 0 then
						print("Peddler sold:")
					end

					total = total + price
					local _, link = GetItemInfo(itemID)
					local output = "    " .. sellCount + 1 .. '. ' .. link

					if amount > 1 then
						output = output .. "x" .. amount
					end

					output = output .. " for " .. priceToGold(price)
					print(output)
				end

				-- Actually sell the item!
				UseContainerItem(bagNumber, slotNumber)
				sellCount = sellCount + 1
				if (SellLimit and sellCount >= BUYBACK_COUNT) then
					break
				end
			end

			if (SellLimit and sellCount >= BUYBACK_COUNT) then
				break
			end
		end
	end

	if total > 0 and not Silent then
		print("For a total of " .. priceToGold(total))
	end
end

local function showCoinTexture(itemButton)
	if not itemButton.coins then
		local texture = itemButton:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\AddOns\\Peddler\\coins")
		texture:SetPoint("BOTTOMRIGHT", -3, 1)

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

local function checkItem(bagNumber, slotNumber, itemButton)
	local itemID = GetContainerItemID(bagNumber, slotNumber)

	if itemID then
		if itemIsToBeSold(itemID) then
			showCoinTexture(itemButton)
		elseif itemButton.coins then
			itemButton.coins:Hide()
		end
	elseif itemButton.coins then
		itemButton.coins:Hide()
	end
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
	for bagNumber = 0, 4 do
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
	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
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
	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			local itemButton = _G["BaudBagSubBag" .. bagNumber .. "Item" .. slotNumber]
			checkItem(bagNumber, slotNumber, itemButton)
		end
	end
end

local function markAdiBagBags()
	local totalSlotCount = 0
	for bagNumber = 0, 4 do
		totalSlotCount = totalSlotCount + GetContainerNumSlots(bagNumber)
	end

	-- For some reason, AdiBags can have way more buttons than the actual amount of bag slots... not sure how or why.
	totalSlotCount = totalSlotCount + 30

	for slotNumber = 1, totalSlotCount do
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
	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			local itemButton = _G["ARKINV_Frame1ContainerBag" .. bagNumber + 1 .. "Item" .. slotNumber]
			checkItem(bagNumber, slotNumber, itemButton)
		end
	end
end

local function markCargBagsNivayaBags()
	local totalSlotCount = 0
	for bagNumber = 0, 4 do
		totalSlotCount = totalSlotCount + GetContainerNumSlots(bagNumber)
	end

	for slotNumber = 1, totalSlotCount do
		local itemButton = _G["NivayaSlot" .. slotNumber]
		if itemButton then
			local itemsBagNumber = itemButton:GetParent():GetID()
			local itemsSlotNumber = itemButton:GetID()
			checkItem(itemsBagNumber, itemsSlotNumber, itemButton)
		end
		slotNumber = slotNumber + 1
	end
end

-- Also works for bBag.
local function markNormalBags()
	for containerNumber = 0, 4 do
		local container = _G["ContainerFrame" .. containerNumber + 1]
		if (container:IsShown()) then
			local bagsSlotCount = GetContainerNumSlots(containerNumber)
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
		end
	end
end

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
	elseif IsAddOnLoaded("cargBags_Nivaya") then
		markCargBagsNivayaBags()
	else
		usingDefaultBags = true
		markNormalBags()
	end
end

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

local function handleEvent(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "Peddler" then
		peddler:UnregisterEvent("ADDON_LOADED")

		if not ItemsToSell then
			ItemsToSell = {}
		end

		if not UnmarkedItems then
			UnmarkedItems = {}
		end

		if not ModifierKey then
			ModifierKey = "CTRL"
		end

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

local function handleItemClick(self, button)
	local modifierDown = (ModifierKey == 'CTRL' and IsControlKeyDown() or (ModifierKey == 'SHIFT' and IsShiftKeyDown() or (ModifierKey == 'ALT' and IsAltKeyDown())))
	local usingPeddler = modifierDown and button == 'RightButton'
	if not usingPeddler then
		return
	end

	local bagNumber = self:GetParent():GetID()
	local slotNumber = self:GetID()

	local itemID = GetContainerItemID(bagNumber, slotNumber)
	if not itemID then
		return
	end

	local _, link, quality, _, _, _, _, _, _, _, price = GetItemInfo(itemID)
	if price == 0 then
		return
	end

	if (quality == 0 and AutoSellGreyItems) or
		(quality == 1 and AutoSellWhiteItems) or
		(quality == 2 and AutoSellGreenItems) then
		if UnmarkedItems[itemID] then
			UnmarkedItems[itemID] = nil
		else
			UnmarkedItems[itemID] = 1
		end
	elseif ItemsToSell[itemID] then
		ItemsToSell[itemID] = nil
	else
		ItemsToSell[itemID] = 1
	end

	markWares()
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)