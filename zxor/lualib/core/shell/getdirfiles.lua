local t_insert = table.insert
local s_gsub = ngx.re.gsub
local s_find = string.find
local s_upper = string.upper
local split = require 'core.string.split'

local is_win = nil
local sys_is_window = function()
	if is_win ~= nil then return is_win end
	local ostype = s_upper(os.getenv("OS") or "")
	return s_find(ostype,"WIN",1,true)
end

local getfiles_in_linux = nil
getfiles_in_linux = function (dir,ext,files,keepext)
	files = files or {}
	local file = io.popen('ls -l ' .. dir)
	if not file then
		return files
	end

	for line in file:lines() do
		local sps = split(line,' ')
		if sps and #sps > 8 then
			local t = sps[1]:sub(1,1)
			local fn = sps[9]
			if t == 'd' then
				getfiles_in_linux(dir .. '/' .. fn,ext,files,keepext)
			elseif t == '-' then
				local _, _, n, e = s_find(fn, "(.*)%.([^\n\r]*)$")
				--core.log.info('fn = ', fn, ' n = ',n, ' e = ',e)
				if not ext or ngx.re.match(e,ext,'jo') then
					if keepext then
						files[#files+1] = dir .. '/' .. fn
					else
						files[#files+1] = dir .. '/' .. n
					end
				end
			end
			--core.log.info('type = ',t,' fn = ',fn)
		end
	end

	return files
end

-- todo test
local getfiles_in_windows = nil
getfiles_in_windows = function (dir,ext,files,keepext)
	files = files or {}
	local file = io.popen('dir ' .. dir)
	if not file then
		return files
	end

	for line in file:lines() do
		local sps = split(line,' ')
		if sps and #sps > 3 then
			local t = sps[3]
			local fn = sps[4]
			if t == '<DIR>' then
				getfiles_in_windows(dir .. '\\' .. fn,ext,files,keepext)
			else
				local _, _, n, e = s_find(fn, "(.*)%.([^\n\r]*)$")
				--core.log.info('fn = ', fn, ' n = ',n, ' e = ',e)
				if not ext or ngx.re.match(e,ext,'jo') then
					if keepext then
						files[#files+1] = dir .. '/' .. fn
					else
						files[#files+1] = dir .. '/' .. n
					end
				end
			end
			--core.log.info('type = ',t,' fn = ',fn)
		end
	end

	return files
end

--获取指定目录下的所有扩展名为ext的文件
local _M = function (dir,ext,files,keepext)
	if sys_is_window() then
		return getfiles_in_windows(dir,ext,files,keepext)
	else
		return getfiles_in_linux(dir,ext,files,keepext)
	end
end

return _M