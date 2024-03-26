--[[
safe cjson
--]]
local cjson = require "cjson.safe"
--无空洞
cjson.encode_sparse_array(true,1,1)
cjson.encode_empty_table_as_object(false)
cjson.encode_number_precision(16)

return cjson