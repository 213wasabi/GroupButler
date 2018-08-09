local config = require "groupbutler.config"
local api = require "telegram-bot-api.methods".init(config.telegram.token)
local get_bot = require "groupbutler.bot"
local locale = require "groupbutler.languages"
local i18n = locale.translate

local _M = {}

local bot

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
	bot = get_bot.init()
	return self
end

function _M:onTextMessage(msg, blocks)
	local db = self.db
	local u = self.u

	if not msg.service then return end
	if blocks[1] == 'new_chat_member:bot' or blocks[1] == 'migrate_from_chat_id' then
		-- set the language
		--[[locale.language = db:get(string.format('lang:%d', msg.from.id)) or config.lang
		if not config.available_languages[locale.language] then
			locale.language = 'en'
		end]]
		if u:is_blocked_global(msg.from.id) then
			api.sendMessage(msg.chat.id, i18n("_You (user ID: %d) are in the blocked list_"):format(msg.from.id), "Markdown")
			api.leaveChat(msg.chat.id)
			return
		end
		if config.bot_settings.admin_mode and not u:is_superadmin(msg.from.id) then
			api.sendMessage(msg.chat.id, i18n("_Admin mode is on: only the bot admin can add me to a new group_"), "Markdown")
			api.leaveChat(msg.chat.id)
			return
		end
		-- save language
		--[[if locale.language then
			db:set(string.format('lang:%d', msg.chat.id), locale.language)
		end]]
		u:initGroup(msg.chat.id)
		-- send manuals
		local text
		if blocks[1] == 'new_chat_member:bot' then
			text = i18n("Hello everyone!\n"
				.. "My name is %s, and I'm a bot made to help administrators in their hard work.\n")
				:format(bot.first_name:escape())
		else
			text = i18n("Yay! This group has been upgraded. You are great! Now I can work properly :)\n")
		end
		--[[if not u:is_admin(msg.chat.id, bot.id) then
			if u:is_owner(msg.chat.id, msg.from.id) then
				text = text .. i18n("Hmm… apparently I'm not an administrator. "
					.. "I can be more useful if you make me an admin. "
					.. "See [here](https://telegram.me/GroupButler_ch/104) how to do it.\n")
			else
				text = text .. i18n("Hmm… apparently I'm not an administrator. "
					.. "I can be more useful if I'm an admin. Ask a creator to make me an admin. "
					.. "If they don't know how, there is a good [guide](https://telegram.me/GroupButler_ch/104).\n")
			end
		end
		text = text .. i18n("I can do a lot of cool things. To discover about them, "
				-- TODO: old link, update it
			.. "watch this [video-tutorial](https://youtu.be/uqNumbcUyzs).") ]]
		api.sendMessage(msg.chat.id, text, "Markdown")
	elseif blocks[1] == 'left_chat_member:bot' then
		u:remGroup(msg.chat.id, true)
	else
		u:logEvent(blocks[1], msg)
	end
end

_M.triggers = {
	onTextMessage = {
		'^###(new_chat_member:bot)',
		'^###(migrate_from_chat_id)',
		'^###(left_chat_member:bot)',
		'^###(pinned_message)$',
		'^###(new_chat_title)$',
		'^###(new_chat_photo)$',
		'^###(delete_chat_photo)$'
	}
}

return _M
