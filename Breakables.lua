Breakables = LibStub("AceAddon-3.0"):NewAddon("Breakables", "AceConsole-3.0", "AceEvent-3.0")
local babbleInv = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()

local MillingId = 51005
local MillingItemSubType = babbleInv["Herb"]
local CanMill = false

local ProspectingId = 31252
local ProspectingItemSubType = babbleInv["Metal & Stone"]
local CanProspect = false

local DisenchantId = 13262
local CanDisenchant = false

local IDX_LINK = 1
local IDX_COUNT = 2
local IDX_TYPE = 3
local IDX_TEXTURE = 4
local IDX_BAG = 5
local IDX_SLOT = 6

function Breakables:OnInitialize()
	self.defaults = {
		profile = {
			buttonFrameLeft = 100,
			buttonFrameTop = -100,
		}
	}
	self.db = LibStub("AceDB-3.0"):New("BreakablesDB", self.defaults)

	self:RegisterChatCommand("breakables", "OnSlashCommand")
	self:RegisterChatCommand("brk", "OnSlashCommand")

	-- would have used ITEM_PUSH here, but that seems to fire after looting and before the bag actually gets the item
	-- another alternative is to parse the chat msg, but that seems lame...however, that should only fire once as opposed to BAG_UPDATE's potential double-fire
	self:RegisterEvent("BAG_UPDATE", "OnItemReceived")
end

function Breakables:OnEnable()
	CanMill = IsUsableSpell(GetSpellInfo(MillingId))
	CanProspect = IsUsableSpell(GetSpellInfo(ProspectingId))
	CanDisenchant = IsUsableSpell(GetSpellInfo(DisenchantId))

	if CanMill or CanProspect or CanDisenchant then
		self:CreateButtonFrame()
	end
end

function Breakables:OnDisable()

end

function Breakables:OnSlashCommand(input)
	self:FindBreakables()
end

function Breakables:OnItemReceived(bag)
	self:FindBreakables()
end

function Breakables:CreateButtonFrame()
	if not self.buttonFrame then
		self.buttonFrame = CreateFrame("Button", "BreakablesButtonFrame1", UIParent, "SecureActionButtonTemplate")
	end
	self.buttonFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.db.profile.buttonFrameLeft, self.db.profile.buttonFrameTop)

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

		self.buttonFrame:SetAttribute("type1", "spell")
		self.buttonFrame:SetAttribute("spell1", GetSpellInfo(MillingId))

		local _,_,texture = GetSpellInfo((CanMill and MillingId) or (CanProspect and ProspectingId) or DisenchantingId)
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
	self.db.profile.buttonFrameLeft = xOff
	self.db.profile.buttonFrameTop = yOff
end

function Breakables:FindBreakables()
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

	for i=1,#foundBreakables do
		if foundBreakables[i][IDX_COUNT] >= 5 then
			if not self.herbs then
				self.herbs = {}
			end

			numBreakableStacks = numBreakableStacks + 1

			if not self.herbs[numBreakableStacks] then
				self.herbs[numBreakableStacks] = CreateFrame("Button", "BreakablesButtonStackFrame"..numBreakableStacks, self.buttonFrame, "SecureActionButtonTemplate")
			end
			local btn = self.herbs[numBreakableStacks]
			btn:SetPoint("LEFT", numBreakableStacks == 1 and self.buttonFrame or self.herbs[numBreakableStacks - 1], "RIGHT")
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
			btn.text:SetText(foundBreakables[i][IDX_COUNT].." ("..(floor(foundBreakables[i][IDX_COUNT]/5))..")")

			btn:SetScript("OnEnter", function() self:OnEnterBreakableButton(foundBreakables[i]) end)
			btn:SetScript("OnLeave", function() self:OnLeaveBreakableButton(foundBreakables[i]) end)

			if not btn.icon then
				btn.icon = btn:CreateTexture(nil, "BACKGROUND")
			end
			btn.icon:SetTexture(foundBreakables[i][IDX_TEXTURE])
			btn.icon:SetAllPoints(btn)
		end
	end

	if self.herbs and numBreakableStacks < #self.herbs then
		for i=numBreakableStacks+1,#self.herbs do
			self.herbs[i].icon:SetTexture(nil)
			self.herbs[i].text:SetText()
			self.herbs[i]:EnableMouse(false)
		end
	end

	if numBreakableStacks == 0 then
		self.buttonFrame:Hide()
	else
		self.buttonFrame:Show()
	end
end

function Breakables:OnEnterBreakableButton(breakable)
	GameTooltip:SetOwner(this, "ANCHOR_PRESERVE")
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
	local texture, itemCount, locked, quality, readable = GetContainerItemInfo(bagId, slotId)
	if texture then
		local itemLink = GetContainerItemLink(bagId, slotId)


		local _, _, _, _, _, itemType, itemSubType, _, _, itemTexture = GetItemInfo(itemLink)

		if (CanMill and itemSubType == MillingItemSubType)
			or (CanProspect and itemSubType == ProspectingItemSubType) then
			return {itemLink, itemCount, itemSubType, itemTexture, bagId, slotId}
		end
	end

	return nil
end

function Breakables:MergeBreakables(foundBreakable, breakableList)
	for n=1,#breakableList do
		local existingLink, existingCount, existingType = breakableList[n]
		local itemLink, itemCount, itemType = foundBreakable

		if foundBreakable[IDX_LINK] == breakableList[n][IDX_LINK] then
			breakableList[n][IDX_COUNT] = breakableList[n][IDX_COUNT] + foundBreakable[IDX_COUNT]
			return true
		end
	end

	return false
end
