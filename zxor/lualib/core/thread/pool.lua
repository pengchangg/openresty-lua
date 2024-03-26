local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_wait = ngx.thread.wait

local semaphore = require("ngx.semaphore")
local core_table = require("core.table")
local new_table = core_table.new
local del_table = core_table.release
local t_insert = table.insert
local t_remove = table.remove

local _M = { version = 0.1 }
local mt = { __index = _M }

_M.new = function(self, max_worker_num, one_timer_max_task_num)
	local m = {
		workers = new_table(20, 0, "thread.pool.workers"),
		worker_num = 0,
		free_woker_num = 0,
		inwork = false,
		prestop = false,
		max_worker_num = max_worker_num or 100,
		max_task_cap = (max_worker_num or 100) * 5,
		sema_workers = semaphore:new(),
		sema_free = semaphore:new(),
		tasks = new_table(20, 0, "thread.pool.tasks"),
		max_task_num = one_timer_max_task_num or 100000,
		cur_timer = 0,
		cur_timer_task_num = 0,
	}

	return setmetatable(m, mt)
end

local _one_worker_thread = function(self, wk)
	while self.inwork do
		if wk.task then
			local ok, err = pcall(wk.task.func, unpack(wk.task.data, 1, wk.task.data_len))
			if not ok then
				core.log.error("do worker in pool failed. -> ", err or "unkonwn")
			end
			del_table(wk.task)
			wk.task = false
			self.sema_free:post(1)
			if wk.timer == self.cur_timer then
				t_insert(self.workers, wk)
			else
				break
			end
		else
			wk.sema:wait(30)
		end
	end

	self.worker_num = self.worker_num - 1
	del_table(wk)
end

local _new_worker_thread = function(self)
	self.worker_num = self.worker_num + 1
	local wk = new_table(0, 8, "thread.pool.worker")
	wk.idx = self.cur_timer .. ":" .. self.worker_num
	wk.task = false
	wk.sema = semaphore:new()
	wk.timer = self.cur_timer
	wk.thread = ngx_thread_spawn(_one_worker_thread, self, wk)

	return wk
end

local _get_worker_thread = nil
_get_worker_thread = function(self)
	if #self.workers == 0 then
		if self.max_worker_num <= self.worker_num then
			--等待空闲协程
			while true do
				self.sema_free:wait(30)
				if #self.workers > 0 then
					break
				end
			end
		else
			return _new_worker_thread(self)
		end
	end

	local wk = t_remove(self.workers)
	if not wk or not wk.sema then
		return _get_worker_thread(self)
	end

	return wk
end

_M.add = function(self, func, ...)
	if not self.inwork or worker.killed then
		return false, "not in work"
	end

	if #self.tasks > self.max_task_cap then
		return false, "no cap"
	end

	local task = new_table(0, 5, "thread.pool.worker.task")
	task.func = func
	task.data = { ... }
	task.data_len = select("#", ...)
	t_insert(self.tasks, task)
	self.sema_workers:post(1)
	return true
end

local _worker_loop = nil
_worker_loop = function(self)
	self.cur_timer = self.cur_timer + 1
	self.cur_timer_task_num = 0
	while not self.prestop and not worker.killed do
		if #self.tasks > 0 then
			local tasks = self.tasks
			self.tasks = new_table(20, 0, "thread.pool.tasks")
			for _, task in ipairs(tasks) do
				local wk = _get_worker_thread(self)
				wk.task = task
				wk.sema:post(1)
				self.cur_timer_task_num = self.cur_timer_task_num + 1
			end

			del_table(tasks)

			if self.cur_timer_task_num > self.max_task_num then
				break
			end
		else
			self.sema_workers:wait(30)
		end
	end

	if not self.prestop and not worker.killed then
		core.go(0, _worker_loop, self)
		return
	end

	--保证缓冲池里的任务全部执行完毕
	if #self.tasks > 0 then
		local tasks = self.tasks
		self.tasks = new_table(20, 0, "thread.pool.tasks")
		for _, task in ipairs(tasks) do
			local wk = _get_worker_thread(self)
			wk.task = task
			wk.sema:post(1)
		end

		del_table(tasks)
	end

	ngx.sleep(1)
	self.inwork = false
end

_M.run = function(self)
	if self.inwork then
		return
	end

	self.inwork = true
	self.prestop = false

	core.go(0, _worker_loop, self)
end

_M.stop = function(self)
	self.prestop = true
	self.sema_workers:post(1)
end

_M.empty = function(self)
	return #self.workers == self.worker_num
end

return _M

