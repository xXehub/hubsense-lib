-- hubsense - Word Suggester Hub
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

-- ESP Variables
local ESPEnabled = false
local ESPConnections = {}
local ESPObjects = {}
local ESPSettings = {
	ShowName = true,
	ShowDistance = true,
	ShowHealth = true,
	ShowBox = true,
	MaxDistance = 1000,
	TeamCheck = false,
	NameColor = Color3.fromRGB(255, 255, 255),
	BoxColor = Color3.fromRGB(255, 0, 0),
	HealthBarColor = Color3.fromRGB(0, 255, 0)
}

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

-- ==================== ESP FUNCTIONS ====================
local function CreateESP(player)
	if not player.Character or ESPObjects[player] then return end
	
	local char = player.Character
	local hrp = char:FindFirstChild('HumanoidRootPart')
	local humanoid = char:FindFirstChild('Humanoid')
	if not hrp or not humanoid then return end
	
	local espFolder = Instance.new('Folder')
	espFolder.Name = 'ESP_' .. player.Name
	espFolder.Parent = char
	
	-- Billboard GUI for name and distance
	local billboard = Instance.new('BillboardGui')
	billboard.Name = 'ESPBillboard'
	billboard.Adornee = hrp
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = espFolder
	
	local nameLabel = Instance.new('TextLabel')
	nameLabel.Name = 'NameLabel'
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = ESPSettings.NameColor
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextSize = 16
	nameLabel.Parent = billboard
	
	local distanceLabel = Instance.new('TextLabel')
	distanceLabel.Name = 'DistanceLabel'
	distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
	distanceLabel.Position = UDim2.new(0, 0, 0.5, 0)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Text = '0m'
	distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	distanceLabel.TextStrokeTransparency = 0.5
	distanceLabel.Font = Enum.Font.SourceSans
	distanceLabel.TextSize = 14
	distanceLabel.Parent = billboard
	
	-- Box ESP (Highlight)
	local highlight = Instance.new('Highlight')
	highlight.Name = 'ESPHighlight'
	highlight.Adornee = char
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = ESPSettings.BoxColor
	highlight.FillColor = ESPSettings.BoxColor
	highlight.Parent = espFolder
	
	ESPObjects[player] = espFolder
end

local function RemoveESP(player)
	if ESPObjects[player] then
		ESPObjects[player]:Destroy()
		ESPObjects[player] = nil
	end
end

local function UpdateESP()
	local localPlayer = game.Players.LocalPlayer
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild('HumanoidRootPart') then return end
	local localHRP = localPlayer.Character.HumanoidRootPart
	
	for player, espFolder in pairs(ESPObjects) do
		if player and player.Character and player.Character:FindFirstChild('HumanoidRootPart') then
			local hrp = player.Character.HumanoidRootPart
			local distance = (localHRP.Position - hrp.Position).Magnitude
			
			-- Check distance and team
			local shouldShow = distance <= ESPSettings.MaxDistance
			if ESPSettings.TeamCheck and player.Team == localPlayer.Team then
				shouldShow = false
			end
			
			local billboard = espFolder:FindFirstChild('ESPBillboard')
			local highlight = espFolder:FindFirstChild('ESPHighlight')
			
			if billboard then
				billboard.Enabled = shouldShow and (ESPSettings.ShowName or ESPSettings.ShowDistance)
				if billboard.Enabled then
					local nameLabel = billboard:FindFirstChild('NameLabel')
					local distanceLabel = billboard:FindFirstChild('DistanceLabel')
					if nameLabel then
						nameLabel.Visible = ESPSettings.ShowName
						nameLabel.TextColor3 = ESPSettings.NameColor
					end
					if distanceLabel then
						distanceLabel.Visible = ESPSettings.ShowDistance
						distanceLabel.Text = math.floor(distance) .. 'm'
					end
				end
			end
			
			if highlight then
				highlight.Enabled = shouldShow and ESPSettings.ShowBox
				if highlight.Enabled then
					highlight.OutlineColor = ESPSettings.BoxColor
					highlight.FillColor = ESPSettings.BoxColor
				end
			end
			
			-- Health bar update
			if ESPSettings.ShowHealth then
				local humanoid = player.Character:FindFirstChild('Humanoid')
				if humanoid and billboard and billboard.Enabled then
					local healthPercent = humanoid.Health / humanoid.MaxHealth
					-- Could add health bar frame here if needed
				end
			end
		else
			RemoveESP(player)
		end
	end
end

local function ToggleESP(enabled)
	ESPEnabled = enabled
	
	if enabled then
		-- Create ESP for all existing players
		for _, player in pairs(game.Players:GetPlayers()) do
			if player ~= game.Players.LocalPlayer then
				if player.Character then
					CreateESP(player)
				end
			end
		end
		
		-- Listen for new players and character spawns
		ESPConnections.PlayerAdded = game.Players.PlayerAdded:Connect(function(player)
			if player ~= game.Players.LocalPlayer then
				player.CharacterAdded:Connect(function()
					wait(0.5)
					if ESPEnabled then CreateESP(player) end
				end)
				if player.Character then CreateESP(player) end
			end
		end)
		
		ESPConnections.PlayerRemoving = game.Players.PlayerRemoving:Connect(function(player)
			RemoveESP(player)
		end)
		
		-- Update loop
		ESPConnections.UpdateLoop = game:GetService('RunService').RenderStepped:Connect(function()
			if ESPEnabled then UpdateESP() end
		end)
	else
		-- Remove all ESP
		for player, _ in pairs(ESPObjects) do
			RemoveESP(player)
		end
		
		-- Disconnect all connections
		for _, connection in pairs(ESPConnections) do
			connection:Disconnect()
		end
		ESPConnections = {}
	end
end

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
	Title = 'hubsense | Word Suggester',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

-- Side navbar: Main + Visual + UI Config
local Tabs = {
	Main = Window:AddTab('Main'),
	Visual = Window:AddTab('Visual'),
	['UI Config'] = Window:AddTab('UI Config'),
}

-- Card: Word Search with Tabbox (Word + Settings)
-- Linoria: Tabboxes are added directly to the Tab, not inside a Groupbox
local WordTabs = Tabs.Main:AddLeftTabbox('Word Search')
local WordTab = WordTabs:AddTab('Word')
local SettingsTab = WordTabs:AddTab('Settings')

-- Status labels inside Settings tab
local StatusLabel = SettingsTab:AddLabel('Database Status: Loading...', true)
local FilterLabel = SettingsTab:AddLabel('Filter: Min 1 - Max 100 chars', true)
SettingsTab:AddDivider()

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
-- WordTab:AddLabel('Quick Search:')
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

-- Search Results in separate card
local ResultsBox = Tabs.Main:AddLeftGroupbox('Search Results')

local PageInfoLabel = ResultsBox:AddLabel('Page: 1 / 1 | Total: 0 words', true)
ResultsBox:AddDivider()

-- Table with proper column formatting
local ROWS = 15
local RowLabels = {}

-- Add table rows with column formatting (No | Result)
for i = 1, ROWS do
	RowLabels[i] = ResultsBox:AddLabel('', false)
end

ResultsBox:AddDivider()

-- Pagination controls inline
WordTab:AddButton({
	Text = 'Prev',
	DoubleClick = false,
	Tooltip = 'Go to previous page',
	Func = function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			Refresh()
		end
	end
}):AddButton({
	Text = 'Next',
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

WordTab:AddDivider()

-- Update results display function
local function UpdateResultsDisplay()
	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)

	if #currentSearchResults == 0 or startIndex > endIndex then
		-- Clear all rows when no results
		for i = 1, ROWS do
			RowLabels[i]:SetText('')
		end
		PageInfoLabel:SetText('Page: 1 / 1 | Total: 0 words')
		return
	end

	-- Fill visible rows with formatted table data
	local row = 1
	for i = startIndex, endIndex do
		if row > ROWS then break end
		local no = string.format('%02d', i)
		local word = currentSearchResults[i]
		-- Format: "No | Result" with proper spacing
		RowLabels[row]:SetText(string.format('%-4s | %s', no, word))
		row = row + 1
	end
	-- Clear remaining empty rows
	for i = row, ROWS do
		RowLabels[i]:SetText('')
	end

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
	Text = 'Apply Filters & Reload',
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

-- ==================== VISUAL TAB (ESP) ====================
local ESPBox = Tabs.Visual:AddLeftGroupbox('ESP Settings')

ESPBox:AddToggle('EnableESP', {
	Text = 'Enable ESP',
	Default = false,
	Tooltip = 'Toggle ESP on/off',
	Callback = function(Value)
		ToggleESP(Value)
	end
})

ESPBox:AddDivider()

ESPBox:AddToggle('ShowName', {
	Text = 'Show Names',
	Default = true,
	Tooltip = 'Display player names',
	Callback = function(Value)
		ESPSettings.ShowName = Value
	end
})

ESPBox:AddToggle('ShowDistance', {
	Text = 'Show Distance',
	Default = true,
	Tooltip = 'Display distance to players',
	Callback = function(Value)
		ESPSettings.ShowDistance = Value
	end
})

ESPBox:AddToggle('ShowBox', {
	Text = 'Show Box',
	Default = true,
	Tooltip = 'Display box around players',
	Callback = function(Value)
		ESPSettings.ShowBox = Value
	end
})

ESPBox:AddToggle('TeamCheck', {
	Text = 'Team Check',
	Default = false,
	Tooltip = 'Hide teammates from ESP',
	Callback = function(Value)
		ESPSettings.TeamCheck = Value
	end
})

ESPBox:AddDivider()

ESPBox:AddSlider('MaxDistance', {
	Text = 'Max Distance',
	Default = 1000,
	Min = 100,
	Max = 5000,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		ESPSettings.MaxDistance = Value
	end
})

local ESPColorsBox = Tabs.Visual:AddRightGroupbox('ESP Colors')

ESPColorsBox:AddLabel('Name Color:'):AddColorPicker('NameColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Name Color',
	Callback = function(Value)
		ESPSettings.NameColor = Value
	end
})

ESPColorsBox:AddLabel('Box Color:'):AddColorPicker('BoxColor', {
	Default = Color3.fromRGB(255, 0, 0),
	Title = 'Box Color',
	Callback = function(Value)
		ESPSettings.BoxColor = Value
	end
})

-- ==================== UI CONFIG TAB ====================
local MenuGroup = Tabs['UI Config']:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
	Text = '⚠️ Unload UI',
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

	Library:SetWatermark(('hubsense | %s fps | %s ms | Words: %s'):format(
		math.floor(FPS),
		math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()),
		#Words
	))
end)

Library.KeybindFrame.Visible = true

Library:OnUnload(function()
	WatermarkConnection:Disconnect()
	print('hubsense unloaded!')
	Library.Unloaded = true
end)

-- Theme Manager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('hubsense')
SaveManager:SetFolder('hubsense/WordSuggester')

SaveManager:BuildConfigSection(Tabs['UI Config'])
ThemeManager:ApplyToTab(Tabs['UI Config'])

-- Set GameSense/Skeet theme
ThemeManager:ApplyTheme('Default')

SaveManager:LoadAutoloadConfig()