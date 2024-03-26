local pairs = pairs
local type = type

local ngx_today = ngx.today
local ngx_now = ngx.now
local ngx_localtime = ngx.localtime
local string_sub = string.sub
local string_format = string.format
local ngx_re_gsub = ngx.re.gsub
local exec = core.shell.execute

local semaphore = require("ngx.semaphore")

local new_table = core.table.new
local log_info = core.log.info
local log_error = core.log.error
local go = core.go
local cjson_encode = core.cjson.encode

local _M = {}
_M._VERSION = "0.0.1"

local data = new_table(2000, 0)
local seam = semaphore.new()

local server_id = 0

local new_worker = ngx.run_worker_thread

local gen_filename = function(appname)
	local today = ngx_today()
	local localtime = ngx_localtime()
	local hms = ngx_re_gsub(string_sub(localtime, #today + 2), ":", "-")

	local dir = string_format(
		"/%s/%s/%s_%s",
		---@diagnostic disable-next-line: undefined-field
		config.remoteResourcesPath or "tmp",
		today,
		appname,
		today
	)

	exec("mkdir -p " .. dir)

	local filename = string_format("%s/%s_%d.log", dir, hms, server_id)
	local file_struct = {}
	file_struct.filename = filename
	file_struct.today = today

	return file_struct
end

local FILELINE = 1800
local COUNTLINE = 500000
local file_line = {}
local file_name = {}

local function save_data(file_limit)
	local today = ngx_today()

	for appname, appdata in pairs(data) do
		file_name[appname] = file_name[appname] or gen_filename(appname)

		log_info("appname->", appname, " log filename --> ", file_name[appname].filename, ",today-->", today)

		if #appdata >= file_limit or today ~= file_name[appname].today then
			log_info("write data line:" .. #appdata)
			data[appname] = new_table(2000, 0)
			file_line[appname] = (file_line[appname] or 0) + #appdata

			local ok, r1, r2 = new_worker("worker", "data.worker", "writer", appdata, file_name[appname].filename)

			if not ok then
				log_error("write logs failed -> ", r1, r2)
			end

			if file_line[appname] > COUNTLINE then
				file_name[appname] = gen_filename(appname)
				file_line[appname] = 0
			end
		end

		if today ~= file_name[appname].today then
			-- 跨天需要更新文件路径
			file_name[appname] = gen_filename(appname)
		end
	end
end

local writer = function()
	---@diagnostic disable-next-line: undefined-field
	server_id = tonumber(db.redis:incr("statistics:server_id")) + 0

	while not worker.killed do
		---@diagnostic disable-next-line: need-check-nil
		seam:wait(30)
		save_data(FILELINE)
	end

	save_data(1)
end

function _M.run()
	-- 初始化一个thred进行数据的写入文件
	go(0, writer)
end

function _M.report(appname, event)
	event.time = ngx_now()

	if type(event) ~= "table" or not appname then
		return false
	end

	if not event.event_id then
		return false
	end

	log_info("report: appname=" .. appname .. "---" .. cjson_encode(event))
	if not data[appname] then
		data[appname] = {}
	end

	local n = #data[appname] + 1

	data[appname][n] = cjson_encode(event)
	if n >= FILELINE then
		---@diagnostic disable-next-line: need-check-nil
		seam:post(1)
	end
end

return _M
