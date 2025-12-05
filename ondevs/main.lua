-- hubsense - Word Suggester Hub
-- Skeet/GameSense Style UI

local repo = 'https://raw.githubusercontent.com/xXehub/hubsense-lib/refs/heads/main/ondevs/'

local Library = loadstring(game:HttpGet(repo .. 'LinoriaLib.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'SaveManager.lua'))()

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
local ChamsEnabled = false -- Separate from ESP
local ESPConnections = {}
local ChamsConnections = {} -- Separate connections for Chams
local ESPObjects = {}
local ChamsObjects = {} -- Separate storage for Chams highlights
local ESPPreviewFrame = nil
local DynamicESPConnection = nil -- Connection for ESP preview update loop
local SimulatedDistance = 150 -- Simulated distance in studs for ESP preview scaling

-- Forward declarations for functions defined later
local ApplyChamsToModel = nil
local UpdateESPPreview = nil

local ESPSettings = {
	ShowName = true,
	ShowDistance = true,
	ShowHealth = true,
	ShowBox = true,
	BoxESP = false,
	SkeletonESP = false,
	ChamsESP = false,
	FilledBox = false,
	MaxDistance = 1000,
	TeamCheck = false,
	NameColor = Color3.fromRGB(255, 255, 255),
	BoxColor = Color3.fromRGB(255, 0, 0),
	HealthBarColor = Color3.fromRGB(0, 255, 0),
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	DistanceColor = Color3.fromRGB(180, 180, 180),
	TracerColor = Color3.fromRGB(255, 255, 255),
	LineColor = Color3.fromRGB(255, 255, 255),
	-- Chams Settings
	ChamsColor = Color3.fromRGB(255, 120, 0),
	ChamsTransparency = 0.3,
	ChamsVisibleOnly = false,
	ChamsOutline = true,
	ChamsOutlineColor = Color3.fromRGB(0, 0, 0),
	ChamsOutlineTransparency = 0.5,
	-- Other
	FilledBoxTransparency = 0.2
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
			print('[Words] Loaded ' .. #Words .. ' words')
			return true
		else
			warn('[Words] Failed to get response body')
			return false
		end
	end)
	
	if success and result then
		loaded = true
	else
		warn('[Words] Load failed:', result)
		loaded = true -- Set true anyway to prevent infinite retry
	end
end

-- Reload Words with new filter
local function ReloadWords()
	print('[ReloadWords] Starting reload...')
	Words = {}
	WordDictionary = {}
	searchCache = {}
	loaded = false
	currentPage = 1
	currentSearchResults = {}
	
	spawn(function()
		LoadWords()
		local maxWait = 50 -- 5 seconds max
		local waited = 0
		while not loaded and waited < maxWait do
			wait(0.1)
			waited = waited + 1
		end
		print('[ReloadWords] Completed. Words loaded:', #Words)
		if StatusLabel then
			StatusLabel:SetText('✅ Words Loaded: ' .. #Words)
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

-- ==================== CAMERA AND ROTATION FUNCTIONS (DEFINE EARLY) ====================
local CurrentRotation = 180
local CharacterModel = nil
local CameraDistance = 4
local MinZoom = 2
local MaxZoom = 10
local ViewportCamera = nil
local PartMap = {} -- Global part mapping for rotation

local function UpdateCameraZoom(distance)
	CameraDistance = math.clamp(distance, MinZoom, MaxZoom)
	if ViewportCamera then
		-- Camera positioned to view full body (focus on chest area, Y=2)
		-- Use CFrame.lookAt to properly orient camera toward character
		ViewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, 2, CameraDistance), Vector3.new(0, 2, 0))
		ViewportCamera.Focus = CFrame.new(0, 2, 0)
		print('[ESP Preview] Zoom updated:', CameraDistance)
	end
end

local function RotateCharacter(angleDegrees)
	if not CharacterModel or not CharacterModel.PrimaryPart then return end
	if not PartMap or not next(PartMap) then return end
	
	local char = game.Players.LocalPlayer.Character
	if not char then return end
	
	local originalHRP = char:FindFirstChild('HumanoidRootPart')
	if not originalHRP then return end
	
	CurrentRotation = angleDegrees % 360
	
	-- Calculate proper Y offset based on rig type
	local rigType = char:FindFirstChild('Torso') and 'R6' or 'R15'
	local heightOffset = rigType == 'R6' and 2.5 or 2.8
	
	-- Target position: centered at origin with heightOffset, rotated
	local targetCFrame = CFrame.new(0, heightOffset, 0) * CFrame.Angles(0, math.rad(CurrentRotation), 0)
	
	-- Rotate all parts around center point
	for originalPart, clonedPart in pairs(PartMap) do
		if clonedPart and clonedPart.Parent and originalPart and originalPart.Parent then
			pcall(function()
				if clonedPart:IsA('BasePart') and originalPart:IsA('BasePart') then
					local offset = originalHRP.CFrame:ToObjectSpace(originalPart.CFrame)
					clonedPart.CFrame = targetCFrame:ToWorldSpace(offset)
				end
			end)
		end
	end
end

-- ==================== ESP PREVIEW UPDATE FUNCTION ====================
UpdateESPPreview = function()
	if not ESPPreviewFrame then return end
	
	-- Update Box ESP borders
	if ESPPreviewFrame.BoxTop then
		local boxVisible = ESPSettings.BoxESP == true
		ESPPreviewFrame.BoxTop.Visible = boxVisible
		ESPPreviewFrame.BoxBottom.Visible = boxVisible
		ESPPreviewFrame.BoxLeft.Visible = boxVisible
		ESPPreviewFrame.BoxRight.Visible = boxVisible
		
		if boxVisible then
			local boxColor = ESPSettings.BoxColor or Color3.fromRGB(255, 0, 0)
			ESPPreviewFrame.BoxTop.BackgroundColor3 = boxColor
			ESPPreviewFrame.BoxBottom.BackgroundColor3 = boxColor
			ESPPreviewFrame.BoxLeft.BackgroundColor3 = boxColor
			ESPPreviewFrame.BoxRight.BackgroundColor3 = boxColor
		end
	end
	
	-- Update Filled Box
	if ESPPreviewFrame.BoxFill then
		ESPPreviewFrame.BoxFill.Visible = ESPSettings.FilledBox == true
		ESPPreviewFrame.BoxFill.BackgroundColor3 = ESPSettings.BoxColor or Color3.fromRGB(255, 0, 0)
		ESPPreviewFrame.BoxFill.BackgroundTransparency = ESPSettings.FilledBoxTransparency or 0.2
	end
	
	-- Update Chams (uses direct part coloring in ViewportFrame)
	-- Force update chams every time UpdateESPPreview is called
	if ApplyChamsToModel and CharacterModel then
		pcall(function()
			ApplyChamsToModel(ESPSettings.ChamsESP == true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
		end)
	end
	
	-- Update Skeleton ESP visibility and colors (Universal R6/R15)
	local skeletonVisible = ESPSettings.SkeletonESP == true
	local skeletonColor = ESPSettings.SkeletonColor or Color3.fromRGB(255, 255, 255)
	
	-- Update all skeleton lines (works with dynamic skeleton system)
	if SkeletonLines then
		for _, line in pairs(SkeletonLines) do
			if line and line.Parent then
				line.Visible = skeletonVisible
				line.BackgroundColor3 = skeletonColor
			end
		end
	end
	
	-- Update head dot
	if HeadDotFrame then
		HeadDotFrame.Visible = skeletonVisible
		HeadDotFrame.BackgroundColor3 = skeletonColor
	end
	
	-- Update Name Label
	if ESPPreviewFrame.NameLabel then
		ESPPreviewFrame.NameLabel.Visible = ESPSettings.ShowName == true
		ESPPreviewFrame.NameLabel.TextColor3 = ESPSettings.NameColor or Color3.fromRGB(255, 255, 255)
	end
	
	-- Update Distance Label
	if ESPPreviewFrame.DistanceLabel then
		ESPPreviewFrame.DistanceLabel.Visible = ESPSettings.ShowDistance == true
		ESPPreviewFrame.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
	end
	
	-- Update Health Bar
	if ESPPreviewFrame.HealthBarBG and ESPPreviewFrame.HealthBar and ESPPreviewFrame.HealthText then
		local healthVisible = ESPSettings.ShowHealth == true
		ESPPreviewFrame.HealthBarBG.Visible = healthVisible
		ESPPreviewFrame.HealthBar.Visible = healthVisible
		ESPPreviewFrame.HealthText.Visible = healthVisible
		
		if healthVisible then
			ESPPreviewFrame.HealthBar.BackgroundColor3 = ESPSettings.HealthBarColor or Color3.fromRGB(0, 255, 0)
		end
	end
	
	-- Refresh skeleton if toggled
	if skeletonVisible and UpdateSkeletonPreview then
		UpdateSkeletonPreview()
	end
end

-- ==================== ESP FUNCTIONS (ADVANCED) ====================
-- Calculate 2D box position from 3D character
local function CalculateBox(character)
	local camera = workspace.CurrentCamera
	local hrp = character:FindFirstChild('HumanoidRootPart')
	if not hrp then return nil, nil, false end
	
	local rigType = character:FindFirstChild('Torso') and 'R6' or 'R15'
	local position = hrp.Position
	local cframe = hrp.CFrame
	local upVector = cframe.UpVector
	
	-- Calculate top and bottom positions
	local topY = rigType == 'R6' and 0.5 or 1.8
	local bottomY = rigType == 'R6' and 4 or 2.5
	
	local top, topOnScreen = camera:WorldToViewportPoint(position + (upVector * topY))
	local bottom, bottomOnScreen = camera:WorldToViewportPoint(position - (upVector * bottomY))
	
	if not (topOnScreen and bottomOnScreen) then
		return nil, nil, false
	end
	
	-- Calculate box dimensions
	local width = math.max(math.floor(math.abs(top.X - bottom.X)), 3)
	local height = math.max(math.floor(math.max(math.abs(bottom.Y - top.Y), width / 2)), 3)
	local boxSize = Vector2.new(math.floor(math.max(height / 1.5, width)), height)
	local boxPosition = Vector2.new(math.floor(top.X / 2 + bottom.X / 2 - boxSize.X / 2), math.floor(math.min(top.Y, bottom.Y)))
	
	return boxPosition, boxSize, true
end

local function CreateESP(player)
	if not player.Character or ESPObjects[player] then return end
	
	local char = player.Character
	local hrp = char:FindFirstChild('HumanoidRootPart')
	local humanoid = char:FindFirstChild('Humanoid')
	if not hrp or not humanoid then return end
	
	-- Create ESP objects table
	ESPObjects[player] = {
		-- 2D Box
		BoxOutline = Drawing.new('Square'),
		Box = Drawing.new('Square'),
		BoxFilled = Drawing.new('Square'),  -- Filled box
		
		-- Tracer
		Tracer = Drawing.new('Line'),
		
		-- Text labels
		NameText = Drawing.new('Text'),
		DistanceText = Drawing.new('Text'),
		HealthText = Drawing.new('Text'),
		
		-- Health bar
		HealthBarOutline = Drawing.new('Line'),
		HealthBar = Drawing.new('Line'),
		
		-- Head dot
		HeadDotOutline = Drawing.new('Circle'),
		HeadDot = Drawing.new('Circle'),
		
		-- Skeleton lines
		Skeleton = {},
		
		-- Chams (3D Highlight)
		Chams = nil  -- Will be created if character exists
	}
	
	-- Initialize skeleton lines
	for i = 1, 6 do
		ESPObjects[player].Skeleton[i] = Drawing.new('Line')
	end
	
	local espObj = ESPObjects[player]
	
	-- Set default properties for box
	espObj.BoxOutline.Thickness = 3
	espObj.BoxOutline.Filled = false
	espObj.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
	espObj.BoxOutline.Transparency = 1
	espObj.Box.Thickness = 1
	espObj.Box.Filled = false
	espObj.Box.Color = ESPSettings.BoxColor
	espObj.Box.Transparency = 1
	
	-- Set default properties for tracer
	espObj.Tracer.Thickness = 1
	espObj.Tracer.Color = ESPSettings.LineColor
	espObj.Tracer.Transparency = 1
	
	-- Set default properties for text
	espObj.NameText.Size = 13
	espObj.NameText.Center = true
	espObj.NameText.Outline = true
	espObj.NameText.Color = ESPSettings.NameColor
	espObj.NameText.Transparency = 1
	
	espObj.DistanceText.Size = 12
	espObj.DistanceText.Center = true
	espObj.DistanceText.Outline = true
	espObj.DistanceText.Color = Color3.fromRGB(180, 180, 180)
	espObj.DistanceText.Transparency = 1
	
	espObj.HealthText.Size = 11
	espObj.HealthText.Outline = true
	espObj.HealthText.Color = Color3.fromRGB(255, 255, 255)
	espObj.HealthText.Transparency = 1
	
	-- Set default properties for health bar
	espObj.HealthBarOutline.Thickness = 3
	espObj.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
	espObj.HealthBarOutline.Transparency = 1
	espObj.HealthBar.Thickness = 1
	espObj.HealthBar.Transparency = 1
	
	-- Set default properties for head dot
	espObj.HeadDotOutline.Thickness = 3
	espObj.HeadDotOutline.NumSides = 30
	espObj.HeadDotOutline.Color = Color3.fromRGB(0, 0, 0)
	espObj.HeadDotOutline.Transparency = 1
	espObj.HeadDotOutline.Filled = false
	espObj.HeadDot.Thickness = 1
	espObj.HeadDot.NumSides = 30
	espObj.HeadDot.Color = ESPSettings.SkeletonColor
	espObj.HeadDot.Transparency = 1
	espObj.HeadDot.Filled = false
	
	-- Set default properties for skeleton
	for i = 1, 6 do
		espObj.Skeleton[i].Thickness = 1
		espObj.Skeleton[i].Color = ESPSettings.SkeletonColor
		espObj.Skeleton[i].Transparency = 1
	end
	
	-- Set default properties for filled box
	espObj.BoxFilled.Filled = true
	espObj.BoxFilled.Color = ESPSettings.BoxColor
	espObj.BoxFilled.Transparency = 1 - ESPSettings.FilledBoxTransparency
	
	-- Note: Chams (Highlight) is now handled separately by ToggleChams
end

local function RemoveESP(player)
	if ESPObjects[player] then
		-- Remove all Drawing objects
		local espObj = ESPObjects[player]
		
		if espObj.Box then espObj.Box:Remove() end
		if espObj.BoxOutline then espObj.BoxOutline:Remove() end
		if espObj.BoxFilled then espObj.BoxFilled:Remove() end
		if espObj.Tracer then espObj.Tracer:Remove() end
		if espObj.NameText then espObj.NameText:Remove() end
		if espObj.DistanceText then espObj.DistanceText:Remove() end
		if espObj.HealthText then espObj.HealthText:Remove() end
		if espObj.HealthBar then espObj.HealthBar:Remove() end
		if espObj.HealthBarOutline then espObj.HealthBarOutline:Remove() end
		if espObj.HeadDot then espObj.HeadDot:Remove() end
		if espObj.HeadDotOutline then espObj.HeadDotOutline:Remove() end
		
		if espObj.Skeleton then
			for i = 1, 6 do
				if espObj.Skeleton[i] then
					espObj.Skeleton[i]:Remove()
				end
			end
		end
		
		ESPObjects[player] = nil
	end
end

local function UpdateESP()
	local localPlayer = game.Players.LocalPlayer
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild('HumanoidRootPart') then return end
	local localHRP = localPlayer.Character.HumanoidRootPart
	local camera = workspace.CurrentCamera
	
	for player, espObj in pairs(ESPObjects) do
		if player and player.Character and player.Character:FindFirstChild('HumanoidRootPart') then
			local char = player.Character
			local hrp = char:FindFirstChild('HumanoidRootPart')
			local humanoid = char:FindFirstChild('Humanoid')
			local head = char:FindFirstChild('Head')
			
			local distance = (localHRP.Position - hrp.Position).Magnitude
			
			-- Check distance and team
			local shouldShow = distance <= ESPSettings.MaxDistance
			if ESPSettings.TeamCheck and player.Team == localPlayer.Team then
				shouldShow = false
			end
			
			if humanoid and humanoid.Health <= 0 then
				shouldShow = false
			end
			
			-- Calculate 2D box
			local boxPosition, boxSize, onScreen = CalculateBox(char)
			
			if shouldShow and onScreen and boxPosition and boxSize then
				-- Update Box ESP
				if ESPSettings.BoxESP then
					espObj.BoxOutline.Visible = true
					espObj.BoxOutline.Position = boxPosition
					espObj.BoxOutline.Size = boxSize
					espObj.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
					
					espObj.Box.Visible = true
					espObj.Box.Position = boxPosition
					espObj.Box.Size = boxSize
					espObj.Box.Color = ESPSettings.BoxColor
				else
					espObj.BoxOutline.Visible = false
					espObj.Box.Visible = false
				end
				
				-- Update Filled Box
				if ESPSettings.FilledBox then
					espObj.BoxFilled.Visible = true
					espObj.BoxFilled.Position = boxPosition
					espObj.BoxFilled.Size = boxSize
					espObj.BoxFilled.Color = ESPSettings.BoxColor
					espObj.BoxFilled.Transparency = 1 - ESPSettings.FilledBoxTransparency
				else
					espObj.BoxFilled.Visible = false
				end
				
				-- Note: Chams is now handled separately by UpdateChams
				
				-- Update Tracer
				if ESPSettings.ShowBox then
					espObj.Tracer.Visible = true
					local viewportSize = camera.ViewportSize
					espObj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
					espObj.Tracer.To = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y)
					espObj.Tracer.Color = ESPSettings.LineColor
				else
					espObj.Tracer.Visible = false
				end
				
				-- Update Name
				if ESPSettings.ShowName then
					espObj.NameText.Visible = true
					espObj.NameText.Text = player.DisplayName or player.Name
					espObj.NameText.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y - 18)
					espObj.NameText.Color = ESPSettings.NameColor
				else
					espObj.NameText.Visible = false
				end
				
				-- Update Distance
				if ESPSettings.ShowDistance then
					espObj.DistanceText.Visible = true
					espObj.DistanceText.Text = string.format('[%dm]', math.floor(distance))
					espObj.DistanceText.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
				else
					espObj.DistanceText.Visible = false
				end
				
				-- Update Health Bar
				if ESPSettings.ShowHealth and humanoid then
					local health = humanoid.Health
					local maxHealth = humanoid.MaxHealth
					local healthPercent = health / maxHealth
					
					espObj.HealthBarOutline.Visible = true
					espObj.HealthBarOutline.From = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y + 1)
					espObj.HealthBarOutline.To = Vector2.new(boxPosition.X - 6, boxPosition.Y - 1)
					
					espObj.HealthBar.Visible = true
					espObj.HealthBar.From = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y)
					espObj.HealthBar.To = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y - (boxSize.Y * healthPercent))
					espObj.HealthBar.Color = Color3.fromRGB(255 - math.floor(healthPercent * 255), math.floor(healthPercent * 255), 0)
					
					espObj.HealthText.Visible = true
					espObj.HealthText.Text = tostring(math.floor(health))
					espObj.HealthText.Position = Vector2.new(boxPosition.X - 20, boxPosition.Y + boxSize.Y - (boxSize.Y * healthPercent) - 7)
				else
					espObj.HealthBarOutline.Visible = false
					espObj.HealthBar.Visible = false
					espObj.HealthText.Visible = false
				end
				
				-- Update Head Dot
				if ESPSettings.SkeletonESP and head then
					local headPos, headOnScreen = camera:WorldToViewportPoint(head.Position)
					if headOnScreen then
						local headTop = camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)).Position)
						local headBottom = camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, -head.Size.Y / 2, 0)).Position)
						local headRadius = math.abs((headTop - headBottom).Y) / 2
						
						espObj.HeadDotOutline.Visible = true
						espObj.HeadDotOutline.Position = Vector2.new(headPos.X, headPos.Y)
						espObj.HeadDotOutline.Radius = headRadius
						
						espObj.HeadDot.Visible = true
						espObj.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
						espObj.HeadDot.Radius = headRadius
						espObj.HeadDot.Color = ESPSettings.SkeletonColor
					else
						espObj.HeadDotOutline.Visible = false
						espObj.HeadDot.Visible = false
					end
				else
					espObj.HeadDotOutline.Visible = false
					espObj.HeadDot.Visible = false
				end
				
				-- Update Skeleton
				if ESPSettings.SkeletonESP then
					local torso = char:FindFirstChild('UpperTorso') or char:FindFirstChild('Torso')
					local leftArm = char:FindFirstChild('LeftUpperArm') or char:FindFirstChild('Left Arm')
					local rightArm = char:FindFirstChild('RightUpperArm') or char:FindFirstChild('Right Arm')
					local leftLeg = char:FindFirstChild('LeftUpperLeg') or char:FindFirstChild('Left Leg')
					local rightLeg = char:FindFirstChild('RightUpperLeg') or char:FindFirstChild('Right Leg')
					
					local parts = {head, torso, leftArm, rightArm, leftLeg, rightLeg}
					local validParts = true
					
					for _, part in pairs(parts) do
						if not part then
							validParts = false
							break
						end
					end
					
					if validParts then
						local connections = {
							{head, torso}, -- Neck
							{torso, leftArm}, -- Left shoulder
							{torso, rightArm}, -- Right shoulder
							{torso, leftLeg}, -- Left hip
							{torso, rightLeg}, -- Right hip
							{leftLeg, rightLeg} -- Pelvis
						}
						
						for i = 1, 6 do
							local from, to = connections[i][1], connections[i][2]
							local fromPos, fromOnScreen = camera:WorldToViewportPoint(from.Position)
							local toPos, toOnScreen = camera:WorldToViewportPoint(to.Position)
							
							if fromOnScreen and toOnScreen then
								espObj.Skeleton[i].Visible = true
								espObj.Skeleton[i].From = Vector2.new(fromPos.X, fromPos.Y)
								espObj.Skeleton[i].To = Vector2.new(toPos.X, toPos.Y)
								espObj.Skeleton[i].Color = ESPSettings.SkeletonColor
							else
								espObj.Skeleton[i].Visible = false
							end
						end
					else
						for i = 1, 6 do
							espObj.Skeleton[i].Visible = false
						end
					end
				else
					for i = 1, 6 do
						espObj.Skeleton[i].Visible = false
					end
				end
			else
				-- Hide all ESP elements (Chams handled separately)
				if espObj.Box then espObj.Box.Visible = false end
				if espObj.BoxOutline then espObj.BoxOutline.Visible = false end
				if espObj.BoxFilled then espObj.BoxFilled.Visible = false end
				if espObj.Tracer then espObj.Tracer.Visible = false end
				if espObj.NameText then espObj.NameText.Visible = false end
				if espObj.DistanceText then espObj.DistanceText.Visible = false end
				if espObj.HealthText then espObj.HealthText.Visible = false end
				if espObj.HealthBar then espObj.HealthBar.Visible = false end
				if espObj.HealthBarOutline then espObj.HealthBarOutline.Visible = false end
				if espObj.HeadDot then espObj.HeadDot.Visible = false end
				if espObj.HeadDotOutline then espObj.HeadDotOutline.Visible = false end
				for i = 1, 6 do
					if espObj.Skeleton[i] then espObj.Skeleton[i].Visible = false end
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

-- ==================== CHAMS SYSTEM (INDEPENDENT FROM ESP) ====================
local function IsPlayerVisible(player)
	local localPlayer = game.Players.LocalPlayer
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild('Head') then return false end
	local localHead = localPlayer.Character.Head
	
	if not player.Character or not player.Character:FindFirstChild('HumanoidRootPart') then return false end
	local targetHRP = player.Character.HumanoidRootPart
	
	-- Raycast from local player's head to target's HumanoidRootPart
	local origin = localHead.Position
	local direction = (targetHRP.Position - origin)
	local distance = direction.Magnitude
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {localPlayer.Character, player.Character}
	
	local result = workspace:Raycast(origin, direction.Unit * distance, raycastParams)
	
	-- If raycast hits nothing or hits further than target, player is visible
	return result == nil or result.Distance >= distance - 1
end

local function CreateChams(player)
	if player == game.Players.LocalPlayer then return end
	if ChamsObjects[player] then return end
	
	local char = player.Character
	if not char then return end
	
	local highlight = Instance.new('Highlight')
	highlight.Name = 'Chams'
	highlight.Adornee = char
	highlight.FillColor = ESPSettings.ChamsColor
	highlight.FillTransparency = ESPSettings.ChamsTransparency
	highlight.OutlineColor = ESPSettings.ChamsOutlineColor
	highlight.OutlineTransparency = ESPSettings.ChamsOutline and ESPSettings.ChamsOutlineTransparency or 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = true
	highlight.Parent = char
	
	ChamsObjects[player] = highlight
end

local function RemoveChams(player)
	if ChamsObjects[player] then
		ChamsObjects[player]:Destroy()
		ChamsObjects[player] = nil
	end
end

local function UpdateChams()
	local localPlayer = game.Players.LocalPlayer
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild('HumanoidRootPart') then return end
	local localHRP = localPlayer.Character.HumanoidRootPart
	
	for player, highlight in pairs(ChamsObjects) do
		if player and player.Character and player.Character:FindFirstChild('HumanoidRootPart') then
			local char = player.Character
			local hrp = char:FindFirstChild('HumanoidRootPart')
			local humanoid = char:FindFirstChild('Humanoid')
			
			local distance = (localHRP.Position - hrp.Position).Magnitude
			
			-- Check distance and team
			local shouldShow = distance <= ESPSettings.MaxDistance
			if ESPSettings.TeamCheck and player.Team == localPlayer.Team then
				shouldShow = false
			end
			
			if humanoid and humanoid.Health <= 0 then
				shouldShow = false
			end
			
			-- Check visibility if ChamsVisibleOnly is enabled
			if shouldShow and ESPSettings.ChamsVisibleOnly then
				shouldShow = IsPlayerVisible(player)
			end
			
			if shouldShow then
				highlight.Enabled = true
				highlight.FillColor = ESPSettings.ChamsColor
				highlight.FillTransparency = ESPSettings.ChamsTransparency
				highlight.OutlineColor = ESPSettings.ChamsOutlineColor
				highlight.OutlineTransparency = ESPSettings.ChamsOutline and ESPSettings.ChamsOutlineTransparency or 1
			else
				highlight.Enabled = false
			end
		else
			RemoveChams(player)
		end
	end
end

local function ToggleChams(enabled)
	ChamsEnabled = enabled
	ESPSettings.ChamsESP = enabled
	
	if enabled then
		-- Create Chams for all existing players
		for _, player in pairs(game.Players:GetPlayers()) do
			if player ~= game.Players.LocalPlayer then
				if player.Character then
					CreateChams(player)
				end
			end
		end
		
		-- Listen for new players and character spawns
		ChamsConnections.PlayerAdded = game.Players.PlayerAdded:Connect(function(player)
			if player ~= game.Players.LocalPlayer then
				player.CharacterAdded:Connect(function()
					wait(0.5)
					if ChamsEnabled then CreateChams(player) end
				end)
				if player.Character then CreateChams(player) end
			end
		end)
		
		ChamsConnections.PlayerRemoving = game.Players.PlayerRemoving:Connect(function(player)
			RemoveChams(player)
		end)
		
		-- Update loop
		ChamsConnections.UpdateLoop = game:GetService('RunService').RenderStepped:Connect(function()
			if ChamsEnabled then UpdateChams() end
		end)
	else
		-- Remove all Chams
		for player, _ in pairs(ChamsObjects) do
			RemoveChams(player)
		end
		
		-- Disconnect all connections
		for _, connection in pairs(ChamsConnections) do
			connection:Disconnect()
		end
		ChamsConnections = {}
	end
	
	-- Update preview
	UpdateESPPreview()
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
	Title = 'hubsense | made by elhubski',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
	Size = UDim2.fromOffset(660, 560)
})

-- Side navbar: Main + Visual + Configuration
local Tabs = {
	Main = Window:AddTab('Main'),
	Visual = Window:AddTab('Visual'),
	['Configuration'] = Window:AddTab('Configuration'),
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

-- Search Results in separate card (CREATE FIRST)
local ResultsBox = Tabs.Main:AddLeftGroupbox('Search Results')

-- Table with proper widget
local ResultsTable = ResultsBox:AddTable({
	Headers = {'No', 'Word'};
	MaxRows = 15;
})

ResultsBox:AddDivider()

-- Pagination info and controls at bottom
local PageInfoLabel = ResultsBox:AddLabel('Page: 1 / 1 | Total: 0 words', true)

-- Update results display function (DEFINE BEFORE BUTTONS)
local function UpdateResultsDisplay()
	local startIndex = (currentPage - 1) * wordsPerPage + 1
	local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)

	if #currentSearchResults == 0 or startIndex > endIndex then
		-- Clear table when no results
		ResultsTable:Clear()
		PageInfoLabel:SetText('Page: 1 / 1 | Total: 0 words')
		return
	end

	-- Build rows data
	local rowsData = {}
	for i = startIndex, endIndex do
		if #rowsData >= 15 then break end
		local no = string.format('%02d', i)
		local word = currentSearchResults[i]
		table.insert(rowsData, {no, word})
	end

	-- Update table with new data
	ResultsTable:SetRows(rowsData)

	local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
	PageInfoLabel:SetText('Page: ' .. currentPage .. ' / ' .. totalPages .. ' | Total: ' .. #currentSearchResults .. ' words')
end

-- Add pagination buttons after function definition
ResultsBox:AddButton({
	Text = 'Prev',
	DoubleClick = false,
	Tooltip = 'Go to previous page',
	Func = function()
		if #currentSearchResults > 0 and currentPage > 1 then
			currentPage = currentPage - 1
			UpdateResultsDisplay()
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
				UpdateResultsDisplay()
			end
		end
	end
})

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
			UpdateResultsDisplay()
			return
		end
		currentPage = 1
		currentSearchResults = SuggestWords(Value, 1000)
		UpdateResultsDisplay()
	end
})

WordTab:AddDivider()

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

-- ==================== VISUAL TAB (ESP & CHAMS) ====================
local ESPTabbox = Tabs.Visual:AddLeftTabbox('ESP & Chams')

-- ===== ESP TAB =====
local ESPTab = ESPTabbox:AddTab('ESP Settings')

ESPTab:AddToggle('EnableESP', {
	Text = 'Enable ESP',
	Default = false,
	Tooltip = 'Toggle ESP on/off',
	Callback = function(Value)
		ToggleESP(Value)
	end
}):AddKeyPicker('ESPKeybind', {
	Default = 'F2',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'ESP Keybind',
	NoUI = false
})

ESPTab:AddSlider('MaxDistance', {
	Text = 'Max Distance',
	Default = 1000,
	Min = 100,
	Max = 5000,
	Rounding = 0,
	Suffix = ' studs',
	Compact = false,
	Callback = function(Value)
		ESPSettings.MaxDistance = Value
	end
})

ESPTab:AddToggle('ShowName', {
	Text = 'Show Names',
	Default = true,
	Tooltip = 'Display player names',
	Callback = function(Value)
		ESPSettings.ShowName = Value
		UpdateESPPreview()
	end
}):AddColorPicker('NameColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Name Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.NameColor = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('ShowDistance', {
	Text = 'Show Distance',
	Default = true,
	Tooltip = 'Display distance to players',
	Callback = function(Value)
		ESPSettings.ShowDistance = Value
		UpdateESPPreview()
	end
}):AddColorPicker('DistanceColor', {
	Default = Color3.fromRGB(180, 180, 180),
	Title = 'Distance Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.DistanceColor = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('ShowHealth', {
	Text = 'Show Health',
	Default = true,
	Tooltip = 'Display health bar',
	Callback = function(Value)
		ESPSettings.ShowHealth = Value
		UpdateESPPreview()
	end
}):AddColorPicker('HealthBarColor', {
	Default = Color3.fromRGB(0, 255, 0),
	Title = 'Health Bar Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.HealthBarColor = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('ShowBox', {
	Text = 'Show Line',
	Default = true,
	Tooltip = 'Display line around players',
	Callback = function(Value)
		ESPSettings.ShowBox = Value
		UpdateESPPreview()
	end
}):AddColorPicker('LineColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Line Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.LineColor = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('BoxESP', {
	Text = 'Box ESP',
	Default = false,
	Tooltip = 'Display box outline around players',
	Callback = function(Value)
		ESPSettings.BoxESP = Value
		UpdateESPPreview()
	end
}):AddColorPicker('BoxColor', {
	Default = Color3.fromRGB(255, 0, 0),
	Title = 'Box Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.BoxColor = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('SkeletonESP', {
	Text = 'Skeleton ESP',
	Default = false,
	Tooltip = 'Display skeleton bones',
	Callback = function(Value)
		ESPSettings.SkeletonESP = Value
		if ESPPreviewFrame and ESPPreviewFrame.UpdateSkeleton then
			ESPPreviewFrame.UpdateSkeleton()
		end
		UpdateESPPreview()
	end
}):AddColorPicker('SkeletonColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Skeleton Color',
	Transparency = 0,
	Callback = function(Value)
		ESPSettings.SkeletonColor = Value
		if ESPPreviewFrame and ESPPreviewFrame.UpdateSkeleton then
			ESPPreviewFrame.UpdateSkeleton()
		end
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('FilledBox', {
	Text = 'Filled Box',
	Default = false,
	Tooltip = 'Fill box background with transparent color',
	Callback = function(Value)
		ESPSettings.FilledBox = Value
		UpdateESPPreview()
	end
})

ESPTab:AddToggle('TeamCheck', {
	Text = 'Team Check',
	Default = false,
	Tooltip = 'Hide teammates from ESP',
	Callback = function(Value)
		ESPSettings.TeamCheck = Value
	end
})

-- ===== CHAMS TAB =====
local ChamsTab = ESPTabbox:AddTab('Chams')

ChamsTab:AddToggle('ChamsESP', {
	Text = 'Enable Chams',
	Default = false,
	Tooltip = 'Highlight player body parts with color overlay',
	Callback = function(Value)
		ToggleChams(Value)
	end
}):AddKeyPicker('ChamsKeybind', {
	Default = 'F3',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Chams Keybind',
	NoUI = false
})

ChamsTab:AddLabel(''):AddColorPicker('ChamsColor', {
	Default = Color3.fromRGB(255, 120, 0),
	Title = 'Chams Fill Color',
	Transparency = 0.3,
	Callback = function(Value)
		ESPSettings.ChamsColor = Value
		-- Get transparency from Options
		if Options.ChamsColor then
			ESPSettings.ChamsTransparency = Options.ChamsColor.Transparency or 0.3
		end
		-- Force immediate update
		if ApplyChamsToModel and CharacterModel and ESPSettings.ChamsESP then
			pcall(function()
				ApplyChamsToModel(true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
			end)
		end
	end
})

ChamsTab:AddToggle('ChamsVisibleOnly', {
	Text = 'Visible Only',
	Default = false,
	Tooltip = 'Only show chams when player is visible (not behind walls)',
	Callback = function(Value)
		ESPSettings.ChamsVisibleOnly = Value
	end
})

ChamsTab:AddToggle('ChamsOutline', {
	Text = 'Show Outline',
	Default = true,
	Tooltip = 'Display outline around chams',
	Callback = function(Value)
		ESPSettings.ChamsOutline = Value
		-- Force immediate update
		if ApplyChamsToModel and CharacterModel and ESPSettings.ChamsESP then
			pcall(function()
				ApplyChamsToModel(true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
			end)
		end
	end
}):AddColorPicker('ChamsOutlineColor', {
	Default = Color3.fromRGB(0, 0, 0),
	Title = 'Outline Color',
	Transparency = 0.5,
	Callback = function(Value)
		ESPSettings.ChamsOutlineColor = Value
		-- Get transparency from Options
		if Options.ChamsOutlineColor then
			ESPSettings.ChamsOutlineTransparency = Options.ChamsOutlineColor.Transparency or 0.5
		end
		-- Force immediate update
		if ApplyChamsToModel and CharacterModel and ESPSettings.ChamsESP then
			pcall(function()
				ApplyChamsToModel(true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
			end)
		end
	end
})

local ESPPreviewBox = Tabs.Visual:AddRightGroupbox('ESP Preview')

local PreviewButton = ESPPreviewBox:AddButton({
	Text = 'Show Preview',
	Tooltip = 'Toggle ESP Preview window',
	Func = function()
		if ESPPreviewFrame and ESPPreviewFrame.Window then
			local isVisible = ESPPreviewFrame.Window.Holder.Visible
			if isVisible then
				ESPPreviewFrame.Window:Hide()
				PreviewButton:SetText('Show Preview')
			else
				ESPPreviewFrame.Window:Show()
				PreviewButton:SetText('Hide Preview')
			end
		end
	end
})

ESPPreviewBox:AddToggle('AutoShowPreview', {
	Text = 'Auto Show on Start',
	Default = true,
	Tooltip = 'Auto show preview on start',
	Callback = function(Value)
		-- Save preference
	end
})

ESPPreviewBox:AddButton({
	Text = 'Refresh Avatar',
	Tooltip = 'Reload player avatar in preview',
	Func = function()
		if ESPPreviewFrame and ESPPreviewFrame.UpdateAvatar then
			ESPPreviewFrame.UpdateAvatar()
		end
	end
})

ESPPreviewBox:AddSlider('AvatarRotation', {
	Text = 'Avatar Rotation',
	Default = 180,
	Min = 0,
	Max = 360,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		if ESPPreviewFrame and ESPPreviewFrame.RotateAvatar then
			ESPPreviewFrame.RotateAvatar(Value)
		end
	end
})

ESPPreviewBox:AddButton({
	Text = 'Reset Rotation',
	Tooltip = 'Reset avatar to front view',
	Func = function()
		if Options.AvatarRotation then
			Options.AvatarRotation:SetValue(180)
		end
		if ESPPreviewFrame and ESPPreviewFrame.RotateAvatar then
			ESPPreviewFrame.RotateAvatar(180)
		end
	end
})

ESPPreviewBox:AddSlider('CameraZoom', {
	Text = 'Camera Zoom',
	Default = 4,
	Min = 2,
	Max = 10,
	Rounding = 1,
	Compact = false,
	Callback = function(Value)
		UpdateCameraZoom(Value)
	end
})

ESPPreviewBox:AddButton({
	Text = 'Reset Zoom',
	Tooltip = 'Reset camera zoom to default',
	Func = function()
		if Options.CameraZoom then
			Options.CameraZoom:SetValue(4)
		end
		UpdateCameraZoom(4)
	end
})

-- ==================== UI CONFIG TAB ====================
local MenuGroup = Tabs['Configuration']:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
	Text = '⚠️ Unload UI',
	DoubleClick = true,
	Tooltip = 'Unload the entire UI (double click)',
	Func = function()
		Library:Unload()
	end
})

MenuGroup:AddButton({
	Text = '🗑️ Unload Script',
	DoubleClick = true,
	Tooltip = 'Disconnect all ESP connections and cleanup (double click)',
	Func = function()
		-- Disconnect ESP connections
		for _, connection in pairs(ESPConnections) do
			if connection then
				connection:Disconnect()
			end
		end
		ESPConnections = {}
		
		-- Remove all ESP objects
		for player, _ in pairs(ESPObjects) do
			RemoveESP(player)
		end
		
		-- Disconnect dynamic ESP connection
		if DynamicESPConnection then
			DynamicESPConnection:Disconnect()
			DynamicESPConnection = nil
		end
		
		print('Script unloaded - all connections disconnected')
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
	FrameCounter = FrameCounter + 1

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

SaveManager:BuildConfigSection(Tabs['Configuration'])
ThemeManager:ApplyToTab(Tabs['Configuration'])

-- Set GameSense/Skeet theme
ThemeManager:ApplyTheme('Default')

SaveManager:LoadAutoloadConfig()

-- ==================== SECONDARY WINDOW FOR ESP PREVIEW ====================
local SecondaryWindow = Library:CreateSecondaryWindow({
	Title = 'ESP Preview';
	ParentWindow = Window;  -- Attach to main window
	StickyMode = true;  -- Follow parent window (NOT draggable!)
	OffsetFromParent = Vector2.new(1, 0);  -- 1px gap for seamless look (formula already has -2px overlap)
	Size = UDim2.fromOffset(280, 350);
	Resizable = false;  -- Disabled when sticky
	MinimizeKey = 'End';  -- Press End to minimize/restore
	AutoShow = true;
})

-- WAIT FOR RENDER then fix position using AbsolutePosition
task.wait(0.1)
local mainAbsPos = Window.Holder.AbsolutePosition
local mainAbsSize = Window.Holder.AbsoluteSize
-- Position right next to main window (8px gap)
SecondaryWindow.Holder.Position = UDim2.fromOffset(mainAbsPos.X + mainAbsSize.X + 8, mainAbsPos.Y)

-- DEBUG: Print actual positions
print('[DEBUG] Main AbsolutePosition:', mainAbsPos)
print('[DEBUG] Main AbsoluteSize:', mainAbsSize)
print('[DEBUG] Secondary NEW Position:', SecondaryWindow.Holder.Position)

-- OVERRIDE position tracking to use AbsolutePosition (fix sticky mode)
local function UpdateSecondaryPosition()
	if not SecondaryWindow or not SecondaryWindow.Holder or not SecondaryWindow.Holder.Parent then return end
	local currentMainPos = Window.Holder.AbsolutePosition
	local currentMainSize = Window.Holder.AbsoluteSize
	SecondaryWindow.Holder.Position = UDim2.fromOffset(currentMainPos.X + currentMainSize.X + 8, currentMainPos.Y)
end

-- Connect to main window position changes
Window.Holder:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateSecondaryPosition)
Window.Holder:GetPropertyChangedSignal('AbsoluteSize'):Connect(UpdateSecondaryPosition)

-- Keep secondary window visibility in sync with the main window toggle
if SecondaryWindow and SecondaryWindow.Holder then
	SecondaryWindow.Holder.Visible = Window.Holder.Visible
	Window.Holder:GetPropertyChangedSignal('Visible'):Connect(function()
		if SecondaryWindow.Holder then
			SecondaryWindow.Holder.Visible = Window.Holder.Visible
		end
	end)
end

-- Get container from secondary window
local SecondaryContainer = SecondaryWindow:GetContainer()

-- Add ESP Preview to secondary window instead of main window
local ESPPreviewHolder = Library:Create('Frame', {
	BackgroundTransparency = 1;
	Size = UDim2.new(1, 0, 1, 0);
	Parent = SecondaryContainer;
})

-- Create preview widget inside secondary window container
local ESPPreview = Library:Create('Frame', {
	BackgroundColor3 = Library.BackgroundColor;
	BorderColor3 = Library.OutlineColor;
	BorderSizePixel = 1;
	Size = UDim2.new(1, 0, 1, 0);
	ZIndex = 5;
	Parent = ESPPreviewHolder;
})

Library:AddToRegistry(ESPPreview, {
	BackgroundColor3 = 'BackgroundColor';
	BorderColor3 = 'OutlineColor';
})

-- Content frame
local ContentFrame = Library:Create('Frame', {
	BackgroundColor3 = Library.MainColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0, 4, 0, 4);
	Size = UDim2.new(1, -8, 1, -8);
	ZIndex = 6;
	Parent = ESPPreview;
})

Library:AddToRegistry(ContentFrame, {
	BackgroundColor3 = 'MainColor';
})

-- ===== 3D VIEWPORT AVATAR (User's Real Character) =====
print('[ESP Preview] Creating 3D Viewport Container...')

-- Main preview container (dark background)
local PreviewContainer = Library:Create('Frame', {
	BackgroundColor3 = Color3.fromRGB(15, 15, 20);
	BackgroundTransparency = 0;
	BorderSizePixel = 1;
	BorderColor3 = Color3.fromRGB(40, 40, 45);
	Size = UDim2.new(1, 0, 1, 0);
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 7;
	Parent = ContentFrame;
})

-- 3D ViewportFrame (centered)
local ViewportFrame = Instance.new('ViewportFrame')
ViewportFrame.BackgroundTransparency = 1
ViewportFrame.Size = UDim2.new(1, 0, 1, 0)
ViewportFrame.Position = UDim2.new(0, 0, 0, 0)
ViewportFrame.ZIndex = 8
ViewportFrame.Parent = PreviewContainer
ViewportFrame.Ambient = Color3.fromRGB(255, 255, 255)
ViewportFrame.LightColor = Color3.fromRGB(255, 255, 255)

-- Create camera for viewport
ViewportCamera = Instance.new('Camera')
ViewportCamera.Parent = ViewportFrame
ViewportFrame.CurrentCamera = ViewportCamera
-- Use CFrame.lookAt to properly orient camera toward character
ViewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, 2, 4), Vector3.new(0, 2, 0))
ViewportCamera.Focus = CFrame.new(0, 2, 0)

-- Clone player's character into viewport
local function CreateCharacterModel()
	local player = game.Players.LocalPlayer
	local character = player.Character
	
	if not character then
		warn('[ESP Preview] Character not found, waiting...')
		character = player.CharacterAdded:Wait()
	end
	
	-- Clear old model
	if CharacterModel then
		CharacterModel:Destroy()
		PartMap = {}
	end
	
	-- Clone character
	CharacterModel = Instance.new('Model')
	CharacterModel.Name = 'PreviewCharacter'
	CharacterModel.Parent = ViewportFrame
	
	PartMap = {} -- Reset part mapping
	
	-- Clone all character parts (BaseParts only for cleaner model)
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA('BasePart') then
			local clonedPart = part:Clone()
			clonedPart.Parent = CharacterModel
			clonedPart.Anchored = true
			clonedPart.CanCollide = false
			
			-- Remove scripts/welds (keep visuals like Decals, SpecialMesh)
			for _, child in ipairs(clonedPart:GetChildren()) do
				if child:IsA('Script') or child:IsA('LocalScript') or child:IsA('Motor6D') or child:IsA('Weld') then
					child:Destroy()
				end
			end
			
			PartMap[part] = clonedPart
		end
	end
	
	-- Set primary part
	local originalHRP = character:FindFirstChild('HumanoidRootPart')
	local clonedHRP = PartMap[originalHRP]
	
	if clonedHRP then
		CharacterModel.PrimaryPart = clonedHRP
		
		-- Position avatar standing upright at origin (0, 0, 0)
		-- Calculate proper Y offset so feet are at Y=0
		local rigType = character:FindFirstChild('Torso') and 'R6' or 'R15'
		local heightOffset = rigType == 'R6' and 2.5 or 2.8  -- Adjust based on rig type
		
		-- Position all parts relative to HRP (standing pose at origin)
		for originalPart, clonedPart in pairs(PartMap) do
			if clonedPart and clonedPart.Parent and originalPart and originalPart.Parent then
				-- Get offset from original character (preserves standing pose)
				local offset = originalHRP.CFrame:ToObjectSpace(originalPart.CFrame)
				-- Apply to new position (centered at origin, raised by heightOffset)
				clonedPart.CFrame = CFrame.new(0, heightOffset, 0) * offset
			end
		end
	end
	
	print('[ESP Preview] 3D Character Model Created with', #CharacterModel:GetChildren(), 'parts')
	
	-- Apply initial rotation (front-facing)
	RotateCharacter(CurrentRotation)
end

-- Create initial character
pcall(CreateCharacterModel)

-- Chams ESP for ViewportFrame uses direct part coloring (Highlight doesn't work in ViewportFrame)
-- Store original part colors for restore
local OriginalPartColors = {}
local PreviewChamsEnabled = false -- Renamed to avoid conflict with global ChamsEnabled
local ChamsOutlineParts = {} -- Store outline parts for outline effect
local ChamsOutlineEdgeOffsets = {} -- Store edge offsets for manual position updates

-- Function to apply chams effect to CharacterModel parts (assign to forward declaration)
ApplyChamsToModel = function(enabled, fillColor, transparency)
	if not CharacterModel then return end
	
	-- Helper function to create edge lines for wireframe outline
	local function CreateWireframeOutline(basePart)
		local outlineFolder = Instance.new('Folder')
		outlineFolder.Name = 'ChamsOutline'
		outlineFolder.Parent = basePart
		
		local size = basePart.Size
		local halfX, halfY, halfZ = size.X/2 + 0.02, size.Y/2 + 0.02, size.Z/2 + 0.02
		local thickness = 0.03 -- Thin line thickness
		
		local outlineColor = ESPSettings.ChamsOutlineColor or Color3.fromRGB(0, 0, 0)
		local outlineTransparency = ESPSettings.ChamsOutlineTransparency or 0
		
		-- Define 12 edges of a box (each edge as position offset and size)
		local edges = {
			-- Bottom face edges (Y = -halfY)
			{CFrame.new(0, -halfY, -halfZ), Vector3.new(size.X + 0.04, thickness, thickness)}, -- front bottom
			{CFrame.new(0, -halfY, halfZ), Vector3.new(size.X + 0.04, thickness, thickness)},  -- back bottom
			{CFrame.new(-halfX, -halfY, 0), Vector3.new(thickness, thickness, size.Z + 0.04)}, -- left bottom
			{CFrame.new(halfX, -halfY, 0), Vector3.new(thickness, thickness, size.Z + 0.04)},  -- right bottom
			-- Top face edges (Y = +halfY)
			{CFrame.new(0, halfY, -halfZ), Vector3.new(size.X + 0.04, thickness, thickness)},  -- front top
			{CFrame.new(0, halfY, halfZ), Vector3.new(size.X + 0.04, thickness, thickness)},   -- back top
			{CFrame.new(-halfX, halfY, 0), Vector3.new(thickness, thickness, size.Z + 0.04)},  -- left top
			{CFrame.new(halfX, halfY, 0), Vector3.new(thickness, thickness, size.Z + 0.04)},   -- right top
			-- Vertical edges (connecting top and bottom)
			{CFrame.new(-halfX, 0, -halfZ), Vector3.new(thickness, size.Y + 0.04, thickness)}, -- front-left
			{CFrame.new(halfX, 0, -halfZ), Vector3.new(thickness, size.Y + 0.04, thickness)},  -- front-right
			{CFrame.new(-halfX, 0, halfZ), Vector3.new(thickness, size.Y + 0.04, thickness)},  -- back-left
			{CFrame.new(halfX, 0, halfZ), Vector3.new(thickness, size.Y + 0.04, thickness)},   -- back-right
		}
		
		-- Store edge data for this part (for manual position updates)
		ChamsOutlineEdgeOffsets[basePart] = {}
		
		for i, edge in ipairs(edges) do
			local edgePart = Instance.new('Part')
			edgePart.Name = 'Edge' .. i
			edgePart.Anchored = true -- Anchored since we update manually
			edgePart.CanCollide = false
			edgePart.CanQuery = false
			edgePart.CastShadow = false
			edgePart.Massless = true
			edgePart.Material = Enum.Material.Neon
			edgePart.Color = outlineColor
			edgePart.Transparency = outlineTransparency
			edgePart.Size = edge[2]
			edgePart.CFrame = basePart.CFrame * edge[1]
			edgePart.Parent = outlineFolder
			
			-- Store offset for manual updates (WeldConstraint doesn't work in ViewportFrame)
			ChamsOutlineEdgeOffsets[basePart][edgePart] = edge[1]
		end
		
		return outlineFolder
	end
	
	-- Helper function to update wireframe outline colors
	local function UpdateWireframeOutline(outlineFolder)
		local outlineColor = ESPSettings.ChamsOutlineColor or Color3.fromRGB(0, 0, 0)
		local outlineTransparency = ESPSettings.ChamsOutlineTransparency or 0
		
		for _, edgePart in ipairs(outlineFolder:GetChildren()) do
			if edgePart:IsA('BasePart') then
				edgePart.Color = outlineColor
				edgePart.Transparency = outlineTransparency
			end
		end
	end
	
	for _, part in ipairs(CharacterModel:GetDescendants()) do
		if part:IsA('BasePart') and part.Name ~= 'ChamsOutline' and not part:FindFirstAncestor('ChamsOutline') then
			if enabled then
				-- Store original color if not stored
				if not OriginalPartColors[part] then
					OriginalPartColors[part] = {
						Color = part.Color,
						Material = part.Material,
						Transparency = part.Transparency
					}
				end
				-- Apply chams effect
				part.Color = fillColor or Color3.fromRGB(255, 120, 0)
				part.Material = Enum.Material.Neon -- Glowing effect
				part.Transparency = transparency or 0.3
				
				-- Add wireframe outline
				if ESPSettings.ChamsOutline then
					if not ChamsOutlineParts[part] then
						-- Create wireframe outline (12 edge lines)
						ChamsOutlineParts[part] = CreateWireframeOutline(part)
					else
						-- Update existing outline colors
						UpdateWireframeOutline(ChamsOutlineParts[part])
					end
				else
					-- Remove outline if disabled
					if ChamsOutlineParts[part] then
						ChamsOutlineParts[part]:Destroy()
						ChamsOutlineParts[part] = nil
						ChamsOutlineEdgeOffsets[part] = nil
					end
				end
			else
				-- Restore original colors
				if OriginalPartColors[part] then
					part.Color = OriginalPartColors[part].Color
					part.Material = OriginalPartColors[part].Material
					part.Transparency = OriginalPartColors[part].Transparency
				end
				-- Remove outline
				if ChamsOutlineParts[part] then
					ChamsOutlineParts[part]:Destroy()
					ChamsOutlineParts[part] = nil
					ChamsOutlineEdgeOffsets[part] = nil
				end
			end
		end
	end
	
	PreviewChamsEnabled = enabled
end

print('[ESP Preview] Chams System Initialized (ViewportFrame compatible)')

-- Update character when respawning
game.Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5) -- Wait for character to fully load
	-- Reset original colors and outline parts before recreating model
	OriginalPartColors = {}
	-- Cleanup existing outline parts
	for _, outlinePart in pairs(ChamsOutlineParts) do
		if outlinePart and outlinePart.Parent then
			outlinePart:Destroy()
		end
	end
	ChamsOutlineParts = {}
	ChamsOutlineEdgeOffsets = {} -- Clear edge offsets too
	pcall(CreateCharacterModel)
	-- Re-apply chams if it was enabled
	if ESPSettings.ChamsESP then
		ApplyChamsToModel(true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
	end
end)

print('[ESP Preview] 3D Viewport Avatar Created')

-- ESP Overlays Container
local ESPOverlay = Library:Create('Frame', {
	BackgroundTransparency = 1;
	Size = UDim2.new(1, 0, 1, 0);
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 20;
	Parent = PreviewContainer;
})

-- Box ESP (around dummy - professional sizing)
local BoxOutline = Library:Create('Frame', {
	BackgroundTransparency = 1;
	BorderSizePixel = 0;
	Size = UDim2.new(0, 120, 0, 200);  -- Compact box untuk R6
	Position = UDim2.new(0.5, -60, 0.5, -95);  -- Perfect centered
	ZIndex = 21;
	Parent = ESPOverlay;
})

-- Filled Box Background (behind borders)
local BoxFill = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.BoxColor;
	BackgroundTransparency = ESPSettings.FilledBoxTransparency;
	BorderSizePixel = 0;
	Size = UDim2.new(1, 0, 1, 0);
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 21;
	Visible = ESPSettings.FilledBox;
	Parent = BoxOutline;
})

-- Box borders (4 lines, cleaner 1px thickness)
local BoxTop = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.BoxColor;
	BorderSizePixel = 0;
	Size = UDim2.new(1, 0, 0, 1);  -- 1px for cleaner look
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 22;
	Visible = ESPSettings.BoxESP;  -- Set default visibility
	Parent = BoxOutline;
})

local BoxBottom = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.BoxColor;
	BorderSizePixel = 0;
	Size = UDim2.new(1, 0, 0, 1);
	Position = UDim2.new(0, 0, 1, -1);
	ZIndex = 22;
	Visible = ESPSettings.BoxESP;  -- Set default visibility
	Parent = BoxOutline;
})

local BoxLeft = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.BoxColor;  -- Dynamic color
	BorderSizePixel = 0;
	Size = UDim2.new(0, 1, 1, 0);  -- 1px width
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 22;
	Visible = ESPSettings.BoxESP;  -- Set default visibility
	Parent = BoxOutline;
})

local BoxRight = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.BoxColor;  -- Dynamic color
	BorderSizePixel = 0;
	Size = UDim2.new(0, 1, 1, 0);
	Position = UDim2.new(1, -1, 0, 0);
	ZIndex = 22;
	Visible = ESPSettings.BoxESP;  -- Set default visibility
	Parent = BoxOutline;
})

print('[ESP Preview] Box ESP Created')

-- Health Bar (left side of box) - vertical bar style
local HealthBarBG = Library:Create('Frame', {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0);
	BorderColor3 = Color3.fromRGB(0, 0, 0);
	BorderSizePixel = 1;
	Size = UDim2.new(0, 3, 1, 0);  -- Slim vertical bar
	Position = UDim2.new(0, -7, 0, 0);  -- Left side of box
	ZIndex = 23;
	Visible = ESPSettings.ShowHealth;  -- Set default visibility
	Parent = BoxOutline;
})

local HealthBar = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.HealthBarColor;  -- Use settings color
	BorderSizePixel = 0;
	Size = UDim2.new(1, 0, 1, 0);  -- Full = 100%
	Position = UDim2.new(0, 0, 1, 0);  -- Start from bottom
	AnchorPoint = Vector2.new(0, 1);  -- Anchor to bottom
	ZIndex = 24;
	Visible = ESPSettings.ShowHealth;  -- Set default visibility
	Parent = HealthBarBG;
})

-- Health Text (100) - positioned above health bar
local HealthText = Library:CreateLabel({
	Position = UDim2.new(0, -22, 0, -3);  -- Above health bar
	Size = UDim2.new(0, 20, 0, 14);
	Text = '100';
	TextSize = 11;
	TextColor3 = Color3.fromRGB(255, 255, 255);
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	TextXAlignment = Enum.TextXAlignment.Right;
	ZIndex = 25;
	Visible = ESPSettings.ShowHealth;  -- Set default visibility
	Parent = HealthBarBG;
})

print('[ESP Preview] Health Bar Created')

-- Player Name Label (above box) - dynamically get from LocalPlayer
local function getPlayerDisplayName()
	local player = game.Players.LocalPlayer
	if player then
		return player.DisplayName or player.Name
	else
		return 'Player'
	end
end

local NameLabel = Library:CreateLabel({
	Position = UDim2.new(0, 0, 0, -18);  -- 18px above box outline (dynamic positioning)
	Size = UDim2.new(1, 0, 0, 16);
	Text = getPlayerDisplayName();
	TextSize = 11;
	TextColor3 = ESPSettings.NameColor;
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	ZIndex = 25;
	Visible = ESPSettings.ShowName;  -- Set default visibility
	Parent = BoxOutline;  -- Parent to BoxOutline for relative positioning
})

print('[ESP Preview] Name Label Created')

-- Distance Label (below box) - dynamically calculate from simulated distance
local DistanceLabel = Library:CreateLabel({
	Position = UDim2.new(0.5, -60, 1, 5);  -- Below box
	Size = UDim2.new(0, 120, 0, 14);
	Text = string.format('[%dm]', math.floor(SimulatedDistance or 150));
	TextSize = 10;
	TextColor3 = ESPSettings.DistanceColor;
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	ZIndex = 25;
	Visible = ESPSettings.ShowDistance;  -- Set default visibility
	Parent = BoxOutline;
})

print('[ESP Preview] Distance and Labels Created')

-- ==================== DYNAMIC ESP PREVIEW SYSTEM ====================
-- Use same skeleton logic as in-game ESP module (from UpdateESP function)

-- Initialize SkeletonLines array globally
SkeletonLines = {}
HeadDotFrame = nil

local function UpdateDynamicESPPreview()
	if not CharacterModel or not ViewportCamera or not CharacterModel.PrimaryPart then return end
	if not ViewportFrame or not ESPOverlay then return end
	
	local camera = ViewportCamera
	local char = CharacterModel
	local hrp = char.PrimaryPart or char:FindFirstChild('HumanoidRootPart')
	if not hrp then return end
	
	-- Get ViewportFrame absolute size for coordinate conversion
	local vpAbsSize = ViewportFrame.AbsoluteSize
	if vpAbsSize.X == 0 or vpAbsSize.Y == 0 then return end
	
	-- Get viewport center
	local vpCenterX = vpAbsSize.X / 2
	local vpCenterY = vpAbsSize.Y / 2
	
	-- Camera properties
	local fov = math.rad(camera.FieldOfView)
	local tanHalfFov = math.tan(fov / 2)
	local camCF = camera.CFrame
	local camPos = camCF.Position
	
	-- Project 3D world position to 2D screen coordinates using proper perspective projection
	local function WorldToScreen(worldPos)
		-- Transform point to camera space
		-- In camera space: X = right, Y = up, Z = into screen (away from camera)
		local localPos = camCF:PointToObjectSpace(worldPos)
		
		-- Check if point is in front of camera (negative Z in camera space means in front)
		-- Camera looks toward -Z in local space
		local depth = -localPos.Z
		if depth <= 0.1 then
			return Vector2.new(-9999, -9999), false
		end
		
		-- Perspective projection
		-- Project X and Y based on depth and FOV
		-- At depth D, the visible height is 2 * D * tan(fov/2)
		-- So 1 unit maps to viewportHeight / (2 * D * tan(fov/2)) pixels
		
		-- Normalized coordinates (-1 to 1 for viewport edges)
		local ndcX = localPos.X / (depth * tanHalfFov * (vpAbsSize.X / vpAbsSize.Y))
		local ndcY = localPos.Y / (depth * tanHalfFov)
		
		-- Convert to screen coordinates
		-- ndcX: -1 = left edge, +1 = right edge
		-- ndcY: -1 = bottom edge, +1 = top edge (flip for screen Y)
		local screenX = vpCenterX + (ndcX * vpCenterX)
		local screenY = vpCenterY - (ndcY * vpCenterY)
		
		return Vector2.new(screenX, screenY), true
	end
	
	-- ===== UPDATE SKELETON ESP =====
	if ESPSettings.SkeletonESP then
		-- Get body parts based on rig type from CharacterModel (cloned model)
		local head = char:FindFirstChild('Head')
		
		-- R15 parts
		local upperTorso = char:FindFirstChild('UpperTorso')
		local lowerTorso = char:FindFirstChild('LowerTorso')
		local leftUpperArm = char:FindFirstChild('LeftUpperArm')
		local leftLowerArm = char:FindFirstChild('LeftLowerArm')
		local leftHand = char:FindFirstChild('LeftHand')
		local rightUpperArm = char:FindFirstChild('RightUpperArm')
		local rightLowerArm = char:FindFirstChild('RightLowerArm')
		local rightHand = char:FindFirstChild('RightHand')
		local leftUpperLeg = char:FindFirstChild('LeftUpperLeg')
		local leftLowerLeg = char:FindFirstChild('LeftLowerLeg')
		local leftFoot = char:FindFirstChild('LeftFoot')
		local rightUpperLeg = char:FindFirstChild('RightUpperLeg')
		local rightLowerLeg = char:FindFirstChild('RightLowerLeg')
		local rightFoot = char:FindFirstChild('RightFoot')
		
		-- R6 parts (fallback)
		local torso = char:FindFirstChild('Torso')
		local leftArm = char:FindFirstChild('Left Arm')
		local rightArm = char:FindFirstChild('Right Arm')
		local leftLeg = char:FindFirstChild('Left Leg')
		local rightLeg = char:FindFirstChild('Right Leg')
		
		local connections = {}
		
		if upperTorso then
			-- R15 skeleton (14 connections for full body)
			connections = {
				{head, upperTorso},           -- 1: Neck
				{upperTorso, lowerTorso},     -- 2: Spine
				{upperTorso, leftUpperArm},   -- 3: Left shoulder
				{leftUpperArm, leftLowerArm}, -- 4: Left elbow
				{leftLowerArm, leftHand},     -- 5: Left wrist
				{upperTorso, rightUpperArm},  -- 6: Right shoulder
				{rightUpperArm, rightLowerArm}, -- 7: Right elbow
				{rightLowerArm, rightHand},   -- 8: Right wrist
				{lowerTorso, leftUpperLeg},   -- 9: Left hip
				{leftUpperLeg, leftLowerLeg}, -- 10: Left knee
				{leftLowerLeg, leftFoot},     -- 11: Left ankle
				{lowerTorso, rightUpperLeg},  -- 12: Right hip
				{rightUpperLeg, rightLowerLeg}, -- 13: Right knee
				{rightLowerLeg, rightFoot},   -- 14: Right ankle
			}
		elseif torso then
			-- R6 skeleton (6 connections)
			connections = {
				{head, torso},      -- 1: Neck
				{torso, leftArm},   -- 2: Left shoulder
				{torso, rightArm},  -- 3: Right shoulder
				{torso, leftLeg},   -- 4: Left hip
				{torso, rightLeg},  -- 5: Right hip
				{leftLeg, rightLeg} -- 6: Pelvis (optional)
			}
		end
		
		-- Draw/update skeleton lines
		local lineCount = #connections
		for i = 1, math.max(lineCount, 14) do
			if i <= lineCount and connections[i] then
				local from, to = connections[i][1], connections[i][2]
				
				if from and to then
					local fromPos, fromVisible = WorldToScreen(from.Position)
					local toPos, toVisible = WorldToScreen(to.Position)
					
					if fromVisible and toVisible then
						-- Create line if needed
						if not SkeletonLines[i] then
							SkeletonLines[i] = Library:Create('Frame', {
								BackgroundColor3 = ESPSettings.SkeletonColor;
								BorderSizePixel = 0;
								AnchorPoint = Vector2.new(0, 0.5);
								ZIndex = 25;
								Parent = ESPOverlay;
							})
						end
						
						local line = SkeletonLines[i]
						local dx = toPos.X - fromPos.X
						local dy = toPos.Y - fromPos.Y
						local length = math.sqrt(dx * dx + dy * dy)
						local angle = math.deg(math.atan2(dy, dx))
						
						line.Visible = true
						line.BackgroundColor3 = ESPSettings.SkeletonColor
						line.Size = UDim2.fromOffset(math.max(1, math.floor(length)), 2)
						line.Position = UDim2.fromOffset(math.floor(fromPos.X), math.floor(fromPos.Y))
						line.Rotation = angle
					else
						if SkeletonLines[i] then
							SkeletonLines[i].Visible = false
						end
					end
				else
					if SkeletonLines[i] then
						SkeletonLines[i].Visible = false
					end
				end
			else
				-- Hide extra lines
				if SkeletonLines[i] then
					SkeletonLines[i].Visible = false
				end
			end
		end
		
		-- Draw head dot
		if head then
			local headPos, headVisible = WorldToScreen(head.Position)
			if headVisible then
				if not HeadDotFrame then
					HeadDotFrame = Library:Create('Frame', {
						BackgroundColor3 = ESPSettings.SkeletonColor;
						BorderSizePixel = 0;
						AnchorPoint = Vector2.new(0.5, 0.5);
						ZIndex = 26;
						Parent = ESPOverlay;
					})
					Library:Create('UICorner', {
						CornerRadius = UDim.new(1, 0);
						Parent = HeadDotFrame;
					})
				end
				
				local dotSize = 8
				HeadDotFrame.Visible = true
				HeadDotFrame.BackgroundColor3 = ESPSettings.SkeletonColor
				HeadDotFrame.Size = UDim2.fromOffset(dotSize, dotSize)
				HeadDotFrame.Position = UDim2.fromOffset(math.floor(headPos.X), math.floor(headPos.Y))
			else
				if HeadDotFrame then
					HeadDotFrame.Visible = false
				end
			end
		end
	else
		-- Hide skeleton if disabled
		for i = 1, 14 do
			if SkeletonLines[i] then
				SkeletonLines[i].Visible = false
			end
		end
		if HeadDotFrame then
			HeadDotFrame.Visible = false
		end
	end
	
	-- ===== UPDATE BOX ESP =====
	local rigType = char:FindFirstChild('Torso') and 'R6' or 'R15'
	local upVector = hrp.CFrame.UpVector
	local position = hrp.Position
	local topYOffset = rigType == 'R6' and 0.5 or 1.8
	local bottomYOffset = rigType == 'R6' and 4 or 2.5
	
	local topPos, topVisible = WorldToScreen(position + (upVector * topYOffset))
	local bottomPos, bottomVisible = WorldToScreen(position - (upVector * bottomYOffset))
	
	if topVisible and bottomVisible then
		local height = math.abs(bottomPos.Y - topPos.Y)
		if height < 10 then height = 100 end -- Fallback
		
		local boxWidth = math.max(height / 1.8, 40) -- Aspect ratio for human body
		local boxHeight = height
		
		local boxCenterX = (topPos.X + bottomPos.X) / 2
		local minY = math.min(topPos.Y, bottomPos.Y)
		
		-- Update BoxOutline position and size
		BoxOutline.Position = UDim2.fromOffset(
			math.floor(boxCenterX - boxWidth / 2),
			math.floor(minY)
		)
		BoxOutline.Size = UDim2.fromOffset(math.floor(boxWidth), math.floor(boxHeight))
	end
	
	-- ===== UPDATE CHAMS ESP =====
	-- Chams in ViewportFrame uses direct part coloring (Highlight doesn't work)
	local chamsEnabled = ESPSettings.ChamsESP == true
	
	-- Always update chams when enabled to ensure real-time color/transparency changes
	if chamsEnabled then
		ApplyChamsToModel(true, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
	elseif chamsEnabled ~= PreviewChamsEnabled then
		-- Only call when toggling off to restore original colors
		ApplyChamsToModel(false, ESPSettings.ChamsColor, ESPSettings.ChamsTransparency)
	end
	
	-- Update wireframe outline positions and colors (manual update since WeldConstraint doesn't work in ViewportFrame)
	if chamsEnabled and ESPSettings.ChamsOutline then
		local outlineColor = ESPSettings.ChamsOutlineColor or Color3.fromRGB(0, 0, 0)
		local outlineTransparency = ESPSettings.ChamsOutlineTransparency or 0
		
		for part, outlineFolder in pairs(ChamsOutlineParts) do
			if part and part.Parent and outlineFolder and outlineFolder.Parent then
				-- Get edge offsets for this part
				local edgeOffsets = ChamsOutlineEdgeOffsets[part]
				
				for _, edgePart in ipairs(outlineFolder:GetChildren()) do
					if edgePart:IsA('BasePart') then
						-- Update color and transparency
						edgePart.Color = outlineColor
						edgePart.Transparency = outlineTransparency
						
						-- Update position based on stored offset (follows part rotation)
						if edgeOffsets and edgeOffsets[edgePart] then
							edgePart.CFrame = part.CFrame * edgeOffsets[edgePart]
						end
					end
				end
			end
		end
	end
end

-- Update loop for dynamic ESP preview
if DynamicESPConnection then
	DynamicESPConnection:Disconnect()
end

DynamicESPConnection = game:GetService('RunService').RenderStepped:Connect(function()
	if CharacterModel and ViewportCamera and ESPOverlay then
		pcall(UpdateDynamicESPPreview)
	end
end)

print('[ESP Preview] Dynamic ESP System Initialized')

-- ==================== END DYNAMIC ESP PREVIEW ====================

-- Skeleton Lines Container (Universal R6/R15 Support) - LEGACY (kept for compatibility)
local SkeletonContainer = Library:Create('Frame', {
	BackgroundTransparency = 1;
	Size = UDim2.new(1, 0, 1, 0);
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 22;
	Parent = ESPOverlay;
	Visible = false; -- Hidden since we use dynamic system now
})

-- Legacy UpdateSkeletonPreview function (now redirects to dynamic system)
local UpdateSkeletonPreview = function()
	if UpdateDynamicESPPreview then
		UpdateDynamicESPPreview()
	end
end

-- Store references for dynamic updates (backward compatibility)
local HeadToTorso, TorsoToLeftArm, TorsoToRightArm, LeftArmLine, RightArmLine
local TorsoToLeftLeg, TorsoToRightLeg, LeftLegLine, RightLegLine

print('[ESP Preview] Legacy skeleton system redirected to dynamic system')

-- Initial update to show proper state
task.wait(0.1)

-- Force initial skeleton visibility update
if ESPSettings.SkeletonESP then
	UpdateSkeletonPreview()
end

-- Update dynamic labels continuously
spawn(function()
	while wait(1) do
		if NameLabel then
			NameLabel.Text = getPlayerDisplayName()
		end
		if DistanceLabel then
			DistanceLabel.Text = string.format('[%dm]', math.floor(SimulatedDistance or 150))
		end
	end
end)

UpdateESPPreview()

-- Store references in global table
ESPPreviewFrame = {
	Window = SecondaryWindow;
	Main = ESPPreview;
	PreviewContainer = PreviewContainer;
	ViewportFrame = ViewportFrame;
	CharacterModel = CharacterModel;
	BoxTop = BoxTop;
	BoxBottom = BoxBottom;
	BoxLeft = BoxLeft;
	BoxRight = BoxRight;
	BoxFill = BoxFill;  -- Filled Box reference
	SkeletonContainer = SkeletonContainer;
	SkeletonLines = SkeletonLines; -- Store all skeleton lines (will be updated)
	HeadDotFrame = HeadDotFrame; -- Head dot circle
	-- Backward compatibility
	HeadToTorso = HeadToTorso;
	TorsoToLeftArm = TorsoToLeftArm;
	TorsoToRightArm = TorsoToRightArm;
	LeftArmLine = LeftArmLine;
	RightArmLine = RightArmLine;
	TorsoToLeftLeg = TorsoToLeftLeg;
	TorsoToRightLeg = TorsoToRightLeg;
	LeftLegLine = LeftLegLine;
	RightLegLine = RightLegLine;
	-- Labels and health
	NameLabel = NameLabel;
	DistanceLabel = DistanceLabel;
	HealthBar = HealthBar;
	HealthBarBG = HealthBarBG;
	HealthText = HealthText;
	ContentFrame = ContentFrame;
	ESPOverlay = ESPOverlay;
	ApplyChams = ApplyChamsToModel; -- Chams function for ViewportFrame
	-- Update functions
	Update = UpdateESPPreview;
	UpdateAvatar = CreateCharacterModel;
	RotateAvatar = RotateCharacter;
	UpdateSkeleton = function()
		UpdateSkeletonPreview()
		-- Update reference after skeleton rebuild
		ESPPreviewFrame.SkeletonLines = SkeletonLines
	end;
}

print('[ESP Preview] Initialized with 3D avatar and universal skeleton system')

-- ===== END OF ESP PREVIEW INITIALIZATION =====