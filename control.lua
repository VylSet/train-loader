script.on_init(function()
    storage.train_loaders = storage.train_loaders or {}
    storage.train_stop_gaps = storage.train_stop_gaps or {}
    storage.loader_ui_count = storage.loader_ui_count or 5
end)

script.on_configuration_changed(function()
    storage.train_loaders = storage.train_loaders or {}
    storage.train_stop_gaps = storage.train_stop_gaps or {}
    storage.loader_ui_count = storage.loader_ui_count or 5
end)

local function balance_loaders_in_group(train_stop_id, surface)
    local group_loaders = {}
    local loader_inventories = {}
    local total_items = {}

    -- First part remains the same (gathering loaders and counting items)
    for loader_id, data in pairs(storage.train_loaders) do
        if data.train_stop_id == train_stop_id and not data.loader_state then
            local loader = game.get_entity_by_unit_number(loader_id)
            local loader_inv = loader.get_inventory(defines.inventory.chest)
            if loader and loader.valid then
                local inventory = loader.get_inventory(defines.inventory.chest)
                table.insert(group_loaders, loader)
                loader_inventories[loader] = inventory
                
                -- Count items in this loader
                for item_name, name in pairs(inventory.get_contents()) do
                    total_items[name.name] = (total_items[name.name] or 0) + name.count
                    loader_inv.remove{name = name.name, count = name.count}
                end
            end
        end
    end

    if #group_loaders == 0 then return end
    game.print("going to balance this many items: " .. table_size(total_items) .. " with this many loaders: " .. #group_loaders)

    -- figure out how much each loader should get. so divide the totals in total_items by the number of loaders
    local items_per_loader = {}
    for item_name, count in pairs(total_items) do
        items_per_loader[item_name] = math.floor(count / #group_loaders)
    end

    if items_per_loader then end
    -- fill each loader with the items it should have
    for _, loader in pairs(group_loaders) do
        local inventory = loader_inventories[loader]
        for item_name, count in pairs(items_per_loader) do
            local inserted_count = inventory.insert{name = item_name, count = count}
            if inserted_count > 0 then
                total_items[item_name] = total_items[item_name] - inserted_count
            end
        end
    end
    



end

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

local experimental_balancing = settings.startup["experimental-balancing"].value

script.on_event(defines.events.on_train_changed_state, function(event) -- if a train is stopped
    local train = event.train

    if train.state == defines.train_state.wait_station or train.state == defines.train_state.manual_control_stop then
        for loader_id, data in pairs(storage.train_loaders) do
            local loader = game.get_entity_by_unit_number(loader_id)
            if loader and loader.name == 'train-loader' then
                -- there has to be a more efficient way to do this
                if experimental_balancing then
                    balance_loaders_in_group(data.train_stop_id, loader.surface)
                end
            end
        end
        for loader_id, data in pairs(storage.train_loaders) do
            local loader = game.get_entity_by_unit_number(loader_id)
            if loader and loader.name == 'train-loader' then

                process_loader(loader_id, loader)
            end
        end
    end
end)

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

        frame.add{type = "label",caption = "Loaders: " .. storage.loader_ui_count}.style.font = "heading-1"
        local button_frame = frame.add{
                type = "flow",
                direction = "horizontal",          
        }
        local minus = button_frame.add{type = "button",caption = "-", name = "minus" }
        local plus = button_frame.add{type = "button",caption = "+", name = "plus" }
        minus.style.maximal_width = 52
        plus.style.maximal_width = 52

        frame.add{type = "button", name = "set-all-to-load", caption = "All Load"}
        frame.add{type = "button", name = "set-all-to-unload", caption = "All Unload"}
        for i = 0, storage.loader_ui_count do 
            local button = frame.add{
                type = "button",
                name = "loader-button-" .. i,
                caption = i .. "",
                tags = {train_stop_id = event.entity.unit_number, loader_count = i}
            }
        end

         -- add gap preference buttons
         frame.add{name = "gap-label", type = "label", caption = "Locomotives:"}
         local gap_frame = frame.add{name="gap-frame", type="flow", direction = "horizontal"}
         gap_frame.add{
             type = "button",
             name = "gap-style-compact",
             caption = "0",
             tags = {train_stop_id = event.entity.unit_number, gap_style = "compact"}
         }.style.maximal_width = 33
         gap_frame.add{
             type = "button",
             name = "gap-style-normal",
             caption = "1",
             tags = {train_stop_id = event.entity.unit_number, gap_style = "normal"}
         }.style.maximal_width = 33
         gap_frame.add{
            type = "button",
            name = "gap-style-extra",
            caption = "2",
            tags = {train_stop_id = event.entity.unit_number, gap_style = "extra"}
        }.style.maximal_width = 34

    end

    if event.gui_type == defines.gui_type.entity and event.entity.name == "train-loader" then
        local player = game.players[event.player_index]
        local gui = player.gui.relative
        local loader_id = event.entity.unit_number
        if gui["toggle-frame"] then gui["toggle-frame"].destroy() end -- Clear any existing GUI elements

        -- ensure data exists for this loader
        storage.train_loaders[loader_id] = storage.train_loaders[loader_id] or { loader_state = false }

        -- balance_loaders_in_group(storage.train_loaders[loader_id].train_stop_id, event.entity.surface)


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

    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.gui_type == defines.gui_type.entity then
        local player = game.players[event.player_index]
        local gui = player.gui.relative
        if gui["toggle-frame"] then gui["toggle-frame"].destroy() end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    if event.element.name == "gap-style-normal" or event.element.name == "gap-style-compact" or event.element.name == "gap-style-extra" then
        local train_stop_id = event.element.tags.train_stop_id
        local gap_style = event.element.tags.gap_style
        storage.train_stop_gaps[train_stop_id] = gap_style
    -- handle loader count buttons
    elseif string.match(event.element.name, "loader%-button%-") then
        local player = game.players[event.player_index]
        local train_stop_id = event.element.tags.train_stop_id
        local loader_count = event.element.tags.loader_count
        local surface = player.surface

        for _, entity in pairs(surface.find_entities_filtered{type = "train-stop"}) do
            if entity.unit_number == train_stop_id then
                clear_train_stop_loaders(train_stop_id, surface, entity)
                if loader_count == 0 then 
                    if remote.interfaces["cybersyn"] then 
                        local cyber_combinators = surface.find_entities_filtered{name = "cybersyn-combinator", position = entity.position, radius = 2.2}
                        if cyber_combinators[1] then 
                            local stop_id = remote.call("cybersyn", "get_id_from_stop", entity)
                            if stop_id then 
                                remote.call("cybersyn", "reset_stop_layout", stop_id, nil, true)
                            end
                        end
                    end
                    return -- if loader count is 0, we're done
                end 
                local gap_style = storage.train_stop_gaps[train_stop_id] or "normal"
                local loader_positions = calculate_loader_positions(entity, loader_count, gap_style)
                
                local real_count = 0
                local ghost_count = 0
                
                -- if we couldn't find enough valid positions
                if #loader_positions < loader_count then
                    game.print("Warning: Only found " .. #loader_positions .. " valid positions out of " .. loader_count .. " requested due to missing rails or filled loaders")
                end
                
                for _, pos_data in pairs(loader_positions) do
                    local created_entity
                    if pos_data.can_place_real then
                        created_entity = surface.create_entity{
                            name = "train-loader", 
                            position = pos_data.position, 
                            force = entity.force
                        }
                        real_count = real_count + 1
                        
                        storage.train_loaders[created_entity.unit_number] = {
                            loader_state = false, 
                            train_stop_id = train_stop_id
                        }

                        rendering.draw_sprite{
                            sprite = "custom-silo-sprite",
                            target = created_entity,
                            surface = surface,
                            render_layer = "object"
                        }
                        -- cyber
                        if remote.interfaces["cybersyn"] then 
                            local my_inserter = surface.create_entity{
                                name = "invisible-inserter", 
                                position = {x = pos_data.position.x, y = pos_data.position.y - 2}, 
                                force = entity.force
                            }
                        end
                    else
                        created_entity = surface.create_entity{
                            name = "entity-ghost", 
                            inner_name = "train-loader", 
                            position = pos_data.position, 
                            force = entity.force, 
                            expires = false
                        }
                        ghost_count = ghost_count + 1
                    end
                    
                    surface.create_trivial_smoke{name = "smoke-fast", position = pos_data.position}

                end
                
                -- Provide feedback about placement results
                if ghost_count > 0 then
                    game.print(string.format(
                        "Placed %d loader(s) and %d ghost(s). Clear obstructions to upgrade ghosts to real loaders.", 
                        real_count, 
                        ghost_count
                    ))
                end
                
                if remote.interfaces["cybersyn"] then 
                    local cyber_combinators = surface.find_entities_filtered{
                        name = "cybersyn-combinator", 
                        position = entity.position, 
                        radius = 2.2
                    }
                    if cyber_combinators[1] then
                        local stop_id = remote.call("cybersyn", "get_id_from_stop", entity)
                        if stop_id then 
                            remote.call("cybersyn", "reset_stop_layout", stop_id, nil, true)
                        end
                    end
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
    elseif event.element.name == "plus" or event.element.name == "minus" then
        -- adjust the count, ensuring it doesn't go below 0
        if event.element.name == "plus" then
            storage.loader_ui_count = storage.loader_ui_count + 1
        else
            storage.loader_ui_count = math.max(0, storage.loader_ui_count - 1)
        end

        -- rebuild the UI dynamically
        local player = game.players[event.player_index]
        local gui = player.gui.relative
        local frame = gui["loader-buttons-frame"]
        
        if frame then
            -- update the label
            local label = frame.children[1]
            label.caption = "Loaders: " .. storage.loader_ui_count
            
            -- remove existing loader buttons
            for i = 0, #frame.children do
                local button = frame["loader-button-" .. i]
                if button then button.destroy() end
            end
            if frame["gap-label"] then
                frame["gap-label"].destroy()
            end
            
            -- recreate loader buttons
            for i = 0, storage.loader_ui_count do 
                local button = frame.add{
                    type = "button",
                    name = "loader-button-" .. i,
                    caption = i .. "",
                    tags = {train_stop_id = player.opened.unit_number, loader_count = i}
                }
            end
            frame.add{name = "gap-label", type = "label", caption = "Locomotives:"}
            if frame["gap-frame"] then
                frame["gap-frame"].destroy()
            end
            local gap_frame = frame.add{name="gap-frame", type="flow", direction = "horizontal"}

            gap_frame.add{
                type = "button",
                name = "gap-style-compact",
                caption = "0",
                tags = {train_stop_id = player.opened.unit_number, gap_style = "normal"}
            }.style.maximal_width = 33

            gap_frame.add{
                type = "button",
                name = "gap-style-normal",
                caption = "1",
                tags = {train_stop_id = player.opened.unit_number, gap_style = "normal"}
            }.style.maximal_width = 33

            gap_frame.add{
                type = "button",
                name = "gap-style-extra",
                caption = "2",
                tags = {train_stop_id = player.opened.unit_number, gap_style = "normal"}
            }.style.maximal_width = 33
        end
    end
end)

function calculate_loader_positions(entity, count, gap_style)
    local positions = {}
    local base_spacing = 7  -- distance between each loader/wagon center
    local surface = entity.surface

    local direction_offsets = {
        [defines.direction.north] = {dx = -2, dy = 1},  -- x is fixed offset, y gets spacing
        [defines.direction.east]  = {dx = -1, dy = -2}, -- x gets spacing, y is fixed offset
        [defines.direction.south] = {dx = 2,  dy = -1}, -- x is fixed offset, y gets spacing
        [defines.direction.west]  = {dx = 1,  dy = 2}   -- x gets spacing, y is fixed offset
    }

    for i = 1, count do
        local offset
        if gap_style == "compact" then
            offset = (i > 1 and (i - 1) * base_spacing or 0) + 3
        elseif gap_style == "extra" then
            offset = (base_spacing * 2) + ((i - 1) * base_spacing) + 3  -- Double gap only at start
        else -- "normal" gap style
            offset = (i * base_spacing) + 3
        end
        local dir = direction_offsets[entity.direction]
        local potential_position = {
            x = entity.position.x + (math.abs(dir.dx) == 1 and dir.dx * offset or dir.dx),
            y = entity.position.y + (math.abs(dir.dy) == 1 and dir.dy * offset or dir.dy)
        }

        local area = {
            {potential_position.x - 2, potential_position.y - 2},
            {potential_position.x + 2, potential_position.y + 2}
        }

        local conflicting_entities = surface.find_entities_filtered{area = area}

        local non_rail_conflicts = {} -- filter out straight-rails from the conflicting entities
        local has_non_empty_loader = false
        
        for _, conflicting_entity in pairs(conflicting_entities) do
            if conflicting_entity.name == "train-loader" then
                local inventory = conflicting_entity.get_inventory(defines.inventory.chest)
                if not inventory.is_empty() then
                    has_non_empty_loader = true
                    break
                end
            elseif conflicting_entity.name ~= "straight-rail" and conflicting_entity.type ~= "corpse" and conflicting_entity.type ~= "cargo-wagon" then
                table.insert(non_rail_conflicts, conflicting_entity)
            end
        end

        -- check for rails specifically under the potential position
        local rails = surface.find_entities_filtered{name = "straight-rail", position = potential_position, radius = 1}

        -- Only add the position if there's no non-empty loader
        if not has_non_empty_loader then
            table.insert(positions, {
                position = potential_position,
                can_place_real = #rails > 0 and #non_rail_conflicts == 0
            })
        end
    end

    if entity.direction == defines.direction.south then
        local reversed_loader_positions = {}
        for i = #positions, 1, -1 do
            table.insert(reversed_loader_positions, positions[i])
        end
        positions = reversed_loader_positions
    end

    return positions
end


function clear_train_stop_loaders(train_stop_id, surface, entity)
    if not entity or not entity.valid then return end
    
    local position = entity.position
    local radius = 93  -- not great?

    for loader_id, data in pairs(storage.train_loaders) do
        if data.train_stop_id == train_stop_id then
            local loaders = surface.find_entities_filtered{
                name = "train-loader",
                area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
            }

            for _, loader in pairs(loaders) do
                if loader.valid and loader.unit_number == loader_id then
                    local inventory = loader.get_inventory(defines.inventory.chest)
                    
                    if inventory.is_empty() then
                        local inserters = surface.find_entities_filtered{ -- clean up associated inserters
                            name = "invisible-inserter",
                            area = {
                                {x = loader.position.x - 0.5, y = loader.position.y - 1.5},
                                {x = loader.position.x + 0.5, y = loader.position.y - 0.5}
                            }
                        }
                        for _, inserter in pairs(inserters) do
                            if inserter.valid then
                                inserter.destroy()
                            end
                        end
                        loader.destroy()
                        storage.train_loaders[loader_id] = nil
                        break
                    else
                        game.print("Can't remove 1 or more loaders because they contain items")
                        -- game.print("Cannot remove loader at {" .. loader.position.x .. ", " .. loader.position.y .. "} because it contains items")
                    end
                end
            end
        end
    end

    local ghosts = surface.find_entities_filtered{ -- clean up ghosts
        name = "entity-ghost",
        ghost_name = "train-loader",
        area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
    }

    for _, ghost in pairs(ghosts) do
        if ghost.valid then -- Clean up associated inserter ghosts if they exist
            local inserter_ghosts = surface.find_entities_filtered{
                name = "entity-ghost",
                ghost_name = "invisible-inserter",
                area = {
                    {x = ghost.position.x - 0.5, y = ghost.position.y - 1.5},
                    {x = ghost.position.x + 0.5, y = ghost.position.y - 0.5}
                }
            }
            for _, inserter_ghost in pairs(inserter_ghosts) do
                if inserter_ghost.valid then
                    inserter_ghost.destroy()
                end
            end
            ghost.destroy()
        end
    end
end

local function clean_up_destroyed_train_loader(event)
    local entity = event.entity
    if entity.name == "train-loader" and storage.train_loaders[entity.unit_number] then
        storage.train_loaders[entity.unit_number] = nil
        local inserters = event.entity.surface.find_entities_filtered{
            name = "invisible-inserter",
            area = {
                {x = event.entity.position.x - 0.5, y = event.entity.position.y - 1.5},
                {x = event.entity.position.x + 0.5, y = event.entity.position.y - 0.5}
            }
        }
        for _, inserter in pairs(inserters) do
            if inserter.valid then
                inserter.destroy()
            end
        end
    end
end

script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity}, clean_up_destroyed_train_loader)
