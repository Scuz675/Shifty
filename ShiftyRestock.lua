-- Shifty Restock
-- Druid reagent restocking on merchant open.
-- Uses fresh bag recounts modeled after Purchases.lua.
-- Prevents duplicate buys by keeping one processed set until MERCHANT_CLOSED.

local SH_RESTOCK_ITEMS = {
	["Maple Seed"] = true,
	["Stranglethorn Seed"] = true,
	["Ashwood Seed"] = true,
	["Hornbeam Seed"] = true,
	["Ironwood Seed"] = true,
	["Wild Berries"] = true,
	["Wild Thornroot"] = true,
}

local SH_RestockState = {
	merchantOpen = false,
	processedThisMerchant = {},
	frame = nil,
}

local function SH_Restock_Debug(msg)
	if type(HSDebugTrace) == "function" and ShiftyDebugEnabled == 1 then
		HSDebugTrace("RESTOCK", tostring(msg))
	end
end

local function SH_Restock_ResetMerchantPass()
	SH_RestockState.processedThisMerchant = {}
end

local function SH_Restock_SearchItem(itemname)
	local count = 0
	local bag, slot
	for bag = 0, 4 do
		if GetContainerNumSlots(bag) > 0 then
			for slot = 0, GetContainerNumSlots(bag) do
				if GetContainerItemLink(bag, slot) then
					local _, _, link = string.find(GetContainerItemLink(bag, slot), "(item:%d+:%d+:%d+:%d+)")
					local item = nil
					if link then
						item = GetItemInfo(link)
					end
					if item == itemname then
						local _, q = GetContainerItemInfo(bag, slot)
						count = count + (q or 0)
					end
				end
			end
		end
	end
	return count
end

local function SH_Restock_BuyNeeded(itemName, targetQty)
	local i
	local target = tonumber(targetQty) or 0
	if target <= 0 then return end

	if SH_RestockState.processedThisMerchant[itemName] == true then
		SH_Restock_Debug("skip duplicate merchant pass " .. tostring(itemName))
		return
	end

	for i = 1, GetMerchantNumItems() do
		local name = GetMerchantItemInfo(i)
		if name == itemName then
			local amountInBag = tonumber(SH_Restock_SearchItem(itemName)) or 0
			local needed = target - amountInBag

			if needed > 0 then
				BuyMerchantItem(i, needed)
				if type(HSPrint) == "function" then
					HSPrint("|cffd08524Shifty |cffffffffBought |cffecd226" .. tostring(needed) .. " |cffffffffof |cffecd226" .. itemName .. " |cffffffff(" .. tostring(amountInBag) .. "/" .. tostring(target) .. ")")
				end
				SH_Restock_Debug(itemName .. " have=" .. amountInBag .. " target=" .. target .. " bought=" .. needed)
			else
				SH_Restock_Debug(itemName .. " already have=" .. amountInBag .. " target=" .. target)
			end

			SH_RestockState.processedThisMerchant[itemName] = true
			return
		end
	end
end

function SH_Restock_OnMerchantShow()
	if type(ShiftyRestockSettings) ~= "table" then return end
	if type(ShiftyRestockSettings.reagents) ~= "table" then return end

	if SH_RestockState.merchantOpen ~= true then
		SH_RestockState.merchantOpen = true
		SH_Restock_ResetMerchantPass()
		SH_Restock_Debug("merchant opened")
	else
		SH_Restock_Debug("duplicate MERCHANT_SHOW ignored for reset")
	end

	local itemName, cfg
	for itemName, cfg in ShiftyRestockSettings.reagents do
		if SH_RESTOCK_ITEMS[itemName] and type(cfg) == "table" and cfg.enabled == 1 and (tonumber(cfg.quantity) or 0) > 0 then
			SH_Restock_BuyNeeded(itemName, cfg.quantity)
		end
	end
end

function SH_Restock_OnMerchantClosed()
	SH_Restock_Debug("merchant closed")
	SH_RestockState.merchantOpen = false
	SH_Restock_ResetMerchantPass()
end

if SH_RestockState.frame == nil then
	SH_RestockState.frame = CreateFrame("Frame", "ShiftyRestockFrame", UIParent)
	SH_RestockState.frame:RegisterEvent("MERCHANT_SHOW")
	SH_RestockState.frame:RegisterEvent("MERCHANT_CLOSED")
	SH_RestockState.frame:SetScript("OnEvent", function()
		if event == "MERCHANT_SHOW" then
			SH_Restock_OnMerchantShow()
		elseif event == "MERCHANT_CLOSED" then
			SH_Restock_OnMerchantClosed()
		end
	end)
end
