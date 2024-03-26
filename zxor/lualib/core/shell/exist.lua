--判定文件是否存在
local shell = require "resty.shell"

local _M = function(path)
	local ok, _, err = shell.run("test -f " .. path)
	if not ok then
		return false, err
	end
	return true
end

return _M
