
local modpath = minetest.get_modpath(minetest.get_current_modname())

local QuadTree = dofile(modpath .. "/quadtree/QuadTree.lua")

local DIMENSION = 5000

-- We keep track of every snitch. Every time the server restarts, we rebuild our
-- QuadTree of snitches from the snitch entries, for fast-lookup.
--
-- We never delete nodes from the QuadTree, we just mark them as deleted,
-- exclude them from any lookups, and remove them from the snitch-registry
-- proper. When the QuadTree is next rebuilt, the entry won't be there.
SnitchRegistry = {
   snitches = {},
   qt = QuadTree.new(0, -(DIMENSION / 2), -(DIMENSION / 2),
                     DIMENSION, DIMENSION)
}

function SnitchRegistry.entry(name, v)
   local obj = {
      name = name,
      pos = v,
      players_in_proximity = {},
      bbox = {
         lx = v.x - 10, lz = v.z - 10,
         -- hx = 10, hz = 10
      },
      -- QuadTree was originally written for LOVE so it wants this function
      getPosition = function(self)
         return self.bbox.lx, self.bbox.lz
      end,
      active = true
   }
   return obj
end

function SnitchRegistry.register(name, v)
   SnitchRegistry.snitches[vtos(v)] = { name = name, pos = v }
   local entry = SnitchRegistry.entry(name, v)
   SnitchRegistry.qt:insert(entry, entry.bbox.lx, entry.bbox.lz)
end

function SnitchRegistry.unregister(name, v)
   SnitchRegistry.snitches[vtos(v)] = nil

   local dimx = v.x
   local dimz = v.z
   local all_entries = SnitchRegistry.qt:retrieve(dimx, dimz)

   for _,entry in ipairs(all_entries) do
      if vector.equals(entry.pos, v) then
         entry.active = false
      end
   end
end

function SnitchRegistry.get_nearby(v)
   local new_x = v.x
   local new_z = v.z
   local all_entries = SnitchRegistry.qt:retrieve(new_x - 10, new_z - 10)
   local active_entries = {}

   for _,entry in ipairs(all_entries) do
      if entry.active then
         table.insert(active_entries, entry)
      end
   end

   return active_entries
end

local storage = minetest.get_mod_storage()

function SnitchRegistry.save()
   storage:set_string(
      "SnitchRegistry", minetest.serialize(SnitchRegistry.snitches)
   )

   local n = 0
   for _ in pairs(SnitchRegistry.snitches) do n = n + 1 end

   minetest.log("SnitchRegistry: saved " .. n .. " snitches to disk.")
end

function SnitchRegistry.load()
   SnitchRegistry.snitches = minetest.deserialize(
      storage:get_string("SnitchRegistry")
   )
   SnitchRegistry.snitches = SnitchRegistry.snitches or {}

   local n = 0
   for _,snitch in pairs(SnitchRegistry.snitches) do
      local entry = SnitchRegistry.entry(snitch.name, snitch.pos)
      SnitchRegistry.qt:insert(entry, entry.bbox.lx, entry.bbox.lz)
      n = n + 1
   end
   minetest.log("SnitchRegistry: loaded " .. n .. " snitches from disk.")
end

SnitchRegistry.load()

minetest.register_on_shutdown(function()
      SnitchRegistry.save()
end)

--------------------------------------------------------------------------------
--
-- Action registry
--
--------------------------------------------------------------------------------

local timer = 0
minetest.register_globalstep(function(dtime)
   timer = timer + dtime
   if timer >= 0.5 then
      for _,player in ipairs(minetest.get_connected_players()) do
         local ppos = player:get_pos()
         local nearby_snitches = SnitchRegistry.get_nearby(ppos)
         for _,entry in ipairs(nearby_snitches) do
            -- Sanity check that nearby nodes actually exist in the world
            local node = minetest.get_node(entry.pos)
            if node.name ~= "ignore" and node.name ~= entry.name then
               SnitchRegistry.unregister(entry.name, entry.pos)
               minetest.log("Unregistered stale " .. entry.name .. " at ("
                               .. vtos(entry.pos) .. ").")
               goto continue
            end

            local pname = player:get_player_name()
            local def = minetest.registered_nodes[entry.name]
            if vector.distance(ppos, entry.pos) < 10 then
               if not entry.players_in_proximity[pname] then
                  if def.on_proximity_entered then
                     def.on_proximity_entered(entry.pos, player)
                  end
                  entry.players_in_proximity[pname] = true
               elseif entry.players_in_proximity[pname] then
                  if def.on_proximity_remain then
                     def.on_proximity_remain(entry.pos, player)
                  end
               end
            elseif entry.players_in_proximity[pname] then
               if def.on_proximity_exited then
                  def.on_proximity_exited(entry.pos, player)
               end
               entry.players_in_proximity[pname] = nil
            end
            ::continue::
         end
      end
      timer = 0
   end
end)

minetest.register_on_joinplayer(function(player)
      local ppos = player:get_pos()
      local nearby_snitches = SnitchRegistry.get_nearby(ppos)
      for _,entry in ipairs(nearby_snitches) do
         if vector.distance(ppos, entry.pos) < 10 then
            local def = minetest.registered_nodes[entry.name]
            if def.on_proximity_join then
               def.on_proximity_join(entry.pos, player)
            end
            local pname = player:get_player_name()
            entry.players_in_proximity[pname] = true
         end
      end
end)

minetest.register_on_leaveplayer(function(player)
      local ppos = player:get_pos()
      local nearby_snitches = SnitchRegistry.get_nearby(ppos)
      for _,entry in ipairs(nearby_snitches) do
         if vector.distance(ppos, entry.pos) < 10 then
            local def = minetest.registered_nodes[entry.name]
            if def.on_proximity_leave then
               def.on_proximity_leave(entry.pos, player)
            end
            local pname = player:get_player_name()
            entry.players_in_proximity[pname] = false
         end
      end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode,
                                        itemstack, pointed_thing)
      local nearby_snitches = SnitchRegistry.get_nearby(pos)
      for _,entry in ipairs(nearby_snitches) do
         if vector.distance(pos, entry.pos) < 10 then
            local def = minetest.registered_nodes[entry.name]
            if def.on_proximity_place then
               def.on_proximity_place(entry.pos, placer, pos, newnode)
            end
         end
      end
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
      local nearby_snitches = SnitchRegistry.get_nearby(pos)
      for _,entry in ipairs(nearby_snitches) do
         if vector.distance(pos, entry.pos) < 10 then
            local def = minetest.registered_nodes[entry.name]
            if def.on_proximity_dig then
               def.on_proximity_dig(entry.pos, digger, pos, oldnode)
            end
         end
      end
end)

minetest.register_on_dieplayer(function(player, reason)
      local ppos = player:get_pos()
      local nearby_snitches = SnitchRegistry.get_nearby(ppos)
      for _,entry in ipairs(nearby_snitches) do
         if vector.distance(ppos, entry.pos) < 10 then
            local def = minetest.registered_nodes[entry.name]
            if def.on_proximity_death then
               def.on_proximity_death(entry.pos, player, reason)
            end
         end
      end
end)

--------------------------------------------------------------------------------
--
-- Testings
--
--------------------------------------------------------------------------------

minetest.register_node(
   "block_alert:loudspeaker",
   {
      description = "Loudspeaker",
      tiles = {"default_wood.png^[colorize:#802BB177"},
      groups = {choppy = 2, oddly_breakable_by_hand = 2, wood = 1},
      after_place_node = function(pos, placer, itemstack, pointed_thing)
         SnitchRegistry.register("block_alert:loudspeaker", pos)
      end,
      after_dig_node = function(pos, placer, itemstack, pointed_thing)
         SnitchRegistry.unregister("block_alert:loudspeaker", pos)
      end,
      on_proximity_entered = function(pos, player)
         local pname = player:get_player_name()
         minetest.chat_send_player(
            pname, "<Loudspeaker(".. vtos(pos) .. ")> "
               .. "I AM A LOUD SPEAKER! HEAR ME FROM AFAR!"
         )
      end,
      on_proximity_exited = function(pos, player)
         local pname = player:get_player_name()
         minetest.chat_send_player(
            pname, "<Loudspeaker(".. vtos(pos) .. ")> "
               .. "THIS IS THE NEW AGE OF ADVERTISEMENT!"
         )
      end,
      on_proximity_join = function(pos, player)
         local pname = player:get_player_name()
         minetest.chat_send_player(
            pname, "<Loudspeaker(".. vtos(pos) .. ")> "
               .. "WELCOME! PLEASE BUY MY THINGS!"
         )
      end,
      on_proximity_place = function(pos, placer, placepos, newnode)
         local pname = placer:get_player_name()
         minetest.chat_send_player(
            pname, "<Loudspeaker(".. vtos(pos) .. ")> "
               .. "DON'T PLACE THINGS HERE, GRIEFER!"
         )
      end,
      on_proximity_dig = function(pos, digger, digpos, oldnode)
         local pname = digger:get_player_name()
         minetest.chat_send_player(
            pname, "<Loudspeaker(".. vtos(pos) .. ")> "
               .. "GRIEFER! THERE'S A GRIEFER DIGGING HERE!"
         )
      end,
   }
)
