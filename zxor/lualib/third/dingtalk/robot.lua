local hmac = require("resty.hmac")

local _M = { _VERSION = "0.01" }

local mt = { __index = _M }

local webhook = "https://oapi.dingtalk.com/robot/send?access_token="

_M.new = function(self, access_token, token)
	local ctx = {
		webhook = webhook .. access_token,
		token = token,
	}

	return setmetatable(ctx, mt)
end

local _sign = function(token, timestamp)
	local d, err = hmac:new(token, hmac.ALGOS.SHA256)
	if not d then
		return d, err
	end
	local signstr = d:final(timestamp .. "\n" .. token)
	if not signstr then
		return signstr, err
	end

	return ngx.encode_base64(signstr)
end

local _send_message = function(self, message)
	local timestamp = math.floor(ngx.now() * 1000)
	local signstr, err = _sign(self.token, timestamp)
	if not signstr then
		return false, err
	end

	local url = self.webhook .. "&timestamp=" .. timestamp .. "&sign=" .. signstr
	local ok, rs = core.http.post(url, nil, message, {
		["Content-Type"] = "application/json",
	})

	return ok, rs
end

_M.send_text = function(self, content, atMobiles, atUserIds, atAll)
	if not content then
		return false, "no content"
	end
	local message = {
		msgtype = "text",
		text = {
			content = content,
		},
		at = {
			atMobiles = atMobiles,
			atUserIds = atUserIds,
			isAtAll = atAll and true or false,
		},
	}

	return _send_message(self, message)
end

_M.send_link = function(self, title, content, msgurl, picture)
	if not title then
		return false, "no title"
	end
	if not content then
		return false, "no content"
	end
	if not msgurl then
		return false, "no msgurl"
	end

	local message = {
		msgtype = "link",
		link = {
			title = title,
			text = content,
			picUrl = picture,
			messageUrl = msgurl,
		},
	}

	return _send_message(self, message)
end

_M.send_markdown = function(self, title, content, atMobiles, atUserIds, atAll)
	if not title then
		return false, "no title"
	end
	if not content then
		return false, "no content"
	end

	local message = {
		msgtype = "markdown",
		markdown = {
			title = title,
			text = content,
		},
		at = {
			atMobiles = atMobiles,
			atUserIds = atUserIds,
			isAtAll = atAll and true or false,
		},
	}

	return _send_message(self, message)
end

_M.send_simple_actioncard = function(self, title, content, btnTitle, btnUrl, btnOrientation)
	if not title then
		return false, "no title"
	end
	if not content then
		return false, "no content"
	end
	if not btnTitle then
		return false, "no singleTitle"
	end
	if not btnUrl then
		return false, "no singleURL"
	end

	local message = {
		msgtype = "actionCard",
		actionCard = {
			title = title,
			text = content,
			singleTitle = btnTitle,
			singleURL = btnUrl,
			btnOrientation = btnOrientation and "1" or "0",
		},
	}

	return _send_message(self, message)
end

local actionCard = { _VERSION = "0.01" }
local mt_ac = { __index = actionCard }

actionCard.new = function(self, robot, title, content, btnOrientation)
	local ac = {
		message = {
			msgtype = "actionCard",
			actionCard = {
				title = title,
				text = content,
				btns = {},
				btnOrientation = btnOrientation and "1" or "0",
			},
		},
		robot = robot,
	}

	return setmetatable(ac, mt_ac)
end

actionCard.addbtn = function(self, title, url)
	self.btns[#self.btns + 1] = {
		title = title,
		actionURL = url,
	}
end

actionCard.send = function(self)
	return _send_message(self.robot, self.message)
end

_M.get_new_actioncard = function(self, title, content, btnOrientation)
	if not title then
		return false, "no title"
	end
	if not content then
		return false, "no content"
	end

	return actionCard:new(title, content, btnOrientation)
end

local feedCard = { _VERSION = "0.01" }
local mt_fc = { __index = feedCard }

feedCard.new = function(self, robot)
	local ac = {
		message = {
			msgtype = "feedCard",
			feedCard = {
				links = {},
			},
		},
		robot = robot,
	}

	return setmetatable(ac, mt_fc)
end

feedCard.addlink = function(self, title, url, picture)
	self.links[#self.links + 1] = {
		title = title,
		messageURL = url,
		picURL = picture,
	}
end

feedCard.send = function(self)
	return _send_message(self.robot, self.message)
end

_M.get_new_feedcard = function(self)
	return feedCard:new(self)
end

return _M

