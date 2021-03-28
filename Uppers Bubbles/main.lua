UppersBubbles = UppersBubbles or {}
UppersBubbles.default_settings = {
    opacity = 0.03,
    red = 0.1,
    green = 1,
    blue = 0.5,
    override_inside = true,
    inside_opacity = 0.03,
    inside_red = 1,
    inside_green = 0,
    inside_blue = 0.7,
    override_placement = true,
    placement_opacity = 0.1,
    placement_red = 0.1,
    placement_green = 0.4,
    placement_blue = 1,
    polygons = 4
}

UppersBubbles._mod_path = ModPath
UppersBubbles._options_menu_file = UppersBubbles._mod_path .. "menu/options.json"
UppersBubbles._save_path = SavePath
UppersBubbles._save_file = UppersBubbles._save_path .. "uppers_bubbles.json"

local function FadeColor(color)
    return color * managers.environment_controller._current_flashbang
end

local function deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        setmetatable(copy, deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function UppersBubbles:Setup()
    if not self.settings then
        self:Load()
        self:CreateColors()
    end

    UppersBubbles.SetupHooks()
end

function UppersBubbles:Load()
    self.settings = deep_copy(self.default_settings)
    local file = io.open(self._save_file, "r")
    if file then
        local data = file:read("*a")
        if data then
            local decoded_data = json.decode(data)

            if decoded_data then
                for key, value in pairs(self.settings) do
                    if decoded_data[key] ~= nil then
                        self.settings[key] = decoded_data[key]
                    end
                end
            end
        end
        file:close()
    end
end

function UppersBubbles:Save()
    local file = io.open(self._save_file, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

function UppersBubbles:CreateColors()
    local flash = 0
    if managers.environment_controller and managers.environment_controller._current_flashbang then
        flash = math.min(managers.environment_controller._current_flashbang + 0.1 or 0, 1)
    end

    local opacity_multiplier = 1 - (math.max(flash - 0.6, 0) / 0.4)

    self.color =
        Color(
        UppersBubbles.settings.opacity * opacity_multiplier,
        UppersBubbles.settings.red,
        UppersBubbles.settings.green,
        UppersBubbles.settings.blue
    )

    self.inside_color =
        Color(
        UppersBubbles.settings.inside_opacity * opacity_multiplier,
        UppersBubbles.settings.inside_red,
        UppersBubbles.settings.inside_green,
        UppersBubbles.settings.inside_blue
    )

    self.placement_color =
        Color(
        UppersBubbles.settings.placement_opacity * opacity_multiplier,
        UppersBubbles.settings.placement_red,
        UppersBubbles.settings.placement_green,
        UppersBubbles.settings.placement_blue
    )
end

function UppersBubbles.UpdateButtons()
    for _, item in pairs(MenuHelper:GetMenu("uppers_bubbles")._items_list) do
        if
            item:name() == "uppers_bubbles_inside_opacity" or item:name() == "uppers_bubbles_inside_red" or
                item:name() == "uppers_bubbles_inside_green" or
                item:name() == "uppers_bubbles_inside_blue"
         then
            item:set_enabled(UppersBubbles.settings.override_inside)
        elseif
            item:name() == "uppers_bubbles_placement_opacity" or item:name() == "uppers_bubbles_placement_red" or
                item:name() == "uppers_bubbles_placement_green" or
                item:name() == "uppers_bubbles_placement_blue"
         then
            item:set_enabled(UppersBubbles.settings.override_placement)
        end
    end
end

function UppersBubbles.SetupHooks()
    Hooks:PostHook(
        PlayerDamage,
        "update",
        "UppersBubbles_PlayerDamage_update",
        function(self)
            local position = self._unit:position()
            for i, o in pairs(FirstAidKitBase.List) do
                o._brush = o._brush or Draw:brush(UppersBubbles.color)

                local distance = mvector3.distance(position, o.pos)
                if (distance <= o.min_distance) then
                    o._brush:set_color(
                        UppersBubbles.settings.override_inside and UppersBubbles.inside_color or UppersBubbles.color
                    )
                else
                    o._brush:set_color(UppersBubbles.color)
                end

                o._brush:sphere(o.pos, o.min_distance, UppersBubbles.settings.polygons)
            end
        end
    )

    Hooks:PostHook(
        PlayerEquipment,
        "valid_shape_placement",
        "UppersBubbles_PlayerEquipment_valid_shape_placement",
        function(self, equipment_id, equipment_data)
            if
                equipment_id == "first_aid_kit" and alive(self._dummy_unit) and
                    managers.player:has_category_upgrade("first_aid_kit", "first_aid_kit_auto_recovery")
             then
                self._brush =
                    self._brush or
                    Draw:brush(
                        UppersBubbles.settings.override_placement and UppersBubbles.placement_color or
                            UppersBubbles.color
                    )
                local min_distance = tweak_data.upgrades.values.first_aid_kit.first_aid_kit_auto_recovery[1]
                self._brush:set_color(
                    UppersBubbles.settings.override_placement and UppersBubbles.placement_color or UppersBubbles.color
                )
                self._brush:sphere(self._dummy_unit:position(), min_distance, UppersBubbles.settings.polygons)
            end
        end
    )

    Hooks:PostHook(
        CoreEnvironmentControllerManager,
        "update",
        "UppersBubbles_CoreEnvironmentControllerManager_update",
        function(self, t, dt)
            UppersBubbles:CreateColors()
        end
    )

    Hooks:Add(
        "LocalizationManagerPostInit",
        "UppersBubbles_LocalizationManagerPostInit",
        function(loc)
            loc:load_localization_file(UppersBubbles._mod_path .. "loc/english.txt")
        end
    )

    Hooks:Add(
        "MenuManagerInitialize",
        "UppersBubbles_MenuManagerInitialize",
        function(menu_manager)
            function MenuCallbackHandler:uppers_bubbles_opacity_callback(item)
                UppersBubbles.settings.opacity = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_red_callback(item)
                UppersBubbles.settings.red = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_green_callback(item)
                UppersBubbles.settings.green = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_blue_callback(item)
                UppersBubbles.settings.blue = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_override_inside_callback(item)
                UppersBubbles.settings.override_inside = item:value() == "on"

                UppersBubbles.UpdateButtons()
            end

            function MenuCallbackHandler:uppers_bubbles_inside_opacity_callback(item)
                UppersBubbles.settings.inside_opacity = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_inside_red_callback(item)
                UppersBubbles.settings.inside_red = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_inside_green_callback(item)
                UppersBubbles.settings.inside_green = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_inside_blue_callback(item)
                UppersBubbles.settings.inside_blue = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_override_placement_callback(item)
                UppersBubbles.settings.override_placement = item:value() == "on"

                UppersBubbles.UpdateButtons()
            end

            function MenuCallbackHandler:uppers_bubbles_placement_opacity_callback(item)
                UppersBubbles.settings.placement_opacity = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_placement_red_callback(item)
                UppersBubbles.settings.placement_red = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_placement_green_callback(item)
                UppersBubbles.settings.placement_green = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_placement_blue_callback(item)
                UppersBubbles.settings.placement_blue = round(item:value(), 2)
            end

            function MenuCallbackHandler:uppers_bubbles_back_callback(item)
                UppersBubbles:CreateColors()
                UppersBubbles:Save()
            end

            function MenuCallbackHandler:uppers_bubbles_default_callback(item)
                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_red"] = true},
                    UppersBubbles.default_settings.opacity
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_red"] = true},
                    UppersBubbles.default_settings.red
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_green"] = true},
                    UppersBubbles.default_settings.green
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_blue"] = true},
                    UppersBubbles.default_settings.blue
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_override_inside"] = true},
                    UppersBubbles.default_settings.override_inside
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_inside_opacity"] = true},
                    UppersBubbles.default_settings.inside_opacity
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_inside_red"] = true},
                    UppersBubbles.default_settings.inside_red
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_inside_green"] = true},
                    UppersBubbles.default_settings.inside_green
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_inside_blue"] = true},
                    UppersBubbles.default_settings.inside_blue
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_override_placement"] = true},
                    UppersBubbles.default_settings.override_placement
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_placement_opacity"] = true},
                    UppersBubbles.default_settings.placement_opacity
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_placement_red"] = true},
                    UppersBubbles.default_settings.placement_red
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_placement_green"] = true},
                    UppersBubbles.default_settings.placement_green
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["uppers_bubbles_placement_blue"] = true},
                    UppersBubbles.default_settings.placement_blue
                )

                UppersBubbles.UpdateButtons()
            end

            MenuHelper:LoadFromJsonFile(UppersBubbles._options_menu_file, UppersBubbles, UppersBubbles.settings)
        end
    )
end

UppersBubbles:Setup()
