Breakables = LibStub("AceAddon-3.0"):NewAddon("Breakables", "AceConsole-3.0", "AceEvent-3.0")
local babbleInv = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()

local MillingId = 51005
local MillingItemSubType = babbleInv["Herb"]
local CanMill = false

local ProspectingId = 31252
local ProspectingItemSubType = babbleInv["Metal & Stone"]
local CanProspect = false

local DisenchantId = 13262
local DisenchantTypes = {babbleInv["Armor"], babbleInv["Weapon"]}
local CanDisenchant = false
local EnchantingLevel = 0

local IDX_LINK = 1
local IDX_COUNT = 2
local IDX_TYPE = 3
local IDX_TEXTURE = 4
local IDX_BAG = 5
local IDX_SLOT = 6
local IDX_TYPE = 7

function Breakables:OnInitialize()
	self.defaults = {
		profile = {
			buttonFrameLeft = 100,
			buttonFrameTop = -100,
			hideIfNoBreakables = true,
			maxBreakablesToShow = 5,
		}
	}
	self.db = LibStub("AceDB-3.0"):New("BreakablesDB", self.defaults)
	self.settings = self.db.profile

--	self:RegisterChatCommand("breakables", "OnSlashCommand")
--	self:RegisterChatCommand("brk", "OnSlashCommand")

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Breakables", self:GetOptions(), {"breakables", "brk"})
end

function Breakables:OnEnable()
	CanMill = IsUsableSpell(GetSpellInfo(MillingId))
	CanProspect = IsUsableSpell(GetSpellInfo(ProspectingId))
	CanDisenchant = IsUsableSpell(GetSpellInfo(DisenchantId))

	self:RegisterEvents()

	if CanDisenchant then
		self:GetEnchantingLevel()
	end

	if CanMill or CanProspect or CanDisenchant then
		self:CreateButtonFrame()
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
--[[
function Breakables:OnSlashCommand(input)
	self:FindBreakables()
end
]]
function Breakables:OnItemReceived(bag)
	self:FindBreakables()
end

function Breakables:OnEnterCombat()
	self.bCombat = true
end

function Breakables:OnLeaveCombat()
	self.bCombat = false

	if self.bPendingUpdate then
		self.bPendingUpdate = false
		self:FindBreakables()
	end
end

function Breakables:OnTradeSkillUpdate()
	self:GetEnchantingLevel()
end

-- todo: figure out how to get the enchanting level without the player opening the tradeskill window...
function Breakables:GetEnchantingLevel()
	EnchantingLevel = 0
end

function Breakables:GetOptions()
	return {
		name = "Breakables",
		handler = Breakables,
		type = "group",
		args = {
			hideNoBreakables = {
				type = "toggle",
				name = "Hide bar without breakables",
				desc = "Whether or not to hide the action bar if no breakables are present in your bags",
				get = function()
					return self.settings.hideIfNoBreakables
				end,
				set = function(v)
					self.settings.hideIfNoBreakables = v
					self:FindBreakables()
				end,
			},
--[[			maxBreakables = {
				type = 'range',
				name = 'Max number of breakables to display',
				desc = 'How many breakable buttons to display next to the profession button at maximum',
				min = 1,
				max = 50,
				step = 1,
				get = function()
					return self.settings.maxBreakablesToShow
				end,
				set = function(v)
					self.settings.maxBreakablesToShow = v
					self:FindBreakables()
				end,
			},
]]
		},
	}
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
	if self.bCombat then
		self.bPendingUpdate = true
		return
	end

	local foundBreakables = {}
	local i=1
	local numBreakableStacks = 0

	for bagId=1,NUM_BAG_SLOTS do
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
		if foundBreakables[i][IDX_COUNT] >= 5 then
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
			btn:SetAttribute("type1", "item")
			btn:SetAttribute("bag1", foundBreakables[i][IDX_BAG])
			btn:SetAttribute("slot1", foundBreakables[i][IDX_SLOT])

			if not btn.text then
				btn.text = btn:CreateFontString()
				btn.text:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
			end
			btn.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

			if self:BreakableIsDisenchantable(foundBreakables[i][IDX_TYPE], foundBreakables[i][IDX_LEVEL]) then
				btn.text:SetText(foundBreakables[i][IDX_COUNT])
			else
				btn.text:SetText(foundBreakables[i][IDX_COUNT].." ("..(floor(foundBreakables[i][IDX_COUNT]/5))..")")
			end

			btn:SetScript("OnEnter", function() self:OnEnterBreakableButton(foundBreakables[i]) end)
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

function Breakables:OnEnterBreakableButton(breakable)
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
		local extraInfo = BreakablesTooltipTextLeft2:GetText()

		if (CanMill and itemSubType == MillingItemSubType and extraInfo == ITEM_MILLABLE)
			or (CanProspect and itemSubType == ProspectingItemSubType and extraInfo == ITEM_PROSPECTABLE)
			or (CanDisenchant and itemRarity >= 2 and self:BreakableIsDisenchantable(itemType, itemLevel)) then
			return {itemLink, itemCount, itemSubType, itemTexture, bagId, slotId, itemLevel}
		end
	end

	return nil
end

function Breakables:MergeBreakables(foundBreakable, breakableList)
	local _, foundItemId = strsplit(":", foundBreakable[IDX_LINK])
	for n=1,#breakableList do
		local _, listItemId = strsplit(":", breakableList[n][IDX_LINK])
		if foundItemId == listItemId then
			breakableList[n][IDX_COUNT] = breakableList[n][IDX_COUNT] + foundBreakable[IDX_COUNT]
			return true
		end
	end

	return false
end

function Breakables:SortBreakables(foundBreakables)
	for i=1,#foundBreakables do
		local _, iId = strsplit(":", foundBreakables[i][IDX_LINK])
		for j=i,#foundBreakables do
			local _, jId = strsplit(":", foundBreakables[j][IDX_LINK])
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
