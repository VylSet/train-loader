local train_loader_entity = table.deepcopy(data.raw["container"]["steel-chest"])
train_loader_entity.name = "train-loader"
train_loader_entity.minable = {result = "train-loader", mining_time = 1, count = 0}
local stored_size = tonumber(settings.startup["train_loader_inventory_size"].value) or 96
train_loader_entity.inventory_size = stored_size
train_loader_entity.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
train_loader_entity.selection_box = {{-1.85, -1.85}, {1.85, 1.85}}
train_loader_entity.flags = {"player-creation", "get-by-unit-number"}
train_loader_entity.icon_draw_specification = {shift = {0, -3}, scale = 1.4, scale_for_many = 2.4}
train_loader_entity.picture = {
    layers = {
        {
            filename = "__train-loader__/graphics/shadow.png",
            priority = "extra-high",
            width = 1, -- I should probably render nothing instead of one pixel?
            height = 1,
            shift = util.by_pixel(0, -128),
        },
        {
            filename = "__train-loader__/graphics/shadow.png",
            priority = "extra-high",
            draw_as_shadow = true,
            width = 384,
            height = 93,
            shift = util.by_pixel(141, 16),
        }
    }
}

data:extend{train_loader_entity}

local train_loader_item = {
    type = "item",
    name = "train-loader",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "storage",
    order = "b[storage]-b[steel-chest]",
    place_result = "train-loader",
    stack_size = 50
}

data:extend{train_loader_item}

data:extend({
    {
        type = "sprite",
        name = "custom-silo-sprite",
        filename = "__train-loader__/graphics/loader-silo.png",
        width = 124,  
        height = 384, 
        shift = util.by_pixel(0, -128),
    }
})

-- I really want to avoid compound entities and there has to be a better way to do this
-- but this only loads for cybersyn so it's not too bad
local invisible_inserter = table.deepcopy(data.raw["inserter"]["fast-inserter"])
invisible_inserter.name = "invisible-inserter"
invisible_inserter.minable = {result = "iron-plate", mining_time = 0.4, count = 0}
invisible_inserter.collision_box = {{-0.15, -0.15}, {0.15, 0.15}}
invisible_inserter.selection_box = {{-0.1, -0.1}, {0.1, 0.1}}
invisible_inserter.hand_base_picture = {
    filename = "__core__/graphics/empty.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 1
}
invisible_inserter.hand_closed_picture = {
    filename = "__core__/graphics/empty.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 1
}
invisible_inserter.hand_open_picture = {
    filename = "__core__/graphics/empty.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 1
}
invisible_inserter.platform_picture = {
    sheet = {
        filename = "__core__/graphics/empty.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 1
    }
}
invisible_inserter.energy_source = {type = "void"}

data:extend{invisible_inserter}
