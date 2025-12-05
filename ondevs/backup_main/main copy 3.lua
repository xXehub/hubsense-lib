-- HubSense - Word Suggester Hub
-- Skeet/GameSense Style UI

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Word Suggester Variables
local url = "https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words.txt"
local Words = {}
local loaded = false
local WordDictionary = {}
local searchCache = {}
local minCharacters = 1
local maxCharacters = 100
local currentPage = 1
local wordsPerPage = 50
local currentSearchResults = {}

-- Load Words Function
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
			res = req({Url = url, Method = "GET"})
		else
			local ok, body = pcall(function() return game:HttpGet(url) end)
			if ok and body then res = { Body = body } end
		end
		if res and res.Body then
			for w in res.Body:gmatch("[^\r\n]+") do
				local wordLower = w:lower()
				local wordLen = #wordLower
				
				if wordLen >= minCharacters and wordLen <= maxCharacters then
					table.insert(Words, wordLower)
					local firstLetter = wordLower:sub(1,1)
					if not WordDictionary[firstLetter] then
						WordDictionary[firstLetter] = {}
					end
					table.insert(WordDictionary[firstLetter], wordLower)
				end
			end
			loaded = true
			return true
		end
	end)
	
	loaded = true
end

-- Reload Words with new filter
local function ReloadWords()
	Words = {}
	WordDictionary = {}
	searchCache = {}
	loaded = false
	currentPage = 1
	currentSearchResults = {}
	
	spawn(function()
		LoadWords()
		while not loaded do
			wait(0.1)
		end
	end)
end

-- Suggest Words Function
local function SuggestWords(input, count)
	if not loaded then 
		return {}
	end
	if #Words == 0 then 
		return {}
	end
	
	input = input:lower()
	
	local cacheKey = input .. "_" .. count
	if searchCache[cacheKey] then
		return searchCache[cacheKey]
	end
	
	local possible = {}
	local results = {}
	
	local firstLetter = input:sub(1,1)
	local wordList = WordDictionary[firstLetter] or {}
	
	local searchList = #wordList > 0 and wordList or Words
	
	for i = 1, #searchList do
		local word = searchList[i]
		if word:sub(1, #input) == input then
			table.insert(possible, word)
			if #possible >= 1000 then break end
		end
	end
	
	table.sort(possible, function(a, b)
		return #a < #b
	end)
	
	local maxResults = math.min(count, #possible)
	for i = 1, maxResults do
		table.insert(results, possible[i])
	end
	
	if #possible > maxResults then
		for i = 1, math.min(10, #possible - maxResults) do
			local r = math.random(maxResults + 1, #possible)
			table.insert(results, possible[r])
		end
	end
	
	searchCache[cacheKey] = results
	if #searchCache > 100 then
		local keys = {}
		for k in pairs(searchCache) do
			table.insert(keys, k)
		end
		for i = 1, 30 do
			if keys[i] then
				searchCache[keys[i]] = nil
			end
		end
	end
	
	return results
end

-- Start loading words in background
spawn(LoadWords)

-- Try load external game feature logic from epic.lua via executor
local Epic
pcall(function()
	if readfile then
		local content = readfile("epic.lua")
		if content and #content > 0 then
			Epic = loadstring(content)()
		end
	end
end)

local Window = Library:CreateWindow({
	Title = 'HubSense | Word Suggester',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

-- Side navbar: Main + UI Config
local Tabs = {
	Main = Window:AddTab('Main'),
	['UI Config'] = Window:AddTab('UI Config'),
}

-- Card: Word Search with Tabbox (Word + Settings)
-- Linoria: Tabboxes are added directly to the Tab, not inside a Groupbox
local WordTabs = Tabs.Main:AddLeftTabbox('Word Search')
local WordTab = WordTabs:AddTab('Word')
local SettingsTab = WordTabs:AddTab('Settings')

-- Status labels inside Word tab
local StatusLabel = WordTab:AddLabel('Database Status: Loading...', true)
local FilterLabel = WordTab:AddLabel('Filter: Min 1 - Max 100 chars', true)
WordTab:AddDivider()

-- Search Input
WordTab:AddInput('SearchInput', {
	Default = '',
	Numeric = false,
	Finished = false,
	Text = 'Search Query',
	Tooltip = 'Type letters to search for words',
	Placeholder = 'Type here...',
	Callback = function(Value)
		if not loaded then return end
		if Value == '' or #Value < 1 then
			currentSearchResults = {}
			currentPage = 1
			return
		end
		currentPage = 1
		currentSearchResults = SuggestWords(Value, 1000)
		-- refresh results display
		UpdateResultsDisplay()
	end
})

WordTab:AddDivider()
WordTab:AddLabel('Quick Search:')
WordTab:AddDropdown('QuickSearch', {
	Values = { 'cat', 'dog', 'test', 'word', 'game', 'code', 'script', 'roblox' },
	Default = 1,
	Multi = false,
	Text = 'Templates',
	Tooltip = 'Quick search templates',
	Callback = function(Value)
		Options.SearchInput:SetValue(Value)
	end
})

WordTab:AddDivider()

-- Pagination (buttons) and page info
local PageInfoLabel = WordTab:AddLabel('Page: 1 / 1 | Total: 0 words', true)

-- Pagination controls moved under the results table

-- Settings sub-tab
SettingsTab:AddSlider('MinChars', {
	Text = 'Min Characters',
	Default = 1,
	Min = 1,
	Max = 50,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		minCharacters = Value
		FilterLabel:SetText('Filter: Min ' .. minCharacters .. ' - Max ' .. maxCharacters .. ' chars')
	end
})

SettingsTab:AddSlider('MaxChars', {
	Text = 'Max Characters',
	Default = 100,
	Min = 1,
	Max = 100,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		maxCharacters = Value
		FilterLabel:SetText('Filter: Min ' .. minCharacters .. ' - Max ' .. maxCharacters .. ' chars')
	end
})

SettingsTab:AddDivider()

SettingsTab:AddSlider('WordsPerPage', {
	Text = 'Words Per Page',
	Default = 50,
	Min = 10,
	Max = 200,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		wordsPerPage = Value
	end
})

SettingsTab:AddButton({
	Text = '🔄 Apply Filters & Reload',
	DoubleClick = false,
	Tooltip = 'Apply filter settings and reload database',
	Func = function()
		if minCharacters > maxCharacters then
			maxCharacters = minCharacters
			Options.MaxChars:SetValue(maxCharacters)
		end
		StatusLabel:SetText('Reloading with filters...')
		ReloadWords()
	end
})

SettingsTab:AddButton({
	Text = 'Clear Cache',
	DoubleClick = true,
	Tooltip = 'Clear search cache (double click)',
	Func = function()
		searchCache = {}
	end
})

-- Results Groupbox (Right column): label list display
local ResultsBox = Tabs.Main:AddRightGroupbox('Search Results')
local ResultsDropdown = ResultsBox:AddDropdown('ResultsList', {
	Values = { 'Type to search...' },
	Default = 1,
	Multi = false,
	Text = 'Results (select to view)',
	Tooltip = 'Current page results'
})

ResultsBox:AddDivider()

local function UpdateResultsDisplay()
	if #currentSearchResults == 0 then
		ResultsDropdown:SetValues({ 'No results' })
		ResultsDropdown:SetValue('No results')
		PageInfoLabel:SetText('Page: 1 / 1 | Total: 0 words')
		return
	end

	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)

	local display = {}
	for i = startIndex, endIndex do
		display[#display + 1] = currentSearchResults[i]
	end
	if #display == 0 then display = { 'No results (page empty)' } end
	ResultsDropdown:SetValues(display)
	ResultsDropdown:SetValue(display[1])

	local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
	PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
end

-- Hook updates to search and pagination
local function Refresh()
	UpdateResultsDisplay()
end

-- Update results when typing
Options.SearchInput:OnChanged(function()
	Refresh()
end)

-- Also refresh every frame for page changes (lightweight)
game:GetService('RunService').RenderStepped:Connect(function()
	Refresh()
end)

-- Pagination controls below the results table
ResultsBox:AddButton({
	Text = '⬅️ Previous Page',
	DoubleClick = false,
	Tooltip = 'Go to previous page',
	Func = function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			Refresh()
		end
	end
})

ResultsBox:AddButton({
	Text = 'Next Page ➡️',
	DoubleClick = false,
	Tooltip = 'Go to next page',
	Func = function()
		if #currentSearchResults > 0 then
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			if currentPage < totalPages then
				currentPage = currentPage + 1
				Refresh()
			end
		end
	end
})

-- ==================== GAME FEATURES (from epic.lua if present) ====================
local GameFeaturesBox = Tabs.Main:AddRightGroupbox('Game Features')

GameFeaturesBox:AddSlider('WalkSpeed', {
	Text = 'Walk Speed',
	Default = 16,
	Min = 16,
	Max = 200,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		if Epic and Epic.setWalkSpeed then
			local ok, err = pcall(Epic.setWalkSpeed, Value)
			if not ok then warn(err) end
		else
			local lp = game.Players.LocalPlayer
			if lp.Character and lp.Character:FindFirstChild('Humanoid') then
				lp.Character.Humanoid.WalkSpeed = Value
			end
		end
	end
})

GameFeaturesBox:AddSlider('JumpPower', {
	Text = 'Jump Power',
	Default = 50,
	Min = 50,
	Max = 200,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		if Epic and Epic.setJumpPower then
			local ok, err = pcall(Epic.setJumpPower, Value)
			if not ok then warn(err) end
		else
			local lp = game.Players.LocalPlayer
			if lp.Character and lp.Character:FindFirstChild('Humanoid') then
				lp.Character.Humanoid.JumpPower = Value
			end
		end
	end
})

GameFeaturesBox:AddDivider()

GameFeaturesBox:AddToggle('FlyHack', {
	Text = 'Fly Hack',
	Default = false,
	Tooltip = 'Enable fly movement',
	Callback = function(Value)
		local speed = (Options.FlySpeed and Options.FlySpeed.Value) or 50
		if Epic and Epic.toggleFly then
			local ok, err = pcall(Epic.toggleFly, Value, speed)
			if not ok then warn(err) end
		else
			-- Fallback simple fly using BodyVelocity
			local lp = game.Players.LocalPlayer
			local char = lp.Character or lp.CharacterAdded:Wait()
			local hrp = char:WaitForChild('HumanoidRootPart')
			local humanoid = char:WaitForChild('Humanoid')
			if Value then
				local bv = Instance.new('BodyVelocity')
				bv.Name = 'HubSenseFlyVelocity'
				bv.MaxForce = Vector3.new(4000, 4000, 4000)
				bv.Parent = hrp
				game:GetService('RunService').RenderStepped:Connect(function()
					if not Toggles.FlyHack.Value then return end
					local cam = workspace.CurrentCamera
					local dir = humanoid.MoveDirection
					if dir.Magnitude > 0 then
						bv.Velocity = cam.CFrame.LookVector * speed
					else
						bv.Velocity = Vector3.new()
					end
				end)
			else
				local bv = hrp:FindFirstChild('HubSenseFlyVelocity')
				if bv then bv:Destroy() end
			end
		end
	end
})

GameFeaturesBox:AddSlider('FlySpeed', {
	Text = 'Fly Speed',
	Default = 50,
	Min = 10,
	Max = 200,
	Rounding = 0,
	Compact = false,
})

-- Removed old top-level Settings tab (now inside Word Search card)

-- ==================== UI CONFIG TAB ====================
local MenuGroup = Tabs['UI Config']:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
	Text = 'Unload UI',
	DoubleClick = true,
	Tooltip = 'Unload the entire UI (double click)',
	Func = function()
		Library:Unload()
	end
})

MenuGroup:AddLabel('Menu keybind'):AddKeyPicker('MenuKeybind', {
	Default = 'Insert',
	NoUI = true,
	Text = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind

-- Status Monitor
spawn(function()
	while not loaded do
		wait(0.5)
		StatusLabel:SetText('Loading... ' .. #Words .. ' words')
	end
	
	StatusLabel:SetText('✅ Words Loaded: ' .. #Words)
end)

-- Watermark
Library:SetWatermarkVisibility(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
	FrameCounter += 1

	if (tick() - FrameTimer) >= 1 then
		FPS = FrameCounter
		FrameTimer = tick()
		FrameCounter = 0
	end

	Library:SetWatermark(('HubSense | %s fps | %s ms | Words: %s'):format(
		math.floor(FPS),
		math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()),
		#Words
	))
end)

Library.KeybindFrame.Visible = true

Library:OnUnload(function()
	WatermarkConnection:Disconnect()
	print('HubSense unloaded!')
	Library.Unloaded = true
end)

-- Theme Manager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('HubSense')
SaveManager:SetFolder('HubSense/WordSuggester')

SaveManager:BuildConfigSection(Tabs['UI Config'])
ThemeManager:ApplyToTab(Tabs['UI Config'])

-- Set GameSense/Skeet theme
ThemeManager:ApplyTheme('Default')

SaveManager:LoadAutoloadConfig()