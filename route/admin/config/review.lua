local respond = core.respond
local scripts = require("data.scripts")
local ddl = require("common.ddl")

-- local server_list = {
--     {
--         name = "正式服",
--         server = "https://intranet-dataanalysis-test-admin.laiyouxi.com:1443/"
--     }
-- }


local _M = function(args, headers)
    local appname = args.appname
    if not args.appname then
        return respond(502, nil, 'appname is empty', nil)
    end

    local data = {}

    local scripts_list, _ = scripts.get(appname)

    local table_list, _ = ddl.get_table(appname)

    data.scripts_list = scripts_list
    data.table_list = table_list
    -- data.server_list = server_list


    return respond(0, data, 'ok', nil)
end

return _M
