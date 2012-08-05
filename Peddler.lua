-- Assign global functions to locals for optimisation.
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemID = GetContainerItemID
local UseContainerItem = UseContainerItem
local IsControlKeyDown = IsControlKeyDown
local next = next

local ItemsToSell = {}

local peddler = CreateFrame("Frame", nil, UIParent)
peddler:RegisterEvent("MERCHANT_SHOW")

local function peddleGoods(self, event, ...)
	-- No items to be sold, do nothing!
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
	local bagNumber = self:GetParent():GetID()
	local slotNumber = self:GetID()

	local itemID = GetContainerItemID(bagNumber, slotNumber)

	if IsControlKeyDown() and button == 'RightButton' then
		if ItemsToSell[itemID] then
			local amountToSell = ItemsToSell[itemID] + 1
			ItemsToSell[itemID] = amountToSell
			print("Selling " .. amountToSell .. " x " .. itemID)
		else
			ItemsToSell[itemID] = 1
			print("Selling " .. itemID)
		end
	end

end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)