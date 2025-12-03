-- HubSense (Gamesneze UI) - Word Suggester + Game Features
-- Uses UI library in gamesneze/source.lua; results displayed via List (table)

-- Load Gamesneze UI library from cloud with local fallback
local gslib, gsutil, gpointers, gtheme do
	local CLOUD_URL = 'https://raw.githubusercontent.com/weakhoes/Roblox-UI-Libs/refs/heads/main/GameSneeze%20Lib/GameSneeze%20Lib%20Source.lua'
	local ok, src = pcall(function()
		return game:HttpGet(CLOUD_URL)
	end)
	if ok and src and #src > 0 then
		gslib, gsutil, gpointers, gtheme = loadstring(src)()
	else
		gslib, gsutil, gpointers, gtheme = loadstring(readfile('gamesneze/source.lua'))()
	end
end

-- Patch image loader to avoid broken external assets (gradient/arrows)
do
	if gsutil and gsutil.LoadImage then
		local _orig = gsutil.LoadImage
		gsutil.LoadImage = function(a, b, c, d)
			local instance, imageName, imageLink
			if typeof(a) == 'table' then
				instance, imageName, imageLink = b, c, d
			else
				instance, imageName, imageLink = a, b, c
			end
			if imageName == 'gradient' or imageName == 'gradientdown' or imageName == 'arrow_down' or imageName == 'arrow_up' then
				return
			end
			local ok = pcall(function()
				_orig(a, b, c, d)
			end)
			if not ok then
				-- silently ignore image load failures
				return
			end
		end
	end
end

local function UpdateAccent(color)
	if gtheme then gtheme.accent = color end
	if gslib and gslib.colors then
		for inst, map in pairs(gslib.colors) do
			if map.Color == 'accent' then inst.Color = color end
		end
	end
end

-- Config
local WINDOW_NAME = 'HubSense | Word Suggester'
local ACCENT = Color3.fromRGB(55,175,225)

-- Word suggester state
local url = 'https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words.txt'
local Words = {}
local loaded = false
local WordDictionary = {}
local searchCache = {}
local minCharacters = 1
local maxCharacters = 100
local currentPage = 1
local wordsPerPage = 50
local currentSearchResults = {}

-- Load words
local function getRequest()
	local req = request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
	return req
end

local function LoadWords()
	if loaded then return end
	local success, result = pcall(function()
		local req = getRequest()
		local res
		if req then
			res = req({Url = url, Method = 'GET'})
		else
			local ok, body = pcall(function() return game:HttpGet(url) end)
			if ok and body then res = { Body = body } end
		end
		if res and res.Body then
			for w in res.Body:gmatch('[^\r\n]+') do
				local wordLower = w:lower()
				local len = #wordLower
				if len >= minCharacters and len <= maxCharacters then
					table.insert(Words, wordLower)
					local first = wordLower:sub(1,1)
					WordDictionary[first] = WordDictionary[first] or {}
					table.insert(WordDictionary[first], wordLower)
				end
			end
			loaded = true
			return true
		end
	end)
	loaded = true
end

local function ReloadWords()
	Words = {}
	WordDictionary = {}
	searchCache = {}
	loaded = false
	currentPage = 1
	currentSearchResults = {}
	task.spawn(function()
		LoadWords()
		while not loaded do task.wait(0.1) end
	end)
end

local function SuggestWords(input, count)
	if not loaded or #Words == 0 then return {} end
	input = input:lower()
	local cacheKey = input .. '_' .. tostring(count)
	local cached = searchCache[cacheKey]
	if cached then return cached end
	local first = input:sub(1,1)
	local list = WordDictionary[first] or Words
	local possible = {}
	for i=1,#list do
		local word = list[i]
		if word:sub(1,#input) == input then
			possible[#possible+1] = word
			if #possible >= 1000 then break end
		end
	end
	table.sort(possible, function(a,b) return #a < #b end)
	local results = {}
	local maxResults = math.min(count, #possible)
	for i=1,maxResults do results[i] = possible[i] end
	if #possible > maxResults then
		for i=1, math.min(10, #possible - maxResults) do
			local r = math.random(maxResults + 1, #possible)
			results[#results+1] = possible[r]
		end
	end
	searchCache[cacheKey] = results
	if #searchCache > 100 then
		local idx = 0
		for k in pairs(searchCache) do
			idx = idx + 1
			if idx <= 30 then searchCache[k] = nil end
		end
	end
	return results
end

-- Start loading in background
spawn(LoadWords)

-- Create window
local Window = gslib:New({ name = WINDOW_NAME, size = Vector2.new(600, 470), accent = ACCENT })
Window.uibind = Enum.KeyCode.Insert

-- Pages
local Main = Window:Page({ name = 'Main' })
local UIConfig = Window:Page({ name = 'UI Config' })

-- Word Search card with tabs (Word, Settings)
local WordTab, SettingsTab = Main:MultiSection({ sections = { 'Word', 'Settings' }, side = 'left', size = 220 })

-- Search input + templates + pagination
local SearchBox = WordTab:TextBox({ def = '', max = 64, placeholder = 'Type to search...', pointer = 'SearchInput', reactive = true, callback = function(Value)
	if not loaded then return end
	if Value == '' then
		currentSearchResults = {}
		currentPage = 1
	else
		currentPage = 1
		currentSearchResults = SuggestWords(Value, 1000)
	end
	if _G.HS_UpdateResults then _G.HS_UpdateResults() end
end })

WordTab:Label({ name = 'Quick Search:' })
WordTab:Dropdown({ name = nil, max = 5, options = { 'cat','dog','test','word','game','code','script','roblox' }, def = 'cat', callback = function(val)
	gslib.pointers['SearchInput']:Set(val)
end })

-- Pagination buttons
WordTab:ButtonHolder({ buttons = {
	{ '⬅️ Previous Page', function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			if _G.HS_UpdateResults then _G.HS_UpdateResults() end
		end
	end },
	{ 'Next Page ➡️', function()
		if #currentSearchResults > 0 then
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			if currentPage < totalPages then
				currentPage = currentPage + 1
				if _G.HS_UpdateResults then _G.HS_UpdateResults() end
			end
		end
	end }
} })

-- Settings controls
SettingsTab:Slider({ name = 'Min Characters', def = 1, min = 1, max = 50, callback = function(v)
	minCharacters = v
end })
SettingsTab:Slider({ name = 'Max Characters', def = 100, min = 1, max = 100, callback = function(v)
	maxCharacters = v
end })
SettingsTab:Slider({ name = 'Words Per Page', def = 50, min = 10, max = 200, callback = function(v)
	wordsPerPage = v
end })
SettingsTab:Button({ name = 'Apply Filters & Reload', callback = function()
	if minCharacters > maxCharacters then maxCharacters = minCharacters end
	ReloadWords()
end })
SettingsTab:Button({ name = 'Clear Cache', callback = function()
	searchCache = {}
end })

-- Results (table/list) on right
local ResultsSection = Main:Section({ name = 'Results Table', side = 'right', size = 260 })
local ResultsList = ResultsSection:List({ max = 15, options = { 'Type to search...' }, def = 1 })

-- Refresh/Update results into list (table)
_G.HS_UpdateResults = function()
	if #currentSearchResults == 0 then
		ResultsList.options = { 'No results' }
		ResultsList.current = 1
		ResultsList.scrollingindex = 0
		ResultsList:UpdateScroll()
		return
	end
	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
	local display = {}
	for i = startIndex, endIndex do
		display[#display+1] = currentSearchResults[i]
	end
	if #display == 0 then display = { 'No results (page empty)' } end
	ResultsList.options = display
	ResultsList.current = 1
	ResultsList.scrollingindex = 0
	ResultsList:UpdateScroll()
end

-- Game Features (uses epic.lua if available)
local Epic
pcall(function()
	if readfile then
		local content = readfile('epic.lua')
		if content and #content > 0 then Epic = loadstring(content)() end
	end
end)

local GameFeatures = Main:Section({ name = 'Game Features', side = 'right', size = 140 })
GameFeatures:Slider({ name = 'Walk Speed', def = 16, min = 16, max = 200, callback = function(v)
	if Epic and Epic.setWalkSpeed then pcall(Epic.setWalkSpeed, v) else
		local lp = game.Players.LocalPlayer
		if lp.Character and lp.Character:FindFirstChild('Humanoid') then lp.Character.Humanoid.WalkSpeed = v end
	end
end })
GameFeatures:Slider({ name = 'Jump Power', def = 50, min = 50, max = 200, callback = function(v)
	if Epic and Epic.setJumpPower then pcall(Epic.setJumpPower, v) else
		local lp = game.Players.LocalPlayer
		if lp.Character and lp.Character:FindFirstChild('Humanoid') then lp.Character.Humanoid.JumpPower = v end
	end
end })
GameFeatures:Slider({ name = 'Fly Speed', def = 50, min = 10, max = 200, pointer = 'FlySpeed' })
GameFeatures:Toggle({ name = 'Fly Hack', def = false, callback = function(state)
	local speed = (gslib.pointers['FlySpeed'] and gslib.pointers['FlySpeed']:Get()) or 50
	if Epic and Epic.toggleFly then pcall(Epic.toggleFly, state, speed) else
		local lp = game.Players.LocalPlayer
		local char = lp.Character or lp.CharacterAdded:Wait()
		local hrp = char:WaitForChild('HumanoidRootPart')
		local hum = char:WaitForChild('Humanoid')
		if state then
			local bv = Instance.new('BodyVelocity')
			bv.Name = 'HubSenseFlyVelocity'
			bv.MaxForce = Vector3.new(4000, 4000, 4000)
			bv.Parent = hrp
			game:GetService('RunService').RenderStepped:Connect(function()
				if not gslib.pointers or not gslib.pointers['FlySpeed'] then return end
				if not state then return end
				local s = gslib.pointers['FlySpeed']:Get()
				local cam = workspace.CurrentCamera
				local dir = hum.MoveDirection
				if dir.Magnitude > 0 then bv.Velocity = cam.CFrame.LookVector * s else bv.Velocity = Vector3.new() end
			end)
		else
			local bv = hrp:FindFirstChild('HubSenseFlyVelocity')
			if bv then bv:Destroy() end
		end
	end
end })

-- UI Config page (general)
local Menu = UIConfig:Section({ name = 'Menu', side = 'left', size = 80 })
Menu:Button({ name = 'Unload UI', callback = function() Window:Unload() end })
Menu:Label({ name = 'Toggle Menu: INSERT' })

-- Theme configuration
local ThemeSection = UIConfig:Section({ name = 'Theme', side = 'left', size = 120 })
ThemeSection:Colorpicker({ name = 'Accent', pointer = 'Accent', def = { Color = ACCENT, Transparency = 1 }, callback = function(v)
	UpdateAccent(v.Color)
end })
ThemeSection:Keybind({ name = 'Menu Keybind', pointer = 'MenuBind', def = Enum.KeyCode.Insert, callback = function(key)
	Window.uibind = key
end })

-- Config management
local CONFIG_DIR = (gslib.folders and gslib.folders.configs) or 'Atlanta/Configs'
pcall(function()
	if isfolder and not isfolder('Atlanta') then makefolder('Atlanta') end
	if isfolder and not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
end)

local function ListConfigs()
	local names = {}
	if listfiles then
		for _, p in ipairs(listfiles(CONFIG_DIR)) do
			local n = p:match('[\\/]([^\\/]+)%.json$')
			if n then table.insert(names, n) end
		end
	end
	table.sort(names)
	return names
end

local ConfigSection = UIConfig:Section({ name = 'Config', side = 'right', size = 180 })
local ConfigNameBox = ConfigSection:TextBox({ def = 'default', max = 64, placeholder = 'Config name', pointer = 'ConfigName' })
local ConfigList = ConfigSection:Dropdown({ name = 'Configs', options = ListConfigs(), def = nil, max = 10, pointer = 'ConfigList' })

ConfigSection:ButtonHolder({ buttons = {
	{ 'Save', function()
		local name = (gslib.pointers['ConfigName'] and gslib.pointers['ConfigName']:Get()) or 'default'
		local path = CONFIG_DIR .. '/' .. name .. '.json'
		local cfg = Window:GetConfig()
		pcall(function() writefile(path, cfg) end)
	end },
	{ 'Load', function()
		local name = (gslib.pointers['ConfigList'] and gslib.pointers['ConfigList']:Get()) or (gslib.pointers['ConfigName'] and gslib.pointers['ConfigName']:Get()) or 'default'
		local path = CONFIG_DIR .. '/' .. name .. '.json'
		local ok, data = pcall(function() return readfile(path) end)
		if ok and data then Window:LoadConfig(data) end
	end },
	{ 'Delete', function()
		local name = (gslib.pointers['ConfigList'] and gslib.pointers['ConfigList']:Get()) or (gslib.pointers['ConfigName'] and gslib.pointers['ConfigName']:Get()) or 'default'
		local path = CONFIG_DIR .. '/' .. name .. '.json'
		if delfile then pcall(function() delfile(path) end) end
	end },
	{ 'Refresh', function()
		local opts = ListConfigs()
		if gslib.pointers['ConfigList'] then
			gslib.pointers['ConfigList'].options = opts
		end
	end }
} })

-- Watermark
Window:Watermark({ name = '$$$$$ HubSense $$$$$ || Ping : $PING || Fps : $FPS' })

-- Initialize
Window:Initialize()
