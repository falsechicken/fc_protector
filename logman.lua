--[[ 

 LogMan - A log manager library for Minetest. (Maybe more of a wrapper.)
 
 Copyright (C) 2015 False_Chicken

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]

-- VARS --
local debugMode = false -- If true debug messages will be printed.
local debugMessagesToPlayers = false -- It true debug messages will be send to the players as well.

local NAME = "LogMan" -- Name of the library. Used when printing messages about messages.
-- END VARS --

-- FUNCTIONS --

--[[
Logs a message to the console. 

Params:

<modName> - Name of the mod printing the message.

<level> - The severity level of the message.
0 = Debug : Shown only when debug mode is on.
1 = Info : Used to inform the user of casual messages.
2 = Warning : Used to warn the user of a non critical issue.
3 = Error : Used to inform the user of a critical problem.

<message> : The message to be logged.
]]
function logMessage (modName, level, message)
	
	local constructedMessage = ""
	local time = os.date("%H:%M:%S") .. ": "
	
	if level == 0 then
		if debugMode then
			constructedMessage = time .. modName .. " [DEBUG]: " .. message
			if debugMessagesToPlayers then
				broadcastMessage(constructedMessage)
			end
		end
	elseif level == 1 then
		constructedMessage = time .. modName .. " [INFO]: " .. message
	elseif level == 2 then
		constructedMessage = time .. modName .. " [WARNING]: " .. message
	elseif level == 3 then
		constructedMessage = time .. modName .. " [ERROR]: " .. message
	else
		logMessage(NAME, 2, "Invalid log message level provided.")
	end
	
	print(constructedMessage)
end

--[[
Logs a message to the console. Does not format the message in any way.
Essentially print().

Params:

<message> : The message to be logged.
]]
function logRawMessage (message)
	print(message)
end

--[[
Sends a message to all players.

Params:

<message> : The message to send.
]]
function broadcastMessage (message)
	minetest.chat_send_all(message)
end

--[[
Sends a message to a player. Prints as a chat message.

Params:

<player> : The player object to send the message to.

<message> : The message to send.
]]
function sendMessageToPlayer (player, message)
	local playerName = player:get_player_name()
	minetest.chat_send_player(playerName, message)
end

--[[
Sends a message to a player. Prints as a chat message.

Params:

<playerName> : The name of the player to send the message to.

<message> : The message to send.
]]
function sendMessageToPlayerName (playerName, message)
	minetest.chat_send_player(playerName, message)
end

--[[
Sends a message to a list of players. Prints as a chat message.

Params:

<playerList> : Array of player objects to send a message to.

<message> : The message to send.
]]
function sendMessageToPlayerList (playerList, message)
	for i, player in ipairs(playerList) do
		local playerName = player:get_player_name()
		minetest.chat_send_player(playerName, message)
	end
end

--[[
Sends a message to a list of players. Prints as a chat message.

Params:

<playerNamesList> : Array of player names to send a message to.

<message> : The message to send.
]]
function sendMessageToPlayerNameList (playerNamesList, message)
	for i, playerName in ipairs(playerNamesList) do
		minetest.chat_send_player(playerName, message)
	end
end

-- SETTINGS FUNCTIONS --

--[[
Enable debug mode.
]]
function enableDebugMode()
	debugMode = true
end

--[[
Disable debug mode.
]]
function disableDebugMode()
	debugMode = false
end

--[[
Enable the sending of debug messages to players.

Will have no effect if debug mode is not enabled.
]]
function enableDebugPlayerMessages()
	debugMessagesToPlayers = true
end

--[[
Disable the sending of debug messages to players.
]]
function disableDebugPlayerMessages()
	debugMessagesToPlayers = false
end

-- END SETTINGS FUNCTIONS --

-- END FUNCTIONS --
