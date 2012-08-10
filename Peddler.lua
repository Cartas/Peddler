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

local function priceToGold(price)
	local gold = price / 10000
	local silver = (price % 10000) / 100
	local copper = (price % 10000) % 100

	return math.floor(gold) .. "|cFFFFCC33g|r " .. math.floor(silver) .. "|cFFC9C9C9s|r " .. math.floor(copper) .. "|cFFCC8890c|r"
end

local peddler = CreateFrame("Frame", nil, UIParent)
peddler:RegisterEvent("PLAYER_ENTERING_WORLD")
peddler:RegisterEvent("ADDON_LOADED")
peddler:RegisterEvent("MERCHANT_SHOW")

local function peddleGoods()
	local output = "Peddler sold:\n"
	local total = 0

	foundItems = {}
	for bagNumber = 0, 4 do
		local bagsSlotCount = GetContainerNumSlots(bagNumber)
		for slotNumber = 1, bagsSlotCount do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			if itemID then
				local _, link, quality, _, _, _, _, _, _, _, price = GetItemInfo(itemID)

				if ItemsToSell[itemID] then
					local itemButton = _G["ContainerFrame" .. bagNumber + 1 .. "Item" .. bagsSlotCount - slotNumber + 1]

					if itemButton.coins then
						itemButton.coins:Hide()
					end

					ItemsToSell[itemID] = ItemsToSell[itemID] - 1

					if foundItems[itemID] then
						foundItems[itemID] = foundItems[itemID] + 1
					else
						foundItems[itemID] = 1
					end

					local _, amount = GetContainerItemInfo(bagNumber, slotNumber)

					if price > 0 then
						price = price * amount

						total = total + price
						output = output .. link

						if amount > 1 then
							output = output .. "x" .. amount
						end

						output = output .. " for " .. priceToGold(price) .. "\n"
					end

					-- Actually sell the item!
					UseContainerItem(bagNumber, slotNumber)
				end
			end
		end
	end

	ItemsToSell = {}

	if total > 0 then
		output = output .. "\nFor a total of " .. priceToGold(total)
		print(output)
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
end

local function checkItem(bagNumber, slotNumber, itemButton)
	local itemID = GetContainerItemID(bagNumber, slotNumber)
	if itemID and ItemsToSell[itemID] then
		showCoinTexture(itemButton)
	elseif itemButton.coins then
		itemButton.coins:Hide()
		itemButton.coins = nil
	end
end

local bagginsInitialisationTimer
local bagginsInitialised = false

local function markBagginsBags()
	if bagginsInitialisationTimer then
		bagginsInitialisationTimer:SetScript("OnUpdate", nil)
		bagginsInitialisationTimer = nil
	end

	for bagid, bag in ipairs(Baggins.bagframes) do
		for sectionid, section in ipairs(bag.sections) do
			for buttonid, itemButton in ipairs(section.items) do
				local bagNumber = itemButton:GetParent():GetID()
				local slotNumber = itemButton:GetID()

				checkItem(bagNumber, slotNumber, itemButton)
			end
		end
	end
end

local function initBaggins()
	if not bagginsInitialised then
		bagginsInitialisationTimer = CreateFrame("Frame")
		bagginsInitialisationTimer:SetScript("OnUpdate", markBagginsBags)
		bagginsInitialised = true
	end
end

local function markCombuctorBags()
	print(_G["Combuctor"].bags)
	for _,frame in pairs(Combuctor.frames) do
		for _,bagID in pairs(frame.sets.bags) do
			for slot = 1, Combuctor:GetBagSize(bag) do
				local item = self.items[ToIndex(bag, slot)]
				print(item)
			end
		end
	end
end

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
	if not ItemsToSell then
		ItemsToSell = {}
	end

	for bag = NUM_BAG_FRAMES, 0, -1 do
		for slot = GetContainerNumSlots(bag), 1, -1 do
			local slots = GetContainerNumSlots(bag)
			local itemButton = _G['ContainerFrame' .. bag + 1 .. 'Item' .. slots - slot + 1]
			local itemID = GetContainerItemID(bag, slot)
			if ItemsToSell[itemID] then
				showCoinTexture(itemButton)
			elseif itemButton.coins then
				itemButton.coins:Hide()
			end
		end
	end
end

local function handleEvent(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "Peddler" then
		peddler:UnregisterEvent("ADDON_LOADED")

		if Baggins then
			Baggins:RegisterSignal("Baggins_BagOpened", initBaggins, Baggins)
		else
			markWares()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		peddler:RegisterEvent("BAG_UPDATE")
	elseif event == "BAG_UPDATE" then
		markWares()
	elseif event == "MERCHANT_SHOW" then
		peddleGoods()
	end
end

peddler:SetScript("OnEvent", handleEvent)

local function handleItemClick(self, button)
	local usingPeddler = IsControlKeyDown() and button == 'RightButton'
	if not usingPeddler then
		return
	end

	local bagNumber = self:GetParent():GetID()
	local slotNumber = self:GetID()

	local itemID = GetContainerItemID(bagNumber, slotNumber)
	if not itemID then
		return
	end

	local _, link, _, _, _, _, _, _, _, _, price = GetItemInfo(itemID)
	if price == 0 then
		return
	end

	if ItemsToSell[itemID] then
		ItemsToSell[itemID] = nil
	else
		ItemsToSell[itemID] = 1
	end

	markWares()
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)