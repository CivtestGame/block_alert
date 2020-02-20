
local modpath = minetest.get_modpath(minetest.get_current_modname())

local QuadTree = dofile(modpath .. "/quadtree/QuadTree.lua")

local DIMENSION = 10000

-- We keep track of every snitch. Every time the server restarts, we rebuild our
-- QuadTree of snitches from the snitch entries, for fast-lookup.
--
-- We never delete nodes from the QuadTree, we just mark them as deleted,
-- exclude them from any lookups, and remove them from the snitch-registry
-- proper. When the QuadTree is next rebuilt, the entry won't be there.
SnitchRegistry = {
   snitches = {},
   qt = QuadTree.new(0, 0, 0, DIMENSION*2, DIMENSION*2)
}

function SnitchRegistry.entry(name, v)
   local obj = {
      name = name,
      pos = v,
      -- QuadTree was originally written for LOVE so it wants this function
      getPosition = function(self)
         return self.pos.x + DIMENSION, self.pos.z + DIMENSION
      end,
      active = true
   }
   return obj
end

function SnitchRegistry.register(name, v)
   snitches[vtos(v)] = { name = name, pos = v }

   local dimx = v.x + DIMENSION
   local dimz = v.z + DIMENSION
   local entry = SnitchRegistry.entry(name, v)
   SnitchRegistry.qt:insert(entry, dimx, dimz)
end

function SnitchRegistry.unregister(name, v)
   snitches[vtos(v)] = nil

   local dimx = v.x + DIMENSION
   local dimz = v.z + DIMENSION
   local all_entries = SnitchRegistry.qt:retrieve(dimx, dimz)

   for _,entry in ipairs(all_entries) do
      if vector.equals(entry.pos, v) then
         entry.active = false
      end
   end
end

function SnitchRegistry.get_nearby(v)
   local new_x = v.x + DIMENSION
   local new_z = v.z + DIMENSION
   local all_entries = SnitchRegistry.qt:retrieve(new_x, new_z)
   local active_entries = {}

   for _,entry in ipairs(all_entries) do
      if entry.active then
         table.insert(active_entries, entry)
      end
   end

   return active_entries
end
