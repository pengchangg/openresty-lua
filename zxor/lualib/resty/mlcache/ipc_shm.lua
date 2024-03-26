-- vim: st=4 sts=4 sw=4 et:

local shared       = ngx.shared
local setmetatable = setmetatable
local lrucache   = require "resty.lrucache"

local _M = {}
local mt = { __index = _M }

function _M.new(shm, debug, size)
    local dict = shared[shm]
    if not dict then
        return nil, "no such lua_shared_dict: " .. shm
    end

    local self    = {
        dict      = dict,
        lru       = lrucache.new(size),
    }

    return setmetatable(self, mt)
end


function _M:subscribe(channel, cb)
    return nil
end

--缓存值改变时，值版本号+1
function _M:broadcast(channel, key)
    if key == "" then
        -- purge
        self.dict:flush_all()
        self.lru:flush_all()
    else
        local version = self.dict:incr(key, 1, 0)
        if version then
            self.lru:set(key, version)
        else
            self.lru:delete(key)
        end
    end

    return true
end

function _M:poll(key, timeout)
    local version, err = self.dict:get(key)
    if not version or err then
        version = self.dict:incr(key, 1, 0)
        self.lru:set(key, version)
        return "update"
    end

    local curverison = self.lru:get(key)
    self.lru:set(key, version)
    if not curverison or curverison < version then
        return 'update'
    end

    return true
end


return _M
