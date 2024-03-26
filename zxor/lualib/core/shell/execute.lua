--执行linux命令
local shell = require "resty.shell"
local _M = function(cmd, stdin, timeout, max_size)
    local ok, out, err, reason, status = shell.run(cmd, stdin, timeout, max_size)
    if not ok then
        return nil, reason, status
    end
    return out, err, status
end

return _M