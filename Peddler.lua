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
	if not next(ItemsToSell) then
		return
	end

	for bagNumber = 0, 4 do
		for slotNumber = 1, GetContainerNumSlots(bagNumber) do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			if ItemsToSell[itemID] then
				local texture = ItemsToSell[itemID]
				texture:Hide()
				texture = nil
				UseContainerItem(bagNumber, slotNumber)
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

	if ItemsToSell[itemID] then
		local texture = ItemsToSell[itemID]
		texture:Hide()
		texture = nil
		ItemsToSell[itemID] = nil
	else
		local texture = self:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\AddOns\\Peddler\\coins")
		texture:SetPoint("BOTTOMRIGHT", -3, 1)
		texture:Show()
		ItemsToSell[itemID] = texture
	end
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", handleItemClick)