TransmogDE = TransmogDE or {}
TransmogDE.ItemBodyLocation = {}
TransmogDE.ItemTag = {}
TransmogDE.BodyLocations = {}

local function updateTransmogBodyLocations()
	TransmogDE.ItemBodyLocation = {
		TransmogLocation = ItemBodyLocation.get(ResourceLocation.of("TransmogDE:Transmog_Location")),
		--ItemBodyLocation.register("TransmogDE:TransmogLocation"),
		Hide_Everything = ItemBodyLocation.get(ResourceLocation.of("TransmogDE:Hide_Everything_Location")),
		--ItemBodyLocation.register("TransmogDE:Hide_Everything"),
	}
	TransmogDE.ItemTag = {
		Hide_Everything = ItemTag.get(ResourceLocation.of("TransmogDE:Hide_Everything")),
		-- ItemTag.register("TransmogDE:Hide_Everything"),
	}
	local locTransmog = TransmogDE.ItemBodyLocation.TransmogLocation
	local locHide = TransmogDE.ItemBodyLocation.Hide_Everything

	local group = BodyLocations.getGroup("Human")
	TransmogDE.BodyLocations = {
		TransmogLocation = group:getOrCreateLocation(locTransmog),
		Hide_Everything = group:getOrCreateLocation(locHide),
	}
	group:setMultiItem(locTransmog, true)
	local locations = group:getAllLocations();
	local locationsSize = locations:size() - 1

	for i = 0, locationsSize do
		local bodyLocationId = locations:get(i):getId()
		TmogPrint("Trying to Hide: " .. tostring(bodyLocationId) .. " with: " .. tostring(locHide))
		if TransmogDE.isTransmoggableBodylocation(tostring(bodyLocationId)) then
			group:setHideModel(locHide, bodyLocationId)
		end
	end
end

Events.OnGameBoot.Add(updateTransmogBodyLocations)
