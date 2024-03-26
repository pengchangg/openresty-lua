---@diagnostic disable-next-line: undefined-field
local cache_user = cache.user

local _M = {}

_M.new = function(self, appname, id)
	local user = {}
	user.appname = appname
	user.id = id
	user.flag = appname .. ":" .. id
	return setmetatable(user, { __index = _M })
end

function _M.set(self, new_attrs, update)
	local attrs = cache_user:get(self.flag) or {}

	local upattrs = {}
	for name, value in pairs(new_attrs) do
		if update or attrs[name] == nil then
			upattrs[name] = value
		end
	end

	return cache_user:set(self.flag, upattrs)
end

return _M
