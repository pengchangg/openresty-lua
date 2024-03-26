--[[
实体对象管理
--]]
local config = config
local entity = core.entity

local entities = {}
local entity_init_param = {}

local _M = {}

local _new_entity = function(eid,et,init_args)
	if not entity_init_param[et] then return nil end
	
	local ent_param = entity_init_param[et]
	
	local ent = entity:new(eid,et,ent_param.heart)
	
	if ent_param.init then
		if not ent_param.init(ent,init_args) then return nil end
	end
	
	ent:init(ent_param.on_message,ent.on_heart,ent.on_destroy)
	ent.cache = entity_init_param[et].cache
	
	return ent
end

_M.get = function(eid,et,notcreate,init_args)
	et = et or 0
	entities[et] = entities[et] or {}

	if not entities[et][eid] and not notcreate then
		entities[et][eid] = _new_entity(eid,et,init_args)
		if not entities[et][eid] then return false,'new entity error' end
	end
	
	return entities[et][eid]
end

_M.set = function(eid,et,entity)
	if not eid then return false end
	et = et or 0
	entities[et] = entities[et] or {}
	entities[et][eid] = entity
	
	return true
end

_M.del = function(eid,et)
	if not eid then return true end
	et = et or 0
	if entities[et] then
		if entities[et][eid] then
			entities[et][eid]:destory(0,true)
		end
		entities[et][eid] = nil
	end
	
	return true
end

_M.clear = function(code)
	for et,ets in pairs(entities) do
		for eid,entity in pairs(ets) do
			if entity then
				entity:destory(code,false)
			end
			entities[et][eid] = nil
		end
		entities[et] = nil
	end
	entities = {}
end

_M.set_entity_params = function(et,init,on_message,on_heart,on_destroy,cache)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].init = init
	entity_init_param[et].on_message = on_message
	entity_init_param[et].on_heart = on_heart
	entity_init_param[et].on_destroy = on_destroy
	entity_init_param[et].cache = cache
end

_M.entity_init = function(et,init)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].init = init
end

_M.on_message = function(et,on_message)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].on_message = on_message
end

_M.on_heart = function(et,on_heart,heart)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].on_heart = on_heart
	entity_init_param[et].heart = heart or 1
end

_M.on_destroy = function(et,on_destroy)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].on_destroy = on_destroy
end

_M.bind_cache = function(et,cache)
	et = et or 0
	entity_init_param[et] = entity_init_param[et] or {}
	entity_init_param[et].cache = cache
end

_M.get_entity_types = function()
	local rs = {}
	for et,_ in pairs(entity_init_param) do
		rs[#rs + 1] = et
	end
	return rs
end

_M.get_entities = function(et)
	if not et then
		return entities
	else
		return entities[et]
	end
end

return _M