-- Copyright (C) Dejiang Zhu(doujiang24)


local bit = require "bit"
local request = require "resty.kafka.request"

local snappy = require "resty.snappy"

local setmetatable = setmetatable
local byte = string.byte
local sub = string.sub
local rshift = bit.rshift
local lshift = bit.lshift
local char = string.char
local bor = bit.bor
local band = bit.band
local strbyte = string.byte
local crc32 = ngx.crc32_long
local tostring = tostring
local tonumber = tonumber
local concat = table.concat

local ok, new_tab = pcall(require, "table.new")
if not ok then
	new_tab = function (narr, nrec) return {} end
end

local API_VERSION_V0 = 0
local API_VERSION_V1 = 1
local API_VERSION_V2 = 2

local COMPRESS_NO = 0
local COMPRESS_GZIP = 1
local COMPRESS_SNAPPY = 2
local COMPRESS_LZ4 = 3
local COMPRESS_ZSTD = 4

local _M = {}
local mt = { __index = _M }

function _M.new(self, str, api_version)
    local resp = setmetatable({
        str = str,
        maxoffset = #str,
        offset = 1,
        correlation_id = 0,
        api_version = api_version,
    }, mt)

    resp.correlation_id = resp:int32()

    return resp
end

local function to_int16(str, offset)
    local high = byte(str, offset) or 0
    -- high padded
    return bor((high >= 128) and 0xffff0000 or 0, lshift(high, 8), (byte(str, offset + 1) or 0))
end

function _M.int16(self)
    local offset = self.offset
    self.offset = offset + 2

    return to_int16(self.str,offset)
end

local function to_int32(str, offset)
    local offset = offset or 1
    local a, b, c, d = strbyte(str, offset, offset + 3)
    return bor(lshift((a or 0), 24), lshift((b or 0), 16), lshift((c or 0), 8), (d or 0))
end
_M.to_int32 = to_int32

function _M.int32(self)
    local offset = self.offset
    self.offset = offset + 4

    return to_int32(self.str, offset)
end

local function to_int64(str,offset)
    local a, b, c, d, e, f, g, h = strbyte(str, offset, offset + 7)

    --[[
    -- only 52 bit accuracy
    local hi = bor(lshift(a, 24), lshift(b, 16), lshift(c, 8), d)
    local lo = bor(lshift(f, 16), lshift(g, 8), h)
    return hi * 4294967296 + 16777216 * e + lo
    --]]

    return 4294967296LL * bor(lshift((a or 0), 56), lshift((b or 0), 48), lshift((c or 0), 40), lshift((d or 0), 32))
            + 16777216LL * (e or 0) + bor(lshift((f or 0), 16), lshift((g or 0), 8), (h or 0))
end

-- XX return cdata: LL
function _M.int64(self)
    local offset = self.offset
    self.offset = offset + 8

    return to_int64(self.str,offset)
end

function _M.string(self)
    local len = self:int16()
    if len <= 0 then return '' end

    local offset = self.offset
    self.offset = offset + len

    return sub(self.str, offset, offset + len - 1)
end

function _M.bytes(self)
    local len = self:int32()
    if len <= 0 then return '' end

    local offset = self.offset
    self.offset = offset + len

    return sub(self.str, offset, offset + len - 1)
end

local function str_int16(int)
    return char(band(rshift(int, 8), 0xff),band(int, 0xff))
end

local function str_int32(int)
    -- ngx.say(debug.traceback())
    return char(band(rshift(int, 24), 0xff),
                band(rshift(int, 16), 0xff),
                band(rshift(int, 8), 0xff),
                band(int, 0xff))
end

-- XX int can be cdata: LL or lua number
local function str_int64(int)
    return char(tonumber(band(rshift(int, 56), 0xff)),
                tonumber(band(rshift(int, 48), 0xff)),
                tonumber(band(rshift(int, 40), 0xff)),
                tonumber(band(rshift(int, 32), 0xff)),
                tonumber(band(rshift(int, 24), 0xff)),
                tonumber(band(rshift(int, 16), 0xff)),
                tonumber(band(rshift(int, 8), 0xff)),
                tonumber(band(int, 0xff)))
end

local check_message_value = nil

local read_one_message_from_value_magic_2 = function(topic,partition,value,of)
    local message = new_tab(0, 12)

    message.topic = topic
    message.partition = partition

    message.offset = to_int64(value,of)
    of = of + 8

    message.size = to_int32(value,of)
    of = of + 4

    of = of + message.size

    if true then 
        core.log.info('read_one_message_from_value_magic_2 todo ....')
        return nil, of
    end

    message.PartitionLeaderEpoch = to_int32(value,of)
    of = of + 4

    message.magic = byte(value,of)
    of = of + 1

    message.crc = to_int32(value,of)
    of = of + 4

    message.attribute = to_int16(value,of)
    of = of + 2

    message.LastOffsetDelta = to_int32(value,of)
    of = of + 4

    message.FirstTimestamp = to_int64(value,of)
    of = of + 8

    message.MaxTimestamp = to_int64(value,of)
    of = of + 8

    message.ProducerId = to_int64(value,of)
    of = of + 8

    message.ProducerEpoch = to_int16(value,of)
    of = of + 2

    message.FirstSequence = to_int32(value,of)
    of = of + 4

    local recordnum = to_int32(value,of)
    of = of + 4

    for i = 1,recordnum do

    end
end

local read_one_message_from_value = function(topic,partition,value,offset)
    local of = offset or 1
    local maxof = #value

    local magic = byte(value,of + 16)
    local attribute = byte(value,of + 17)
    if magic == 2 then
        --todo
        return read_one_message_from_value_magic_2(topic,partition,value,offset)
    end

    local message = new_tab(0, 12)

    message.topic = topic
    message.partition = partition

    message.offset = to_int64(value,of)
    of = of + 8
    if message.offset < 0 then
        return nil, -1
    end

    message.size = to_int32(value,of)
    of = of + 4

    if message.size <= 0 then
        core.log.info('read_one_message_from_value error -> size == 0')
        return nil,of
    end

    message.crc = to_int32(value,of)
    of = of + 4

    message.magic = byte(value,of)
    of = of + 1

    message.attribute = byte(value,of)
    of = of + 1

	if message.magic == API_VERSION_V1 then
		message.timestamp = to_int64(value,of)
		of = of + 8
	end

    local len = to_int32(value,of)
    of = of + 4
    if len > 0 then
        message.key = sub(value, of, of + len - 1)
        of = of + len
    else
        message.key = ''
    end

    len = to_int32(value,of)
    of = of + 4
    if len > 0 then
        message.value = sub(value, of, of + len - 1)
        of = of + len
    else
        message.value = ''
    end

    -- 检查crc值
    local res = sub(value,offset + 16,of - 1)
    if to_int32(str_int32(crc32(res))) == message.crc then
        message.check_crc = 1
    else
        message.check_crc = 0
        core.log.info('check message failed.',to_int32(str_int32(crc32(res))),'<>',message.crc)
    end

    --core.log.info('read one message -> ',message.size,' - ',message.crc, ' - ',message.magic, ' - ',message.attribute, ' - ',message.key,' - ',message.value,' - ', offset + 12 + message.size)

    return message, offset + 12 + message.size
end

local read_gzip_messages = function(topic,partition,value,msgset,idx)
    core.log.info('this is a gzip message. todo...')
	--[[
		0x1f, 0x8b,	
		0x08,
	--]]

    return idx
end

local read_snappy_messages = function(topic,partition,value,msgset,idx)
    --[[
		130, 83, 78, 65, 80, 80, 89, 0, -- SNAPPY magic
		0, 0, 0, 1, -- min version
		0, 0, 0, 1, -- default version
		_, _, _, _,	-- data length
    --]]
	if #value < 20 then return idx end

    local val,err = snappy.uncompress(sub(value,21)) --21
    if val then
        local size = #val
        local of = 1
        local message = nil
        --core.log.info('read snappy messageset ', of , ' / ', size)
        while of < size do
            --core.log.info('read one snapp message ', of , ' / ', size)
            message, of = read_one_message_from_value(topic,partition,val,of)
			idx = check_message_value(topic,partition,message,msgset,idx)
            if of == -1 then
                of = size
            end
		end
    end

    return idx
end

local read_lz4_messages = function(topic,partition,value,msgset,idx)
    core.log.info('this is a zstd message. todo...')
	--[[
		0x04, 0x22, 0x4D, 0x18, // LZ4 magic number
		100,                  // LZ4 flags: version 01, block indepedant, content checksum
		_, _, _, _,...,	-- data
		_, _, _, _,	-- LZ4 checksum
	--]]
	return idx
end

local read_zstd_messages = function(topic,partition,value,msgset,idx)
    core.log.info('this is a lz4 message. todo...')

	return idx
end

check_message_value = function(topic,partition,message,msgset,idx)
    if not message then return idx end
	local compress = band(message.attribute,7)
	if compress == COMPRESS_SNAPPY then
		idx = read_snappy_messages(topic,partition,message.value,msgset,idx)
	elseif compress == COMPRESS_GZIP then
		idx = read_gzip_messages(topic,partition,message.value,msgset,idx)
	elseif compress == COMPRESS_LZ4 then 
		idx = read_lz4_messages(topic,partition,message.value,msgset,idx)
	elseif compress == COMPRESS_ZSTD then 
		idx = read_zstd_messages(topic,partition,message.value,msgset,idx)
	else
		msgset[idx] = message
		idx = idx + 1
	end

	return idx
end

function _M.message_set(self,topic,partition)
    local msgsize = self:int32()
    --core.log.info('topic = ',topic, ' partition = ',partition, ' offset = ',self.offset,' maxoffset = ',self.maxoffset, ' msgsize = ',msgsize)
    if msgsize <= 0 then
        --core.log.info('mesage set is empty.')
        return {}
    end

    local msgset = new_tab(1000,0)
    local maxoffset = msgsize + self.offset - 1
    if maxoffset > self.maxoffset then
        maxoffset = self.maxoffset
    end
    local idx = 1
    local message = nil

    --core.log.info('read message set ',self.offset,' / ',maxoffset)
    while self.offset < maxoffset do
        --core.log.info('read one message ',self.offset,' / ',maxoffset)
        message,self.offset = read_one_message_from_value(topic,partition,self.str,self.offset)
        idx = check_message_value(topic,partition,message,msgset,idx)
        if self.offset == -1 then
            self.offset = maxoffset
        end
    end

    return msgset
end


function _M.correlation_id(self)
    return self.correlation_id
end


return _M
