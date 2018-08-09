local config = require "groupbutler.config"
local api = require "telegram-bot-api.methods".init(config.telegram.token)
local locale = require "groupbutler.languages"
local i18n = locale.translate
local null = ngx.null

local _M = {}

_M.__index = _M

setmetatable(_M, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function _M.new(main)
	local self = setmetatable({}, _M)
	self.update = main.update
	self.u = main.u
	self.db = main.db
	return self
end

local function cache_chat_title(self, chat_id)
	local db = self.db
	print('caching title...')
	local key = 'chat:'..chat_id..':title'
	local title = api.getChat(chat_id).title
	db:set(key, title)
	db:expire(key, config.bot_settings.cache_time.chat_titles)
	return title
end

local function get_chat_title(self, chat_id)
	local db = self.db
	local title = db:get('chat:'..chat_id..':title')
	if title == null then
		return cache_chat_title(self, chat_id)
	end
	return title
end

local function do_keyboard_config(self, chat_id, user_id) -- is_admin
	local u = self.u
	local keyboard = {
		inline_keyboard = {
			{{text = i18n("🛠 Menu"), callback_data = 'config:menu:'..chat_id}},
			{{text = i18n("⚡️ Antiflood"), callback_data = 'config:antiflood:'..chat_id}},
			{{text = i18n("🌈 Media"), callback_data = 'config:media:'..chat_id}},
			{{text = i18n("🚫 Antispam"), callback_data = 'config:antispam:'..chat_id}},
			{{text = i18n("📥 Log channel"), callback_data = 'config:logchannel:'..chat_id}}
		}
	}

	if u:can(chat_id, user_id, "can_restrict_members") then
		table.insert(keyboard.inline_keyboard,
			{{text = i18n("⛔️ Default permissions"), callback_data = 'config:defpermissions:'..chat_id}})
	end

	return keyboard
end

function _M:onTextMessage(msg)
	local u = self.u
	local db = self.db
	if msg.chat.type ~= 'private' then
		if u:is_allowed('config', msg.chat.id, msg.from) then
			local chat_id = msg.chat.id
			local keyboard = do_keyboard_config(self, chat_id, msg.from.id)
			if db:get('chat:'..chat_id..':title') == null then cache_chat_title(self, chat_id, msg.chat.title) end
			local res = api.sendMessage(msg.from.id,
				i18n("<b>%s</b>\n<i>Change the settings of your group</i>"):format(msg.chat.title:escape_html()), 'html',
					nil, nil, nil, keyboard)
			if not u:is_silentmode_on(msg.chat.id) then --send the responde in the group only if the silent mode is off
				if res then
					api.sendMessage(msg.chat.id, i18n("_I've sent you the keyboard via private message_"), "Markdown")
				else
					u:sendStartMe(msg)
				end
			end
		end
	end
end

function _M:onCallbackQuery(msg)
	local chat_id = msg.target_id
	local keyboard = do_keyboard_config(self, chat_id, msg.from.id, msg.from.admin)
	local text = i18n("<i>Change the settings of your group</i>")
	local chat_title = get_chat_title(self, chat_id)
	if chat_title then
		text = ("<b>%s</b>\n"):format(chat_title:escape_html())..text
	end
	api.editMessageText(msg.chat.id, msg.message_id, nil, text, 'html', nil, keyboard)
end

_M.triggers = {
	onTextMessage = {
		config.cmd..'config$',
		config.cmd..'settings$',
	},
	onCallbackQuery = {
		'^###cb:config:back:'
	}
}

return _M
