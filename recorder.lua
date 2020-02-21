
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
        SnitchRegistry.register("block_alert:recorder", pos)
    end,
    after_dig_node = function(pos, placer, itemstack, pointed_thing)
       SnitchRegistry.unregister("block_alert:recorder", pos)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local pname = (clicker and clicker:get_player_name()) or ""
        if util.check_permission(pos, pname) then
            minetest.show_formspec(
               pname, "block_alert:recorder_log", recorder.get_formspec(pos)
            )
        end
    end,
    on_proximity_entered = function(pos, player)
       recorder.handle_player_event(player, pos, "entered")
    end,
    on_proximity_exited = function(pos, player)
       recorder.handle_player_event(player, pos, "exited")
    end,
    on_proximity_join = function(pos, player)
       recorder.handle_player_event(player, pos, "logged in")
    end,
    on_proximity_leave = function(pos, player)
       recorder.handle_player_event(player, pos, "logged out")
    end,
    on_proximity_dig = function(pos, digger, digpos, oldnode)
       recorder.handle_block_event(digger, pos, digpos, oldnode, "broke")
    end,
    on_proximity_place = function(pos, placer, placepos, newnode)
       recorder.handle_block_event(placer, pos, placepos, newnode, "placed")
    end,
    on_proximity_death = function(pos, player, reason)
       recorder.handle_player_death(player, pos, reason)
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

local function get_log(recorder_pos)
    local meta = minetest.get_meta(recorder_pos)
    local log = minetest.deserialize(meta:get_string("log"))
    return log or {}
end

local function add_entry(recorder_pos, message)
    local dated_message = os.date("![%m-%d %H:%M:%S] ") .. message
    local log = get_log(recorder_pos)
    table.insert(log, 1, dated_message)
    if #log > 1000 then
       table.remove(log)
    end
    local meta = minetest.get_meta(recorder_pos)
    meta:set_string("log", minetest.serialize(log))
    meta:mark_as_private("log")
end

function recorder.get_formspec(recorder_pos)
    local log = get_log(recorder_pos)
    local formspec = {
        "size[15,10]",
        "real_coordinates[true]",
        "textlist[0.5,0.5;14,9;log;"
    }
    for _,text in pairs(log) do
        table.insert(formspec, minetest.formspec_escape(text))
        table.insert(formspec, ",")
    end
    table.insert(formspec, "]")
    return table.concat(formspec, "")
end

function recorder.handle_block_event(player, rec_pos, event_pos, node, event_type)
   if (not player) or (not minetest.is_player(player)) then
       return
   end
   local pname = player:get_player_name()
   local message = pname .. " " .. event_type .. " " .. node.name
      .. " at " .. pprintv(event_pos)

   local has_privilege = util.check_permission(rec_pos, pname)
   if not has_privilege then
      add_entry(rec_pos, message)
   end
end

function recorder.handle_player_event(player, recorder_pos, event_type)
   local has_privilege = ct.has_locked_container_privilege(recorder_pos, player)
   if not has_privilege then
      local pname = player:get_player_name()
      local ppos = player:get_pos()
      local message = pname .. " " .. event_type .. " at " .. pprintv(ppos) .. "."
      add_entry(recorder_pos, message)
   end
end

function recorder.handle_player_death(player, recorder_pos, reason)
   local pname = player:get_player_name()
   local ppos = player:get_pos()
   local message = "died"
   if reason.type == "punch" and reason.object then
      message = "killed by " .. reason.object:get_player_name()
   end
   message = pname .. " " .. message .. " at " .. pprintv(ppos) .. "."
   add_entry(recorder_pos, message)
end
