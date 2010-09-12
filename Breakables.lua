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

local BREAKABLE_HERB = 1
local BREAKABLE_ORE = 2
local BREAKABLE_DE = 3

local _G = _G

Breakables.optionsFrame = {}

function Breakables:OnInitialize()
	self.defaults = {
		profile = {
			buttonFrameLeft = 100,
			buttonFrameTop = -100,
			hideIfNoBreakables = true,
			maxBreakablesToShow = 5,
			showSoulbound = false,
			hideEqManagerItems = true,
			hide = false,
			hideInCombat = false,
		}
	}
	self.db = LibStub("AceDB-3.0"):New("BreakablesDB", self.defaults)
	self.settings = self.db.profile

	self:RegisterChatCommand("brk", "OnSlashCommand")

	self:InitLDB()
end

function Breakables:InitLDB()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)

	if (LDB) then
		local ldbButton = LDB:NewDataObject("Breakables", {
			type = "launcher",
			text = "Breakables",
			icon = "Interface\\Icons\\ability_warrior_sunder",
			OnClick = function(_, msg)
				self:OnSlashCommand()
			end,
		})
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
		self:CreateButtonFrame()
		if self.settings.hide and self.buttonFrame then
			self.buttonFrame:Hide()
		end
	else
		self:UnregisterAllEvents()
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
end

function Breakables:OnSlashCommand(input)
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function Breakables:OnItemReceived(bag)
	self:FindBreakables()
end

function Breakables:OnEnterCombat()
	self.bCombat = true
	if self.settings.hideInCombat then
		self.buttonFrame:Hide()
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
		name = "Breakables",
		handler = Breakables,
		type = "group",
		args = {
			intro = {
				type = "description",
				fontSize = "small",
				name = [[Thanks for using |cff33ff99Breakables|r! Use |cffffff78/brk|r to open this menu or |cffffff78/breakables|r to access the same options on the command line.

Hold shift and drag the profession button to move the breakables bar around. If you have any feature requests or problems, please email |cff33ff99breakables@parnic.com|r or visit the |cffffff78curse.com|r or |cffffff78wowinterface.com|r page and leave a comment.]],
				order = 0,
			},
			hideAlways = {
				type = "toggle",
				name = "Hide bar",
				desc = "This will completely hide the breakables bar whether you have anything to break down or not. Note that you can toggle this in a macro using the /breakables command as well.",
				get = function(info)
					return self.settings.hide
				end,
				set = function(info, v)
					self.settings.hide = v
					if info.uiType == "cmd" then
						print("|cff33ff99Breakables|r: set |cffffff78maxBreakables|r to " .. tostring(self.settings.hide))
					end
					if v then
						self.buttonFrame:Hide()
					else
						self.buttonFrame:Show()
						self:FindBreakables()
					end
				end,
				order = 1
			},
			hideNoBreakables = {
				type = "toggle",
				name = "Hide if no breakables",
				desc = "Whether or not to hide the action bar if no breakables are present in your bags",
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
				name = "Hide during combat",
				desc = "Whether or not to hide the breakables bar when you enter combat and show it again when leaving combat.",
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
				name = 'Max number to display',
				desc = 'How many breakable buttons to display next to the profession button at maximum',
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
		},
	}

	if CanDisenchant then
		opts.args.showSoulbound = {
			type = "toggle",
			name = "Show soulbound items",
			desc = "Whether or not to display soulbound items as breakables.",
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
			name = "Hide Eq. Mgr items",
			desc = "Whether or not to hide items that are part of an equipment set in the game's equipment manager.",
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
	if not self.buttonFrame then
		self.buttonFrame = CreateFrame("Button", "BreakablesButtonFrame1", UIParent, "SecureActionButtonTemplate")
	end
	self.buttonFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.settings.buttonFrameLeft, self.settings.buttonFrameTop)

	if not self.buttonFrame.icon then
		self.buttonFrame.icon = self.buttonFrame:CreateTexture(nil, "BACKGROUND")
	end
	if CanMill or CanProspect or CanDisenchant then
		self.buttonFrame:SetWidth(40)
		self.buttonFrame:SetHeight(40)

		self.buttonFrame:EnableMouse(true)
		self.buttonFrame:RegisterForClicks("LeftButtonUp")

		self.buttonFrame:SetMovable(true)
		self.buttonFrame:RegisterForDrag("LeftButton")
		self.buttonFrame:SetScript("OnMouseDown", function() self:OnMouseDown() end)
		self.buttonFrame:SetScript("OnMouseUp", function() self:OnMouseUp() end)
		self.buttonFrame:SetClampedToScreen(true)

		local spellName, _, texture = GetSpellInfo((CanMill and MillingId) or (CanProspect and ProspectingId) or DisenchantId)

		self.buttonFrame:SetAttribute("type1", "spell")
		self.buttonFrame:SetAttribute("spell1", spellName)

		self.buttonFrame.icon:SetTexture(texture)
		self.buttonFrame.icon:SetAllPoints(self.buttonFrame)
	else
		self.buttonFrame:SetTexture(nil)
	end
end

function Breakables:OnMouseDown()
	if IsShiftKeyDown() then
		self.buttonFrame:StartMoving()
	end
end

function Breakables:OnMouseUp()
	self.buttonFrame:StopMovingOrSizing()

	local _, _, _, xOff, yOff = self.buttonFrame:GetPoint(1)
	self.settings.buttonFrameLeft = xOff
	self.settings.buttonFrameTop = yOff
end

function Breakables:FindBreakables()
	if self.settings.hide then
		return
	end

	if self.bCombat then
		self.bPendingUpdate = true
		return
	end

	local foundBreakables = {}
	local i=1
	local numBreakableStacks = 0

	for bagId=0,NUM_BAG_SLOTS do
		local found = self:FindBreakablesInBag(bagId)
		for n=1,#found do
			local addedToExisting = self:MergeBreakables(found[n], foundBreakables)

			if not addedToExisting then
				foundBreakables[i] = found[n]
				i = i + 1
			end
		end
	end

	self:SortBreakables(foundBreakables)

	for i=1,#foundBreakables do
		local isDisenchantable = self:BreakableIsDisenchantable(foundBreakables[i][IDX_TYPE], foundBreakables[i][IDX_LEVEL])
		if (CanDisenchant and isDisenchantable) or foundBreakables[i][IDX_COUNT] >= 5 then
			if not self.breakableButtons then
				self.breakableButtons = {}
			end

			numBreakableStacks = numBreakableStacks + 1

			if not self.breakableButtons[numBreakableStacks] then
				self.breakableButtons[numBreakableStacks] = CreateFrame("Button", "BreakablesButtonStackFrame"..numBreakableStacks, self.buttonFrame, "SecureActionButtonTemplate")
			end
			local btn = self.breakableButtons[numBreakableStacks]
			btn:SetPoint("LEFT", numBreakableStacks == 1 and self.buttonFrame or self.breakableButtons[numBreakableStacks - 1], "RIGHT")
			btn:SetWidth(40)
			btn:SetHeight(40)
			btn:EnableMouse(true)
			btn:RegisterForClicks("AnyUp")

			local BreakableAbilityName = GetSpellInfo((foundBreakables[i][IDX_BREAKABLETYPE] == BREAKABLE_HERB and MillingId) or (foundBreakables[i][IDX_BREAKABLETYPE] == BREAKABLE_ORE and ProspectingId) or DisenchantId)
			btn:SetAttribute("type", "macro")
			btn:SetAttribute("macrotext", "/cast "..BreakableAbilityName.."\n/use "..foundBreakables[i][IDX_BAG].." "..foundBreakables[i][IDX_SLOT])

--			btn:SetAttribute("type1", "item")
--			btn:SetAttribute("bag1", foundBreakables[i][IDX_BAG])
--			btn:SetAttribute("slot1", foundBreakables[i][IDX_SLOT])

			if not btn.text then
				btn.text = btn:CreateFontString()
				btn.text:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
			end
			btn.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

			if not isDisenchantable then
				btn.text:SetText(foundBreakables[i][IDX_COUNT].." ("..(floor(foundBreakables[i][IDX_COUNT]/5))..")")
			end

			btn:SetScript("OnEnter", function(this) self:OnEnterBreakableButton(this, foundBreakables[i]) end)
			btn:SetScript("OnLeave", function() self:OnLeaveBreakableButton(foundBreakables[i]) end)

			if not btn.icon then
				btn.icon = btn:CreateTexture(nil, "BACKGROUND")
			end
			btn.icon:SetTexture(foundBreakables[i][IDX_TEXTURE])
			btn.icon:SetAllPoints(btn)

			if numBreakableStacks >= self.settings.maxBreakablesToShow then
				break
			end
		end
	end

	if self.breakableButtons and numBreakableStacks < #self.breakableButtons then
		for i=numBreakableStacks+1,#self.breakableButtons do
			self.breakableButtons[i].icon:SetTexture(nil)
			self.breakableButtons[i].text:SetText()
			self.breakableButtons[i]:EnableMouse(false)
		end
	end

	if self.buttonFrame then
		if numBreakableStacks == 0 and self.settings.hideIfNoBreakables then
			self.buttonFrame:Hide()
		else
			self.buttonFrame:Show()
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
		local _, _, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = GetItemInfo(itemLink)

		self.myTooltip:SetBagItem(bagId, slotId)

		if CanDisenchant and itemRarity and itemRarity >= RARITY_UNCOMMON and self:BreakableIsDisenchantable(itemType, itemLevel) then
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
				return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_DE, soulbound}
			else
				return nil
			end
		end

		local extraInfo = BreakablesTooltipTextLeft2:GetText()

		if CanMill and (itemSubType == MillingItemSubType or itemSubType == MillingItemSecondarySubType) and extraInfo == ITEM_MILLABLE then
			return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_HERB, false}
		end

		if CanProspect and itemSubType == ProspectingItemSubType and extraInfo == ITEM_PROSPECTABLE then
			return {itemLink, itemCount, itemType, itemTexture, bagId, slotId, itemSubType, itemLevel, BREAKABLE_ORE, false}
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
