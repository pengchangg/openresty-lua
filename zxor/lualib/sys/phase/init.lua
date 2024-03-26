local re_define_log = function ()
    local cmds = {
        stderr = ngx.STDERR,
        emerg  = ngx.EMERG,
        alert  = ngx.ALERT,
        crit   = ngx.CRIT,
        error  = ngx.ERR,
        warn   = ngx.WARN,
        notice = ngx.NOTICE,
        info   = ngx.INFO,
    }
    
    local floor = math.floor
    local concat = table.concat
    local ngx_process = require "ngx.process"
    local ngx_now = ngx.now

    local ffi = require 'ffi'
    ffi.cdef[[
        ssize_t write(int fd, const char *buf, size_t n);
    ]]
    local sys_fd = {
        stdin = 0,
        stdout = 1,
        stderr = 2,
    }

    local getinfo = require 'debug'.getinfo
    local prefix_len = #core.work_path + 2
    local get_function = function ()
        local info = getinfo(3)
        info.file = string.sub(info.short_src, prefix_len)
        return info.file .. ':' .. info.currentline, info.name .. '()'
    end

    local write_rec = ffi.C.write
    local rec = {0, 'record', '-', 0, '-', '-', '-', '-', '-', '-', '-', '\n'}
    local print = function (level, flag, message)
        if not message or #message == 0 then
            return
        end
        
        local now = ngx_now()
        local sec = floor(now)
        local ms = floor((now - sec) * 1000)
        rec[1] = sec
        rec[2] = level or '-'
        rec[3] = flag or '-'
        rec[4] = ms
        --rec[5] = ngx_process.get_master_pid() .. '#' .. ngx.worker.pid() .. '#' .. ngx.worker.id()
        --rec[6], rec[7], rec[8], rec[9], 
        rec[9], rec[10] = get_function()
        rec[11] = message
    
        local content = concat(rec, ' ')
        write_rec(sys_fd.stdout, content, #content)
    end

    local cjson_encode = core.cjson.encode
    core.log.record = function (flag, message)
        return print('record', flag, cjson_encode(message))
    end

    local cmds = {
        stderr = ngx.STDERR,
        emerg  = ngx.EMERG,
        alert  = ngx.ALERT,
        crit   = ngx.CRIT,
        error  = ngx.ERR,
        warn   = ngx.WARN,
        notice = ngx.NOTICE,
        info   = ngx.INFO,
    }
    local loglevel = require 'ngx.errlog'.get_sys_filter_level()
    ngx.log = function (level, ...)
        if level <= loglevel then
            return print(level, 'log', concat({...}))
        end
    end
    for name, level in pairs(cmds) do
        core.log[name] = function (...)
            if level <= loglevel then
                return print(name, nil, concat({...}))
            end
        end
    end
end

local _M = function(indocker)
    if indocker then
       re_define_log()
    end
end

return _M