-- vim: st=4 sts=4 sw=4 et:

local ERR          = ngx.ERR
local WARN         = ngx.WARN
local INFO         = ngx.INFO
local sleep        = ngx.sleep
local shared       = ngx.shared
local worker_pid   = ngx.worker.pid
local worker_id    = ngx.worker.id
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

local ngx_process = require "ngx.process" 
local semaphore = require "ngx.semaphore"

local function marshall(pid, wid, data)
    return fmt("%d:%d:%s", pid, wid, data)
end

local function unmarshall(str)
    local sep_1 = find(str, ":", nil, true)
	local sep_2 = find(str, ":", sep_1 + 1, true)
	local pid  = tonumber(sub(str, 1, sep_1 - 1))
	local wid  = tonumber(sub(str, sep_1 + 1, sep_2 - 1))
    local data = sub(str, sep_2 + 1)

    return pid, wid, data
end

local _M = {}
local mt = { __index = _M }

function _M.new(redis_name)
    local rds = db[redis_name]
    if not rds then
        return nil, "no such redis: " .. redis_name
    end

    local self    = {
        rds       = rds,
		channels = {},
		bcpool = {},
    }

    return setmetatable(self, mt)
end

function _M:subscribe(channel, callback)
    if type(channel) ~= "string" then
        error("channel must be a string", 2)
    end

    if type(callback) ~= "function" then
        error("callback must be a function", 2)
    end

	if self.channels[channel] then
		return true
	end

	local mypid = ngx_process.get_master_pid()
	local mywid = worker_id()
	local rds = self.rds

	self.channels[channel] = true
	core.go(0, function ()
		rds:subscribe(channel, function (message)
			local frompid, fromwid, data = unmarshall(message)
			if mypid ~= frompid then
				callback(data,mywid == 0)
			elseif mywid ~= fromwid then
				callback(data,false)
			end
		end)
	end)
end

local start_bc = function (self, channel)
	local bc = self.bcpool[channel]
	if not bc then
		bc = {
			sema = semaphore:new(),
			events = {},
			add = function (this, event)
				insert(this.events,event)
				this.sema:post(1)
			end
		}
		bc.running = true
		self.bcpool[channel] = bc

		local rds = self.rds
		local bcfun = function (events)
			local pipe = rds:init_pipeline()
			if pipe then
				for _, event in ipairs(events) do
					pipe:publish(channel,event)
				end
				local _,err = rds:commit_pipeline(pipe)
				if err then
					return false, err
				end
			else
				return false, 'new pipe failed'
			end

			return true
		end

		core.go(0,function ()
			local events = {}
			local cleartable = core.table.clear
			
			while true do
				if #events > 0 then
					if not bcfun(events) then
						core.log.error('ipc_redis broadcast failed')
					end
					cleartable(events)
				elseif #bc.events > 0 then
					events, bc.events = bc.events, events
					if bcfun(events) then
						cleartable(events)
					end
				else
					if worker.killed then
						break
					end
					bc.sema:wait(3)
				end
			end

			bc.running = false
			self.bcpool[channel] = nil
		end)
	end

	if not bc or not bc.running then
		return nil
	end

	return bc
end

function _M:broadcast(channel, data)
    if type(channel) ~= "string" then
        error("channel must be a string", 2)
    end

    if type(data) ~= "string" then
        error("data must be a string", 2)
    end

	if not self.pid then
		self.pid = ngx_process.get_master_pid()
	end
	if not self.wid then
		self.wid = ngx.worker.id()
	end

    local marshalled_event = marshall(self.pid, self.wid, data)
	local bc = start_bc(self, channel)
	if bc then
		return bc:add(marshalled_event)
	else
		return self.rds:publish(channel,marshalled_event)
	end
end

function _M:poll(key, timeout)
    return true
end


return _M
