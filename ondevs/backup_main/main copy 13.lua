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
local ESPConnections = {}
local ESPObjects = {}
local ESPPreviewFrame = nil
local SimulatedDistance = 150 -- Simulated distance in studs for ESP preview scaling
local ESPSettings = {
	ShowName = true,
	ShowDistance = true,
	ShowHealth = true,
	ShowBox = true,
	BoxESP = false,
	SkeletonESP = false,
	ShowSelf = true,  -- TRUE by default so preview works immediately
	MaxDistance = 1000,
	TeamCheck = false,
	NameColor = Color3.fromRGB(255, 255, 255),
	BoxColor = Color3.fromRGB(255, 0, 0),
	HealthBarColor = Color3.fromRGB(0, 255, 0),
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	DistanceColor = Color3.fromRGB(180, 180, 180),
	TracerColor = Color3.fromRGB(255, 255, 255)
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
		ViewportCamera.CFrame = CFrame.new(0, 1, CameraDistance)
		ViewportCamera.Focus = CFrame.new(0, 1, 0)
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
	local targetCFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(CurrentRotation), 0)
	
	-- Rotate all parts using stored PartMap
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
local function UpdateESPPreview()
	print('[ESP Preview] === UpdateESPPreview CALLED ===')
	print('[ESP Preview] ESPPreviewFrame exists:', ESPPreviewFrame ~= nil)
	
	if not ESPPreviewFrame then
		print('[ESP Preview] ERROR: ESPPreviewFrame is nil!')
		return
	end
	
	-- Check if ShowSelf is enabled
	if not ESPSettings.ShowSelf then
		print('[ESP Preview] ShowSelf is OFF - hiding all ESP elements')
		-- Hide everything when ShowSelf is disabled
		if ESPPreviewFrame.BoxOutline then ESPPreviewFrame.BoxOutline.Visible = false end
		if ESPPreviewFrame.HeadCircle then ESPPreviewFrame.HeadCircle.Visible = false end
		if ESPPreviewFrame.BodyRect then ESPPreviewFrame.BodyRect.Visible = false end
		if ESPPreviewFrame.LeftLeg then ESPPreviewFrame.LeftLeg.Visible = false end
		if ESPPreviewFrame.RightLeg then ESPPreviewFrame.RightLeg.Visible = false end
		if ESPPreviewFrame.LeftArm then ESPPreviewFrame.LeftArm.Visible = false end
		if ESPPreviewFrame.RightArm then ESPPreviewFrame.RightArm.Visible = false end
		if ESPPreviewFrame.Spine then ESPPreviewFrame.Spine.Visible = false end
		if ESPPreviewFrame.NameLabel then ESPPreviewFrame.NameLabel.Visible = false end
		if ESPPreviewFrame.DistanceLabel then ESPPreviewFrame.DistanceLabel.Visible = false end
		if ESPPreviewFrame.HealthBarBG then ESPPreviewFrame.HealthBarBG.Visible = false end
		return
	end
	
	print('[ESP Preview] ShowSelf is ON - updating ESP elements')
	print('[ESP Preview] Updating ESP overlays...')
	print('[ESP Preview] Settings - Box:', ESPSettings.BoxESP, 'Skeleton:', ESPSettings.SkeletonESP)
	print('[ESP Preview] Settings - Name:', ESPSettings.ShowName, 'Distance:', ESPSettings.ShowDistance, 'Health:', ESPSettings.ShowHealth)
	
	-- Update Box ESP FIRST
	print('[ESP Preview] Checking BoxOutline...')
	if ESPPreviewFrame.BoxOutline then
		print('[ESP Preview]   BoxOutline found! Setting visible to:', ESPSettings.BoxESP)
		ESPPreviewFrame.BoxOutline.Visible = ESPSettings.BoxESP
		if ESPSettings.BoxESP then
			ESPPreviewFrame.BoxOutline.BorderColor3 = ESPSettings.BoxColor
		end
		print('[ESP Preview]   BoxOutline.Visible =', ESPPreviewFrame.BoxOutline.Visible)
		print('[ESP Preview]   BoxOutline.Parent =', ESPPreviewFrame.BoxOutline.Parent and ESPPreviewFrame.BoxOutline.Parent.Name or 'nil')
		print('[ESP Preview]   BoxOutline.ZIndex =', ESPPreviewFrame.BoxOutline.ZIndex)
		print('[ESP Preview]   BoxOutline.Size =', ESPPreviewFrame.BoxOutline.Size)
		print('[ESP Preview]   BoxOutline.Position =', ESPPreviewFrame.BoxOutline.Position)
		print('[ESP Preview]   BoxOutline.AbsolutePosition =', ESPPreviewFrame.BoxOutline.AbsolutePosition)
		print('[ESP Preview]   BoxOutline.AbsoluteSize =', ESPPreviewFrame.BoxOutline.AbsoluteSize)
	else
		print('[ESP Preview]   ERROR: BoxOutline is nil!')
	end
	
	-- Update Skeleton visibility and colors
	local showSkeleton = ESPSettings.SkeletonESP
	if ESPPreviewFrame.HeadCircle then
		ESPPreviewFrame.HeadCircle.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.HeadCircle.BorderColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.BodyRect then
		ESPPreviewFrame.BodyRect.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.BodyRect.BorderColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.LeftLeg then
		ESPPreviewFrame.LeftLeg.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.LeftLeg.BorderColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.RightLeg then
		ESPPreviewFrame.RightLeg.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.RightLeg.BorderColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.LeftArm then
		ESPPreviewFrame.LeftArm.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.LeftArm.BackgroundColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.RightArm then
		ESPPreviewFrame.RightArm.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.RightArm.BackgroundColor3 = ESPSettings.SkeletonColor
		end
	end
	
	if ESPPreviewFrame.Spine then
		ESPPreviewFrame.Spine.Visible = showSkeleton
		if showSkeleton then
			ESPPreviewFrame.Spine.BackgroundColor3 = ESPSettings.SkeletonColor
		end
	end
	
	-- Update Box ESP visibility and color
	if ESPPreviewFrame.BoxOutline then
		ESPPreviewFrame.BoxOutline.Visible = ESPSettings.BoxESP
		if ESPSettings.BoxESP then
			ESPPreviewFrame.BoxOutline.BorderColor3 = ESPSettings.BoxColor
		end
		print('[ESP Preview] BoxOutline visible:', ESPPreviewFrame.BoxOutline.Visible)
	end
	
	-- Update Name
	if ESPPreviewFrame.NameLabel then
		ESPPreviewFrame.NameLabel.TextColor3 = ESPSettings.NameColor
		ESPPreviewFrame.NameLabel.Visible = ESPSettings.ShowName
		print('[ESP Preview] NameLabel visible:', ESPPreviewFrame.NameLabel.Visible)
	end
	
	-- Update Distance with proper color
	if ESPPreviewFrame.DistanceLabel then
		ESPPreviewFrame.DistanceLabel.Visible = ESPSettings.ShowDistance
		if ESPSettings.ShowDistance then
			ESPPreviewFrame.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
		end
		print('[ESP Preview] DistanceLabel visible:', ESPPreviewFrame.DistanceLabel.Visible)
	end
	
	-- Update Health Bar
	if ESPPreviewFrame.HealthBar then
		ESPPreviewFrame.HealthBar.BackgroundColor3 = ESPSettings.HealthBarColor
		ESPPreviewFrame.HealthBar.Visible = ESPSettings.ShowHealth
	end
	
	if ESPPreviewFrame.HealthBarBG then
		ESPPreviewFrame.HealthBarBG.Visible = ESPSettings.ShowHealth
		print('[ESP Preview] HealthBarBG visible:', ESPPreviewFrame.HealthBarBG.Visible)
	end
	
	if ESPPreviewFrame.HealthText then
		ESPPreviewFrame.HealthText.Visible = ESPSettings.ShowHealth
	end
	
	print('[ESP Preview] Update completed!')
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
		Skeleton = {}
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
	espObj.Tracer.Color = ESPSettings.BoxColor
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
end

local function RemoveESP(player)
	if ESPObjects[player] then
		-- Remove all Drawing objects
		local espObj = ESPObjects[player]
		
		if espObj.Box then espObj.Box:Remove() end
		if espObj.BoxOutline then espObj.BoxOutline:Remove() end
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
				
				-- Update Tracer
				if ESPSettings.ShowBox then
					espObj.Tracer.Visible = true
					local viewportSize = camera.ViewportSize
					espObj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
					espObj.Tracer.To = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y)
					espObj.Tracer.Color = ESPSettings.BoxColor
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
				-- Hide all ESP elements
				if espObj.Box then espObj.Box.Visible = false end
				if espObj.BoxOutline then espObj.BoxOutline.Visible = false end
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
	Title = 'hubsense | sakkarepmu',
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
		UpdateESPPreview()
	end
})

ESPBox:AddToggle('ShowDistance', {
	Text = 'Show Distance',
	Default = true,
	Tooltip = 'Display distance to players',
	Callback = function(Value)
		ESPSettings.ShowDistance = Value
		UpdateESPPreview()
	end
})

ESPBox:AddToggle('ShowBox', {
	Text = 'Show Line',
	Default = true,
	Tooltip = 'Display box around players',
	Callback = function(Value)
		ESPSettings.ShowBox = Value
		UpdateESPPreview()
	end
})

ESPBox:AddToggle('ShowHealth', {
	Text = 'Show Health',
	Default = true,
	Tooltip = 'Display health bar',
	Callback = function(Value)
		ESPSettings.ShowHealth = Value
		UpdateESPPreview()
	end
})

ESPBox:AddToggle('BoxESP', {
	Text = 'Box ESP',
	Default = false,
	Tooltip = 'Display box outline around players',
	Callback = function(Value)
		ESPSettings.BoxESP = Value
		UpdateESPPreview()
	end
})

ESPBox:AddToggle('SkeletonESP', {
	Text = 'Skeleton ESP',
	Default = false,
	Tooltip = 'Display skeleton bones',
	Callback = function(Value)
		ESPSettings.SkeletonESP = Value
		UpdateESPPreview()
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

ESPBox:AddToggle('ShowSelf', {
	Text = 'Show Self ESP',
	Default = true,
	Tooltip = 'Show ESP on your own character (affects preview)',
	Callback = function(Value)
		ESPSettings.ShowSelf = Value
		print('[ESP Settings] ShowSelf toggled to:', Value)
		UpdateESPPreview()
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

ESPBox:AddDivider()

ESPBox:AddButton({
	Text = 'Show Preview',
	Tooltip = 'Show ESP Preview window',
	Func = function()
		if ESPPreviewFrame and ESPPreviewFrame.Window then
			ESPPreviewFrame.Window:Show()
		end
	end
}):AddButton({
	Text = 'Hide Preview',
	Tooltip = 'Hide ESP Preview window',
	Func = function()
		if ESPPreviewFrame and ESPPreviewFrame.Window then
			ESPPreviewFrame.Window:Hide()
		end
	end
})

ESPBox:AddButton({
	Text = 'Refresh Avatar',
	Tooltip = 'Reload player avatar in preview',
	Func = function()
		if ESPPreviewFrame and ESPPreviewFrame.UpdateAvatar then
			ESPPreviewFrame.UpdateAvatar()
		end
	end
})

ESPBox:AddDivider()

ESPBox:AddSlider('AvatarRotation', {
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

ESPBox:AddButton({
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

ESPBox:AddDivider()

ESPBox:AddSlider('CameraZoom', {
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

ESPBox:AddButton({
	Text = 'Reset Zoom',
	Tooltip = 'Reset camera zoom to default',
	Func = function()
		if Options.CameraZoom then
			Options.CameraZoom:SetValue(4)
		end
		UpdateCameraZoom(4)
	end
})

ESPBox:AddToggle('AutoShowPreview', {
	Text = 'Auto Show Preview',
	Default = true,
	Tooltip = 'Auto show preview on start',
	Callback = function(Value)
		-- Save preference
	end
})

local ESPColorsBox = Tabs.Visual:AddRightGroupbox('ESP Colors')

ESPColorsBox:AddLabel('Name Color:'):AddColorPicker('NameColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Name Color',
	Callback = function(Value)
		ESPSettings.NameColor = Value
		UpdateESPPreview()
	end
})

ESPColorsBox:AddLabel('Distance Color:'):AddColorPicker('DistanceColor', {
	Default = Color3.fromRGB(180, 180, 180),
	Title = 'Distance Color',
	Callback = function(Value)
		ESPSettings.DistanceColor = Value
		UpdateESPPreview()
	end
})

ESPColorsBox:AddLabel('Box Color:'):AddColorPicker('BoxColor', {
	Default = Color3.fromRGB(255, 0, 0),
	Title = 'Box Color',
	Callback = function(Value)
		ESPSettings.BoxColor = Value
		UpdateESPPreview()
	end
})

ESPColorsBox:AddLabel('Tracer Color:'):AddColorPicker('TracerColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Tracer Color',
	Callback = function(Value)
		ESPSettings.TracerColor = Value
		UpdateESPPreview()
	end
})

ESPColorsBox:AddLabel('Health Bar Color:'):AddColorPicker('HealthBarColor', {
	Default = Color3.fromRGB(0, 255, 0),
	Title = 'Health Bar Color',
	Callback = function(Value)
		ESPSettings.HealthBarColor = Value
		UpdateESPPreview()
	end
})

ESPColorsBox:AddLabel('Skeleton Color:'):AddColorPicker('SkeletonColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Skeleton Color',
	Callback = function(Value)
		ESPSettings.SkeletonColor = Value
		UpdateESPPreview()
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

-- Get container from secondary window
local PreviewContainer = SecondaryWindow:GetContainer()

-- Add ESP Preview to secondary window instead of main window
ESPPreviewFrame = Library:Create('Frame', {
	BackgroundTransparency = 1;
	Size = UDim2.new(1, 0, 1, 0);
	Parent = PreviewContainer;
})

-- Create preview widget inside secondary window container
local ESPPreview = Library:Create('Frame', {
	BackgroundColor3 = Library.BackgroundColor;
	BorderColor3 = Library.OutlineColor;
	BorderSizePixel = 1;
	Size = UDim2.new(1, 0, 1, 0);
	ZIndex = 5;
	Parent = ESPPreviewFrame;
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

-- ViewportFrame for 3D Player Avatar
print('[ESP Preview] Creating ViewportFrame...')
local ViewportFrame = Instance.new('ViewportFrame')
ViewportFrame.Size = UDim2.new(1, 0, 1, -40)
ViewportFrame.Position = UDim2.new(0, 0, 0, 20)
ViewportFrame.BackgroundTransparency = 0
ViewportFrame.BorderSizePixel = 0
ViewportFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ViewportFrame.ImageTransparency = 0
ViewportFrame.LightDirection = Vector3.new(1, -1, 1)
ViewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
ViewportFrame.Ambient = Color3.fromRGB(150, 150, 150)
ViewportFrame.ZIndex = 7
ViewportFrame.Parent = ContentFrame

print('[ESP Preview] ViewportFrame created, size:', ViewportFrame.Size)

-- Camera for viewport
print('[ESP Preview] Creating ViewportCamera...')
ViewportCamera = Instance.new('Camera')
ViewportCamera.Parent = ViewportFrame
ViewportFrame.CurrentCamera = ViewportCamera
print('[ESP Preview] Camera assigned to ViewportFrame')

-- ESP OVERLAY CONTAINER - Sits on top of ViewportFrame
local ESPOverlay = Library:Create('Frame', {
	BackgroundTransparency = 1;  -- Transparent
	Size = UDim2.new(1, 0, 1, 0);  -- Full size
	Position = UDim2.new(0, 0, 0, 0);
	ZIndex = 20;  -- Higher than ViewportFrame (7)
	Parent = ContentFrame;
})
print('[ESP Preview] ===== ESP OVERLAY CONTAINER CREATED =====')

-- Create placeholder dummy avatar
local function CreateDummyAvatar()
	print('[ESP Preview] Creating placeholder dummy avatar...')
	
	-- Clear existing
	for _, child in pairs(ViewportFrame:GetChildren()) do
		if child:IsA('Model') or child:IsA('WorldModel') then
			child:Destroy()
		elseif child:IsA('Part') or child:IsA('MeshPart') then
			child:Destroy()
		end
	end
	
	local worldModel = Instance.new('WorldModel')
	worldModel.Parent = ViewportFrame
	
	local dummyModel = Instance.new('Model')
	dummyModel.Name = 'Dummy'
	dummyModel.Parent = worldModel
	
	-- Create simple R15 dummy
	local torso = Instance.new('Part')
	torso.Name = 'UpperTorso'
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = Vector3.new(0, 0, 0)
	torso.Anchored = true
	torso.BrickColor = BrickColor.new('Bright blue')
	torso.Material = Enum.Material.SmoothPlastic
	torso.Parent = dummyModel
	
	local head = Instance.new('Part')
	head.Name = 'Head'
	head.Size = Vector3.new(2, 1, 1)
	head.Position = Vector3.new(0, 1.5, 0)
	head.Anchored = true
	head.BrickColor = BrickColor.new('Bright yellow')
	head.Material = Enum.Material.SmoothPlastic
	
	-- Add face mesh to head
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	head.Parent = dummyModel
	
	local leftArm = Instance.new('Part')
	leftArm.Name = 'LeftUpperArm'
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Position = Vector3.new(-1.5, 0, 0)
	leftArm.Anchored = true
	leftArm.BrickColor = BrickColor.new('Bright yellow')
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Parent = dummyModel
	
	local rightArm = Instance.new('Part')
	rightArm.Name = 'RightUpperArm'
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Position = Vector3.new(1.5, 0, 0)
	rightArm.Anchored = true
	rightArm.BrickColor = BrickColor.new('Bright yellow')
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Parent = dummyModel
	
	local leftLeg = Instance.new('Part')
	leftLeg.Name = 'LeftUpperLeg'
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Position = Vector3.new(-0.5, -2, 0)
	leftLeg.Anchored = true
	leftLeg.BrickColor = BrickColor.new('Br. yellowish green')
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Parent = dummyModel
	
	local rightLeg = Instance.new('Part')
	rightLeg.Name = 'RightUpperLeg'
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Position = Vector3.new(0.5, -2, 0)
	rightLeg.Anchored = true
	rightLeg.BrickColor = BrickColor.new('Br. yellowish green')
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Parent = dummyModel
	
	dummyModel.PrimaryPart = torso
	CharacterModel = dummyModel
	
	-- Setup camera (simple like backup)
	ViewportCamera.CFrame = CFrame.new(0, 1, CameraDistance)
	ViewportCamera.Focus = CFrame.new(0, 1, 0)
	ViewportCamera.FieldOfView = 50
	
	print('[ESP Preview] Dummy avatar created successfully')
	print('[ESP Preview] Dummy parts:', #dummyModel:GetChildren())
	print('[ESP Preview] Camera CFrame:', ViewportCamera.CFrame)
	print('[ESP Preview] Camera looking from FRONT (Z+)')
	print('[ESP Preview] Model center:', torso.Position)
end

-- Clone player character for preview
local function UpdatePlayerAvatar()
	print('[ESP Preview] === Starting UpdatePlayerAvatar ===')
	
	local success, errorMsg = pcall(function()
		-- Clear existing models completely (except Camera)
		for _, child in pairs(ViewportFrame:GetChildren()) do
			if child:IsA('Model') or child:IsA('WorldModel') then
				print('[ESP Preview] Destroying old model:', child.Name)
				child:Destroy()
			elseif child:IsA('Part') or child:IsA('MeshPart') then
				print('[ESP Preview] Destroying old part:', child.Name)
				child:Destroy()
			end
		end
		
		CharacterModel = nil
		PartMap = {}
		
		local player = game.Players.LocalPlayer
		if not player then 
			warn('[ESP Preview] Player is nil!')
			CreateDummyAvatar()
			return 
		end
		
		if not player.Character then 
			warn('[ESP Preview] Character not found! Creating dummy...')
			CreateDummyAvatar()
			return 
		end
		
		print('[ESP Preview] Player found:', player.Name)
		print('[ESP Preview] Player found:', player.Name)
		
		local char = player.Character
		local hrp = char:FindFirstChild('HumanoidRootPart')
		if not hrp then 
			warn('[ESP Preview] HumanoidRootPart not found! Creating dummy...')
			CreateDummyAvatar()
			return 
		end
		
		print('[ESP Preview] Character valid, HRP found')
		print('[ESP Preview] Character children count:', #char:GetChildren())
		
		-- Use WorldModel for better viewport rendering
		local worldModel = Instance.new('WorldModel')
		worldModel.Parent = ViewportFrame
		
		-- Clone character model
		local charModel = Instance.new('Model')
		charModel.Name = player.Name
		charModel.Parent = worldModel
		
		local partsCloned = 0
		local hrpClone = nil
		PartMap = {} -- Reset and store globally
		
		-- First pass: Clone all BaseParts (body parts)
		for _, part in pairs(char:GetChildren()) do
			if part:IsA('BasePart') then
				pcall(function()
					local p = part:Clone()
					-- Remove non-visual elements
					for _, child in pairs(p:GetChildren()) do
						if child:IsA('JointInstance') or child:IsA('Constraint') then
							child:Destroy()
						elseif child:IsA('Script') or child:IsA('LocalScript') or child:IsA('ModuleScript') then
							child:Destroy()
						end
					end
					p.Anchored = true
					p.CanCollide = false
					p.CFrame = part.CFrame
					p.Parent = charModel
					
					PartMap[part] = p -- Store globally
					
					if p.Name == 'HumanoidRootPart' then
						hrpClone = p
					end
					partsCloned = partsCloned + 1
				end)
			end
		end
		
		-- Second pass: Clone Accessories with proper attachment positioning
		for _, acc in pairs(char:GetChildren()) do
			if acc:IsA('Accessory') then
				pcall(function()
					local originalHandle = acc:FindFirstChild('Handle')
					if not originalHandle then return end
					
					-- Clone the accessory
					local a = acc:Clone()
					
					-- Remove scripts
					for _, obj in pairs(a:GetDescendants()) do
						if obj:IsA('Script') or obj:IsA('LocalScript') or obj:IsA('ModuleScript') then
							obj:Destroy()
						end
					end
					
					local handle = a:FindFirstChild('Handle')
					if handle and handle:IsA('BasePart') then
						handle.Anchored = true
						handle.CanCollide = false
						
						-- Use Weld/Attachment data to position correctly
						local originalWeld = originalHandle:FindFirstChildOfClass('Weld')
						local originalAttachment = originalHandle:FindFirstChildOfClass('Attachment')
						
						if originalWeld and originalWeld.Part0 and originalWeld.Part1 then
							-- Find corresponding cloned part
							local attachedPart = originalWeld.Part0 == originalHandle and originalWeld.Part1 or originalWeld.Part0
							local clonedAttachedPart = PartMap[attachedPart]
							
							if clonedAttachedPart then
								-- Calculate proper CFrame based on weld offset
								local offset = originalWeld.C0
								handle.CFrame = clonedAttachedPart.CFrame * offset
							else
								-- Fallback to original CFrame
								handle.CFrame = originalHandle.CFrame
							end
						elseif originalAttachment then
							-- Use attachment system
							local attachmentName = originalAttachment.Name
							
							-- Find matching attachment in body parts
							for originalPart, clonedPart in pairs(PartMap) do
								local bodyAttachment = originalPart:FindFirstChild(attachmentName)
								if bodyAttachment and bodyAttachment:IsA('Attachment') then
									-- Position handle based on attachment
									local handleOffset = originalHandle.CFrame:ToObjectSpace(originalHandle.CFrame)
									local bodyOffset = bodyAttachment.WorldCFrame
									handle.CFrame = clonedPart.CFrame * bodyAttachment.CFrame
									break
								end
							end
						else
							-- No attachment found, use direct CFrame
							handle.CFrame = originalHandle.CFrame
						end
						
						PartMap[originalHandle] = handle
					end
					
					a.Parent = charModel
					partsCloned = partsCloned + 1
				end)
			end
		end
		
		-- Third pass: Clone appearance items
		for _, item in pairs(char:GetChildren()) do
			if item:IsA('Shirt') or item:IsA('Pants') or item:IsA('ShirtGraphic') or item:IsA('BodyColors') then
				pcall(function()
					item:Clone().Parent = charModel
				end)
			end
		end
		
		-- Clone Humanoid
		local humanoid = char:FindFirstChild('Humanoid')
		if humanoid then
			pcall(function()
				local clonedHumanoid = humanoid:Clone()
				clonedHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				clonedHumanoid.Parent = charModel
			end)
		end
		
		print('[ESP Preview] Cloned', partsCloned, 'items from character')
		
		if partsCloned == 0 then
			warn('[ESP Preview] No parts cloned! Creating dummy...')
			CreateDummyAvatar()
			return
		end
		
		print('[ESP Preview] Total items in charModel:', #charModel:GetChildren())
		
		-- Position character in viewport
		if hrpClone then
			charModel.PrimaryPart = hrpClone
			CharacterModel = charModel
			
			-- Move entire model to origin with current rotation
			local originalHRPPos = hrp.CFrame
			local targetCFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(CurrentRotation), 0)
			
			-- Position all parts relative to new HRP position (maintaining relative positions)
			for originalPart, clonedPart in pairs(PartMap) do
				if clonedPart and clonedPart:IsA('BasePart') and originalPart:IsA('BasePart') then
					local offset = originalHRPPos:ToObjectSpace(originalPart.CFrame)
					clonedPart.CFrame = targetCFrame:ToWorldSpace(offset)
				end
			end
			
			-- Update camera (simple like backup)
			ViewportCamera.CFrame = CFrame.new(0, 1, CameraDistance)
			ViewportCamera.Focus = CFrame.new(0, 1, 0)
			ViewportCamera.FieldOfView = 40
			
			print('[ESP Preview] Avatar rendered! Parts:', #charModel:GetDescendants())
			print('[ESP Preview] Camera CFrame:', ViewportCamera.CFrame)
			print('[ESP Preview] Model Position:', hrpClone.Position)
			print('[ESP Preview] WorldModel Children:', #worldModel:GetChildren())
			print('[ESP Preview] WorldModel Parent:', worldModel.Parent and worldModel.Parent.Name or 'nil')
			print('[ESP Preview] CharModel Parent:', charModel.Parent and charModel.Parent.Name or 'nil')
			print('[ESP Preview] ViewportFrame Visible:', ViewportFrame.Visible)
			print('[ESP Preview] ViewportFrame Parent:', ViewportFrame.Parent and ViewportFrame.Parent.Name or 'nil')
			print('[ESP Preview] ViewportFrame Size:', ViewportFrame.AbsoluteSize)
			print('[ESP Preview] ViewportFrame Position:', ViewportFrame.AbsolutePosition)
			print('[ESP Preview] Camera FieldOfView:', ViewportCamera.FieldOfView)
			
			-- Verify parts are actually visible
			local visibleParts = 0
			for _, part in pairs(charModel:GetDescendants()) do
				if part:IsA('BasePart') and part.Transparency < 1 then
					visibleParts = visibleParts + 1
				end
			end
			print('[ESP Preview] Visible parts (Transparency < 1):', visibleParts)
			
			-- Call UpdateESPPreview immediately to show ESP overlays
			print('[ESP Preview] Calling UpdateESPPreview to show overlays...')
			print('[ESP Preview] ESPSettings.BoxESP:', ESPSettings.BoxESP)
			print('[ESP Preview] ESPSettings.SkeletonESP:', ESPSettings.SkeletonESP)
			print('[ESP Preview] ESPSettings.ShowName:', ESPSettings.ShowName)
			print('[ESP Preview] ESPPreviewFrame exists:', ESPPreviewFrame ~= nil)
			
			if ESPPreviewFrame then
				print('[ESP Preview] Elements check:')
				print('  - BoxOutline:', ESPPreviewFrame.BoxOutline ~= nil)
				print('  - HeadCircle:', ESPPreviewFrame.HeadCircle ~= nil)
				print('  - NameLabel:', ESPPreviewFrame.NameLabel ~= nil)
				print('  - HealthBarBG:', ESPPreviewFrame.HealthBarBG ~= nil)
			end
			
			UpdateESPPreview()
			
			-- Force show ESP elements after small delay
			spawn(function()
				task.wait(0.3)
				if ESPPreviewFrame then
					print('[ESP Preview] ===== AUTO-CALCULATING BOX SIZE WITH DISTANCE SCALING =====')
					
					-- Calculate bounding box from avatar in ViewportFrame with distance scaling
					local function CalculateAvatarBounds(distance)
						if not charModel then return nil end
						
						local minX, maxX = math.huge, -math.huge
						local minY, maxY = math.huge, -math.huge
						
						-- Get all parts positions in screen space
						for _, part in pairs(charModel:GetDescendants()) do
							if part:IsA('BasePart') then
								local pos, onScreen = ViewportCamera:WorldToViewportPoint(part.Position)
								if onScreen then
									local size = part.Size
									-- Approximate screen space size
									local offset = ViewportCamera:WorldToViewportPoint(part.Position + Vector3.new(size.X/2, size.Y/2, 0))
									local sizeX = math.abs(offset.X - pos.X) * 2
									local sizeY = math.abs(offset.Y - pos.Y) * 2
									
									minX = math.min(minX, pos.X - sizeX/2)
									maxX = math.max(maxX, pos.X + sizeX/2)
									minY = math.min(minY, pos.Y - sizeY/2)
									maxY = math.max(maxY, pos.Y + sizeY/2)
								end
							end
						end
						
						if minX ~= math.huge then
							local width = maxX - minX
							local height = maxY - minY
							local centerX = (minX + maxX) / 2
							local centerY = (minY + maxY) / 2
							
							-- Convert to GUI coordinates (relative to ViewportFrame)
							local vpSize = ViewportFrame.AbsoluteSize
							
							-- Apply distance scaling (further = smaller)
							local distanceScale = 1 / (distance / 100) -- Scale based on distance
							
							return {
								X = centerX * vpSize.X,
								Y = centerY * vpSize.Y,
								Width = width * vpSize.X * distanceScale,
								Height = height * vpSize.Y * distanceScale
							}
							end
							return nil
						end
						
						local bounds = CalculateAvatarBounds(SimulatedDistance or 150)					
						if bounds and ESPPreviewFrame.BoxOutline then
							-- Update BoxOutline to fit avatar with distance scaling
							local padding = 5 -- Minimal padding for realistic ESP
							ESPPreviewFrame.BoxOutline.Position = UDim2.new(0, bounds.X - bounds.Width/2 - padding, 0, bounds.Y - bounds.Height/2 - padding)
							ESPPreviewFrame.BoxOutline.Size = UDim2.new(0, bounds.Width + padding*2, 0, bounds.Height + padding*2)
							ESPPreviewFrame.BoxOutline.Visible = ESPSettings.BoxESP or true -- Force for now
							ESPPreviewFrame.BoxOutline.BackgroundTransparency = 0.8 -- More transparent for realism
							ESPPreviewFrame.BoxOutline.BackgroundColor3 = ESPSettings.BoxColor
							ESPPreviewFrame.BoxOutline.BorderColor3 = ESPSettings.BoxColor
							ESPPreviewFrame.BoxOutline.BorderSizePixel = 2
							
							print('[ESP Preview] ===== BOX AUTO-FITTED WITH DISTANCE SCALING =====')
							print('[ESP Preview] Simulated Distance:', SimulatedDistance or 150, 'studs')
							print('[ESP Preview] Box Width:', math.floor(bounds.Width + padding*2), 'px')
							print('[ESP Preview] Box Height:', math.floor(bounds.Height + padding*2), 'px')
						else
							print('[ESP Preview] Failed to calculate bounds, using default')
							-- Fallback to manual size
							if ESPPreviewFrame.BoxOutline then
								ESPPreviewFrame.BoxOutline.Visible = true
								ESPPreviewFrame.BoxOutline.BorderColor3 = ESPSettings.BoxColor
							end
						end					-- FORCE Skeleton VISIBLE with proper sizing
					local skeletonScale = bounds and (bounds.Height / 140) or 1 -- Scale based on box height
					
					if ESPPreviewFrame.HeadToSpine then
						ESPPreviewFrame.HeadToSpine.Visible = true
						ESPPreviewFrame.HeadToSpine.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.SpineToLeftShoulder then
						ESPPreviewFrame.SpineToLeftShoulder.Visible = true
						ESPPreviewFrame.SpineToLeftShoulder.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.SpineToRightShoulder then
						ESPPreviewFrame.SpineToRightShoulder.Visible = true
						ESPPreviewFrame.SpineToRightShoulder.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.LeftArmLine then
						ESPPreviewFrame.LeftArmLine.Visible = true
						ESPPreviewFrame.LeftArmLine.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.RightArmLine then
						ESPPreviewFrame.RightArmLine.Visible = true
						ESPPreviewFrame.RightArmLine.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.SpineToHips then
						ESPPreviewFrame.SpineToHips.Visible = true
						ESPPreviewFrame.SpineToHips.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.HipsToLeftHip then
						ESPPreviewFrame.HipsToLeftHip.Visible = true
						ESPPreviewFrame.HipsToLeftHip.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.HipsToRightHip then
						ESPPreviewFrame.HipsToRightHip.Visible = true
						ESPPreviewFrame.HipsToRightHip.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.LeftLegLine then
						ESPPreviewFrame.LeftLegLine.Visible = true
						ESPPreviewFrame.LeftLegLine.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					if ESPPreviewFrame.RightLegLine then
						ESPPreviewFrame.RightLegLine.Visible = true
						ESPPreviewFrame.RightLegLine.BackgroundColor3 = ESPSettings.SkeletonColor
					end
					print('[ESP Preview] Skeleton lines FORCED VISIBLE')
					
					-- FORCE Name VISIBLE
					if ESPPreviewFrame.NameLabel then
						ESPPreviewFrame.NameLabel.Visible = true
						ESPPreviewFrame.NameLabel.TextColor3 = ESPSettings.NameColor
						print('[ESP Preview] NameLabel FORCED VISIBLE')
					end
					
					-- FORCE Distance VISIBLE with simulated distance
					if ESPPreviewFrame.DistanceLabel then
						ESPPreviewFrame.DistanceLabel.Visible = true
						ESPPreviewFrame.DistanceLabel.Text = string.format('[%dm]', math.floor(SimulatedDistance))
						ESPPreviewFrame.DistanceLabel.TextColor3 = ESPSettings.DistanceColor
						print('[ESP Preview] DistanceLabel FORCED VISIBLE - Distance:', SimulatedDistance)
					end
					
					-- FORCE Health Bar VISIBLE
					if ESPPreviewFrame.HealthBarBG then
						ESPPreviewFrame.HealthBarBG.Visible = true
						print('[ESP Preview] HealthBarBG FORCED VISIBLE')
					end
					
					print('[ESP Preview] ===== ALL ESP FORCED TO VISIBLE =====')
				end
			end)
		else
			warn('[ESP Preview] HumanoidRootPart not found in clone! Creating dummy...')
			CreateDummyAvatar()
		end
	end)
	
	
	if not success then
		warn('[ESP Preview] Failed to load avatar:', errorMsg)
		warn('[ESP Preview] Stack trace:', debug.traceback())
		CreateDummyAvatar()
	end
	
	print('[ESP Preview] === UpdatePlayerAvatar completed ===')
end

-- Mouse drag to rotate
local dragging = false
local dragStart = nil
local rotationStart = 0

ViewportFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position.X
		rotationStart = CurrentRotation
	end
end)

ViewportFrame.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position.X - dragStart
		local rotationDelta = delta * 0.5
		local newRotation = rotationStart + rotationDelta
		RotateCharacter(newRotation)
		
		-- Update slider
		if Options.AvatarRotation then
			Options.AvatarRotation:SetValue(newRotation % 360)
		end
	end
end)

ViewportFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

-- Mouse scroll for zoom
ViewportFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local scrollDelta = input.Position.Z
		local newDistance = CameraDistance - (scrollDelta * 0.5) -- Scroll sensitivity
		UpdateCameraZoom(newDistance)
		
		-- Update slider if it exists
		if Options.CameraZoom then
			Options.CameraZoom:SetValue(CameraDistance)
		end
	end
end)

-- Update avatar when character spawns (with delay)
spawn(function()
	print('[ESP Preview] Waiting for character...')
	local player = game.Players.LocalPlayer
	
	-- Wait for character to exist
	if not player.Character then
		print('[ESP Preview] Character not found, waiting...')
		player.CharacterAdded:Wait()
	end
	
	local char = player.Character or player.CharacterAdded:Wait()
	
	-- Wait for HumanoidRootPart
	local hrp = char:FindFirstChild('HumanoidRootPart')
	if not hrp then
		print('[ESP Preview] Waiting for HumanoidRootPart...')
		hrp = char:WaitForChild('HumanoidRootPart', 10)
	end
	
	if hrp then
		print('[ESP Preview] Character ready! Will load avatar after UI setup...')
		-- Don't call UpdatePlayerAvatar here - called after ESPPreviewFrame is ready
	else
		warn('[ESP Preview] HumanoidRootPart timeout, creating dummy')
		CreateDummyAvatar()
	end
end)

game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
	print('[ESP Preview] Character respawned, reloading avatar...')
	-- Wait for character to fully load
	local hrp = char:FindFirstChild('HumanoidRootPart')
	if not hrp then
		print('[ESP Preview] Waiting for HumanoidRootPart on respawn...')
		hrp = char:WaitForChild('HumanoidRootPart', 10)
	end
	
	if hrp then
		print('[ESP Preview] Respawn detected, will update avatar after delay...')
		task.wait(0.5)
		if ESPPreviewFrame then
			UpdatePlayerAvatar()
		else
			print('[ESP Preview] ESPPreviewFrame not ready yet on respawn')
		end
	else
		warn('[ESP Preview] HumanoidRootPart timeout on respawn')
		CreateDummyAvatar()
	end
end)

-- Box ESP Outline (2D Box around player) - IN OVERLAY CONTAINER
local BoxOutline = Library:Create('Frame', {
	BackgroundColor3 = Color3.fromRGB(255, 0, 0);  -- SOLID RED background
	BackgroundTransparency = 0.7;  -- Semi-transparent to see avatar
	BorderColor3 = Color3.fromRGB(255, 255, 255);  -- White border
	BorderSizePixel = 2;
	Position = UDim2.new(0.5, -35, 0.5, -80);  -- Adjusted untuk fit avatar
	Size = UDim2.new(0, 70, 0, 160);  -- Ukuran lebih pas dengan avatar
	ZIndex = 21;
	Visible = true;  -- START VISIBLE
	Parent = ESPOverlay;
})

print('[ESP Preview] ===== BOX OUTLINE CREATED =====')
print('[ESP Preview] BoxOutline should be RED BOX fitted to avatar')
print('[ESP Preview] BoxOutline.Visible:', BoxOutline.Visible)

-- Skeleton overlay container - IN OVERLAY
local SkeletonContainer = Library:Create('Frame', {
	BackgroundTransparency = 1;
	Position = UDim2.new(0, 0, 0, 0);  -- Full size overlay
	Size = UDim2.new(1, 0, 1, 0);
	ZIndex = 22;
	Parent = ESPOverlay;
})

print('[ESP Preview] SkeletonContainer created in ESPOverlay')

-- Skeleton Lines (connecting body parts like real ESP)
-- Head to Spine
local HeadToSpine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -1, 0.5, -60);  -- From head
	Size = UDim2.new(0, 2, 0, 20);  -- Line thickness 2px
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Spine to Left Shoulder
local SpineToLeftShoulder = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -20, 0.5, -35);
	Size = UDim2.new(0, 20, 0, 2);  -- Horizontal line
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Spine to Right Shoulder  
local SpineToRightShoulder = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, 0, 0.5, -35);
	Size = UDim2.new(0, 20, 0, 2);
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Left Shoulder to Left Hand
local LeftArmLine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -20, 0.5, -35);
	Size = UDim2.new(0, 2, 0, 40);  -- Vertical arm
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Right Shoulder to Right Hand
local RightArmLine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, 18, 0.5, -35);
	Size = UDim2.new(0, 2, 0, 40);
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Spine to Hips (center body)
local SpineToHips = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -1, 0.5, -35);
	Size = UDim2.new(0, 2, 0, 35);  -- Spine length
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Hips to Left Hip
local HipsToLeftHip = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -10, 0.5, 0);
	Size = UDim2.new(0, 10, 0, 2);  -- Hip width
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Hips to Right Hip
local HipsToRightHip = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, 0, 0.5, 0);
	Size = UDim2.new(0, 10, 0, 2);
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Left Hip to Left Foot
local LeftLegLine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -10, 0.5, 0);
	Size = UDim2.new(0, 2, 0, 50);  -- Leg length
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Right Hip to Right Foot
local RightLegLine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, 8, 0.5, 0);
	Size = UDim2.new(0, 2, 0, 50);
	ZIndex = 23;
	Visible = false;
	Parent = SkeletonContainer;
})
	Visible = false;
	Parent = SkeletonContainer;
})

local RightArm = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, 16, 0, 30);
	Size = UDim2.new(0, 2, 0, 24);
	ZIndex = 12;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Spine line
local Spine = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.SkeletonColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0.5, -1, 0, 22);
	Size = UDim2.new(0, 2, 0, 42);
	ZIndex = 12;
	Visible = false;
	Parent = SkeletonContainer;
})

-- Player Name Label (above box)
local playerName = game.Players.LocalPlayer.DisplayName or game.Players.LocalPlayer.Name
local NameLabel = Library:CreateLabel({
	Position = UDim2.new(0.5, -60, 0, 2);  -- Back to ContentFrame positioning
	Size = UDim2.new(0, 120, 0, 16);
	Text = playerName;
	TextSize = 12;
	TextColor3 = ESPSettings.NameColor;
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	ZIndex = 25;
	Parent = ESPOverlay;  -- IN OVERLAY
})

-- Distance Label (below box)
local DistanceLabel = Library:CreateLabel({
	Position = UDim2.new(0.5, -50, 1, -23);
	Size = UDim2.new(0, 100, 0, 15);
	Text = string.format('[%dm]', math.floor(SimulatedDistance)); -- Show simulated distance
	TextSize = 10;
	TextColor3 = ESPSettings.DistanceColor;
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	ZIndex = 25;
	Parent = ESPOverlay;  -- IN OVERLAY
})

print('[ESP Preview] Name and Distance labels created in ESPOverlay')

-- Health Bar Background (Left side of box) - IN OVERLAY
local HealthBarBG = Library:Create('Frame', {
	BackgroundColor3 = Color3.fromRGB(30, 30, 30);
	BorderColor3 = Color3.fromRGB(0, 0, 0);
	BorderSizePixel = 1;
	Position = UDim2.new(0, 8, 0.5, -50);
	Size = UDim2.new(0, 4, 0, 100);
	ZIndex = 23;
	Parent = ESPOverlay;  -- IN OVERLAY
})

print('[ESP Preview] HealthBarBG created in ESPOverlay')

-- Health Bar Fill
local HealthBar = Library:Create('Frame', {
	BackgroundColor3 = ESPSettings.HealthBarColor;
	BorderSizePixel = 0;
	Position = UDim2.new(0, 0, 0.25, 0);
	Size = UDim2.new(1, 0, 0.75, 0);
	ZIndex = 14;
	Parent = HealthBarBG;
})

-- Health Text
local HealthText = Library:CreateLabel({
	Position = UDim2.new(0, -22, 0.25, -2);
	Size = UDim2.new(0, 18, 0, 12);
	Text = '75';
	TextSize = 9;
	TextXAlignment = Enum.TextXAlignment.Right;
	BackgroundTransparency = 1;
	TextStrokeTransparency = 0.5;
	ZIndex = 15;
	Parent = HealthBarBG;
})

-- Store references in global table
ESPPreviewFrame = {
	Window = SecondaryWindow;
	Main = ESPPreview;
	ViewportFrame = ViewportFrame;
	UpdateAvatar = UpdatePlayerAvatar;
	RotateAvatar = RotateCharacter;
	BoxOutline = BoxOutline;
	SkeletonContainer = SkeletonContainer;
	-- Skeleton lines
	HeadToSpine = HeadToSpine;
	SpineToLeftShoulder = SpineToLeftShoulder;
	SpineToRightShoulder = SpineToRightShoulder;
	LeftArmLine = LeftArmLine;
	RightArmLine = RightArmLine;
	SpineToHips = SpineToHips;
	HipsToLeftHip = HipsToLeftHip;
	HipsToRightHip = HipsToRightHip;
	LeftLegLine = LeftLegLine;
	RightLegLine = RightLegLine;
	-- Labels and health
	NameLabel = NameLabel;
	DistanceLabel = DistanceLabel;
	HealthBar = HealthBar;
	HealthBarBG = HealthBarBG;
	HealthText = HealthText;
	ContentFrame = ContentFrame;
}

print('[ESP Preview] ESPPreviewFrame initialized with skeleton lines')
print('[ESP Preview] BoxOutline:', BoxOutline)
print('[ESP Preview] Skeleton lines:', HeadToSpine, LeftArmLine, RightArmLine)
print('[ESP Preview] NameLabel:', NameLabel)

-- NOW load the avatar after ESPPreviewFrame is ready
task.wait(0.1)
UpdatePlayerAvatar()

