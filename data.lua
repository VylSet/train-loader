local train_loader_entity = table.deepcopy(data.raw["container"]["steel-chest"])
train_loader_entity.name = "train-loader"
train_loader_entity.minable = {result = "train-loader", mining_time = 1, count = 0}
local stored_size = tonumber(settings.startup["train_loader_inventory_size"].value) or 96
train_loader_entity.inventory_size = stored_size
train_loader_entity.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
train_loader_entity.selection_box = {{-1.85, -1.85}, {1.85, 1.85}}
train_loader_entity.flags = {"get-by-unit-number"}
train_loader_entity.icon_draw_specification = {shift = {0, -3}, scale = 1.4, scale_for_many = 2.4}
train_loader_entity.picture = {
    layers = {
        {
            filename = "__TrainLoader__/graphics/shadow.png",
            priority = "extra-high",
            width = 1, -- I should probably render nothing instead of one pixel?
            height = 1,
            shift = util.by_pixel(0, -128),
        },
        {
            filename = "__TrainLoader__/graphics/shadow.png",
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
        filename = "__TrainLoader__/graphics/loader-silo.png",
        width = 124,  
        height = 384, 
        shift = util.by_pixel(0, -128),
    }
})