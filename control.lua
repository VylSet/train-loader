script.on_init(function()
    storage.train_loaders = storage.train_loaders or {}
end)

local function process_loader(loader_id, loader)
    if not loader.valid then
        storage.train_loaders[loader_id] = nil
        return
    end

    local wagon = loader.surface.find_entities_filtered{ -- look for a wagons below loader
        position = loader.position,
        type = "cargo-wagon",
        radius = 1,
        limit = 1
    }[1]

    if wagon and wagon.train.state == defines.train_state.wait_station or 
       (wagon and wagon.train.state == defines.train_state.manual_control_stop) then
        local loader_inventory = loader.get_inventory(defines.inventory.chest)
        local wagon_inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
        
        -- check the checkbox state for this specific loader
        local is_checked = storage.train_loaders[loader_id] and storage.train_loaders[loader_id].loader_state

        if is_checked then
            for _, item in pairs(wagon_inventory.get_contents()) do -- Checkbox is checked: Transfer items from wagon to loader
                local inserted_count = loader_inventory.insert({name = item.name, count = item.count, quality = item.quality})
                if inserted_count > 0 then 
                    wagon_inventory.remove({name = item.name, count = inserted_count, quality = item.quality})
                end
            end
        else
            for _, item in pairs(loader_inventory.get_contents()) do -- Checkbox is unchecked: Transfer items from loader to wagon
                local inserted_count = wagon_inventory.insert({name = item.name, count = item.count, quality = item.quality})
                if inserted_count > 0 then
                    loader_inventory.remove({name = item.name, count = inserted_count, quality = item.quality})
                end
            end
        end
    end
end

script.on_nth_tick(60, function(event) -- this is not terrible on performance because of get_entity_by_unit_number(?)
    for loader_id, data in pairs(storage.train_loaders) do
        local loader = game.get_entity_by_unit_number(loader_id)
        if loader and loader.name == 'train-loader' then
            process_loader(loader_id, loader)
        end
    end
end)

script.on_event(defines.events.on_train_changed_state, function(event) -- if a train is stopped
    local train = event.train

    if train.state == defines.train_state.wait_station or train.state == defines.train_state.manual_control_stop then
        for loader_id, data in pairs(storage.train_loaders) do
            local loader = game.get_entity_by_unit_number(loader_id)
            if loader and loader.name == 'train-loader' then
                process_loader(loader_id, loader)
            end
        end
    end
end)

script.on_event(defines.events.on_gui_opened, function(event)
    if event.gui_type == defines.gui_type.entity and event.entity.name == "train-stop" then
        local player = game.players[event.player_index]
        local gui = player.gui.relative

        if gui["loader-buttons-frame"] then -- clean up existing GUI elements
            gui["loader-buttons-frame"].destroy()
        end

        local frame = gui.add{ -- create a frame to hold loader buttons
            type = "frame",
            name = "loader-buttons-frame",
            direction = "vertical",
            anchor = {
                gui = defines.relative_gui_type.train_stop_gui,
                position = defines.relative_gui_position.left
            }
        }

        frame.add{type = "label",caption = "Loaders:"}

        for i = 0, 4 do 
            local button = frame.add{
                type = "button",
                name = "loader-button-" .. i,
                caption = i .. "",
                tags = {train_stop_id = event.entity.unit_number, loader_count = i}
            }
        end

        frame.add{type = "button", name = "set-all-to-load", caption = "All Load"}
        frame.add{type = "button", name = "set-all-to-unload", caption = "All Unload"}
    end

    if event.gui_type == defines.gui_type.entity and event.entity.name == "train-loader" then
        local player = game.players[event.player_index]
        local gui = player.gui.relative
        local loader_id = event.entity.unit_number

        -- ensure data exists for this loader
        storage.train_loaders[loader_id] = storage.train_loaders[loader_id] or { loader_state = false }

        if gui["toggle-frame"] then gui["toggle-frame"].destroy() end -- Clear any existing GUI elements

        local frame = gui.add{
            type = "frame",
            name = "toggle-frame",
            direction = "vertical",
            anchor = {
                gui = defines.relative_gui_type.container_gui,
                position = defines.relative_gui_position.right
            }
        }

        frame.add{type = "label",caption = "Switch Loader Modes (unchecked is loader)"}
        
        local loader_state = frame.add{
            type = "checkbox",
            name = "loader-state",
            caption = "Check for unloader mode",
            state = storage.train_loaders[loader_id].loader_state,
        }

        -- add checkbox state change event handler
        script.on_event(defines.events.on_gui_checked_state_changed, function(event)
            if event.element.name == "loader-state" then
                local player = game.players[event.player_index]
                local loader_id = player.opened.unit_number

                -- update the state in storage
                if storage.train_loaders[loader_id] then
                    storage.train_loaders[loader_id].loader_state = event.element.state
                end
            end
        end)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- handle loader count buttons
    if string.match(event.element.name, "loader%-button%-") then
        local player = game.players[event.player_index]
        local train_stop_id = event.element.tags.train_stop_id
        local loader_count = event.element.tags.loader_count
        local surface = player.surface

        for _, entity in pairs(surface.find_entities_filtered{type = "train-stop"}) do
            if entity.unit_number == train_stop_id then
                clear_train_stop_loaders(train_stop_id, surface, entity)
                if loader_count == 0 then return end -- if loader count is 0, we're done

                local loader_positions = calculate_loader_positions(entity, loader_count) -- determine new positions

                -- if we couldn't place all requested loaders
                if #loader_positions < loader_count then
                    game.print("Warning: Only able to place " .. #loader_positions .. " loaders out of " .. loader_count .. " requested due to missing rails or space isn't clear")
                end

                for _, pos in pairs(loader_positions) do
                    local loader = surface.create_entity{name = "train-loader", position = pos, force = entity.force}

                    surface.create_trivial_smoke{name = "smoke-fast", position = pos}

                    -- initialize loader data with default checkbox state
                    storage.train_loaders[loader.unit_number] = {loader_state = false, train_stop_id = train_stop_id}

                    rendering.draw_sprite{
                        sprite = "custom-silo-sprite",
                        target = loader,
                        surface = surface,
                        render_layer = "object"
                    }
                end
                break
            end
        end
    
    elseif event.element.name == "set-all-to-unload" then -- handle "Set All to unload" button click
        local player = game.players[event.player_index]
        local train_stop_id = player.opened.unit_number

        for loader_id, data in pairs(storage.train_loaders) do -- set all related loaders to true
            if data.train_stop_id == train_stop_id then
                storage.train_loaders[loader_id].loader_state = true
            end
        end
    elseif event.element.name == "set-all-to-load" then -- handle "Set All to load" button click
        local player = game.players[event.player_index] 
        local train_stop_id = player.opened.unit_number

        for loader_id, data in pairs(storage.train_loaders) do -- set all related loaders to false
            if data.train_stop_id == train_stop_id then
                storage.train_loaders[loader_id].loader_state = false
            end
        end
    end
end)

function calculate_loader_positions(entity, count)
    local positions = {}
    local spacing = 7  -- distance between each loader/wagon center
    local surface = entity.surface

    local direction_offsets = {
        [defines.direction.north] = {dx = -2, dy = 1},  -- x is fixed offset, y gets spacing
        [defines.direction.east]  = {dx = -1, dy = -2}, -- x gets spacing, y is fixed offset
        [defines.direction.south] = {dx = 2,  dy = -1}, -- x is fixed offset, y gets spacing
        [defines.direction.west]  = {dx = 1,  dy = 2}   -- x gets spacing, y is fixed offset
    }

    for i = 1, count do
        local offset = (i * spacing) + 3
        local dir = direction_offsets[entity.direction]
        local potential_position = {
            x = entity.position.x + (math.abs(dir.dx) == 1 and dir.dx * offset or dir.dx),
            y = entity.position.y + (math.abs(dir.dy) == 1 and dir.dy * offset or dir.dy)
        }

        local area = {
            {potential_position.x - 2, potential_position.y - 2},
            {potential_position.x + 2, potential_position.y + 2}
        }

        local conflicting_entities = surface.find_entities_filtered{area = area } --, force = entity.force}

        local non_rail_conflicts = {} -- filter out straight-rails from the conflicting entities
        for _, conflicting_entity in pairs(conflicting_entities) do
            if conflicting_entity.name ~= "straight-rail" then
                table.insert(non_rail_conflicts, conflicting_entity)
            end
        end

        -- check for rails specifically under the potential position
        local rails = surface.find_entities_filtered{name = "straight-rail", position = potential_position, radius = 1  }

        if #rails > 0 and #non_rail_conflicts == 0 then -- only add if no conflicts and rails exist
            table.insert(positions, potential_position)
        end
    end

    if entity.direction == defines.direction.south then -- reverse the order of loaders for south-facing train stops
        local reversed_loader_positions = {}

        for i = #positions, 1, -1 do -- insert elements from the end of loader_positions to the start of reversed_loader_positions
            table.insert(reversed_loader_positions, positions[i])
        end

        positions = reversed_loader_positions -- handle draw_sprite issue for tall entities
    end

    return positions
end


function clear_train_stop_loaders(train_stop_id, surface, entity)
    if not entity or not entity.valid then return end
    
    local position = entity.position
    local radius = 36  -- not great?

    for loader_id, data in pairs(storage.train_loaders) do
        if data.train_stop_id == train_stop_id then
            -- this radius is a bad solution to fixing performance, granted players won't do this often enough for it to need to be better?
            local loaders = surface.find_entities_filtered{
                name = "train-loader",
                area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
            }

            for _, loader in pairs(loaders) do -- look through the found loaders for the one matching our unit_number
                if loader.valid and loader.unit_number == loader_id then
                    local inventory = loader.get_inventory(defines.inventory.chest)

                    
                    if inventory.is_empty() then -- check if inventory is empty before destroying
                        loader.destroy()
                        storage.train_loaders[loader_id] = nil
                        break  -- we found and destroyed the loader, no need to continue searching
                    else
                        game.print("Cannot remove loader at {" .. loader.position.x .. ", " .. loader.position.y .. "} because it contains items")
                    end
                end
            end
        end
    end
end

local function clean_up_destroyed_train_loader(event)
    local entity = event.entity
    if entity.name == "train-loader" and storage.train_loaders[entity.unit_number] then
        storage.train_loaders[entity.unit_number] = nil
    end
end

script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity}, clean_up_destroyed_train_loader)