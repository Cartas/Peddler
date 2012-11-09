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

	local checkboxLabel =_G[checkbox:GetName() .. "Text"]
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
	local modifierKeys = {"CTRL", "ALT", "SHIFT"}
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

	local modifierKeyLabel = self:CreateFontString(nil, nil, "GameFontHighlight")
	modifierKeyLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -90)
	modifierKeyLabel:SetText("Modifier Key:")

	local modifierKey = CreateFrame("Button", "ModifierKeyDropDown", self, "UIDropDownMenuTemplate")
	modifierKey:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -110)
	UIDropDownMenu_Initialize(ModifierKeyDropDown, initModifierKeys)
	UIDropDownMenu_SetWidth(ModifierKeyDropDown, 90);
	UIDropDownMenu_SetButtonWidth(ModifierKeyDropDown, 90)

	local autoSellLabel = self:CreateFontString(nil, nil, "GameFontNormal")
	autoSellLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 16, -140)
	autoSellLabel:SetText("Automatically sell...")

	local autoSellGreyItems = createCheckBox(self, title, 6, AutoSellGreyItems, "Grey Items", "Automatically sells all grey/junk items.")
	autoSellGreyItems:SetScript("PostClick", function(self, button, down)
		AutoSellGreyItems = self:GetChecked();
	end)

	local autoSellWhiteItems = createCheckBox(self, title, 7, AutoSellWhiteItems, "White Items", "Automatically sells all white/common items.")
	autoSellWhiteItems:SetScript("PostClick", function(self, button, down)
		AutoSellWhiteItems = self:GetChecked();
	end)

	local autoSellGreenItems = createCheckBox(self, title, 8, AutoSellGreenItems, "Green Items", "Automatically sells all green/uncommon items.")
	autoSellGreenItems:SetScript("PostClick", function(self, button, down)
		AutoSellGreenItems = self:GetChecked();
	end)

	self:refresh()
end

InterfaceOptions_AddCategory(frame)

-- Handling Peddler's options.
SLASH_PEDDLER_COMMAND1 = '/peddler'
SlashCmdList['PEDDLER_COMMAND'] = function(command)
	InterfaceOptionsFrame_OpenToCategory('Peddler')
end