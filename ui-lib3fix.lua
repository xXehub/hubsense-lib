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

-- Results label storage
local ResultLabels = {}

-- Update Results Display Function
local function UpdateResultsDisplay()
	-- Clear old labels
	for _, label in pairs(ResultLabels) do
		if label and label.SetText then
			label:SetText('')
		end
	end
	ResultLabels = {}
	
	if #currentSearchResults == 0 then
		return
	end
	
	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
	
	-- Update page info
	local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
	if PageInfoLabel then
		PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
	end
end

local Window = Library:CreateWindow({
	Title = 'HubSense | Word Suggester',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Main = Window:AddTab('Main'),
	['UI Config'] = Window:AddTab('UI Config'),
}

-- ==================== MAIN TAB ====================
-- Word Search Card with Sub-tabs
local WordSearchBox = Tabs.Main:AddLeftGroupbox('Word Search')

local WordTabs = WordSearchBox:AddTabbox('WordTabbox')
local WordTab = WordTabs:AddTab('Word')
local SettingsTab = WordTabs:AddTab('Settings')

-- === WORD TAB ===
-- Status in Word tab
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
		if not loaded then
			return
		end
		
		if Value == "" or #Value < 1 then
			currentSearchResults = {}
			currentPage = 1
			UpdateResultsDisplay()
			return
		end
		
		currentPage = 1
		currentSearchResults = SuggestWords(Value, 1000)
		UpdateResultsDisplay()
	end
})

-- Quick Search
WordTab:AddDivider()
WordTab:AddLabel('Quick Search Templates:')
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

-- Pagination Buttons
WordTab:AddButton({
	Text = '⬅️ Previous Page',
	DoubleClick = false,
	Tooltip = 'Go to previous page',
	Func = function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			UpdateResultsDisplay()
		end
	end
})

WordTab:AddButton({
	Text = 'Next Page ➡️',
	DoubleClick = false,
	Tooltip = 'Go to next page',
	Func = function()
		if #currentSearchResults > 0 then
			local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
			if currentPage < totalPages then
				currentPage = currentPage + 1
				UpdateResultsDisplay()
			end
		end
	end
})

local PageInfoLabel = WordTab:AddLabel('Page: 1 / 1 | Total: 0 words', true)

-- === SETTINGS TAB ===
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
		
		spawn(function()
			while not loaded do
				wait(0.1)
			end
			StatusLabel:SetText('✅ Words Loaded: ' .. #Words)
		end)
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
	Text = 'Clear Cache',
	DoubleClick = true,
	Tooltip = 'Clear search cache (double click)',
	Func = function()
		searchCache = {}
	end
})

-- Results Display Groupbox (Right side)
local ResultsBox = Tabs.Main:AddRightGroupbox('Search Results')

ResultsBox:AddLabel('Results will appear here after search')
ResultsBox:AddDivider()

-- Results label container (will be filled dynamically)
for i = 1, 50 do
	local label = ResultsBox:AddLabel('', true)
	table.insert(ResultLabels, label)
end

-- Update display function (revised)
UpdateResultsDisplay = function()
	if #currentSearchResults == 0 then
		for i = 1, #ResultLabels do
			if ResultLabels[i] then
				if i == 1 then
					ResultLabels[i]:SetText('No results found')
				else
					ResultLabels[i]:SetText('')
				end
			end
		end
		if PageInfoLabel then
			PageInfoLabel:SetText('Page: 1 / 1 | Total: 0 words')
		end
		return
	end
	
	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
	
	local displayIndex = 1
	for i = startIndex, endIndex do
		if ResultLabels[displayIndex] then
			ResultLabels[displayIndex]:SetText(displayIndex .. '. ' .. currentSearchResults[i])
			displayIndex = displayIndex + 1
		end
	end
	
	-- Clear remaining labels
	for i = displayIndex, #ResultLabels do
		if ResultLabels[i] then
			ResultLabels[i]:SetText('')
		end
	end
	
	-- Update page info
	local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
	if PageInfoLabel then
		PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
	end
end

-- Game Features Card
local GameFeaturesBox = Tabs.Main:AddRightGroupbox('Game Features')

GameFeaturesBox:AddToggle('FlyHack', {
	Text = 'Fly Hack',
	Default = false,
	Tooltip = 'Enable flying (Space to fly up, X to fly down)',
	
	Callback = function(Value)
		local player = game.Players.LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		
		if Value then
			-- Enable Fly
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Name = "FlyVelocity"
			bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
			bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			bodyVelocity.Parent = character.HumanoidRootPart
			
			local flySpeed = Options.FlySpeed and Options.FlySpeed.Value or 50
			
			game:GetService("RunService").RenderStepped:Connect(function()
				if not Toggles.FlyHack.Value then return end
				
				local moveDirection = humanoid.MoveDirection
				local camera = workspace.CurrentCamera
				
				if moveDirection.Magnitude > 0 then
					bodyVelocity.Velocity = camera.CFrame.LookVector * flySpeed
				else
					bodyVelocity.Velocity = Vector3.new(0, 0, 0)
				end
				
				-- Space = up, X = down
				local uis = game:GetService("UserInputService")
				if uis:IsKeyDown(Enum.KeyCode.Space) then
					bodyVelocity.Velocity = bodyVelocity.Velocity + Vector3.new(0, flySpeed, 0)
				elseif uis:IsKeyDown(Enum.KeyCode.X) then
					bodyVelocity.Velocity = bodyVelocity.Velocity - Vector3.new(0, flySpeed, 0)
				end
			end)
		else
			-- Disable Fly
			if character:FindFirstChild("HumanoidRootPart") then
				local fv = character.HumanoidRootPart:FindFirstChild("FlyVelocity")
				if fv then fv:Destroy() end
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

GameFeaturesBox:AddDivider()

GameFeaturesBox:AddSlider('WalkSpeed', {
	Text = 'Walk Speed',
	Default = 16,
	Min = 16,
	Max = 200,
	Rounding = 0,
	Compact = false,
	
	Callback = function(Value)
		local player = game.Players.LocalPlayer
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.WalkSpeed = Value
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
		local player = game.Players.LocalPlayer
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.JumpPower = Value
		end
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

-- Add Theme Manager and Save Manager to UI Config
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('HubSense')
SaveManager:SetFolder('HubSense/WordSuggester')

SaveManager:BuildConfigSection(Tabs['UI Config'])
ThemeManager:ApplyToTab(Tabs['UI Config'])

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

-- Set GameSense/Skeet theme
ThemeManager:ApplyTheme('Default')

SaveManager:LoadAutoloadConfig()