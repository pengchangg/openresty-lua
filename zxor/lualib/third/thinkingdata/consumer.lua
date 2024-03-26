local semaphore = require("ngx.semaphore")
local core_table = require("core.table")
local go = core.go
local sleep = ngx.sleep
local new_table = core_table.new
local del_table = core_table.release
local clear_table = core_table.clear
local t_remove = table.remove
local encode = core.cjson.encode
local post = core.http.post

local get_host_from_url = core.dns.get_host_from_url

local update_time = ngx.update_time
local localtime = ngx.localtime

local _M = { _VERSION = "0.01" }

local mt = { __index = _M }

local platForm = "Lua"
local version = "1.2.0"

_M.new = function(self, url, appname, batch)
	batch = tonumber(batch) or 20
	local ctx = {
		url = url,
		appid = appname,
		batch = batch,
		sema = semaphore:new(),
		sema_push = semaphore:new(),
		messages = new_table(batch + 10, 0, "third.thinkingdata.consumer.messages"),
		header = {
			["appid"] = appname,
			["TA-Integration-Type"] = platForm,
			["TA-Integration-Version"] = version,
			["TA-Integration-Count"] = 0,
			["Content-Type"] = "application/json",
		},
		superProperties = {},
	}

	return setmetatable(ctx, mt)
end

local _push = function(self, set, failed)
	local req_num = 0
	while self.inwork and not worker.killed do
		if not self.nurl then
			local _, nurl = get_host_from_url(self.url)
			self.nurl = nurl
		end

		if #self.messages > 0 then
			set[#set + 1] = self.messages
			self.messages = new_table(self.batch + 10, 0, "third.thinkingdata.consumer.messages")
		end

		if #set > 0 then
			for _, messages in ipairs(set) do
				self.header["TA-Integration-Count"] = #messages
				local ok, rs = core.http.post(self.nurl or self.url, nil, messages, self.header)
				--core.log.info(ok,'---',core.cjson.encode(rs))
				if not ok then
					failed[#failed + 1] = messages
					core.log.info("report to thinkingdata failed. ->", rs)
				else
					for _, message in ipairs(messages) do
						if message.properties then
							del_table(message.properties)
						end
						del_table(message)
					end
					del_table(messages)
				end

				req_num = req_num + 1
			end

			if #failed >= 9 then
				del_table(t_remove(failed, 1))
			end

			set, failed = failed, set
			clear_table(failed)

			if req_num > 1000 then
				break
			end
		end

		self.sema:wait(5)
	end

	self.in_push = false
	self.sema_push:post(1)
end

local _start = function(self)
	self.inwork = true
	local set = new_table(10, 0)
	local failed = new_table(10, 0)

	while self.inwork and not worker.killed do
		if not self.in_push then
			self.in_push = true
			core.go(0, _push, self, set, failed)
		end

		self.sema_push:wait(30)
	end

	self.inwork = false
end

_M.start = function(self)
	core.go(0, _start, self)
end

_M.stop = function(self)
	self.inwork = false
end

_M.add_super_property = function(self, name, value)
	self.superProperties[name] = value
end

_M.del_super_property = function(self, name)
	self.superProperties[name] = nil
end

_M.get_superProperties = function(self)
	return self.superProperties
end

_M.clear_superProperties = function(self)
	clear_table(self.superProperties)
end

local preset_props = { "#ip", "#uuid", "#first_check_id", "#time", "#app_id" }
local track_event = {
	track = 1,
	track_update = 1,
	track_overwrite = 1,
}

local check = function(distinctId, accountId, eventType, eventName, eventId, properties)
	if not distinctId and not accountId then
		return false, "distinctId和accountId不能同时为空"
	end
	local ty = type(distinctId)
	if distinctId and ty ~= "string" and ty ~= "number" then
		return false, "distinctId参数应该为数字或字符串"
	end

	ty = type(accountId)
	if accountId and ty ~= "string" and ty ~= "number" then
		return false, "accountId参数应该为数字或字符串"
	end

	ty = type(eventType)
	if ty ~= "string" then
		return false, "type参数应该为字符串类型"
	end

	ty = type(eventName)
	if eventName and ty ~= "string" then
		return false, "eventName应该为字符串类型"
	end

	ty = type(properties)
	if ty ~= "table" then
		return false, "properties应该为Table类型"
	end

	if track_event[eventType] then
		if not eventName or #eventName == 0 then
			return false, "type为track、track_update或track_overwrite时，eventName不能为空"
		end
		if eventType ~= "track" then
			if not eventId or #eventId == 0 then
				return false, "type为track_update或track_overwrite时，eventId不能为空"
			end
		end
	end

	return true
end

local make_event_message = function(distinctId, accountId, eventType, eventName, eventId, properties, superProperties)
	local ok, err = check(distinctId, accountId, eventType, eventName, eventId, properties)
	if not ok then
		return false, err
	end

	local event = new_table(0, 20, "third.thinkingdata.event")
	event["#account_id"] = accountId
	event["#distinct_id"] = distinctId
	event["#type"] = eventType
	event["#event_name"] = eventName
	event["#event_id"] = eventId

	if properties then
		for _, prop in ipairs(preset_props) do
			event[prop] = properties[prop]
		end
	end

	if not event["#time"] then
		update_time()
		event["#time"] = localtime()
	end

	local mergeProperties = new_table(0, 20, "third.thinkingdata.event.moreprop")
	for prop, value in pairs(superProperties or {}) do
		mergeProperties[prop] = value
	end
	for prop, value in pairs(properties or {}) do
		if not event[prop] then
			mergeProperties[prop] = value
		end
	end
	if track_event[eventType] then
		mergeProperties["#lib"] = platForm
		mergeProperties["#lib_version"] = version
	end

	event.properties = mergeProperties

	return event
end

_M.append = function(self, event, addsup)
	local event_message, err = make_event_message(
		event.distinctId,
		event.accountId,
		event.type,
		event.name,
		event.id,
		event.properties,
		addsup and self.superProperties or nil
	)
	if not event_message then
		return false, err
	end

	self.messages[#self.messages + 1] = event_message
	if #self.messages >= self.batch then
		self.sema:post(1)
	end

	return true
end

_M.userSet = function(self, accountId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "user_set"

	local ok, err = self:append(event)
	del_table(event)
	return ok, err
end

_M.userSetOnce = function(self, accountId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "user_setOnce"

	local ok, err = self:append(event)
	del_table(event)
	return ok, err
end

_M.userAdd = function(self, accountId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "user_add"

	local ok, err = self:append(event)
	del_table(event)
	return ok, err
end

_M.userAppend = function(self, accountId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "user_append"

	local ok, err = self:append(event)
	del_table(event)
	return ok, err
end

_M.userUnset = function(self, accountId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	local unSetProperties = new_table(0, 20, "third.thinkingdata.event.moreprop")
	for key, _ in pairs(properties or {}) do
		unSetProperties[properties[key]] = 0
	end

	event.accountId = accountId
	event.properties = unSetProperties
	event.type = "user_unset"

	local ok, err = self:append(event)
	del_table(unSetProperties)
	del_table(event)
	return ok, err
end

_M.userDel = function(self, accountId)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.type = "user_del"

	local ok, err = self:append(event)
	del_table(event)
	return ok, err
end

_M.track = function(self, accountId, eventName, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "track"
	event.name = eventName

	local ok, err = self:append(event, true)
	del_table(event)
	return ok, err
end

_M.trackUpdate = function(self, accountId, eventName, eventId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "track_update"
	event.name = eventName
	event.id = eventId

	local ok, err = self:append(event, true)
	del_table(event)
	return ok, err
end

_M.trackOverwrite = function(self, accountId, eventName, eventId, properties)
	local event = new_table(0, 20, "third.thinkingdata.event")

	event.accountId = accountId
	event.properties = properties
	event.type = "track_overwrite"
	event.name = eventName
	event.id = eventId

	local ok, err = self:append(event, true)
	del_table(event)
	return ok, err
end

return _M

