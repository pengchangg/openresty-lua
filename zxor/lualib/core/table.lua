local pairs = pairs
local ipairs = ipairs
local type = type
local table = table
local ngx_null = nil
if ngx then
	ngx_null = ngx.null
end

local ok, new_tab = pcall(require, "table.new")
if not ok then
	new_tab = function(narr, nrec)
		return {}
	end
end

local nkeys
ok, nkeys = pcall(require, "table.nkeys")
if not ok then
	nkeys = function(tab)
		if type(tab) ~= "table" then
			return 0, "not a table"
		end
		local n = 0
		for _, _ in pairs(tab) do
			n = n + 1
		end
		return n
	end
end

local clear_tab
ok, clear_tab = pcall(require, "table.clear")
if not ok then
	clear_tab = function(tab)
		if type(tab) ~= "table" then
			return false, "not a table"
		end
		for k, _ in pairs(tab) do
			tab[k] = nil
		end
		return true
	end
end

local clone_tab
ok, clone_tab = pcall(require, "table.clone")
if not ok then
	clone_tab = function(tab)
		if type(tab) ~= "table" then
			return nil, "not a table"
		end
		local narr = #tab
		local nrec = nkeys(tab) - narr
		local copy = new_tab(narr, nrec)
		for k, v in pairs(tab) do
			copy[k] = v
		end
		return copy
	end
end

local isarray
ok, isarray = pcall(require, "table.isarray")
if not ok then
	isarray = function(tab)
		if type(tab) ~= "table" then
			return false, "not a table"
		end
		if #tab == nkeys(tab) then
			return true
		end
		return false
	end
end

local isempty
ok, isempty = pcall(require, "table.isempty")
if not ok then
	isempty = function(tab)
		if type(tab) ~= "table" then
			return true, "not a table"
		end
		if nkeys(tab) == 0 then
			return true
		end
		return false
	end
end

local deepclone
deepclone = function(tab)
	local copy = clone_tab(tab)
	for k, v in pairs(copy or {}) do
		if type(v) == "table" then
			copy[k] = deepclone(v)
		end
	end
	return copy
end

local merge
merge = function(origin, extend, notdeep)
	if type(extend) ~= "table" then
		return origin
	end

	for k, v in pairs(extend) do
		if v == ngx_null then
			v = nil
		end

		if type(v) == "table" and type(origin[k]) == "table" and not notdeep and not isarray(origin[k]) then
			merge(origin[k], v)
		else
			origin[k] = v
		end
	end

	return origin
end

local tags = setmetatable(new_tab(0, 8), { __mode = "k" })
local pools = new_tab(0, 8)
local max_pool_size = 1024

local set_gc = function(tab, gc)
	local proxy = newproxy(true)
	getmetatable(proxy).__gc = function()
		local ok, err = pcall(gc, tab)
		if not ok then
			core.log.error("gc error: ", err)
		end
	end
	tab[proxy] = true
end

local fetch = function(narr, nrec, tag)
	if not tag then
		return new_tab(narr, nrec)
	end

	local pool = pools[tag]
	if not pool then
		pool = new_tab(8, 2)
		pool.num = 0
		pools[tag] = pool
	end

	local len = pool.num
	local tab = nil
	if len > 0 then
		tab = pool[len]
		pool[len] = nil
		pool.num = len - 1
	else
		tab = new_tab(narr, nrec)
	end

	tags[tab] = tag
	return tab
end

local release = function(tab, noclear)
	if not tab then
		return
	end

	if not noclear then
		setmetatable(tab, nil)
		clear_tab(tab)
	end

	local tag = tags[tab]
	if tag then
		local pool = pools[tag]
		if not pool then
			pool = new_tab(8, 2)
			pool.num = 0
			pools[tag] = pool
		end

		if pool.num + 1 < max_pool_size then
			pool.num = pool.num + 1
			pool[pool.num] = tab
		end

		tags[tab] = nil
	end
end

table.new = fetch
table.clear = clear_tab
table.clone = clone_tab
table.release = release
table.length = nkeys
table.isarray = isarray
table.isempty = isempty
table.merge = merge
table.gc = set_gc

table.deepclone = function(tab)
	if type(tab) ~= "table" then
		return nil, "not a table"
	end
	return deepclone(tab)
end

table.join = function(tab, array)
	if type(tab) ~= "table" then
		return false, "not a table"
	end
	if type(array) ~= "table" then
		return false, "can not join other data"
	end

	local idx = #tab
	for i, v in ipairs(array) do
		tab[idx + i] = v
	end

	return tab
end

table.get_keys = function(tab)
	if type(tab) ~= "table" then
		return false, "not a table"
	end
	local keys = new_tab(nkeys(tab), 0)
	local idx = 1
	for k, _ in pairs(tab) do
		keys[idx] = k
		idx = idx + 1
	end
	return keys
end

return table

