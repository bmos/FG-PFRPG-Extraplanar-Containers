--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--	search terms for finding extraplanar containers
local tExtraplanarContainers = {
	'of holding',
	'portable hole',
	'efficient quiver',
	'handy haversack'
	}
--	search terms for finding containers to total their contents
local tContainers = {
	'backpack',
	'pouch',
	'quiver',
	'bag'
	}

--	searches provided tTable for provided sItemName
function isContainer(sItemName, tTable)
	if not sItemName or not tTable then return nil; end
	for _,v in pairs(tTable) do
		if string.find(sItemName, v) then
			return true
		end
	end
end

--	checks both tables for match
function isAnyContainer(sItemName)
	return isContainer(sItemName, tExtraplanarContainers) or isContainer(sItemName, tContainers)
end

local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

--	looks through provided charsheet for inventory items that are containers
--	if found, these are added to table_containers_extraplanar or table_containers_mundane as appropriate
local function build_containers(node_pc)
	local table_containers_mundane = {}
	local table_containers_extraplanar = {}
	for _,node_item in pairs(DB.getChildren(node_pc, 'inventorylist')) do
		local string_item_name = string.lower(DB.getValue(node_item, 'name', ''))
		local number_maxweight = DB.getValue(node_item, 'capacityweight', 0);
		local table_dimensions = {
			['nLength'] =  DB.getValue(node_item, 'internal_length', 0),
			['nWidth'] =  DB.getValue(node_item, 'internal_width', 0),
			['nDepth'] =  DB.getValue(node_item, 'internal_depth', 0),
				};
		local number_maxvolume = 0;
		for _,v in spairs(table_dimensions, function(t,a,b) return t[b] < t[a] end) do -- prepare to automatically 'lay flat'/intelligently position items
			number_maxvolume = number_maxvolume + v
		end

		if isContainer(string_item_name, tExtraplanarContainers) then -- this creates an array keyed to the names of any detected extraplanar storage containers
			table_containers_extraplanar[string_item_name] = {
					['nodeItem'] = node_item,
					['nTotalWeight'] = 0,
					['nMaxWeight'] = number_maxweight,
					['nTotalVolume'] = 0,
					['nMaxVolume'] = number_maxvolume,
					['nMaxLength'] = table_dimensions['nLength'],
					['nMaxWidth'] = table_dimensions['nWidth'],
					['nMaxDepth'] = table_dimensions['nDepth'],
					['bTooBig'] = 0,
				};
		elseif isContainer(string_item_name, tContainers) then -- this creates an array keyed to the names of any detected mundane storage containers
			table_containers_mundane[string_item_name] = {
					['nodeItem'] = node_item,
					['nTotalWeight'] = 0,
					['nMaxWeight'] = number_maxweight,
					['nTotalVolume'] = 0,
					['nMaxVolume'] = number_maxvolume,
					['nMaxLength'] = table_dimensions['nLength'],
					['nMaxWidth'] = table_dimensions['nWidth'],
					['nMaxDepth'] = table_dimensions['nDepth'],
					['bTooBig'] = 0,
				};
		end
	end

	return table_containers_mundane, table_containers_extraplanar
end

--	look at items in inventory and calculate their weight
--	items in extraplanar containers will only have weight added to container subtotal
--	items in mundane containers will have weight added to subtotal and encumbrance total
--	items in neither will have weight added to encumbrance total
local function measure_contents(node_pc, table_containers_mundane, table_containers_extraplanar)
	local number_total_weight = 0
	for _,node_item in pairs(DB.getChildren(node_pc, 'inventorylist')) do
		local state_item_carried = DB.getValue(node_item, 'carried', 0)
		if state_item_carried ~= 0 then
			local number_item_count = DB.getValue(node_item, 'count', 0);
			local number_item_weight = DB.getValue(node_item, 'weight', 0);
			local string_item_location = string.lower(DB.getValue(node_item, 'location', ''))

			local table_item_dimensions = {
				['nLength'] = DB.getValue(node_item, 'length', 0),
				['nWidth'] = DB.getValue(node_item, 'width', 0),
				['nDepth'] = DB.getValue(node_item, 'depth', 0)
					};
			local number_item_volume = 0;
			if OptionsManager.isOption('ITEM_VOLUME', 'on') then
				for _,v in spairs(table_item_dimensions, function(t,a,b) return t[b] < t[a] end) do -- prepare to automatically 'lay flat'/intelligently position items
					number_item_volume = number_item_volume + v
				end
			end

			-- add up subtotals of container contents and put them in the table
			if state_item_carried ~= 2 and isContainer(string_item_location, tExtraplanarContainers) then
				if table_containers_extraplanar[string_item_location] then
					table_containers_extraplanar[string_item_location]['nTotalWeight'] = table_containers_extraplanar[string_item_location]['nTotalWeight'] + (number_item_count * number_item_weight)
					table_containers_extraplanar[string_item_location]['nTotalVolume'] = table_containers_extraplanar[string_item_location]['nTotalVolume'] + (number_item_count * number_item_volume)
					if table_containers_extraplanar[string_item_location]['nMaxLength'] < table_item_dimensions['nLength'] then table_containers_extraplanar[string_item_location]['bTooBig'] = 1 end
					if table_containers_extraplanar[string_item_location]['nMaxWidth'] < table_item_dimensions['nWidth'] then table_containers_extraplanar[string_item_location]['bTooBig'] = 1 end
					if table_containers_extraplanar[string_item_location]['nMaxDepth'] < table_item_dimensions['nDepth'] then table_containers_extraplanar[string_item_location]['bTooBig'] = 1 end
				end
			elseif state_item_carried ~= 2 and isContainer(string_item_location, tContainers) then
				if table_containers_mundane[string_item_location] then
					table_containers_mundane[string_item_location]['nTotalWeight'] = table_containers_mundane[string_item_location]['nTotalWeight'] + (number_item_count * number_item_weight)
					table_containers_mundane[string_item_location]['nTotalVolume'] = table_containers_mundane[string_item_location]['nTotalVolume'] + (number_item_count * number_item_volume)
					if table_containers_mundane[string_item_location]['nMaxLength'] < table_item_dimensions['nLength'] then table_containers_mundane[string_item_location]['bTooBig'] = 1 end
					if table_containers_mundane[string_item_location]['nMaxWidth'] < table_item_dimensions['nWidth'] then table_containers_mundane[string_item_location]['bTooBig'] = 1 end
					if table_containers_mundane[string_item_location]['nMaxDepth'] < table_item_dimensions['nDepth'] then table_containers_mundane[string_item_location]['bTooBig'] = 1 end
				end
				number_total_weight = number_total_weight + (number_item_count * number_item_weight)
			else
				number_total_weight = number_total_weight + (number_item_count * number_item_weight)
			end
		end
	end

	return number_total_weight
end

--	writes container subtotals to the relevant container
--	sends chat messages if containers are overfull
local function write_contents_to_containers(node_pc, table_containers, string_error)
	local string_player_name = DB.getValue(node_pc, 'name', Interface.getString("char_name_unknown"))
	for _,table_container in pairs(table_containers) do
		DB.setValue(table_container['nodeItem'], 'extraplanarcontents', 'number', table_container['nTotalWeight'])
		DB.setValue(table_container['nodeItem'], 'contentsvolume', 'number', table_container['nTotalVolume'])
		local string_item_name = DB.getValue(table_container['nodeItem'], 'name', 'extraplanar container')

		-- check weight of contents and announce if excessive
		if table_container['nMaxWeight'] > 0 then
			if (table_container['nTotalWeight'] > table_container['nMaxWeight'])  then

				if not table_container['nodeItem'].getChild('announcedW') then
					DB.setValue(table_container['nodeItem'], 'announcedW', 'number', 1)
					ChatManager.SystemMessage(string.format(Interface.getString(string_error), string_player_name, string_item_name, 'weight'))
				end
			else
				if table_container['nodeItem'].getChild('announcedW') then table_container['nodeItem'].getChild('announcedW').delete() end
			end
		end

		-- check volume of contents and announce if excessive
		if OptionsManager.isOption('ITEM_VOLUME', 'on') and table_container['nMaxVolume'] > 0 then
			if table_container['bTooBig'] == 1 then
				if not table_container['nodeItem'].getChild('announcedV') then
					DB.setValue(table_container['nodeItem'], 'announcedV', 'number', 1)
					ChatManager.SystemMessage(string.format(Interface.getString(string_error), string_player_name, string_item_name, 'maximum dimension'))
				end
			elseif table_container['nTotalVolume'] > table_container['nMaxVolume'] then
				if not table_container['nodeItem'].getChild('announcedV') then
					DB.setValue(table_container['nodeItem'], 'announcedV', 'number', 1)
					ChatManager.SystemMessage(string.format(Interface.getString(string_error), string_player_name, string_item_name, 'volume'))
				end
			else
				if table_container['nodeItem'].getChild('announcedV') then table_container['nodeItem'].getChild('announcedV').delete() end
			end
		end
	end
end

local function updateEncumbrance_new(node_char)
	-- assemble a list of containers and their capacities
	local table_containers_mundane, table_containers_extraplanar = build_containers(node_char)

	-- this will cointain a running total of all items carried by the character
	local number_total = measure_contents(node_char, table_containers_mundane, table_containers_extraplanar)

	-- writes container subtotals to database and handles chat messages
	write_contents_to_containers(node_char, table_containers_mundane, "item_overfull")
	write_contents_to_containers(node_char, table_containers_extraplanar, "item_self_destruct")

	-- rounds total and writes to encumbrance field
	local number_rounded_total = number_total + 0.5 - (number_total + 0.5) % 1
	DB.setValue(node_char, 'encumbrance.load', 'number', number_rounded_total)
end

local function onLocationChanged(node)
	local node_char = node.getChild('....')
	CharManager.updateEncumbrance(node_char)
end

local updateEncumbrance_old = nil
function onInit()
	OptionsManager.registerOption2('ITEM_VOLUME', false, 'option_header_game', 'opt_lab_item_volume', 'option_entry_cycler',
		{ labels = 'option_val_on',
		values = 'on',
		baselabel = 'option_val_off',
		baseval = 'off',
		default = 'off',
	})

	updateEncumbrance_old = CharManager.updateEncumbrance;
	CharManager.updateEncumbrance = updateEncumbrance_new;

	DB.addHandler(DB.getPath('charsheet.*.inventorylist.*.location'), 'onUpdate', onLocationChanged)
end

function onClose()
	CharManager.updateEncumbrance = updateEncumbrance_old;
end