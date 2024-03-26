--仅计算公元元年之后的时间
--时间戳元年为1970/01/01 00:00:00
--时区向东为正，向西为负

local class = require "core.class"
local int = math.floor
local ngx_now = ngx.now
local s_find = string.find
local s_format = string.format
local s_replace = ngx.re.gsub

local _M = class()
_M.base_year = 1970
_M.one_minute = 60		--60
_M.one_hour = 3600      --60*60
_M.one_day = 86400      --60*60*24*1
_M.one_week = 604800    --60*60*24*7
_M.one_month = 2592000  --60*60*24*30
_M.one_month_days = 30
_M.one_year = 31536000  --60*60*24*365
_M.month_D_days = {1,-1,0,0,1,1,2,3,3,4,4,5}
_M.month_D_days[0] = 0
_M.month_D_value = {86400,-86400,0,0,86400,86400,172800,259200,259200,345600,345600,432000}
_M.month_D_value[0] = 0
_M.default_zone = 8
_M.default_zone_D_value = 28800	--60*60*8
_M.leap = {}
_M.leap_from_zero = {}
_M.year_T_value = {}

_M.Week = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
_M.week = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}
_M.Month = {"January","February","March","April","May","June","July","August","September","October","November","December"}
_M.month = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

function _M:__init(zone)
	self.zone = zone or self.default_zone
	self.zone_D_value = self.zone * self.one_hour
end

function _M:get_zone()
	return self.zone or self.default_zone
end

function _M:get_zone_D_value()
	return self.zone_D_value or self.default_zone_D_value
end

function _M:now(bms)
	local ms = ngx_now()
	if not bms then ms = int(ms) end
	return ms
end

function _M:get_random_seed()
	return self:now(true)
end

function _M:is_leap_year(year)
	if self.leap[year] == nil then
		self.leap[year] = (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0))
	end
	return self.leap[year]
end

function _M:calc_leap_year_num_from_zero(year)
	local leap = int(year / 100) *  24 + int(year / 400)
	year = year % 100
	if year == 0 then return leap - 1 end
	leap = leap + int(year / 4)
	if year%4 == 0 then return leap - 1 end
	return leap
end

function _M:calc_year_D_value(y1,y2)
	local from = y2 and y1 or self.base_year
	local to = y2 and y2 or y1
	if not self.leap_from_zero[from] then self.leap_from_zero[from] = self:calc_leap_year_num_from_zero(from) end
	if not self.leap_from_zero[to] then self.leap_from_zero[to] = self:calc_leap_year_num_from_zero(to) end
	if not self.year_T_value[from] then self.year_T_value[from] = (from - self.base_year) * self.one_year + (self.leap_from_zero[from] - self.leap_from_zero[self.base_year]) * self.one_day end
	if not self.year_T_value[to] then self.year_T_value[to] = (to - self.base_year) * self.one_year + (self.leap_from_zero[to] - self.leap_from_zero[self.base_year]) * self.one_day end
	return self.year_T_value[to] - self.year_T_value[from]
end

function _M:time(tab)
	if not tab then return self:now() end
	if not tab.year or not tab.month or not tab.day or tab.month < 1 or tab.day < 1 then return false end
	tab.hour = tab.hour or 12
	tab.min = tab.min or 0
	tab.sec = tab.sec or 0
	if tab.isdst then tab.hour = tab.hour - 1 end
	
	local t = 0
	t = self:calc_year_D_value(tab.year)
	t = t + (tab.month-1) * self.one_month + self.month_D_value[tab.month-1] + (tab.day-1) * self.one_day + tab.hour * self.one_hour + tab.min * self.one_minute + tab.sec
	t = t - self:get_zone_D_value()
	if tab.month > 2 and self:is_leap_year(tab.year) then t = t + self.one_day end
	return t
end

function _M:difftime(t2,t1)
	return t2 - t1
end

function _M:date(f,t)
	if not f then f = "%c" end
	if not t then t = self:now() end
	if f == "*t" then
		t = t + self:get_zone_D_value()
		local tab = {}
		tab.wday = (int(t / self.one_day) % 7 + 4) % 7 + 1
		tab.year = self.base_year + int(t / self.one_year)
		local yt = self:calc_year_D_value(tab.year)
		if yt > t then 
			tab.year = tab.year - 1
			yt = yt - self.one_year
			if self:is_leap_year(tab.year) then yt = yt - self.one_day end
		end
		
		t = t - yt
		tab.yday = int(t / self.one_day) + 1
		local months = int(t / self.one_month)
		tab.month = months + 1
		local mt = months * self.one_month + self.month_D_value[months]
		if tab.month > 2 and self:is_leap_year(tab.year) then mt = mt + self.one_day end
		if mt > t then
			tab.month = tab.month - 1
			mt = mt - self.one_month - self.month_D_value[months] + self.month_D_value[months - 1]
		end
		t = t - mt
		local days = int(t / self.one_day)
		tab.day = days + 1
		if tab.month == 2 and tab.day == 29 and not self:is_leap_year(tab.year) then 
			tab.month = 3
			tab.day = 1
		end
		t = t - days * self.one_day
		tab.hour = int(t / self.one_hour)
		t = t - tab.hour * self.one_hour
		tab.min = int(t / self.one_minute)
		tab.sec = t - tab.min * self.one_minute
		tab.hour = tab.hour
		tab.isdst = false
		return tab
	else
		local tab = {}
		if s_find(f,"%c",1,true) or s_find(f,"%x",1,true) or s_find(f,"%X",1,true) then
			tab = self:date("*t",t)
		else
			if s_find(f,"%a",1,true) or s_find(f,"%A",1,true) or s_find(f,"%w",1,true) then tab.wday = self:get_wday(t) end
			if s_find(f,"%b",1,true) or s_find(f,"%B",1,true) or s_find(f,"%m",1,true) then tab.month = self:get_month(t) end
			if s_find(f,"%d",1,true) then tab.day = self:get_day(t) end
			if s_find(f,"%H",1,true) or s_find(f,"%I",1,true) or s_find(f,"%p",1,true) then tab.hour = self:get_hour(t) end
			if s_find(f,"%j",1,true) then tab.yday = self:get_yday(t) end
			if s_find(f,"%M",1,true) then tab.min = self:get_minute(t) end
			if s_find(f,"%S",1,true) then tab.sec = self:get_second(t) end
			if s_find(f,"%y",1,true) or s_find(f,"%Y",1,true) then tab.year = self:get_year(t) end
		end
		
		tab.year = tab.year or 1970
		tab.month = tab.month or 1
		tab.day = tab.day or 1
		tab.hour = tab.hour or 0
		tab.min = tab.min or 0
		tab.sec = tab.sec or 0
		tab.yday = tab.yday or 0
		tab.wday = tab.wday or 5
		
		local rs = f
		if s_find(f,"%a",1,true) then rs = s_replace(rs,"%a",self.week[tab.wday]) end
		if s_find(f,"%A",1,true) then rs = s_replace(rs,"%A",self.Week[tab.wday]) end
		if s_find(f,"%b",1,true) then rs = s_replace(rs,"%b",self.month[tab.month]) end
		if s_find(f,"%B",1,true) then rs = s_replace(rs,"%B",self.Month[tab.month]) end
		if s_find(f,"%c",1,true) then rs = s_replace(rs,"%c",s_format("%04d/%02d/%02d %02d:%02d:%02d",tab.year,tab.month,tab.day,tab.hour,tab.min,tab.sec)) end
		if s_find(f,"%d",1,true) then rs = s_replace(rs,"%d",s_format("%02d",tab.day)) end
		if s_find(f,"%H",1,true) then rs = s_replace(rs,"%H",s_format("%02d",tab.hour)) end
		if s_find(f,"%I",1,true) then rs = s_replace(rs,"%I",s_format("%02d",tab.hour%12)) end
		if s_find(f,"%j",1,true) then rs = s_replace(rs,"%j",s_format("%03d",tab.yday)) end
		if s_find(f,"%M",1,true) then rs = s_replace(rs,"%M",s_format("%02d",tab.min)) end
		if s_find(f,"%m",1,true) then rs = s_replace(rs,"%m",s_format("%02d",tab.month)) end
		if s_find(f,"%p",1,true) then rs = s_replace(rs,"%p",tab.hour > 12 and "下午(pm)" or "上午(am)") end
		if s_find(f,"%S",1,true) then rs = s_replace(rs,"%S",s_format("%02d",tab.sec)) end
		if s_find(f,"%w",1,true) then rs = s_replace(rs,"%w",tab.wday) end
		if s_find(f,"%x",1,true) then rs = s_replace(rs,"%x",s_format("%04d/%02d/%02d",tab.year,tab.month,tab.day)) end
		if s_find(f,"%X",1,true) then rs = s_replace(rs,"%X",s_format("%02d:%02d:%02d",tab.hour,tab.min,tab.sec)) end
		if s_find(f,"%y",1,true) then rs = s_replace(rs,"%y",s_format("%02d",tab.year%100)) end
		if s_find(f,"%Y",1,true) then rs = s_replace(rs,"%Y",s_format("%04d",tab.year)) end
		if s_find(f,"%%",1,true) then rs = s_replace(rs,"%%","%") end
		
		return rs
	end
end

--p={y=0,M=0,d=-1,h=1,m=0,s=0}
--p.y,p.M.p.d,p.h,p.m,p.s,p.w == nil 表示不使用该参数
--p.y,p.M.p.d,p.w == 0 表示不使用该参数
--p.y,p.M.p.d,p.h,p.m,p.s < 0 表示多少时间之后
--p.y,p.M.p.d > 0 为实际时间点
--p.h,p.m,p.s >= 0 为实际时间点
--p.w 指定星期几，星期一----星期日===》1---7,无视正负
--例子表示意义为指定时间点次日凌晨1点整
function _M:get_next_time(t,p)
	p.y = p.y or 0
	p.M = p.M or 0
	p.d = p.d or 0
	p.w = p.w or 0
	if p.w < 0 then p.w = -p.w end
	if p.w == 0 and p.y <= 0 and p.M <=0 and p.d <= 0 then
		if p.h and p.h < 0 and p.m and p.m < 0 and p.s and p.s < 0 then
			return t - p.y * self.one_year - p.M * self.one_month - p.d * self.one_day - p.h * self.one_hour - p.m * self.one_minute - p.s
		end
	end
	
	local pt = self:date("*t",t)
	if p.w > 0 then
		p.d = pt.wday - p.w - 6
		if p.d >= 0 then p.d = p.d - 7 end
	end
	local nt = {
		year = (p.y ~= 0) and p.y or pt.year,
		month = (p.M ~= 0) and p.M or pt.month,
		day = (p.d ~= 0) and p.d or pt.day,
		hour = p.h or pt.hour,
		min = p.m or pt.min,
		sec = p.s or pt.sec,
	}
	
	if nt.year < 0 then nt.year = pt.year - nt.year end
	if nt.month < 0 then nt.month = pt.month - nt.month end
	if nt.day < 0 then nt.day = pt.day - nt.day end
	if nt.hour < 0 then nt.hour = pt.hour - nt.hour end
	if nt.min < 0 then nt.min = pt.min - nt.min end
	if nt.sec < 0 then nt.sec = pt.sec - nt.sec end

	return self:time(nt)
end

function _M:get_hour_time(hour)
	local ltime = self:now()
	return ltime - ltime % self.one_day + (hour - self:get_zone())*self.one_hour
end

function _M:get_year(t)
	if not t then t = self:now() end
	t = t + self:get_zone_D_value()
	local year = self.base_year + int(t / self.one_year)
	local yt = self:calc_year_D_value(year)
	if yt > t then year = year - 1 end
	return year
end

function _M:get_yday(t)
	if not t then t = self:now() end
	local year = self:get_year(t)
	t = t + self:get_zone_D_value() - self:calc_year_D_value(year)
	return int(t / self.one_day) + 1
end

function _M:get_month(t)
	if not t then t = self:now() end
	local year = self:get_year(t)
	t = t + self:get_zone_D_value() - self:calc_year_D_value(year)
	local month = int(t / self.one_month)
	local mt = month * self.one_month + self.month_D_value[month]
	if month > 1 and self:is_leap_year(year) then mt = mt + self.one_day end
	if mt > t then 
		mt = mt - self.one_month - self.month_D_value[month] + self.month_D_value[month - 1]
		month = month - 1
	end
	if month == 1 and int((t - mt) / self.one_day) == 28 and not self:is_leap_year(year) then month = 2	end
	return month + 1
end

function _M:get_wday(t)
	if not t then t = self:now() end
	return (int((t + self:get_zone_D_value()) / self.one_day) % 7 + 4) % 7 + 1
end

function _M:get_day(t)
	if not t then t = self:now() end
	local m = self:get_month(t) - 1
	local day = self:get_yday(t) - m * self.one_month_days - self.month_D_days[m]
	if m > 1 and self:is_leap_year(self:get_year()) then day = day - 1 end
	return day
end

function _M:get_hour(t)
	if not t then t = self:now() end
	return (int(t % self.one_day / self.one_hour) + self:get_zone()) % 24
end

function _M:get_minute(t)
	if not t then t = self:now() end
	return int(t % self.one_hour / self.one_minute)
end

function _M:get_second(t)
	if not t then t = self:now() end
	return t % self.one_minute
end

--整点时间戳
function _M:get_last_hour_time(t)
	local hour = self:get_hour(t)
	return self:get_hour_time(hour)
end

return _M