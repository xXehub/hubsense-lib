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
local function LoadWords()
	if loaded then return end
	
	local success, result = pcall(function()
		local res = request({Url = url, Method = "GET"})
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

local Window = Library:CreateWindow({
	Title = 'HubSense | Word Suggester',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Search = Window:AddTab('Search'),
	Settings = Window:AddTab('Settings'),
	['UI Config'] = Window:AddTab('UI Config'),
}

-- ==================== SEARCH TAB ====================
local StatusBox = Tabs.Search:AddLeftGroupbox('Status')

StatusBox:AddLabel('Database Status: Loading...')
local StatusLabel = StatusBox:AddLabel('Words Loaded: 0 / ~490,000')
local FilterLabel = StatusBox:AddLabel('Filter: Min 1 - Max 100 chars')

StatusBox:AddDivider()

StatusBox:AddButton({
	Text = 'Refresh Database',
	DoubleClick = false,
	Tooltip = 'Reload the word database',
	Func = function()
		ReloadWords()
		StatusBox:AddLabel('Reloading database...', true)
	end
})

-- Search Box
local SearchBox = Tabs.Search:AddLeftGroupbox('Word Search')

SearchBox:AddInput('SearchInput', {
	Default = '',
	Numeric = false,
	Finished = false,
	Text = 'Search Query',
	Tooltip = 'Type letters to search for words',
	Placeholder = 'Type here...',
	
	Callback = function(Value)
		if not loaded then
			return
		end
		
		if Value == "" or #Value < 1 then
			currentSearchResults = {}
			currentPage = 1
			return
		end
		
		currentPage = 1
		currentSearchResults = SuggestWords(Value, 1000)
		
		if #currentSearchResults > 0 then
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			
			-- Update results dropdown
			local displayWords = {}
			local startIndex = 1
			local endIndex = math.min(wordsPerPage, #currentSearchResults)
			
			for i = startIndex, endIndex do
				table.insert(displayWords, currentSearchResults[i])
			end
			
			Options.ResultsDropdown:SetValues(displayWords)
			Options.ResultsDropdown:SetValue(displayWords[1] or "")
			
			Toggles.SearchStatus:SetValue(true)
		else
			Options.ResultsDropdown:SetValues({"No results found"})
		end
	end
})

SearchBox:AddToggle('SearchStatus', {
	Text = 'Search Active',
	Default = false,
	Tooltip = 'Indicates if search is active'
})

SearchBox:AddDivider()

SearchBox:AddLabel('Quick Search:')
SearchBox:AddDropdown('QuickSearch', {
	Values = { 'cat', 'dog', 'test', 'word', 'game', 'code', 'script', 'roblox' },
	Default = 1,
	Multi = false,
	Text = 'Templates',
	Tooltip = 'Quick search templates',
	
	Callback = function(Value)
		Options.SearchInput:SetValue(Value)
	end
})

-- Results Display
local ResultsBox = Tabs.Search:AddRightGroupbox('Search Results')

ResultsBox:AddLabel('Results (50 per page):')
ResultsBox:AddDivider()

ResultsBox:AddDropdown('ResultsDropdown', {
	Values = { 'Type to search...' },
	Default = 1,
	Multi = false,
	Text = 'Results',
	Tooltip = 'Search results will appear here',
	
	Callback = function(Value)
		-- Display only
	end
})

-- Pagination
local PaginationBox = Tabs.Search:AddRightGroupbox('Pagination')

PaginationBox:AddLabel('Page: 1 / 1 | Total: 0 words')
local PageInfoLabel = PaginationBox:AddLabel('Navigate results:')

PaginationBox:AddButton({
	Text = '⬅️ Previous Page',
	DoubleClick = false,
	Tooltip = 'Go to previous page',
	Func = function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			local startIndex = (currentPage - 1) * wordsPerPage + 1
			local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
			
			local displayWords = {}
			for i = startIndex, endIndex do
				table.insert(displayWords, currentSearchResults[i])
			end
			
			Options.ResultsDropdown:SetValues(displayWords)
			Options.ResultsDropdown:SetValue(displayWords[1] or "")
			
			PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
		end
	end
})

PaginationBox:AddButton({
	Text = 'Next Page ➡️',
	DoubleClick = false,
	Tooltip = 'Go to next page',
	Func = function()
		if #currentSearchResults > 0 then
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			
			if currentPage < totalPages then
				currentPage = currentPage + 1
				
				local startIndex = (currentPage - 1) * wordsPerPage + 1
				local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
				
				local displayWords = {}
				for i = startIndex, endIndex do
					table.insert(displayWords, currentSearchResults[i])
				end
				
				Options.ResultsDropdown:SetValues(displayWords)
				Options.ResultsDropdown:SetValue(displayWords[1] or "")
				
				PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
			end
		end
	end
})

-- ==================== SETTINGS TAB ====================
local FilterBox = Tabs.Settings:AddLeftGroupbox('Word Filters')

FilterBox:AddSlider('MinChars', {
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

FilterBox:AddSlider('MaxChars', {
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

FilterBox:AddDivider()

FilterBox:AddButton({
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
		
		spawn(function()
			while not loaded do
				wait(0.1)
			end
			StatusLabel:SetText('Words Loaded: ' .. #Words)
		end)
	end
})

local PerformanceBox = Tabs.Settings:AddRightGroupbox('Performance')

PerformanceBox:AddSlider('WordsPerPage', {
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

PerformanceBox:AddToggle('AutoSearch', {
	Text = 'Auto Search (Live)',
	Default = true,
	Tooltip = 'Search as you type',
})

PerformanceBox:AddDivider()

PerformanceBox:AddLabel('Cache: Active')
PerformanceBox:AddButton({
	Text = 'Clear Cache',
	DoubleClick = true,
	Tooltip = 'Clear search cache (double click)',
	Func = function()
		searchCache = {}
	end
})

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
	StatusBox:AddLabel('Database ready!')
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