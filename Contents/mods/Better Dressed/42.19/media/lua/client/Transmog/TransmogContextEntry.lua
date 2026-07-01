local iconTexture = getTexture("media/ui/TransmogIcon.png")
local textMenu = getText("IGUI_TransmogDE_Context_Menu")
local textTransmogrify = getText("IGUI_TransmogDE_Context_Transmogrify")
local textHide = getText("IGUI_TransmogDE_Context_Hide")
local textShow = getText("IGUI_TransmogDE_Context_Show")
local textHideAttachedSlots = getText("IGUI_TransmogDE_Context_HideAttachedSlots")
local textShowAttachedSlots = getText("IGUI_TransmogDE_Context_ShowAttachedSlots")
local textHideAttachmentModel = getText("IGUI_TransmogDE_Context_HideAttachmentModel")
local textShowAttachmentModel = getText("IGUI_TransmogDE_Context_ShowAttachmentModel")
local textDefault = getText("IGUI_TransmogDE_Context_Default")
local textRemoveTransmog = getText("IGUI_TransmogDE_Context_RemoveTransmog")
local textColor = getText("IGUI_TransmogDE_Context_Color")
local textTexture = getText("IGUI_TransmogDE_Context_Texture")

local addEditTransmogItemOption = function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local testItem = nil
    local selectedItem = nil
    local clothing = nil
    for _, v in ipairs(items) do
        testItem = v
        if not instanceof(v, "InventoryItem") then
            testItem = v.items[1]
        end
        selectedItem = testItem
        if TransmogDE.isTransmoggable(testItem) then
            clothing = testItem
        end
    end

    if tostring(#items) == "1"
        and selectedItem
        and TransmogDE.isAttachedOrHiddenAttachment
        and TransmogDE.isAttachedOrHiddenAttachment(player, selectedItem) then
        local attachmentOption = nil
        if TransmogDE.isAttachmentModelHidden and TransmogDE.isAttachmentModelHidden(selectedItem) then
            attachmentOption = context:addOption(
                textShowAttachmentModel,
                player,
                TransmogNet.requestShowAttachmentModel,
                selectedItem
            )
        else
            attachmentOption = context:addOption(
                textHideAttachmentModel,
                player,
                TransmogNet.requestHideAttachmentModel,
                selectedItem
            )
        end
        attachmentOption.iconTexture = iconTexture
    end

    if tostring(#items) == "1" and clothing then
        local option = context:addOption(textMenu);
        option.iconTexture = iconTexture
        local menuContext = context:getNew(context);
        context:addSubMenu(option, menuContext);

        menuContext:addOption(
            textTransmogrify,
            player,
            TransmogListViewer.Open,
            clothing
        )

        if not TransmogDE.isClothingHidden(clothing) then
            menuContext:addOption(
                textHide,
                player,
                TransmogNet.requestHide,
                clothing
            )
        else
            menuContext:addOption(
                textShow,
                player,
                TransmogNet.requestShow,
                clothing
            )
        end

        if TransmogDE.hasProvidedAttachmentSlots and TransmogDE.hasProvidedAttachmentSlots(clothing) then
            if not TransmogDE.areAttachedSlotsHidden(clothing) then
                menuContext:addOption(
                    textHideAttachedSlots,
                    player,
                    TransmogNet.requestHideAttachedSlots,
                    clothing
                )
            else
                menuContext:addOption(
                    textShowAttachedSlots,
                    player,
                    TransmogNet.requestShowAttachedSlots,
                    clothing
                )
            end
        end

        local tmogData = TransmogDE.getItemTransmogModData(clothing)
        local transmogTo = tmogData.transmogTo or tmogData.lastTransmogTo
        if transmogTo then
            local tmogScriptItem = ScriptManager.instance:getItem(transmogTo)
            if tmogScriptItem then
                local tmogClothingItemAsset = TransmogDE.getClothingItemAsset(tmogScriptItem)
                if tmogClothingItemAsset:getAllowRandomTint() then
                    menuContext:addOption(
                        textColor,
                        player,
                        ColorPickerModal.Open,
                        clothing
                    );
                end

                local textureChoices = tmogClothingItemAsset:hasModel() and tmogClothingItemAsset:getTextureChoices() or
                                           tmogClothingItemAsset:getBaseTextures()

                -- TmogPrint('clothing', clothing)
                -- TmogPrint('clothing.getClothingItem', clothing:getClothingItem())
                -- TmogPrint('transmogTo', transmogTo)
                -- TmogPrint('tmogClothingItemAsset', tmogClothingItemAsset)
                -- TmogPrint('hasModel()', tmogClothingItemAsset:hasModel())
                -- TmogPrint('getTextureChoices()', tmogClothingItemAsset:getTextureChoices())
                -- TmogPrint('getBaseTextures()', tmogClothingItemAsset:getBaseTextures())
                if textureChoices and (textureChoices:size() > 1) then
                    menuContext:addOption(
                        textTexture,
                        player,
                        TexturePickerModal.Open,
                        clothing,
                        textureChoices
                    );
                end
            end
        end

        if TransmogDE.canRemoveTransmog(clothing) then
            local removeTransmog = menuContext:addOption(
                textRemoveTransmog,
                player,
                TransmogNet.requestRemoveTransmog,
                clothing
            );
            removeTransmog.goodColor = true
        end

        if TransmogDE.canResetTransmog(clothing) then
            local setItemToDefault = menuContext:addOption(
                textDefault,
                player,
                TransmogNet.requestResetDefault,
                clothing
            );
            setItemToDefault.badColor = true
        end
    end

    return context
end

Events.OnFillInventoryObjectContextMenu.Add(addEditTransmogItemOption)
