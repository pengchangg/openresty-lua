local ffi        = require "ffi"
local ffi_new    = ffi.new
local ffi_typeof = ffi.typeof
local ffi_cdef   = ffi.cdef
local ffi_load   = ffi.load
local ffi_str    = ffi.string
local C          = ffi.C

ffi_cdef[[
typedef enum {
  SNAPPY_OK = 0,
  SNAPPY_INVALID_INPUT = 1,
  SNAPPY_BUFFER_TOO_SMALL = 2
} snappy_status;
snappy_status snappy_compress(const char* input, size_t input_length, char* compressed, size_t* compressed_length);
snappy_status snappy_uncompress(const char* compressed, size_t compressed_length, char* uncompressed, size_t* uncompressed_length);
size_t snappy_max_compressed_length(size_t source_length);
snappy_status snappy_uncompressed_length(const char* compressed, size_t compressed_length, size_t* result);
snappy_status snappy_validate_compressed_buffer(const char* compressed, size_t compressed_length);
]]

local ok, libsnappy = pcall(ffi_load, (core.myor_prefix or './zxor') .. "/lualib/resty/snappy/libsnappy.so")
if not ok then
    core.log.info('ERROR: load snappy lib failed. err = ', libsnappy)
    libsnappy = nil
end
local char_t = ffi_typeof("char[?]")
local size_t = ffi_typeof("size_t[1]")
local snappy = {}

function snappy.compress(input)
    if not libsnappy then return nil,'no libsnappy' end
    local input_length = #input
    local max_length = snappy.max_compressed_length(input_length)
    local compressed = ffi_new(char_t, max_length)
    local compressed_length = ffi_new(size_t)
    compressed_length[0] = tonumber(max_length)
    local status = libsnappy.snappy_compress(input, input_length, compressed, compressed_length)
    local len = tonumber(compressed_length[0])
    if (status == C.SNAPPY_OK) then
        return ffi_str(compressed, len), len
    else
        return nil, tonumber(status)
    end
end

function snappy.uncompress(compressed)
    if not libsnappy then return nil,'no libsnappy' end
    local compressed_length   = #compressed
    local uncompressed_length = ffi_new(size_t)
    local status = libsnappy.snappy_uncompressed_length(compressed, compressed_length, uncompressed_length)
    if (status ~= C.SNAPPY_OK) then
        return nil, tonumber(status)
    end
    local uncompressed = ffi_new(char_t, tonumber(uncompressed_length[0]))
    status = libsnappy.snappy_uncompress(compressed, compressed_length, uncompressed, uncompressed_length)
    local len = tonumber(uncompressed_length[0])
    if (status == C.SNAPPY_OK) then
        return ffi_str(uncompressed, len), len
    else
        return nil, tonumber(status)
    end
end

function snappy.max_compressed_length(source_length)
    if not libsnappy then return 0,'no libsnappy' end
    return tonumber(libsnappy.snappy_max_compressed_length(source_length))
end

function snappy.uncompressed_length(compressed)
    if not libsnappy then return nil,'no libsnappy' end
    local result = ffi_new(size_t)
    local status = libsnappy.snappy_uncompressed_length(compressed, #compressed, result)
    if (status == C.SNAPPY_OK) then
        return tonumber(result[0])
    else
        return nil
    end
end

function snappy.validate_compressed_buffer(compressed)
    if not libsnappy then return false,'no libsnappy' end
    local status = libsnappy.snappy_validate_compressed_buffer(compressed, #compressed)
    return status == C.SNAPPY_OK
end

return snappy