local L = LibStub("AceLocale-3.0"):GetLocale("Breakables", false)
Breakables = LibStub("AceAddon-3.0"):NewAddon("Breakables", "AceConsole-3.0", "AceEvent-3.0")
local babbleInv = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()

local MillingId = 51005
local MillingItemSubType = babbleInv["Herb"]
local MillingItemSecondarySubType = babbleInv["Other"]
local CanMill = false

local ProspectingId = 31252
local ProspectingItemSubType = babbleInv["Metal & Stone"]
local CanProspect = false

local DisenchantId = 13262
local DisenchantTypes = {babbleInv["Armor"], babbleInv["Weapon"]}
local CanDisenchant = false

-- item rarity must meet or surpass this to be considered for disenchantability (is that a word?)
local RARITY_UNCOMMON = 2
local RARITY_HEIRLOOM = 7

local IDX_LINK = 1
local IDX_COUNT = 2
local IDX_TYPE = 3
local IDX_TEXTURE = 4
local IDX_BAG = 5
local IDX_SLOT = 6
local IDX_SUBTYPE = 7
local IDX_LEVEL = 8
local IDX_BREAKABLETYPE = 9
local IDX_SOULBOUND = 10
local IDX_NAME = 11

local BREAKABLE_HERB = 1
local BREAKABLE_ORE = 2
local BREAKABLE_DE = 3

local BagUpdateCheckDelay = 1.5
local nextCheck = {}
for i=0,NUM_BAG_SLOTS do
	nextCheck[i] = -1
end

local buttonSize = 28

local _G = _G

local validGrowDirections = {L["Left"], L["Right"], L["Up"], L["Down"]}

-- can be 1 or 2
local numEligibleProfessions = 0

Breakables.optionsFrame = {}
Breakables.justClicked = false

function Breakables:OnInitialize()
	self.defaults = {
		profile = {
			buttonFrameLeft = {100, 100},
			buttonFrameTop = {700, 650},
			hideIfNoBreakables = true,
			maxBreakablesToShow = 5,
			showSoulbound = false,
			hideEqManagerItems = true,
			hide = false,
			hideInCombat = false,
			buttonScale = 1,
			fontSize = 7,
			growDirection = 2,
		}
	}
	self.db = LibStub("AceDB-3.0"):New("BreakablesDB", self.defaults, true)
	self.settings = self.db.profile

	self:RegisterChatCommand("brk", "OnSlashCommand")

	if type(self.settings.buttonFrameLeft) ~= "table" then
		local old = self.settings.buttonFrameLeft
		self.settings.buttonFrameLeft = {}
		self.settings.buttonFrameLeft[1] = old
		self.settings.buttonFrameLeft[2] = self.defaults.profile.buttonFrameLeft[2]
	end
	if type(self.settings.buttonFrameTop) ~= "table" then
		local old = self.settings.buttonFrameTop
		self.settings.buttonFrameTop = {}
		self.settings.buttonFrameTop[1] = old
		self.settings.buttonFrameTop[2] = self.defaults.profile.buttonFrameTop[2]
	end

	self:InitLDB()
end

function Breakables:InitLDB()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)

	if (LDB) then
		local ldbButton = LDB:NewDataObject("Breakables", {
			type = "launcher",
			text = L["Breakables"],
			icon = "Interface\\Icons\\ability_warrior_sunder",
			OnClick = function(button, msg)
				self:OnSlashCommand()
			end,
		})

		if ldbButton then
			function ldbButton:OnTooltipShow()
				self:AddLine(L["Breakables"] .. " @project-version@")
				self:AddLine(L["Click to open Breakables options."], 1, 1, 1)
			end
		end
	end
end

function Breakables:OnEnable()
	CanMill = IsUsableSpell(GetSpellInfo(MillingId))
	CanProspect = IsUsableSpell(GetSpellInfo(ProspectingId))
	CanDisenchant = IsUsableSpell(GetSpellInfo(DisenchantId))

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Breakables", self:GetOptions(), "breakables")
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Breakables")

	self:RegisterEvents()

	if CanMill or CanProspect or CanDisenchant then
		if CanMill then
			numEligibleProfessions = numEligibleProfessions + 1
		end
		if CanProspect then
			numEligibleProfessions = numEligibleProfessions + 1
		end
		if CanDisenchant then
			numEligibleProfessions = numEligibleProfessions + 1
		end

		self:CreateButtonFrame()
		if self.settings.hide then
			self:ToggleButtonFrameVisibility(false)
		else
			self:FindBreakables()
		end
		self.frame:SetScript("OnUpdate", function() self:CheckShouldFindBreakables() end)
	else
		self:UnregisterAllEvents()
	end
end

function Breakables:ToggleButtonFrameVisibility(show)
	for i=1,numEligibleProfessions do
		if self.buttonFrame[i] then
			if show == nil then
				show = not self.buttonFrame[i]:IsVisible()
			end

			if not show then
				self.buttonFrame[i]:Hide()
			else
				self.buttonFrame[i]:Show()
			end
		end
	end
end

function Breakables:RegisterEvents()
	-- would have used ITEM_PUSH here, but that seems to fire after looting and before the bag actually gets the item
	-- another alternative is to parse the chat msg, but that seems lame...however, that should only fire once as opposed to BAG_UPDATE's potential double-fire
	self:RegisterEvent("BAG_UPDATE", "OnItemReceived")

	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

	if CanDisenchant then
		self:RegisterEvent("TRADE_SKILL_UPDATE", "OnTradeSkillUpdate")
	end
end

function Breakables:OnDisable()
	self:UnregisterAllEvents()
	self.frame:SetScript("OnUpdate", nil)
end

function Breakables:OnSlashCommand(input)
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function Breakables:OnItemReceived(event, bag)
	if self.justClicked then
		self:FindBreakables()
		self.justClicked = false
	elseif not bag or bag >= 0 then
		nextCheck[bag] = GetTime() + BagUpdateCheckDelay
	end
end

function Breakables:CheckShouldFindBreakables()
	local latestTime = -1
	for i=0,#nextCheck do
		if nextCheck[i] and nextCheck[i] > latestTime then
			latestTime = nextCheck[i]
		end
	end

	if latestTime > 0 and latestTime <= GetTime() then
		self:FindBreakables()
		for i=0,#nextCheck do
			nextCheck[i] = -1
		end
	end
end

function Breakables:OnEnterCombat()
	self.bCombat = true
	if self.settings.hideInCombat then
		self:ToggleButtonFrameVisibility(false)
	end
end

function Breakables:OnLeaveCombat()
	self.bCombat = false

	if self.bPendingUpdate or self.settings.hideInCombat then
		self.bPendingUpdate = false
		self:FindBreakables()
	end
end

function Breakables:OnTradeSkillUpdate()
	self:GetEnchantingLevel()
end

function Breakables:GetEnchantingLevel()
	local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(1)

	if skillName == "Enchant" then
		local _, rank, maxRank = GetTradeSkillLine()
		self.settings.EnchantingLevel = rank
	end
end

function Breakables:GetOptions()
	local opts = {
		name = L["Breakables"],
		handler = Breakables,
		type = "group",
		args = {
			intro = {
				type = "description",
				fontSize = "small",
				name = L["Welcome"],
				order = 0,
			},
			hideAlways = {
				type = "toggle",
				name = L["Hide bar"],
				desc = L["This will completely hide the breakables bar whether you have anything to break down or not. Note that you can toggle this in a macro using the /breakables command as well."],
				get = function(info)
					return self.settings.hide
				end,
				set = function(info, v)
					self.settings.hide = v
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78maxBreakables|r to " .. tostring(self.settings.hide))
					end
					self:ToggleButtonFrameVisibility(not v)
					if not v then
						self:FindBreakables()
					end
				end,
				order = 1
			},
			hideNoBreakables = {
				type = "toggle",
				name = L["Hide if no breakables"],
				desc = L["Whether or not to hide the action bar if no breakables are present in your bags"],
				get = function(info)
					return self.settings.hideIfNoBreakables
				end,
				set = function(info, v)
					self.settings.hideIfNoBreakables = v
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78hideIfNoBreakables|r to " .. tostring(self.settings.hideIfNoBreakables))
					end
					self:FindBreakables()
				end,
				order = 2,
			},
			hideInCombat = {
				type = "toggle",
				name = L["Hide during combat"],
				desc = L["Whether or not to hide the breakables bar when you enter combat and show it again when leaving combat."],
				get = function(info)
					return self.settings.hideInCombat
				end,
				set = function(info, v)
					self.settings.hideInCombat = v
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78hideInCombat|r to " .. tostring(self.settings.hideInCombat))
					end
				end,
				order = 3,
			},
			maxBreakables = {
				type = 'range',
				name = L["Max number to display"],
				desc = L["How many breakable buttons to display next to the profession button at maximum"],
				min = 1,
				max = 50,
				step = 1,
				get = function(info)
					return self.settings.maxBreakablesToShow
				end,
				set = function(info, v)
					self.settings.maxBreakablesToShow = v
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78maxBreakables|r to " .. tostring(self.settings.maxBreakablesToShow))
					end
					self:FindBreakables()
				end,
				order = 4,
			},
			buttonScale = {
				type = 'range',
				name = L["Button scale"],
				desc = L["This will scale the size of each button up or down."],
				min = 0.1,
				max = 2,
				step = 0.01,
				get = function(info)
					return self.settings.buttonScale
				end,
				set = function(info, v)
					self.settings.buttonScale = v
					Breakables:ApplyScale()
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78buttonScale|r to " .. tostring(self.settings.buttonScale))
					end
				end,
				order = 5,
			},
			fontSize = {
				type = 'range',
				name = L["Font size"],
				desc = L["This sets the size of the text that shows how many items you have to break."],
				min = 4,
				max = 90,
				step = 1,
				get = function(info)
					return self.settings.fontSize
				end,
				set = function(info, v)
					self.settings.fontSize = v
					Breakables:ApplyScale()
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78fontSize|r to " .. tostring(self.settings.fontSize))
					end
				end,
				order = 6,
			},
			growDirection = {
				type = 'select',
				name = L["Button grow direction"],
				desc = L["This controls which direction the breakable buttons grow toward."],
				values = validGrowDirections,
				get = function()
					return self.settings.growDirection
				end,
				set = function(info, v)
					self.settings.growDirection = v
					self:FindBreakables()
				end,
				order = 7,
			},
		},
	}

	if CanDisenchant then
		opts.args.showSoulbound = {
			type = "toggle",
			name = L["Show soulbound items"],
			desc = L["Whether or not to display soulbound items as breakables."],
			get = function(info)
				return self.settings.showSoulbound
			end,
			set = function(info, v)
				self.settings.showSoulbound = v
				if info.uiType == "cmd" then
					print("|cff33ff99Breakables|r: set |cffffff78showSoulbound|r to " .. tostring(self.settings.showSoulbound))
				end
				self:FindBreakables()
			end,
			order = 20,
		}
		opts.args.hideEqManagerItems = {
			type = "toggle",
			name = L["Hide Eq. Mgr items"],
			desc = L["Whether or not to hide items that are part of an equipment set in the game's equipment manager."],
			get = function(info)
				return self.settings.hideEqManagerItems
			end,
			set = function(info, v)
				self.settings.hideEqManagerItems = v
				if info.uiType == "cmd" then
					print("|cff33ff99Breakables|r: set |cffffff78hideEqManagerItems|r to " .. tostring(self.settings.hideEqManagerItems))
				end
				self:FindBreakables()
			end,
			hidden = function()
				return not self.settings.showSoulbound
			end,
			order = 21,
		}
	end

	return opts
end

function Breakables:CreateButtonFrame()
	if not self.frame then
		self.frame = CreateFrame("Frame")
	end
	if not self.buttonFrame then
		self.buttonFrame = {}
	end

	for i=1,numEligibleProfessions do
		if not self.buttonFrame[i] then
			self.buttonFrame[i] = CreateFrame("Button", "BreakablesButtonFrame1", self.frame, "SecureActionButtonTemplate")
		end
		self.buttonFrame[i]:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.settings.buttonFrameLeft[i], self.settings.buttonFrameTop[i])

		if CanMill and (i == 1 or self.buttonFrame[1].type ~= BREAKABLE_HERB) then
			self.buttonFrame[i].type = BREAKABLE_HERB
		elseif CanDisenchant and (i == 1 or self.buttonFrame[1].type ~= BREAKABLE_DE) then
			self.buttonFrame[i].type = BREAKABLE_DE
		elseif CanProspect and (i == 1 or self.buttonFrame[1].type ~= BREAKABLE_ORE) then
			self.buttonFrame[i].type = BREAKABLE_ORE
		end

		if not self.buttonFrame[i].icon then
			self.buttonFrame[i].icon = self.buttonFrame[i]:CreateTexture(nil, "BACKGROUND")
		end
		if self.buttonFrame[i].type then
			self.buttonFrame[i]:SetWidth(buttonSize * self.settings.buttonScale)
			self.buttonFrame[i]:SetHeight(buttonSize * self.settings.buttonScale)

			self.buttonFrame[i]:EnableMouse(true)
			self.buttonFrame[i]:RegisterForClicks("LeftButtonUp")

			self.buttonFrame[i]:SetMovable(true)
			self.buttonFrame[i]:RegisterForDrag("LeftButton")
			self.buttonFrame[i]:SetScript("OnMouseDown", function(frame) self:OnMouseDown(frame) end)
			self.buttonFrame[i]:SetScript("OnMouseUp", function(frame) self:OnMouseUp(frame) end)
			self.buttonFrame[i]:SetClampedToScreen(true)

			local spellName, _, texture = GetSpellInfo((self.buttonFrame[i].type == BREAKABLE_HERB and MillingId) or (self.buttonFrame[i].type == BREAKABLE_ORE and ProspectingId) or DisenchantId)

			self.buttonFrame[i]:SetAttribute("type1", "spell")
			self.buttonFrame[i]:SetAttribute("spell1", spellName)

			self.buttonFrame[i].icon:SetTexture(texture)
			self.buttonFrame[i].icon:SetAllPoints(self.buttonFrame[i])
		else
			self.buttonFrame[i]:SetTexture(nil)
		end
	end
end

function Breakables:ApplyScale()
	if not self.buttonFrame then
		return
	end

	for i=1,numEligibleProfessions do
		-- yes, setscale exists...but it was scaling buttonFrame and breakableButtons differently for some reason. this works better.
		self.buttonFrame[i]:SetWidth(buttonSize * self.settings.buttonScale)
		self.buttonFrame[i]:SetHeight(buttonSize * self.settings.buttonScale)

		if self.breakableButtons[i] then
			for j=1,#self.breakableButtons[i] do
				self.breakableButtons[i][j]:SetWidth(buttonSize * self.settings.buttonScale)
				self.breakableButtons[i][j]:SetHeight(buttonSize * self.settings.buttonScale)
				self.breakableButtons[i][j].text:SetFont(NumberFont_Outline_Med:GetFont(), self.settings.fontSize, "OUTLINE")
			end
		end
	end
end

function Breakables:OnMouseDown(frame)
	if IsShiftKeyDown() then
		frame:StartMoving()
	end
end

function Breakables:OnMouseUp(frame)
	frame:StopMovingOrSizing()

	local frameNum = 1
	for i=1,numEligibleProfessions do
		if self.buttonFrame[i] == frame then
			frameNum = i
			break
		end
	end

	self.settings.buttonFrameLeft[frameNum] = frame:GetLeft()
	self.settings.buttonFrameTop[frameNum] = frame:GetTop()
end

function Breakables:FindBreakables(bag)
	if self.settings.hide then
		return
	end

	if self.bCombat then
		self.bPendingUpdate = true
		return
	end

	local foundBreakables = {}
	local i=1
	local numBreakableStacks = {}

	for bagId=0,NUM_BAG_SLOTS do
		-- this is where i tried to throttle updates...can't just yet since the full breakables list is rebuilt every time this function is called
		-- consider ways of caching off the last-known state of all breakables
		--if bag == nil or bag == bagId then
			local found = self:FindBreakablesInBag(bagId)
			for n=1,#found do
				local addedToExisting = self:MergeBreakables(found[n], foundBreakables)

				if not addedToExisting then
					foundBreakables[i] = found[n]
					i = i + 1
				end
			end
		--end
	end

	self:SortBreakables(foundBreakables)

	if not self.breakableButtons then
		self.breakableButtons = {}
	end

	for i=1,#foundBreakables do
		for j=1,numEligibleProfessions do
			if not self.breakableButtons[j] then
				self.breakableButtons[j] = {}
			end

			if not numBreakableStacks[j] then
				numBreakableStacks[j] = 0
			end

			if foundBreakables[i][IDX_BREAKABLETYPE] == self.buttonFrame[j].type and numBreakableStacks[j] < self.settings.maxBreakablesToShow then
				local isDisenchantable = self:BreakableIsDisenchantable(foundBreakables[i][IDX_TYPE], foundBreakables[i][IDX_LEVEL])
				if (CanDisenchant and isDisenchantable) or foundBreakables[i][IDX_COUNT] >= 5 then
					numBreakableStacks[j] = numBreakableStacks[j] + 1

					local btn = self.breakableButtons[j][numBreakableStacks[j]]
					if not self.breakableButtons[j][numBreakableStacks[j]] then
						self.breakableButtons[j][numBreakableStacks[j]] = CreateFrame("Button", nil, self.buttonFrame[j], "SecureActionButtonTemplate")

						btn = self.breakableButtons[j][numBreakableStacks[j]]

						btn:SetWidth(buttonSize * self.settings.buttonScale)
						btn:SetHeight(buttonSize * self.settings.buttonScale)
						btn:EnableMouse(true)
						btn:RegisterForClicks("AnyUp")

						btn:SetAttribute("type", "spell")

						if not btn.text then
							btn.text = btn:CreateFontString()
							btn.text:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
						end
						btn.text:SetFont(NumberFont_Outline_Med:GetFont(), self.settings.fontSize, "OUTLINE")

						if not btn.icon then
							btn.icon = btn:CreateTexture(nil, "BACKGROUND")
						end
						btn.icon:SetAllPoints(btn)
					end

					local attachFrom = "LEFT"
					local attachTo = "RIGHT"
					if self.settings.growDirection then
						if self.settings.growDirection == 1 then -- left
							attachFrom = "RIGHT"
							attachTo = "LEFT"
						--elseif self.settings.growDirection == 2 then -- right
						elseif self.settings.growDirection == 3 then -- up
							attachFrom = "BOTTOM"
							attachTo = "TOP"
						elseif self.settings.growDirection == 4 then -- down
							attachFrom = "TOP"
							attachTo = "BOTTOM"
						end
					end

					btn:ClearAllPoints()
					btn:SetPoint(attachFrom, numBreakableStacks[j] == 1 and self.buttonFrame[j] or self.breakableButtons[j][numBreakableStacks[j] - 1], attachTo)

					if not isDisenchantable then
						btn.text:SetText(foundBreakables[i][IDX_COUNT].." ("..(floor(foundBreakables[i][IDX_COUNT]/5))..")")
					end

					local BreakableAbilityName = GetSpellInfo((foundBreakables[i][IDX_BREAKABLETYPE] == BREAKABLE_HERB and MillingId) or (foundBreakables[i][IDX_BREAKABLETYPE] == BREAKABLE_ORE and ProspectingId) or DisenchantId)
					btn:SetAttribute("spell", BreakableAbilityName)
					btn:SetAttribute("target-item", foundBreakables[i][IDX_NAME])
					btn.icon:SetTexture(foundBreakables[i][IDX_TEXTURE])

					btn:SetScript("OnEnter", function(this) self:OnEnterBreakableButton(this, foundBreakables[i]) end)
					btn:SetScript("OnLeave", function() self:OnLeaveBreakableButton(foundBreakables[i]) end)

					btn:Show()
				end
			end
		end
	end

	for i=1,numEligibleProfessions do
		if not numBreakableStacks[i] then
			numBreakableStacks[i] = 0
		end

		if self.breakableButtons[i] and numBreakableStacks[i] < #self.breakableButtons[i] then
			for j=numBreakableStacks[i]+1,#self.breakableButtons[i] do
				self.breakableButtons[i][j]:Hide()
				self.breakableButtons[i][j].icon:SetTexture(nil)
			end
		end

		if self.buttonFrame[i] then
			if numBreakableStacks[i] == 0 and self.settings.hideIfNoBreakables then
				self.buttonFrame[i]:Hide()
			else
				self.buttonFrame[i]:Show()
			end
		end
	end
end

function Breakables:OnEnterBreakableButton(this, breakable)
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetBagItem(breakable[IDX_BAG], breakable[IDX_SLOT])
end

function Breakables:OnLeaveBreakableButton(breakable)
	GameTooltip:Hide()
end

function Breakables:FindBreakablesInBag(bagId)
	local foundBreakables = {}
	local i=1

	if GetBagName(bagId) then
		for slotId=1,GetContainerNumSlots(bagId) do
			local found = self:FindBreakablesInSlot(bagId, slotId)
			if found then
				local addedToExisting = self:MergeBreakables(found, foundBreakables)

				if not addedToExisting then
					foundBreakables[i] = found
					i = i + 1
				end
			end
		end
	end

	return foundBreakables
end

function Breakables:FindBreakablesInSlot(bagId, slotId)
	if not self.myTooltip then
		self.myTooltip = CreateFrame("GameTooltip", "BreakablesTooltip", nil, "GameTooltipTemplate")
		self.myTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end

	local texture, itemCount, locked, quality, readable = GetContainerItemInfo(bagId, slotId)
	if texture then
		local itemLink = GetContainerItemLink(bagId, slotId)
		local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = GetItemInfo(itemLink)

		self.myTooltip:SetBagItem(bagId, slotId)

		if CanDisenchant and itemRarity and itemRarity >= RARITY_UNCOMMON and itemRarity < RARITY_HEIRLOOM
			and self:BreakableIsDisenchantable(itemType, itemLevel) then
			local i = 1
			local soulbound = false
			for i=1,5 do
				if _G["BreakablesTooltipTextLeft"..i]:GetText() == ITEM_SOULBOUND then
					soulbound = true
					break
				end
			end

			local isInEquipmentSet = false
			if self.settings.hideEqManagerItems then
				isInEquipmentSet = self:IsInEquipmentSet(self:GetItemIdFromLink(itemLink))
			end
			local shouldHideThisItem = self.settings.hideEqManagerItems and isInEquipmentSet

			if (not soulbound or self.settings.showSoulbound) and not shouldHideThisItem then
				return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_DE, soulbound, itemName}
			else
				return nil
			end
		end

		local extraInfo = BreakablesTooltipTextLeft2:GetText()

		if CanMill and (itemSubType == MillingItemSubType or itemSubType == MillingItemSecondarySubType) and extraInfo == ITEM_MILLABLE then
			return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_HERB, false, itemName}
		end

		if CanProspect and itemSubType == ProspectingItemSubType and extraInfo == ITEM_PROSPECTABLE then
			return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_ORE, false, itemName}
		end
	end

	return nil
end

function Breakables:IsInEquipmentSet(itemId)
	for setIdx=1, GetNumEquipmentSets() do
		local set = GetEquipmentSetInfo(setIdx)
		local itemArray = GetEquipmentSetItemIDs(set)

		for i=1, EQUIPPED_LAST do
			if itemArray[i] and itemArray[i] == itemId then
				return true
			end
		end
	end

	return false
end

function Breakables:GetItemIdFromLink(itemLink)
	local _, foundItemId = strsplit(":", itemLink)
	return tonumber(foundItemId)
end

function Breakables:MergeBreakables(foundBreakable, breakableList)
	local foundItemId = self:GetItemIdFromLink(foundBreakable[IDX_LINK])
	for n=1,#breakableList do
		local listItemId = self:GetItemIdFromLink(breakableList[n][IDX_LINK])
		if foundItemId == listItemId then
			breakableList[n][IDX_COUNT] = breakableList[n][IDX_COUNT] + foundBreakable[IDX_COUNT]
			return true
		end
	end

	return false
end

function Breakables:SortBreakables(foundBreakables)
	for i=1,#foundBreakables do
		local iId = self:GetItemIdFromLink(foundBreakables[i][IDX_LINK])
		for j=i,#foundBreakables do
			local jId = self:GetItemIdFromLink(foundBreakables[j][IDX_LINK])
			if iId < jId then
				local temp = foundBreakables[i]
				foundBreakables[i] = foundBreakables[j]
				foundBreakables[j] = temp
			end
		end
	end
end

function Breakables:BreakableIsDisenchantable(itemType, itemLevel)
	for i=1,#DisenchantTypes do
		if DisenchantTypes[i] == itemType then
			-- todo: figure out if the iLevel works with our enchanting skill level.
			-- formula (from http://www.wowwiki.com/Disenchanting): 5*ceiling(iLevel,5)-100
			return true
		end
	end

	return false
end
