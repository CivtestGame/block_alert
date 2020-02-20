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

function recorder.handle_block_event(pos, node_name, pname, event_type)
    local recorders = util.find_nodes(pos, 5, {"block_alert:recorder"})
    local player = minetest.get_player_by_name(pname)
    if not recorders or not player then
       return
    end

    local message = pname .. " " .. event_type .. " " .. node_name
       .. " at " .. minetest.pos_to_string(pos)
    for _,recorder_pos in ipairs(recorders) do
       local has_privilege = util.check_permission(recorder_pos, pname)
       if not has_privilege then
          add_entry(recorder_pos, message)
       end
    end
end

function recorder.handle_player_event(player, recorder_pos, event_type)
   local has_privilege = ct.has_locked_container_privilege(recorder_pos, player)
   if not has_privilege then
      local pname = player:get_player_name()
      local message = pname .. " " .. event_type
      add_entry(recorder_pos, message)
   end
end
