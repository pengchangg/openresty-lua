
local setmetatable = setmetatable
local type = type

local bit = require "bit"
local rshift = bit.rshift
local band = bit.band

local char = string.char
local concat = table.concat
local new_tab = require('core.table').new

local _M = {}
_M._VERSION = '0.01'

local mt = { __index = _M }

_M.new = function(self, opts)
    opts = opts or {}
	opts.little_endian = opts.little_endian or true

    return setmetatable({
        data = {},
		offset = 1,
		opts = opts,
    }, mt)
end

local _to_bytes = function(number,len,little_endian)
	local ret = new_tab(len,0)
	local bits = 0
	for i = 1,len do
		ret[i] = char(band(rshift(number,bits),0xff))
		bits = bits + 8
	end

	if little_endian then
		for i = 1, len / 2, 1 do
			ret[i],ret[len-i] = ret[len-i],ret[i]
		end
	end

	return concat(ret)
end

local _write = function(self,bytes)
	self.data[self.offset] = bytes
	self.offset = self.offset + 1
	return true
end

_M.uint8 = function(self,int)
	if type(int) ~= "number" or int < 0 or int > 255 then
		return nil, "uint8 must be a number between 0 and 255"
	end
	return _write(self,_to_bytes(int,1,self.opts.little_endian))
end

_M.int8 = function(self,int)
	if type(int) ~= "number" or int < -128 or int > 127 then
		return nil, "int8 must be a number between -128 and 127"
	end
	return _write(self,_to_bytes(int,1,self.opts.little_endian))
end

_M.uint16 = function(self,int)
	if type(int) ~= "number" or int < 0 or int > 65535 then
		return nil, "uint16 must be a number between 0 and 65535"
	end
	return _write(self,_to_bytes(int,2,self.opts.little_endian))
end

_M.int16 = function(self,int)
	if type(int) ~= "number" or int < -32768 or int > 32767 then
		return nil, "int16 must be a number between -32768 and 32767"
	end
	return _write(self,_to_bytes(int,2,self.opts.little_endian))
end

_M.uint32 = function(self,int)
	if type(int) ~= "number" or int < 0 or int > 4294967295 then
		return nil, "uint32 must be a number between 0 and 4294967295"
	end
	return _write(self,_to_bytes(int,4,self.opts.little_endian))
end

_M.int32 = function(self,int)
	if type(int) ~= "number" or int < -2147483648 or int > 2147483647 then
		return nil, "int32 must be a number between -2147483648 and 2147483647"
	end
	return _write(self,_to_bytes(int,4,self.opts.little_endian))
end

_M.uint64 = function(self,int)
	if type(int) ~= "number" or int < 0 or int > 18446744073709551615 then
		return nil, "uint64 must be a number between 0 and 18446744073709551615"
	end
	return _write(self,_to_bytes(int,8,self.opts.little_endian))
end

_M.int64 = function(self,int)
	if type(int) ~= "number" or int < -9223372036854775808 or int > 9223372036854775807 then
		return nil, "int64 must be a number between -9223372036854775808 and 9223372036854775807"
	end
	return _write(self,_to_bytes(int,8,self.opts.little_endian))
end

_M.bytes = function(self,bytes)
	if type(bytes) ~= "string" then
		return nil, "bytes must be a string"
	end
	return _write(self,bytes)
end

_M.bool = function(self,bool)
	return _write(self,_to_bytes(bool and 1 or 0, 1, self.opts.little_endian))
end

_M.package = function(self)
	return concat(self.data)
end

return _M
