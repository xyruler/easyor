--[[
safe cjson
--]]
local cjson = require "cjson.safe"
--无空洞
cjson.encode_sparse_array(true,1,1)
return cjson