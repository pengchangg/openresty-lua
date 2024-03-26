-- vim: st=4 sts=4 sw=4 et:

local ERR          = ngx.ERR
local WARN         = ngx.WARN
local INFO         = ngx.INFO
local sleep        = ngx.sleep
local shared       = ngx.shared
local worker_pid   = ngx.worker.pid
local ngx_log      = ngx.log
local fmt          = string.format
local sub          = string.sub
local find         = string.find
local min          = math.min
local type         = type
local pcall        = pcall
local error        = error
local insert       = table.insert
local tonumber     = tonumber
local setmetatable = setmetatable


local INDEX_KEY        = "lua-resty-ipc:index"
local FORCIBLE_KEY     = "lua-resty-ipc:forcible"

local function marshall(worker_pid, channel, data)
    return fmt("%d:%d:%s%s", worker_pid, #data, channel, data)
end


local function unmarshall(str)
    local sep_1 = find(str, ":", nil      , true)
    local sep_2 = find(str, ":", sep_1 + 1, true)

    local pid      = tonumber(sub(str, 1        , sep_1 - 1))
    local data_len = tonumber(sub(str, sep_1 + 1, sep_2 - 1))

    local channel_last_pos = #str - data_len

    local channel = sub(str, sep_2 + 1, channel_last_pos)
    local data    = sub(str, channel_last_pos + 1)

    return pid, channel, data
end


local function log(lvl, ...)
    return ngx_log(lvl, "[ipc] ", ...)
end


local _M = {}
local mt = { __index = _M }


function _M.new(shm, debug)
    local dict = shared[shm]
    if not dict then
        return nil, "no such lua_shared_dict: " .. shm
    end

    local self    = {
        dict      = dict,
        pid       = debug and 0 or worker_pid(),
        idx       = 0,
        callbacks = {},
    }

    return setmetatable(self, mt)
end


function _M:subscribe(channel, cb)
    if type(channel) ~= "string" then
        error("channel must be a string", 2)
    end

    if type(cb) ~= "function" then
        error("callback must be a function", 2)
    end

    self.callbacks[channel] = cb
end

function _M:broadcast(channel, data)
    if type(channel) ~= "string" then
        error("channel must be a string", 2)
    end

    if type(data) ~= "string" then
        error("data must be a string", 2)
    end

    local marshalled_event = marshall(worker_pid(), channel, data)

    local idx, err = self.dict:incr(INDEX_KEY, 1, 0)
    if not idx then
        return nil, "failed to increment index: " .. err
    end

    local ok, err, forcible = self.dict:set(idx, marshalled_event)
    local trynum = 0
    while not ok and forcible and trynum < 100 do
        ok, err, forcible = self.dict:set(idx, marshalled_event)
        trynum = trynum + 1
    end

    if not ok then
        return nil, "failed to insert event in shm: " .. err
    end

    if forcible then
        -- take note that eviction has started
        -- we repeat this flagging to avoid this key from ever being
        -- evicted itself
        local ok, err = self.dict:set(FORCIBLE_KEY, true)
        if not ok then
            return nil, "failed to set forcible flag in shm: " .. err
        end
    end

    return true
end


-- Note: if this module were to be used by users (that is, users can implement
-- their own pub/sub events and thus, callbacks), this method would then need
-- to consider the time spent in callbacks to prevent long running callbacks
-- from penalizing the worker.
-- Since this module is currently only used by mlcache, whose callback is an
-- shm operation, we only worry about the time spent waiting for events
-- between the 'incr()' and 'set()' race condition.
function _M:poll(key, timeout)
    if timeout ~= nil and type(timeout) ~= "number" then
        error("timeout must be a number", 2)
    end

    local shm_idx, err = self.dict:get(INDEX_KEY)
    if err then
        return nil, "failed to get index: " .. err
    end

    if shm_idx == nil then
        -- no events to poll yet
        return true
    end

    if type(shm_idx) ~= "number" then
        return nil, "index is not a number, shm tampered with"
    end

    if not timeout then
        timeout = 0.002
    end

    if self.idx == 0 then
        local forcible, err = self.dict:get(FORCIBLE_KEY)
        if err then
            return nil, "failed to get forcible flag from shm: " .. err
        end

        if forcible then
            -- shm lru eviction occurred, we are likely a new worker
            -- skip indexes that may have been evicted and resume current
            -- polling idx
            self.idx = shm_idx - 1
        end

    else
        -- guard: self.idx <= shm_idx
        self.idx = min(self.idx, shm_idx)
    end

	local curidx = self.idx
	self.idx = shm_idx
	
	local wait_for_another = 0
	local update_num = 0
	while curidx < shm_idx do
        -- fetch event from shm with a retry policy in case
        -- we run our :get() in between another worker's
        -- :incr() and :set()
        local v
        local idx = curidx + 1

		v, err = self.dict:get(idx)
		
		if not v and not err and wait_for_another == 0 then
			wait_for_another = 1
			sleep(0.01)
			v, err = self.dict:get(idx)
		end
		
        -- fetch next event on next iteration
        -- even if we timeout, we might miss 1 event (we return in timeout and
        -- we don't retry that event), but it's better than being stuck forever
        -- on an event that might have been evicted from the shm.
		curidx = idx
 
        if err then
            log(ERR, "could not get event at index '", curidx, "': ", err)
        elseif type(v) ~= "string" then
            log(ERR, "event at index '", curidx, "' is not a string, ", "shm tampered with")
        else
            local pid, channel, data = unmarshall(v)

            if self.pid ~= pid then
                -- coming from another worker
                local cbs = self.callbacks[channel]
                if cbs then
					cbs(data)
                end
            end
        end
		
		update_num = update_num + 1
		if update_num % 500 == 0 then
			sleep(0.001)
		end
    end

    return true
end


return _M
