-- Assign global functions to locals for optimisation.
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemID = GetContainerItemID
local GetItemInfo = GetItemInfo
local UseContainerItem = UseContainerItem
local IsControlKeyDown = IsControlKeyDown
local next = next

local ItemsToSell = {}

local peddler = CreateFrame("Frame", nil, UIParent)
peddler:RegisterEvent("MERCHANT_SHOW")

local function peddleGoods(self, event, ...)
	if not next(ItemsToSell) then
		return
	end

	for bagNumber = 0, 4 do
		for slotNumber = 1, GetContainerNumSlots(bagNumber) do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			local amountToSell = ItemsToSell[itemID]
			if amountToSell and amountToSell >= 1 then
				UseContainerItem(bagNumber, slotNumber)
				ItemsToSell[itemID] = amountToSell - 1
			end
		end
	end

	ItemsToSell = {}
end

peddler:SetScript("OnEvent", peddleGoods)

local function handleItemClick(self, button)
	local usingPeddler = IsControlKeyDown() and button == 'RightButton'
	if not usingPeddler then
		return
	end

	local bagNumber = self:GetParent():GetID()
	local slotNumber = self:GetID()

	local itemID = GetContainerItemID(bagNumber, slotNumber)
	local _, itemLink = GetItemInfo(itemID)

	if ItemsToSell[itemID] and ItemsToSell[itemID] > 0 then
		if IsShiftKeyDown() then
			ItemsToSell[itemID] = 0
			print("Peddler: No longer selling " .. itemLink)
		else
			local amountToSell = ItemsToSell[itemID] + 1
			ItemsToSell[itemID] = amountToSell
			print("Peddler: Selling " .. amountToSell .. " x " .. itemLink)
		end
	elseif not IsShiftKeyDown() then
		ItemsToSell[itemID] = 1
		print("Peddler: Selling " .. itemLink)
	end
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)