
minetest.register_node("block_alert:recorder",
{
    description = "Recorder Block",
    tiles = {"block_alert_recorder.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, wood = 1},

    after_place_node  = function(pos, placer)
        local meta = minetest.get_meta(pos)
        meta:mark_as_private("name")
        meta:mark_as_private("log")
        meta:set_string("name", "Recorder")
    end,

    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local pname = (clicker and clicker:get_player_name()) or ""
        if util.check_permission(pos, pname) then
            minetest.show_formspec(
               pname, "block_alert:recorder_log", recorder.get_formspec(pos)
            )
        end
    end
})

minetest.register_craft({
    type = "shaped",
    output = "block_alert:recorder",
    recipe = {
        {"group:wood", "group:wood"     ,"group:wood"},
        {"group:wood", "default:bronze_ingot","group:wood"},
        {"group:wood", "group:wood"     ,"group:wood"}
    }
})

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and minetest.is_player(placer) then
       recorder.handle_block_event(
          pos, newnode.name, placer:get_player_name(), "placed"
       )
    end
    return false
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and minetest.is_player(digger) then
       recorder.handle_block_event(
          pos, oldnode.name, digger:get_player_name(), "broke"
       )
    end
end)

pmutils.register_player_move(function(player, playerHistory)
    util.check_new_player_move(player)
end)
