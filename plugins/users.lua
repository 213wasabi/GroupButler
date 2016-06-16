local function do_keybaord_credits()
	local keyboard = {}
    keyboard.inline_keyboard = {
    	{
    		{text = 'Channel', url = 'https://telegram.me/'..config.channel:gsub('@', '')},
    		{text = 'GitHub', url = 'https://github.com/RememberTheAir/GroupButler'},
    		{text = 'Rate me!', url = 'https://telegram.me/storebot?start='..bot.username},
		}
	}
	return keyboard
end

local function get_name_getban(msg, blocks, user_id)
	if blocks[2] then
		return blocks[2]..' ('..user_id..')'
	else
		return msg.reply.from.first_name..' ('..user_id..')'
	end
end

local function getUserBanText(user_id, ln)
	local hash = 'ban:'..user_id
	local ban_info = db:hgetall(hash)
	if not next(ban_info) then
		return lang[ln].getban.nothing
	else
		local ban_index = {
			['kick'] = lang[ln].getban.kick,
			['ban'] = lang[ln].getban.ban,
			['tempban'] = lang[ln].getban.tempban,
			['flood'] = lang[ln].getban.flood,
			['media'] = lang[ln].getban.media,
			['warn'] = lang[ln].getban.warn,
			['arab'] = lang[ln].getban.arab,
			['rtl'] = lang[ln].getban.rtl,
		}
		local text = ''
		for type,n in pairs(ban_info) do
			text = text..'`'..ban_index[type]..'`'..'*'..n..'*\n'
		end
		if text == '' then
			return lang[ln].getban.nothing
		else
			return text
		end
	end
end

local function do_keyboard_getban(user_id)
	local keyboard = {}
	keyboard.inline_keyboard = {
		{
			{text = 'Kick', callback_data = 'getban:kick:'..user_id},
			{text = 'Ban', callback_data = 'getban:ban:'..user_id}
		}
	}
	
	return keyboard
end	

local action = function(msg, blocks, ln)
	if blocks[1] == 'initgroup' then
		if msg.chat.type == 'private' then return end
		if is_mod(msg) then
			local set, is_ok = cross.getSettings(msg.chat.id, ln)
			if not is_ok then
				local nick = msg.from.first_name
				if msg.from.username then
					nick = nick..' ('..msg.from.username..')'
				end
        		cross.initGroup(msg.chat.id, msg.from.id, nick)
        		api.sendMessage(msg.chat.id, 'Should be ok. Try to run /settings command')
        		api.sendLog('#initGroup\n'..vtext(msg.chat)..vtext(msg.from))
        	else
        		api.sendMessage(msg.chat.id, 'This is already ok')
        	end
        end
    end
    if blocks[1] == 'adminlist' then
    	if msg.chat.type == 'private' then return end
    	local no_usernames
    	local send_reply = true
    	if is_locked(msg, 'Modlist') then
    		if is_mod(msg) then
        		no_usernames = true
        	else
        		no_usernames = false
        		send_reply = false
        	end
        else
            no_usernames = true
        end
    	local out
        local creator, adminlist = cross.getModlist(msg.chat.id, no_usernames)
        out = make_text(lang[ln].mod.modlist, creator, adminlist)
        if not send_reply then
        	api.sendMessage(msg.from.id, out, true)
        else
            api.sendReply(msg, out, true)
        end
        mystat('/adminlist')
    end
    if blocks[1] == 'status' then
    	if msg.chat.type == 'private' then return end
    	if is_mod(msg) then
    		local user_id = res_user_group(blocks[2], msg.chat.id)
    		if not user_id then
		 		api.sendReply(msg, lang[ln].bonus.no_user, true)
		 	else
		 		local res = api.getChatMember(msg.chat.id, user_id)
		 		if not res then
		 			api.sendReply(msg, lang[ln].status.unknown)
		 			return
		 		end
		 		local status = res.result.status
				local name = res.result.user.first_name
				if res.result.user.username then name = name..' (@'..res.result.user.username..')' end
				if msg.chat.type == 'group' and is_banned(msg.chat.id, user_id) then
					status = 'kicked'
				end
		 		local text = make_text(lang[ln].status[status], name)
		 		api.sendReply(msg, text)
		 	end
		 	mystat('/status')
	 	end
 	end
 	if blocks[1] == 'id' then
 		if not(msg.chat.type == 'private') and not is_mod(msg) then return end
 		local id
 		if msg.reply then
 			id = msg.reply.from.id
 		else
 			id = msg.chat.id
 		end
 		api.sendReply(msg, '`'..id..'`', true)
 		mystat('/tell')
 	end
 	if blocks[1] == 's' then
 		if not msg.reply or not config.admin.admins[msg.from.id] then return end
 		local original
 		if msg.reply.text then
 			original = msg.reply.text
 		else
 			return
 		end
 		original = original:gsub(blocks[2], blocks[3])
 		original = 'Did you mean:\n"'..original..'"'
 		api.sendReply(msg.reply, original, false, msg.reply.message_id)
 	end
 	if blocks[1] == 'adminmode' then
 		if msg.chat.type == 'private' or not is_mod(msg) then return end
 		local hash = 'chat:'..msg.chat.id..':settings'
 		local status = db:hget(hash, 'Admin_mode')
 		print(status)
 		if blocks[2] == 'on' then
 			if status == 'yes' then
 				db:hset(hash, 'Admin_mode', 'no')
 				api.sendReply(msg, lang[ln].settings.enable.admin_mode_unlocked, true)
 			else
 				api.sendReply(msg, lang[ln].settings.enable.admin_mode_already, true)
 			end
 		elseif blocks[2] == 'off' then
 			if status == 'no' then
 				db:hset(hash, 'Admin_mode', 'yes')
 				api.sendReply(msg, lang[ln].settings.disable.admin_mode_locked, true)
 			else
 				api.sendReply(msg, lang[ln].settings.disable.admin_mode_already, true)
 			end
 		end
 		mystat('/adminmode')
	 end
	if blocks[1] == 'getban' then
		if msg.chat.type ~= 'private' and not is_mod(msg) then return end
		local user_id
		if blocks[2] then
			user_id = res_user_group(blocks[2], msg.chat.id)
			if not user_id then
				api.sendReply(msg, lang[ln].bonus.no_user, true)
		 		return
		 	end
		elseif msg.reply then
			if msg.reply.from.id == bot.id then return end
			user_id = msg.reply.from.id
		else
			api.sendReply(msg, lang[ln].banhammer.reply)
			return
		end
		if is_bot_owner(msg) and msg.reply then
			if msg.reply.forward_from then
				user_id = msg.reply.forward_from.id
			end
		end
		
		local name = get_name_getban(msg, blocks, user_id)
		local text = getUserBanText(user_id, ln)
		text = lang[ln].getban.header..name:mEscape()..'\n'..text
		
		if msg.chat.type == 'private' then
			api.sendReply(msg, text, true)
		else
			local keyboard = do_keyboard_getban(user_id)
			api.sendKeyboard(msg.chat.id, text, keyboard, true)
		end
	end
	if blocks[1] == 'kick' or blocks[1] == 'ban' then
		if not is_mod(msg) then
    		api.answerCallbackQuery(msg.cb_id, lang[ln].not_mod:mEscape_hard())
    		return
		end
		local res, text
		local user_id = msg.text:match('^###cb:getban:%a%a%a%a?:(%d+)$')
		if blocks[1] == 'kick' then
			res, text = api.kickUser(msg.chat.id, user_id, ln)
		elseif blocks[1] == 'ban' then
			res, text = api.kickUser(msg.chat.id, user_id, msg.normal_group, ln)
		end
		if res then
			cross.saveBan(user_id, blocks[1])
			if blocks[1] == 'kick' then
				text = lang[ln].getban.kicked
			elseif blocks[1] == 'ban' then
				text = lang[ln].getban.banned
			end
		end
		api.editMessageText(msg.chat.id, msg.message_id, text, false, true)
	end		
end

return {
	action = action,
	triggers = {
		'^/(id)$',
		'^/(initgroup)$',
		'^/(adminlist)$',
		'^/(status) (@[%w_]+)$',
		'^(s)/(.*)/(.*)$',
		'^/(adminmode) (off)$',
		'^/(adminmode) (on)$',
		'^/(getban)$',
		'^/(getban) (@[%w_]+)$',
		'^###cb:getban:(kick):(%d+)$',
		'^###cb:getban:(ban):(%d+)$',
	}
}