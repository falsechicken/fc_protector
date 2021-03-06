

local modName = "fc_protector"

local LIBS_FOLDER_NAME = "/libs/"

dofile(minetest.get_modpath("fc_protector")..LIBS_FOLDER_NAME.."logman.lua") -- Include LogMan.

minetest.register_privilege("delprotect","Ignore player protection")

fc_protector = {}
fc_protector.radius = 8

fc_protector.get_member_list = function(meta)
	local s = meta:get_string("members")
	local list = s:split(" ")
	return list
end

fc_protector.set_member_list = function(meta, list)
	meta:set_string("members", table.concat(list, " "))
end

fc_protector.is_member = function (meta, name)
	local list = fc_protector.get_member_list(meta)
	for _, n in ipairs(list) do
		if n == name then
			return true
		end
	end
	return false
end

fc_protector.add_member = function(meta, name)
	if fc_protector.is_member(meta, name) then return end
	local list = fc_protector.get_member_list(meta)
	table.insert(list,name)
	fc_protector.set_member_list(meta,list)
end

fc_protector.del_member = function(meta,name)
	local list = fc_protector.get_member_list(meta)
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			break
		end
	end
	fc_protector.set_member_list(meta,list)
end

-- fc_protector Interface

fc_protector.generate_formspec = function(meta)
	if meta:get_int("page") == nil then meta:set_int("page",0) end

	local formspec = "size[8,7]"..default.gui_bg..default.gui_bg_img..default.gui_slots -- Added new formspec defaults
		.."label[2.5,0;-- FC fc_protector interface --]"
		.."label[0,1;Punch node to show protected area]"
		.."label[0,2;Members: (type nick, press Enter to add)]"
	local members = fc_protector.get_member_list(meta)
	
	local npp = 12
	local s = 0
	local i = 0
	for _, member in ipairs(members) do
		if s < meta:get_int("page")*15 then s = s +1 else
			if i < npp then
				formspec = formspec .. "button["..(i%4*2)..","
				..math.floor(i/4+3)..";1.5,.5;fc_protector_member;"..member.."]"
				formspec = formspec .. "button["..(i%4*2+1.25)..","
				..math.floor(i/4+3)..";.75,.5;fc_protector_del_member_"..member..";X]"
			end
			i = i +1
		end
	end
	local add_i = i
	if add_i < npp then
		formspec = formspec
		.."field["..(add_i%4*2+1/3)..","..(math.floor(add_i/4+3)+1/3)..";1.433,.5;fc_protector_add_member;;]"
	end
	               		formspec = formspec.."button_exit[1,6.2;2,0.5;close_me;<< Back]"
	return formspec
end

-- ACTUAL PROTECTION SECTION

-- Infolevel:
-- 0 for no info
-- 1 for "This area is owned by <owner> !" if you can't dig
-- 2 for "This area is owned by <owner>.
-- 3 for checking fc_protector overlaps

fc_protector.can_dig = function(r,pos,digger,onlyowner,infolevel)

	if not digger then
		return false
	end

	local whois = digger

	-- Delprotect privileged users can override protections

	if minetest.check_player_privs(whois, {delprotect=true}) and infolevel == 1 then
		return true
	end

	if infolevel == 3 then infolevel = 1 end

	-- Find the fc_protector nodes

	local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		{"fc_protector:protect", "fc_protector:protect2"})

	for _, pos in ipairs(positions) do
		local meta = minetest.env:get_meta(pos)
		local owner = meta:get_string("owner")

		if owner ~= whois then 
			if onlyowner or not fc_protector.is_member(meta, whois) then
				if infolevel == 1 then
					LogMan:sendMessageToPlayer(whois, "This area is owned by "..owner.." !")
				elseif infolevel == 2 then
					LogMan:sendMessageToPlayer(whois,"This area is owned by "..meta:get_string("owner")..".")
					if meta:get_string("members") ~= "" then
						LogMan:sendMessageToPlayer(whois,"Members: "..meta:get_string("members")..".")
					end
				end
				return false
			end
		end
	end

	if infolevel == 2 then
		if #positions < 1 then
			LogMan:sendMessageToPlayerName(whois,"This area is not protected.")
		else
			local meta = minetest.env:get_meta(positions[1])
			LogMan:sendMessageToPlayerName(whois,"This area is owned by "..meta:get_string("owner")..".")
			if meta:get_string("members") ~= "" then
				LogMan:sendMessageToPlayerName(whois,"Members: "..meta:get_string("members")..".")
			end
		end
		LogMan:sendMessageToPlayerName(whois,"You can build here.")
	end
	return true
end

-- Can node be added or removed, if so return node else true (for protected)

fc_protector.old_is_protected = minetest.is_protected
minetest.is_protected = function(pos, digger)

	if fc_protector.can_dig(fc_protector.radius, pos, digger, false, 1) then
		return fc_protector.old_is_protected(pos, digger)
	else
		return true
	end
end

-- Make sure protection block doesn't overlap another fc_protector's area

fc_protector.old_node_place = minetest.item_place
function minetest.item_place(itemstack, placer, pointed_thing)

	if itemstack:get_name() == "fc_protector:protect" or itemstack:get_name() == "fc_protector:protect2" then
		local pos = pointed_thing.above
		local user = placer:get_player_name()
		if not fc_protector.can_dig(fc_protector.radius * 2, pos, user, true, 3) then
			LogMan:sendMessageToPlayerName(placer:get_player_name(),"Overlaps into another protected area")
			return fc_protector.old_node_place(itemstack, placer, pos)
		end
	end

	return fc_protector.old_node_place(itemstack, placer, pointed_thing)
end

-- END

--= Protection Block

minetest.register_node("fc_protector:protect", {
	description = "Protection Block",
	tiles = {"fc_protector_top.png","fc_protector_top.png","fc_protector_side.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2},
	drawtype = "nodebox",
	node_box = {
		type="fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},
	selection_box = { type="regular" },
	paramtype = "light",
	light_source = 2,

	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
		meta:get_string("owner")..")")
		meta:set_string("members", "")
	end,

	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end

		fc_protector.can_dig(fc_protector.radius,pointed_thing.under,user:get_player_name(),false,2)
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.env:get_meta(pos)
		if fc_protector.can_dig(1,pos,clicker:get_player_name(),true,1) then
			minetest.show_formspec(clicker:get_player_name(), 
			"fc_protector_"..minetest.pos_to_string(pos), fc_protector.generate_formspec(meta)
			)
		end
	end,

	on_punch = function(pos, node, puncher)
		if not fc_protector.can_dig(1,pos,puncher:get_player_name(),true,1) then
			return
		end

		minetest.env:add_entity(pos, "fc_protector:display")
		minetest.env:get_node_timer(pos):start(10)
	end,

	on_timer = function(pos)
		local objs = minetest.env:get_objects_inside_radius(pos,.5)
		for _, o in pairs(objs) do
			if (not o:is_player()) and o:get_luaentity().name == "fc_protector:display" then
				o:remove()
			end
		end
	end,
})

minetest.register_craft({
	output = "fc_protector:protect 4",
	recipe = {
		{"default:stone","default:stone","default:stone"},
		{"default:stone","default:steel_ingot","default:stone"},
		{"default:stone","default:stone","default:stone"},
	}
})

--= Protection Logo

minetest.register_node("fc_protector:protect2", {
	description = "Protection Logo",
	tiles = {"fc_protector_logo.png"},
	wield_image = "fc_protector_logo.png",
	inventory_image = "fc_protector_logo.png",
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2},
	paramtype = 'light',
	paramtype2 = "wallmounted",
	light_source = 2,
	drawtype = "nodebox",
	sunlight_propagates = true,
	walkable = true,
	node_box = {
		type = "wallmounted",
		wall_top    = {-0.375, 0.4375, -0.5, 0.375, 0.5, 0.5},
		wall_bottom = {-0.375, -0.5, -0.5, 0.375, -0.4375, 0.5},
		wall_side   = {-0.5, -0.5, -0.375, -0.4375, 0.5, 0.375},
	},
	selection_box = {type = "wallmounted"},

	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
		meta:get_string("owner")..")")
		meta:set_string("members", "")
	end,

	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		
		fc_protector.can_dig(fc_protector.radius,pointed_thing.under,user:get_player_name(),false,2)
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.env:get_meta(pos)
		if fc_protector.can_dig(1,pos,clicker:get_player_name(),true,1) then
			minetest.show_formspec(clicker:get_player_name(), 
			"fc_protector_"..minetest.pos_to_string(pos), fc_protector.generate_formspec(meta)
			)
		end
	end,

	on_punch = function(pos, node, puncher)
		if not fc_protector.can_dig(1,pos,puncher:get_player_name(),true,1) then
			return
		end

		minetest.env:add_entity(pos, "fc_protector:display")
		minetest.env:get_node_timer(pos):start(10)
	end,

	on_timer = function(pos)
		local objs = minetest.env:get_objects_inside_radius(pos,.5)
		for _, o in pairs(objs) do
			if (not o:is_player()) and o:get_luaentity().name == "fc_protector:display" then
				o:remove()
			end
		end
	end,
})

minetest.register_craft({
	output = "fc_protector:protect2 4",
	recipe = {
		{"default:stone","default:stone","default:stone"},
		{"default:stone","default:copper_ingot","default:stone"},
		{"default:stone","default:stone","default:stone"},
	}
})

-- If name entered into fc_protector formspec

minetest.register_on_player_receive_fields(function(player,formname,fields)
	if string.sub(formname,0,string.len("fc_protector_")) == "fc_protector_" then
		local pos_s = string.sub(formname,string.len("fc_protector_")+1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.env:get_meta(pos)

		if meta:get_int("page") == nil then meta:set_int("page",0) end

		if not fc_protector.can_dig(1,pos,player:get_player_name(),true,1) then
			return
		end

		if fields.fc_protector_add_member then
			for _, i in ipairs(fields.fc_protector_add_member:split(" ")) do
				fc_protector.add_member(meta,i)
			end
		end

		for field, value in pairs(fields) do
			if string.sub(field,0,string.len("fc_protector_del_member_"))=="fc_protector_del_member_" then
				fc_protector.del_member(meta, string.sub(field,string.len("fc_protector_del_member_")+1))
			end
		end

		if fields.close_me then
			meta:set_int("page",meta:get_int("page"))
			else minetest.show_formspec(player:get_player_name(), formname,	fc_protector.generate_formspec(meta))
		end
	end
	
	if formname == "locklabel" then -- If the locklabel is used.
		if fields["nameField"] ~= nil then -- User did not press esc/cancel
			local heldKey = player:get_wielded_item() -- Get the key in hand.
			local keyName = fields["nameField"]
			local keyCode = generateKeyCode() -- Secret code for the key.			
			local newKey = {name="fc_protector:key", count=1, wear=0, metadata=""} -- Define the ItemStack for the new normal key to replace blank key.
			heldKey:replace(newKey) -- Remove blank key and replace with normal key.
			heldKey:set_metadata(keyName .."|"..keyCode) -- Set key metadata. Key name and password seperated by a pipe (|)
			player:set_wielded_item(heldKey)
			LogMan:sendMessageToPlayerName(player:get_player_name(), "Key has been initialized with name: " .. keyName)			
		else
			return
		end		
	end
end)

minetest.register_entity("fc_protector:display", {
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "wielditem",
	visual_size = {x=1.0/1.5,y=1.0/1.5}, -- wielditem seems to be scaled to 1.5 times original node size
	textures = {"fc_protector:display_node"},
	on_step = function(self, dtime)
		local nam = minetest.get_node(self.object:getpos()).name
		if nam ~= "fc_protector:protect" and nam ~= "fc_protector:protect2" then
			self.object:remove()
			return
		end
	end,
})

-- Display-zone node, Do NOT place the display as a node, it is made to be used as an entity (see above)
local x = fc_protector.radius
minetest.register_node("fc_protector:display_node", {
	tiles = {"fc_protector_display.png"},
	use_texture_alpha = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- sides
			{-(x+.55), -(x+.55), -(x+.55), -(x+.45), (x+.55), (x+.55)},
			{-(x+.55), -(x+.55), (x+.45), (x+.55), (x+.55), (x+.55)},
			{(x+.45), -(x+.55), -(x+.55), (x+.55), (x+.55), (x+.55)},
			{-(x+.55), -(x+.55), -(x+.55), (x+.55), (x+.55), -(x+.45)},
			-- top
			{-(x+.55), (x+.45), -(x+.55), (x+.55), (x+.55), (x+.55)},
			-- bottom
			{-(x+.55), -(x+.55), -(x+.55), (x+.55), -(x+.45), (x+.55)},
			-- middle (surround fc_protector)
			{-.55,-.55,-.55, .55,.55,.55},
		},
	},
	selection_box = {
		type = "regular",
	},
	paramtype = "light",
	groups = {dig_immediate=3,not_in_creative_inventory=1},
	drop = "",
})

-- Register Protected Doors

local function on_rightclick(pos, dir, check_name, replace, replace_dir, params)
	pos.y = pos.y+dir
	if not minetest.get_node(pos).name == check_name then
		return
	end
	local p2 = minetest.get_node(pos).param2
	p2 = params[p2+1]
		
	minetest.swap_node(pos, {name=replace_dir, param2=p2})
		
	pos.y = pos.y-dir
	minetest.swap_node(pos, {name=replace, param2=p2})

	local snd_1 = "door_close"
	local snd_2 = "door_open" 
	if params[1] == 3 then
		snd_1 = "door_open"
		snd_2 = "door_close"
	end

	if minetest.get_meta(pos):get_int("right") ~= 0 then
		minetest.sound_play(snd_1, {pos = pos, gain = 0.3, max_hear_distance = 10})
	else
		minetest.sound_play(snd_2, {pos = pos, gain = 0.3, max_hear_distance = 10})
	end
end

-- Protected Wooden Door

local name = "fc_protector:door_wood"

doors.register_door(name, {
	description = "Protected Wooden Door",
	inventory_image = "door_wood.png^fc_protector_logo.png",
	groups = {snappy=1,choppy=2,oddly_breakable_by_hand=2,flammable=2,door=1},
	tiles_bottom = {"door_wood_b.png^fc_protector_logo.png", "door_brown.png"},
	tiles_top = {"door_wood_a.png", "door_brown.png"},
	sounds = default.node_sound_wood_defaults(),
	sunlight = false,
})

minetest.override_item(name.."_b_1", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, 1, name.."_t_1", name.."_b_2", name.."_t_2", {1,2,3,0})
		end
	end,
})

minetest.override_item(name.."_t_1", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, -1, name.."_b_1", name.."_t_2", name.."_b_2", {1,2,3,0})
		end
	end,
})

minetest.override_item(name.."_b_2", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, 1, name.."_t_2", name.."_b_1", name.."_t_1", {3,0,1,2})
		end
	end,
})

minetest.override_item(name.."_t_2", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, -1, name.."_b_2", name.."_t_1", name.."_b_1", {3,0,1,2})
		end
	end,
})

minetest.register_craft({
	output = name,
	recipe = {
		{"group:wood", "group:wood"},
		{"group:wood", "default:copper_ingot"},
		{"group:wood", "group:wood"}
	}
})

minetest.register_craft({
	output = name,
	recipe = {
		{"doors:door_wood", "default:copper_ingot"}
	}
})

-- Protected Steel Door

local name = "fc_protector:door_steel"

doors.register_door(name, {
	description = "Protected Steel Door",
	inventory_image = "door_steel.png^fc_protector_logo.png",
	groups = {snappy=1,bendy=2,cracky=1,melty=2,level=2,door=1},
	tiles_bottom = {"door_steel_b.png^fc_protector_logo.png", "door_grey.png"},
	tiles_top = {"door_steel_a.png", "door_grey.png"},
	sounds = default.node_sound_wood_defaults(),
	sunlight = false,
})

minetest.override_item(name.."_b_1", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, 1, name.."_t_1", name.."_b_2", name.."_t_2", {1,2,3,0})
		end
	end,
})

minetest.override_item(name.."_t_1", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, -1, name.."_b_1", name.."_t_2", name.."_b_2", {1,2,3,0})
		end
	end,
})

minetest.override_item(name.."_b_2", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, 1, name.."_t_2", name.."_b_1", name.."_t_1", {3,0,1,2})
		end
	end,
})

minetest.override_item(name.."_t_2", {
	on_rightclick = function(pos, node, clicker, keyItem)
		if checkLock(pos, node, clicker, keyItem) then
			on_rightclick(pos, -1, name.."_b_2", name.."_t_1", name.."_b_1", {3,0,1,2})
		end
	end,
})

minetest.register_craft({
	output = name,
	recipe = {
		{"default:steel_ingot", "default:steel_ingot"},
		{"default:steel_ingot", "default:copper_ingot"},
		{"default:steel_ingot", "default:steel_ingot"}
	}
})

minetest.register_craft({
	output = name,
	recipe = {
		{"doors:door_steel", "default:copper_ingot"}
	}
})

local function get_locked_chest_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,9]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"list[nodemeta:".. spos .. ";main;0,0.3;8,4;]"..
		"list[current_player;main;0,4.85;8,1;]"..
		"list[current_player;main;0,6.08;8,3;8]"..
		default.get_hotbar_bg(0,4.85)
 return formspec
end

-- Protected Chest
minetest.register_node("fc_protector:chest", {
	description = "Protected Chest",
	tiles = {"default_chest_top.png", "default_chest_top.png", "default_chest_side.png",
		"default_chest_side.png", "default_chest_side.png", "default_chest_front.png^fc_protector_logo.png"},
	paramtype2 = "facedir",
	groups = {choppy=2,oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Protected Chest")
		local inv = meta:get_inventory()
		inv:set_size("main", 8*4)
	end,
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("main") then
			if not minetest.is_protected(pos, player:get_player_name()) then
				return true
			end
		end
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return count
	end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		return stack:get_count()
	end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return stack:get_count()
	end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()..
				" moves stuff to protected chest at "..minetest.pos_to_string(pos))
	end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()..
				" takes stuff from protected chest at "..minetest.pos_to_string(pos))
	end,
	on_rightclick = function(pos, node, clicker, keyItem)
		local meta = minetest.get_meta(pos)
		if checkLock(pos, node, clicker, keyItem) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"default:chest_locked",
				get_locked_chest_formspec(pos)
			)
		end
	end,
})

minetest.register_craft({
	output = 'fc_protector:chest',
	recipe = {
		{'group:wood', 'group:wood', 'group:wood'},
		{'group:wood', 'default:copper_ingot', 'group:wood'},
		{'group:wood', 'group:wood', 'group:wood'},
	}
})

-- Register door/chest keys.
minetest.register_craftitem("fc_protector:key", {
	description = "Normal Key",
	inventory_image = "normal_key.png",
	stack_max = 1,
	on_use = function(keyStack, player)
					LogMan:sendMessageToPlayerName(player:get_player_name(), "Key Name: " .. getKeyName(keyStack)) -- Print the name of the key to the player.
			 end,
	})
	
minetest.register_craftitem("fc_protector:blankkey", {
	description = "Blank Key",
	inventory_image = "blank_key.png",
	stack_max = 1,
on_use = function(keyStack, player)
			showKeyLabelFormspec(player) -- Show key label dialog.
		 end,
on_place = function(keyStack, player)
			LogMan:sendMessageToPlayer(player, "Key has not been initialized! Left click with key to do so now.")
		 end,
})

minetest.register_craft({ -- Blank key recipe.
	type = "shapeless",
	output = "fc_protector:blankkey",
	recipe = {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
})
	
function printKeyData(keyStack, player) -- Print raw key metadata. Debug only.
	
	local keyMetadata = keyStack:get_metadata()
	
	if keyMetadata == "" then
		LogMan:sendMessageToPlayer(player, "Key Data Empty.")
	else
		LogMan:sendMessageToPlayer(player, "Key Data: " .. keyMetadata)
	end
end

function getKeyName(keyStack) -- Get the name of the key
	local keyName = string.split(keyStack:get_metadata(), "|")
	return keyName[1]
end

function getKeyCode(keyStack) -- Get the code of the key. (Secret code (metadata "key") used to actually lock objects.)
	local keyName = string.split(keyStack:get_metadata(), "|")
	return keyName[2]	
end

function setKey(keyStack, nodeToLockPos) -- Called when a door/chest has no key assigned. 
	
	local doorPrefixWood = "fc_protector:door_wood" -- Used when checking for the second node of a door. Fixes the need to set both door nodes with key manually.
	local doorPrefixSteel = "fc_protector:door_steel"
	
	local nodeName = minetest.get_node(nodeToLockPos).name
	
	minetest.get_meta(nodeToLockPos):set_string("key", getKeyCode(keyStack))
	minetest.get_meta(nodeToLockPos):set_string("infotext", "Key: " .. getKeyName(keyStack))
	
	if (nodeName == doorPrefixWood.."_b_1" or nodeName == doorPrefixWood.."_b_2") then -- If we are setting the bottom of the wooden door also set the node above with the same key.
		
	    nodeToLockPos.y = nodeToLockPos.y + 1 -- Move up one since we are at the bottom door node.		
		minetest.get_meta(nodeToLockPos):set_string("key", getKeyCode(keyStack))
		minetest.get_meta(nodeToLockPos):set_string("infotext", "Key: " .. getKeyName(keyStack))
		
	elseif (nodeName == doorPrefixWood.."_t_1" or nodeName == doorPrefixWood.."_t_2") then -- If we are setting the top of the wooden door also set the node below with the same key.
		
		nodeToLockPos.y = nodeToLockPos.y - 1 -- Move down one since we are at the top door node.	
		minetest.get_meta(nodeToLockPos):set_string("key", getKeyCode(keyStack))
		minetest.get_meta(nodeToLockPos):set_string("infotext", "Key: " .. getKeyName(keyStack))
	
	elseif (nodeName == doorPrefixSteel.."_b_1" or nodeName == doorPrefixSteel.."_b_2") then -- If we are setting the bottom of the steel door.
		
		nodeToLockPos.y = nodeToLockPos.y + 1 -- Move up one since we are at the bottom door node.	
		minetest.get_meta(nodeToLockPos):set_string("key", getKeyCode(keyStack))
		minetest.get_meta(nodeToLockPos):set_string("infotext", "Key: " .. getKeyName(keyStack))
	
	elseif (nodeName == doorPrefixSteel.."_t_1" or nodeName == doorPrefixSteel.."_t_2") then -- If we are setting the top of the steel door.
		
		nodeToLockPos.y = nodeToLockPos.y - 1 -- Move down one since we are at the top door node.	
		minetest.get_meta(nodeToLockPos):set_string("key", getKeyCode(keyStack))
		minetest.get_meta(nodeToLockPos):set_string("infotext", "Key: " .. getKeyName(keyStack))
	
	end
	
end

function generateKeyCode() -- Generates a random passcode for key metadata. Called when blank keys are used for the first time.
	local keyCode = math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. 
							math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9)	
	return keyCode
end

function checkLock(pos, node, clicker, keyItem) -- Check to see if door/chest is locked and if key is correct. 
	if minetest.get_meta(pos):get_string("key") == "" then -- Door has no key setup
		if keyItem:get_name() == "fc_protector:key" then -- If the player is holding a key and the door has no assigned key.
			setKey(keyItem, pos) -- Lock the door with the current key.
			LogMan:sendMessageToPlayer(clicker, "Key Set!") -- Inform the player that the lock has been set with key.
		else
			LogMan:sendMessageToPlayer(clicker, "Lock has no key. Right click with key to set.") -- Inform the player that the door is unlocked.
			return true
		end
	else -- Door has key setup
		if keyItem:get_name() == "fc_protector:key" then -- If the player is holding a key check it.
			if getKeyCode(keyItem) == minetest.get_meta(pos):get_string("key") then -- If key matches.
				return true
			else
				LogMan:sendMessageToPlayer(clicker, "Wrong Key!")
				return false
			end
		else -- If not tell the player the door is locked.
			LogMan:sendMessageToPlayer(clicker, "Object Is Locked.")
			return false
	    end
	end
end

function showKeyLabelFormspec(player) -- Show the Key Label formspec. Allows the player to give the key a nickname to help in finding the proper key to a lock.
	local llFormspec = "size[2.4,0.6]" .. "field[0,0.3;3,1;nameField;Key Name;]"
	minetest.show_formspec(player:get_player_name(), "locklabel", llFormspec)
end
