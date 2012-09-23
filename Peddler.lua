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

-- Turns an integer value into the format "Xg Ys Zc".
local function priceToGold(price)
	local gold = price / 10000
	local silver = (price % 10000) / 100
	local copper = (price % 10000) % 100

	return math.floor(gold) .. "|cFFFFCC33g|r " .. math.floor(silver) .. "|cFFC9C9C9s|r " .. math.floor(copper) .. "|cFFCC8890c|r"
end

local peddler = CreateFrame("Frame", nil, UIParent)
local markCounter = 1
local countLimit = 1

peddler:RegisterEvent("PLAYER_ENTERING_WORLD")
peddler:RegisterEvent("ADDON_LOADED")
peddler:RegisterEvent("MERCHANT_SHOW")

local function peddleGoods()
	local total = 0

	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			if itemID then
				local _, link, quality, _, _, _, _, _, _, _, price = GetItemInfo(itemID)

				if ItemsToSell[itemID] or (quality == 0 and not UnmarkedGrayItems[itemID]) then
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
						local output = "    " .. link

						if amount > 1 then
							output = output .. "x" .. amount
						end

						output = output .. " for " .. priceToGold(price)
						print(output)
					end

					-- Actually sell the item!
					UseContainerItem(bagNumber, slotNumber)
				end
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

	peddler:SetScript("OnUpdate", nil)
	markCounter = 0

	if IsAddOnLoaded("Baggins") then
		-- Baggins updates slower than the others, so we have to account for that.
		countLimit = 30
	else
		countLimit = 1
	end
end

local function checkItem(bagNumber, slotNumber, itemButton)
	local itemID = GetContainerItemID(bagNumber, slotNumber)

	if itemID then
		local _, _, quality = GetItemInfo(itemID)
		if ItemsToSell[itemID] or (quality == 0 and not UnmarkedGrayItems[itemID]) then
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

-- Also works for bBag.
local function markNormalBags()
	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			-- It appears there are two ways of finding items!
			--   Accessing via _G means that bagNumbers are 1-based indices and
			--   slot numbers start from the bottom-right rather than top-left!
			local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]
			checkItem(bagNumber, slotNumber, itemButton)
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
	else
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

		if not UnmarkedGrayItems then
			UnmarkedGrayItems = {}
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

	if quality == 0 then
		if UnmarkedGrayItems[itemID] then
			UnmarkedGrayItems[itemID] = nil
		else
			UnmarkedGrayItems[itemID] = 1
		end
	elseif ItemsToSell[itemID] then
		ItemsToSell[itemID] = nil
	else
		ItemsToSell[itemID] = 1
	end

	markWares()
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)

-- Handling Peddler's options.
SLASH_PEDDLER_COMMAND1 = '/peddler'
SlashCmdList['PEDDLER_COMMAND'] = function(command)
	local key = ""
	command, key = strsplit(' ', string.lower(command))

	if command == 'silent' then
		Silent = not Silent
		print('Peddler: Silent mode '.. (Silent and '|cFF00CC00enabled|r' or '|cFFCF0000disabled') .. '|r')
	elseif command == 'modifier' and (key == 'ctrl' or key == 'shift' or key == 'alt') then
		ModifierKey = string.upper(key)
		print('Peddler: Modifier key set to ' .. ModifierKey)
	else
		print('"/peddler silent" [' .. (Silent and '|cFF00CC00ON|r' or '|cFFCF0000OFF') .. '|r]  - Silence chat output about prices and sold item information.')
		print('"/peddler modifier CTRL/SHIFT/ALT" [|cFF00CC00' .. ModifierKey .. '|r] - Set the modifier key you\'d like to flag items with.')
	end
end