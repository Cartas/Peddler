-- Assign global functions to locals for optimisation.
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemID = GetContainerItemID
local UseContainerItem = UseContainerItem
local IsControlKeyDown = IsControlKeyDown
local next = next

local ItemsToSell = {}

	-- 110631 -> 11g6s31c
local function priceToGold(price)
	local gold = price / 10000
	local silver = (price % 10000) / 100
	local copper = (price % 10000) % 100

	return math.floor(gold) .. "g" .. math.floor(silver) .. "s" .. math.floor(copper) .. "c"
end

local peddler = CreateFrame("Frame", nil, UIParent)
peddler:RegisterEvent("MERCHANT_SHOW")

local function peddleGoods(self, event, ...)
	if not next(ItemsToSell) then
		return
	end

	local output = "Peddler sold:\n"
	local total = 0

	for bagNumber = 0, 4 do
		for slotNumber = 1, GetContainerNumSlots(bagNumber) do
			local itemID = GetContainerItemID(bagNumber, slotNumber)

			if ItemsToSell[itemID] then
				local texture = ItemsToSell[itemID]
				texture:Hide()
				texture = nil
				ItemsToSell[itemID] = nil

				UseContainerItem(bagNumber, slotNumber)

				local _, link, _, _, _, _, _, _, _, _, price = GetItemInfo(itemID)
				local _, amount = GetContainerItemInfo(bagNumber, slotNumber)

				price = price * amount

				total = total + price
				output = output .. link .. " for " .. priceToGold(price) .. "\n"
			end
		end
	end

	ItemsToSell = {}

	output = output .. "\nFor a total of " .. priceToGold(total)
	print(output)
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