-- Debug Script for Last Letter Game
-- Run this in executor to discover game structure

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')

print('\n========== LAST LETTER DEBUG ==========\n')

-- ===== 1. FIND REMOTES (Events/Functions) =====
print('===== REMOTES IN REPLICATEDSTORAGE =====')
local function scanForRemotes(parent, depth)
	depth = depth or 0
	local indent = string.rep('  ', depth)
	
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA('RemoteEvent') then
			print(indent .. '[RemoteEvent] ' .. child:GetFullName())
		elseif child:IsA('RemoteFunction') then
			print(indent .. '[RemoteFunction] ' .. child:GetFullName())
		elseif child:IsA('BindableEvent') then
			print(indent .. '[BindableEvent] ' .. child:GetFullName())
		elseif child:IsA('BindableFunction') then
			print(indent .. '[BindableFunction] ' .. child:GetFullName())
		end
		
		if #child:GetChildren() > 0 then
			scanForRemotes(child, depth + 1)
		end
	end
end

scanForRemotes(ReplicatedStorage)

-- ===== 2. FIND UI ELEMENTS =====
print('\n===== PLAYER GUI STRUCTURE =====')
local function scanGui(parent, depth)
	depth = depth or 0
	local indent = string.rep('  ', depth)
	
	if depth > 5 then return end -- Limit depth
	
	for _, child in ipairs(parent:GetChildren()) do
		local info = child.ClassName
		
		if child:IsA('TextLabel') or child:IsA('TextBox') then
			info = info .. ' [Text: "' .. (child.Text or ''):sub(1, 30) .. '"]'
		elseif child:IsA('TextButton') then
			info = info .. ' [Button: "' .. (child.Text or ''):sub(1, 30) .. '"]'
		end
		
		print(indent .. child.Name .. ' (' .. info .. ')')
		
		if #child:GetChildren() > 0 and not child:IsA('TextLabel') then
			scanGui(child, depth + 1)
		end
	end
end

for _, gui in ipairs(PlayerGui:GetChildren()) do
	print('\n--- ' .. gui.Name .. ' ---')
	scanGui(gui, 1)
end

-- ===== 3. FIND MODULES =====
print('\n===== MODULES IN REPLICATEDSTORAGE =====')
local function findModules(parent, depth)
	depth = depth or 0
	local indent = string.rep('  ', depth)
	
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA('ModuleScript') then
			print(indent .. '[Module] ' .. child:GetFullName())
		end
		if #child:GetChildren() > 0 then
			findModules(child, depth + 1)
		end
	end
end

findModules(ReplicatedStorage)

-- ===== 4. FIND VALUE OBJECTS =====
print('\n===== VALUE OBJECTS (Game State) =====')
local function findValues(parent, path)
	path = path or parent.Name
	
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA('StringValue') then
			print('[StringValue] ' .. path .. '/' .. child.Name .. ' = "' .. child.Value .. '"')
		elseif child:IsA('IntValue') or child:IsA('NumberValue') then
			print('[NumberValue] ' .. path .. '/' .. child.Name .. ' = ' .. tostring(child.Value))
		elseif child:IsA('BoolValue') then
			print('[BoolValue] ' .. path .. '/' .. child.Name .. ' = ' .. tostring(child.Value))
		elseif child:IsA('ObjectValue') then
			local val = child.Value and child.Value.Name or 'nil'
			print('[ObjectValue] ' .. path .. '/' .. child.Name .. ' = ' .. val)
		end
		
		if #child:GetChildren() > 0 then
			findValues(child, path .. '/' .. child.Name)
		end
	end
end

findValues(ReplicatedStorage)
findValues(Workspace)

-- ===== 5. SPY ON REMOTES =====
print('\n===== REMOTE SPY (Run and play game to see traffic) =====')

-- Safe hook (skip if not supported)
pcall(function()
	local oldNamecall
	oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
		local method = getnamecallmethod()
		local args = {...}
		
		if method == 'FireServer' and self:IsA('RemoteEvent') then
			print('[FIRE] ' .. self:GetFullName())
			for i, arg in ipairs(args) do
				print('  Arg ' .. i .. ': ' .. typeof(arg) .. ' = ' .. tostring(arg))
			end
		elseif method == 'InvokeServer' and self:IsA('RemoteFunction') then
			print('[INVOKE] ' .. self:GetFullName())
			for i, arg in ipairs(args) do
				print('  Arg ' .. i .. ': ' .. typeof(arg) .. ' = ' .. tostring(arg))
			end
		end
		
		return oldNamecall(self, ...)
	end)
end)

-- Listen to incoming events
for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
	if child:IsA('RemoteEvent') then
		pcall(function()
			child.OnClientEvent:Connect(function(...)
				local args = {...}
				print('[RECEIVE] ' .. child.Name .. ' (' .. child:GetFullName() .. ')')
				for i, arg in ipairs(args) do
					if typeof(arg) == 'table' then
						print('  Arg ' .. i .. ': table')
						for k, v in pairs(arg) do
							print('    ' .. tostring(k) .. ' = ' .. tostring(v))
						end
					else
						print('  Arg ' .. i .. ': ' .. typeof(arg) .. ' = ' .. tostring(arg))
					end
				end
			end)
		end)
	end
end

-- ===== 6. MONITOR GAME STATE =====
print('\n===== MONITORING GAME STATE =====')

-- Try to find common game folders
local gameFolder = ReplicatedStorage:FindFirstChild('Game') 
	or ReplicatedStorage:FindFirstChild('GameData')
	or ReplicatedStorage:FindFirstChild('Data')
	or ReplicatedStorage:FindFirstChild('Shared')

if gameFolder then
	print('Found game folder: ' .. gameFolder:GetFullName())
	for _, child in ipairs(gameFolder:GetDescendants()) do
		if child:IsA('ValueBase') then
			print('  [' .. child.ClassName .. '] ' .. child.Name .. ' = ' .. tostring(child.Value))
			-- Monitor changes
			child.Changed:Connect(function(newVal)
				print('[CHANGED] ' .. child.Name .. ' = ' .. tostring(newVal))
			end)
		end
	end
end

-- Monitor PlayerGui for game UI changes
spawn(function()
	while wait(1) do
		-- Look for answer input box
		for _, gui in ipairs(PlayerGui:GetDescendants()) do
			if gui:IsA('TextBox') and gui.Visible then
				-- Found visible TextBox - might be answer input
				if gui.PlaceholderText and gui.PlaceholderText ~= '' then
					print('[TextBox Found] ' .. gui:GetFullName() .. ' Placeholder: ' .. gui.PlaceholderText)
				end
			end
		end
	end
end)

print('\n========== DEBUG ACTIVE ==========')
print('Play the game normally to see remote traffic!')
print('Look for:')
print('  - Submit/Answer remotes')
print('  - Current word values')
print('  - Join game buttons')
print('=====================================\n')
