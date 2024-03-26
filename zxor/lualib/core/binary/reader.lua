local bit = require "bit"

local setmetatable = setmetatable
local gsub = string.gsub
local byte = string.byte
local sub = string.sub
local char = string.char

local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor

local tonumber = tonumber

local _M = {}
_M._VERSION = '0.01'

local power_2 = {}
for i = 0,64 do
	power_2[i] = 2^i
end

local mt = { __index = _M }

_M.new = function(self, data, opts)
	if type(data) ~= 'string' or #data == 0 then return nil,'no data' end

    opts = opts or {}
	if not opts.little_endian then opts.little_endian = true end
	if opts and opts.base == 'hex' then
		data = gsub(data, '%%(%x%x)', function(h) 
			return char(tonumber(h, 16))
		end)
	end

    return setmetatable({
        data = data,
		offset = 1,
		length = #data,
		opts = opts,
    }, mt)
end

_M.rewind = function(self)
    self.offset = 1
end

_M.skip = function(self, length)
    self.offset = self.offset + length
end

local _read = function(self,length)
	if self.offset + length > self.length then
		return nil, nil, 'not enough length.'
	end

	local offset = self.offset
	self.offset = self.offset + length

	return offset, offset + length - 1
end

local _read_as_number = function (self,length)
	local sidx, eidx, err = _read(self, length)
	if not sidx or not eidx then
		return nil, err
	end

	local tmp = {byte(self.data, sidx, eidx)}
	if not self.opts.little_endian then
		for i = 1, length / 2, 1 do
			tmp[i],tmp[length-i+1] = tmp[length-i+1],tmp[i]
		end
	end

	local ret = 0
	local bits = 0
	for i,v in ipairs(tmp) do
		ret = bor(ret,lshift(v,bits))
		bits = bits + 8
	end
	return ret
end

local _read_as_string = function (self, length)
	local sidx, eidx, err = _read(self, length)
	if not sidx or not eidx then
		return nil, err
	end

	return sub(self.data, sidx, eidx)
end

_M.uint8 = function(self)
    return _read_as_number(self,1)
end

_M.int8 = function(self)
    local ret,err = _read_as_number(self,1)
    if not ret then return ret,err end
    if ret > power_2[7] then ret = ret - power_2[8] end
    return ret
end

_M.uint16 = function(self)
    return _read_as_number(self,2)
end

_M.int16 = function(self)
    local ret,err = _read_as_number(self,2)
    if not ret then return ret,err end
    if ret > power_2[15] then ret = ret - power_2[16] end
    return ret
end

_M.uint32 = function(self)
    return _read_as_number(self,4)
end

_M.int32 = function(self)
    local ret,err = _read_as_number(self,4)
    if not ret then return ret,err end
    if ret > power_2[31] then ret = ret - power_2[32] end
    return ret
end

_M.uint64 = function(self)
    return _read_as_number(self,8)
end

_M.int64 = function(self)
    local ret,err = _read_as_number(self,8)
    if not ret then return ret,err end
    if ret > power_2[63] then ret = ret - power_2[64] end
    return ret
end

_M.float32 = function(self)
    local ret,err = _read_as_number(self,4)
    if not ret then return ret,err end
    local sign = band(rshift(ret,31),1)
    local exponent = band(rshift(ret,23),0xff)
    local mantissa = band(ret,0x7fffff)
    if exponent == 0xff then
        if mantissa == 0 then
            if sign == 0 then
                return math.huge
            else
                return -math.huge
            end
        else
            return 0/0
        end
    end
    if exponent == 0 then
        exponent = -126
    else
        exponent = exponent - 127
        mantissa = bor(mantissa,power_2[23])
    end
end

_M.float64 = function(self)
    local ret,err = _read_as_number(self,8)
    if not ret then return ret,err end
    local sign = band(rshift(ret,63),1)
    local exponent = band(rshift(ret,52),0x7ff)
    local mantissa = band(ret,0xfffffffffffff)
    if exponent == 0x7ff then
        if mantissa == 0 then
            if sign == 0 then
                return math.huge
            else
                return -math.huge
            end
        else
            return 0/0
        end
    end
    if exponent == 0 then
        exponent = -1022
    else
        exponent = exponent - 1023
        mantissa = bor(mantissa,power_2[52])
    end
    local value = (sign == 0 and 1 or -1) * mantissa * power_2[exponent - 52]
    return value
end

_M.bytes = function(self, length)
    return _read_as_string(self, length)
end

_M.bool = function(self)
    local ret,err = _read_as_number(self,1)
    if not ret then return ret,err end
    return ret ~= 0
end

return _M