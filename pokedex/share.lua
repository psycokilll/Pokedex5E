local ljson = require "defsave.json"
local storage = require "pokedex.storage"
local url = require "utils.url"
local notify = require "utils.notify"
local monarch = require "monarch.monarch"
local dex = require "pokedex.dex"
local pokedex = require "pokedex.pokedex"
local statuses = require "pokedex.statuses"
local messages = require "utils.messages"
local _file = require "utils.file"
local platform = require "utils.platform"

local M = {}

-- For checking if sharing is enabled
M.ENABLED = {
	CLIPBOARD = clipboard ~= nil,
	NETWORK = platform.MOBILE_PHONE or platform.MACOS or platform.WINDOWS,
	QRCODE_GENERATE = true,
	QRCODE_READ = platform.MOBILE_PHONE or platform.MACOS,
}
M.ENABLED.ANY = M.ENABLED.CLIPBOARD or M.ENABLED.QRCODE_READ

local function get_clipboard_json()
	local paste = clipboard.paste()
	local json = nil

	if paste then
		-- Ensure the suppposed json ends with a } - Discord mobile seems to have acquired a bug where it sometimes does not end properly
		local munged = paste:sub(-1) == "}" and paste or (paste .. "}")
		
		json = _file.load_json(munged)
	end

	return json, paste
end

function M.add_new_pokemon(pokemon)
	storage.add(pokemon)
	dex.set(pokemon.species.current, dex.states.CAUGHT)
	if url.PARTY then
		msg.post(url.PARTY, messages.REFRESH)
	elseif url.STORAGE then
		msg.post(url.STORAGE, messages.INVENTORY_UPDATED)
		msg.post(url.STORAGE, messages.STORAGE_UPDATED)
	end
end

function M.validate(pokemon)
	if pokemon and type(pokemon) == "table" and pokemon.species and pokemon.species.current and
	pokemon.hp and pokemon.hp.current then
		return true
	end
	return nil
end

function M.import()
	local json, original = get_clipboard_json()
	if json then
		if not M.validate(json) then
			notify.notify("Pokemon data is incomplete")
			notify.notify(original)
			return 
		end
		M.add_new_pokemon(json)
		notify.notify("Welcome " .. (json.nickname or json.species.current) .. "!")
	else
		notify.notify("Could not parse pokemon data")
		notify.notify(original)
	end
end
function M.encode_status(pokemon)
	local new = {}
	for s, _ in pairs(pokemon.statuses or {}) do
		new[statuses.string_to_state[s]] = true
	end
	pokemon.statuses = new
end

function M.get_clipboard()
	local json = get_clipboard_json()	
	if json then
		if not M.validate(json) then
			return 
		end
		M.encode_status(json)
		return json
	end
	return nil
end

local function decode_status(pokemon)
	local new = {}
	for i, _ in pairs(pokemon.statuses or {}) do
		new[statuses.status_names[i]] = true
	end
	pokemon.statuses = new
end

local function serialize_pokemon(pokemon)
	decode_status(pokemon)
	return ljson.encode(pokemon)
end

function M.generate_qr(id)
	local pokemon = storage.get_copy(id)
	if pokemon then
		return qrcode.generate(serialize_pokemon(pokemon))
	end
end

function M.get_sendable_pokemon_copy(id)
	local pokemon = storage.get_copy(id)
	decode_status(pokemon)
	return pokemon
end

function M.export(id)
	local pokemon = storage.get_copy(id)
	clipboard.copy(serialize_pokemon(pokemon))
	notify.notify((pokemon.nickname or pokemon.species.current) .. " copied to clipboard!")
end

return M