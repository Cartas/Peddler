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

	if ItemsToSell[itemID] then
		ItemsToSell[itemID] = nil
		print("Peddler: No longer selling " .. itemLink)
	else
		ItemsToSell[itemID] = 1
		local texture = self:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\AddOns\\Peddler\\coins")
		texture:SetPoint("BOTTOMRIGHT", -3, 1)
		texture:Show()
		print("Peddler: Selling " .. itemLink)
	end
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)