local _, Peddler = ...

local frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
frame.name = "Peddler"
frame:Hide()

frame:SetScript("OnShow", function(self)
	self:CreateOptions()
	self:SetScript("OnShow", nil)
end)

local function createCheckBox(parent, anchor, number, property, label, tooltip)
	local checkbox = CreateFrame("CheckButton", "PeddlerCheckBox" .. number, parent, "ChatConfigCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 16, number * -26)

	local checkboxLabel = _G[checkbox:GetName() .. "Text"]
	checkboxLabel:SetText(label)
	checkboxLabel:SetPoint("TOPLEFT", checkbox, "RIGHT", 5, 7)

	checkbox.tooltip = tooltip
	checkbox:SetChecked(property)

	return checkbox
end

local function changeModifierKey(self)
	UIDropDownMenu_SetSelectedID(ModifierKeyDropDown, self:GetID())
	ModifierKey = self.value
end

local function initModifierKeys(self, level)
	local modifierKeys = {"CTRL", "ALT", "SHIFT", "CTRL-SHIFT", "CTRL-ALT", "ALT-SHIFT"}
	for index, modifierKey in pairs(modifierKeys) do
		local modifierKeyOption = UIDropDownMenu_CreateInfo()
		modifierKeyOption.text = modifierKey
		modifierKeyOption.value = modifierKey
		modifierKeyOption.func = changeModifierKey
		UIDropDownMenu_AddButton(modifierKeyOption)

		if modifierKey == ModifierKey then
			UIDropDownMenu_SetSelectedID(ModifierKeyDropDown, index)
		end
	end
end

local function changeIconPlacement(self)
	UIDropDownMenu_SetSelectedID(IconPlacementDropDown, self:GetID())
	IconPlacement = self.value
end

local function initIconPlacement(self, level)
	local iconPlacements = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
	for index, iconPlacement in pairs(iconPlacements) do
		local iconPlacementOption = UIDropDownMenu_CreateInfo()
		iconPlacementOption.text = iconPlacement
		iconPlacementOption.value = iconPlacement
		iconPlacementOption.func = changeIconPlacement
		UIDropDownMenu_AddButton(iconPlacementOption)

		if iconPlacement == IconPlacement then
			UIDropDownMenu_SetSelectedID(IconPlacementDropDown, index)
		end
	end
end

function frame:CreateOptions()
	local title = self:CreateFontString(nil, nil, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Peddler")

	local sellLimit = createCheckBox(self, title, 1, SellLimit, "Sell Limit", "Limits the amount of items sold in one go, so you may buy all items back.")
	sellLimit:SetScript("PostClick", function(self, button, down)
		SellLimit = self:GetChecked()
	end)

	local silentMode = createCheckBox(self, title, 2, Silent, "Silent Mode", "Silence chat output about prices and sold item information.")
	silentMode:SetScript("PostClick", function(self, button, down)
		Silent = self:GetChecked()
	end)

	local silenceSaleSummary = createCheckBox(self, title, 3, SilenceSaleSummary, "Silence Sale Summary", "Silence the sale summary.")
	silenceSaleSummary:SetScript("PostClick", function(self, button, down)
		SilenceSaleSummary = self:GetChecked()
	end)
	silenceSaleSummary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 190, 2 * -26)

	local modifierKeyLabel = self:CreateFontString(nil, nil, "GameFontNormal")
	modifierKeyLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -90)
	modifierKeyLabel:SetText("Modifier Key (used with right-click to mark/unmark items):")

	local modifierKey = CreateFrame("Button", "ModifierKeyDropDown", self, "UIDropDownMenuTemplate")
	modifierKey:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -107)
	UIDropDownMenu_Initialize(ModifierKeyDropDown, initModifierKeys)
	UIDropDownMenu_SetWidth(ModifierKeyDropDown, 90);
	UIDropDownMenu_SetButtonWidth(ModifierKeyDropDown, 90)

	local iconPlacementLabel = self:CreateFontString(nil, nil, "GameFontNormal")
	iconPlacementLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -150)
	iconPlacementLabel:SetText("Icon Placement (the corner the coins icon should appear in - please reload to apply changes):")

	local iconPlacement = CreateFrame("Button", "IconPlacementDropDown", self, "UIDropDownMenuTemplate")
	iconPlacement:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -167)
	UIDropDownMenu_Initialize(IconPlacementDropDown, initIconPlacement)
	UIDropDownMenu_SetWidth(IconPlacementDropDown, 110);
	UIDropDownMenu_SetButtonWidth(IconPlacementDropDown, 110);

	local autoSellLabel = self:CreateFontString(nil, nil, "GameFontNormal")
	autoSellLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -210)
	autoSellLabel:SetText("Automatically sell...")

	local autoSellSoulboundOnly = createCheckBox(self, title, 8, SoulboundOnly, "Restrict to Soulbound Items", "Only allow Peddler to automatically mark soulbound items for sale (does not restrict grey items, naturally).")
	autoSellSoulboundOnly:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 120, -205)
	autoSellSoulboundOnly:SetScript("PostClick", function(self, button, down)
		SoulboundOnly = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellGreyItems = createCheckBox(self, title, 9, AutoSellGreyItems, "Poor Items", "Automatically sells all grey/junk items.")
	autoSellGreyItems:SetScript("PostClick", function(self, button, down)
		AutoSellGreyItems = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellWhiteItems = createCheckBox(self, title, 10, AutoSellWhiteItems, "Common Items", "Automatically sells all white/common items.")
	autoSellWhiteItems:SetScript("PostClick", function(self, button, down)
		AutoSellWhiteItems = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellGreenItems = createCheckBox(self, title, 11, AutoSellGreenItems, "Uncommon Items", "Automatically sells all green/uncommon items.")
	autoSellGreenItems:SetScript("PostClick", function(self, button, down)
		AutoSellGreenItems = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellBlueItems = createCheckBox(self, title, 12, AutoSellBlueItems, "Rare Items", "Automatically sells all blue/rare items.")
	autoSellBlueItems:SetScript("PostClick", function(self, button, down)
		AutoSellBlueItems = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellPurpleItems = createCheckBox(self, title, 13, AutoSellPurpleItems, "Epic Items", "Automatically sells all purple/epic items.")
	autoSellPurpleItems:SetScript("PostClick", function(self, button, down)
		AutoSellPurpleItems = self:GetChecked()
		Peddler.markWares()
	end)

	local autoSellUnwantedItems = createCheckBox(self, title, 14, AutoSellUnwantedItems, "Unwanted Items", "Automatically sell all items which are unwanted for your current class (e.g. Priests don't want plate gear, so all plate gear will be marked).")
	autoSellUnwantedItems:SetScript("PostClick", function(self, button, down)
		AutoSellUnwantedItems = self:GetChecked()
		Peddler.markWares()
	end)

	local clearWaresList = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	clearWaresList:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -420)
	clearWaresList:SetWidth(110)
	clearWaresList:SetText("Clear Items List")
	clearWaresList:SetScript("PostClick", function(self, button, down)
		ItemsToSell = {}
		Peddler.markWares()
	end)

	local clearWaresLabel = self:CreateFontString(nil, nil, "GameFontHighlightSmall")
	clearWaresLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 19, -450)
	clearWaresLabel:SetText("Clears the list of items you've manually marked for sale, for this character.")

	if self.refresh ~=nil then self:refresh() end
end

InterfaceOptions_AddCategory(frame)

-- Handling Peddler's options.
SLASH_PEDDLER_COMMAND1 = '/peddler'
SlashCmdList['PEDDLER_COMMAND'] = function(command)
	InterfaceOptionsFrame_OpenToCategory('Peddler')
end
