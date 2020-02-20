util = {}
notifier = {}
recorder = {}

minetest.debug("Initialising block_alert")

local modpath = minetest.get_modpath(minetest.get_current_modname())

dofile(modpath .. "/registry.lua")
dofile(modpath .. "/util.lua")
dofile(modpath .. "/notifier.lua")
dofile(modpath .. "/recorder.lua")
dofile(modpath .. "/api.lua")
