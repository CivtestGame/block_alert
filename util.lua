--for lack of a better name...
local player_alert_status = {}

function util.handle_player_entry_event(player, node_pos)
    local node_name = minetest.get_node(node_pos).name
    if node_name == "block_alert:recorder" then
        recorder.handle_player_event(player, node_pos,"entered")
    end
end

function util.handle_player_exit_event(player, node_pos)
    local node_name = minetest.get_node(node_pos).name
    if node_name == "block_alert:recorder" then
        recorder.handle_player_event(player, node_pos,"exited")
    end
end

function util.check_permission(pos, pname)
    local reinf = ct.get_reinforcement(pos)
    if not reinf then
       return false
    end
    local player_id = pm.get_player_by_name(pname).id
    return pm.get_player_group(player_id, reinf.ctgroup_id)
end

function util.find_nodes(center_pos, search_radius, block_type)
    local search_vector = vector.new(search_radius, search_radius, search_radius)
    local bound1 = vector.subtract(center_pos, search_vector)
    local bound2 = vector.add(center_pos, search_vector)
    local nodeList = minetest.find_nodes_in_area(bound1, bound2, block_type)
    return nodeList
end

function util.check_new_player_move(player)
    local player_name = player:get_player_name()
    local old_alert_list = player_alert_status[player_name] or {}
    local new_alert_list = util.find_nodes(
       player:get_pos(),
       5,
       { "block_alert:recorder" }
    )

    local lookup_table_new = {}
    local lookup_table_old = {}

    for _, node_pos in pairs(new_alert_list) do
        local string_pos = minetest.pos_to_string(node_pos)
        lookup_table_new[string_pos] = true
    end

    for _, node_pos in pairs(old_alert_list) do
        local string_pos = minetest.pos_to_string(node_pos)
        if not lookup_table_new[string_pos] then
            handle_player_exit_event(player, node_pos)
        end
        lookup_table_old[string_pos] = true
    end

    for _, node_pos in pairs(new_alert_list) do
        local string_pos = minetest.pos_to_string(node_pos)
        if not lookup_table_old[string_pos] then
            handle_player_entry_event(player, node_pos)
        end
    end

    player_alert_status[player_name] = new_alert_list
end
