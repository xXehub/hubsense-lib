-- Secondary Window Example
-- Demo cara menggunakan CreateSecondaryWindow dari LinoriaLib

local repo = 'https://raw.githubusercontent.com/xXehub/hubsense-lib/refs/heads/main/ondevs/'
local Library = loadstring(game:HttpGet(repo .. 'LinoriaLib.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'ThemeManager.lua'))()

-- ==================== MAIN WINDOW ====================
local Window = Library:CreateWindow({
	Title = 'Main Window Example',
	Center = true,
	AutoShow = true,
	Size = UDim2.fromOffset(550, 450)
})

local Tabs = {
	Main = Window:AddTab('Main'),
	Settings = Window:AddTab('Settings')
}

-- ==================== SECONDARY WINDOW ====================
local SecondaryWindow = Library:CreateSecondaryWindow({
	Title = 'Secondary Window';              -- Window title
	Position = UDim2.fromOffset(580, 50);    -- Position (right of main window)
	Size = UDim2.fromOffset(300, 400);       -- Window size
	Resizable = true;                        -- Allow resizing
	MinSize = Vector2.new(250, 300);         -- Minimum size when resizing
	MinimizeKey = 'End';                     -- Press End key to minimize
	AutoShow = true;                         -- Show on creation
})

-- Get container to add content
local Container = SecondaryWindow:GetContainer()

-- Add some content to secondary window
local ExampleLabel = Library:CreateLabel({
	Position = UDim2.new(0, 0, 0, 0);
	Size = UDim2.new(1, 0, 0, 30);
	Text = 'This is a secondary window!';
	TextSize = 14;
	Parent = Container;
})

local ExampleLabel2 = Library:CreateLabel({
	Position = UDim2.new(0, 0, 0, 35);
	Size = UDim2.new(1, 0, 0, 60);
	Text = 'You can:\n• Drag it anywhere\n• Resize it\n• Minimize with [End] key';
	TextSize = 12;
	TextWrapped = true;
	Parent = Container;
})

-- Add visual example (colored box)
local ColorBox = Library:Create('Frame', {
	BackgroundColor3 = Color3.fromRGB(100, 150, 255);
	BorderColor3 = Color3.fromRGB(50, 100, 200);
	BorderSizePixel = 2;
	Position = UDim2.new(0.5, -50, 0.5, -50);
	Size = UDim2.new(0, 100, 0, 100);
	Parent = Container;
})

local BoxLabel = Library:CreateLabel({
	Size = UDim2.new(1, 0, 1, 0);
	Text = 'Preview';
	TextSize = 16;
	Parent = ColorBox;
})

-- ==================== MAIN WINDOW CONTROLS ====================
local ControlBox = Tabs.Main:AddLeftGroupbox('Secondary Window Controls')

ControlBox:AddButton({
	Text = 'Show Window',
	Func = function()
		SecondaryWindow:Show()
		print('[Secondary] Window shown')
	end
})

ControlBox:AddButton({
	Text = 'Hide Window',
	Func = function()
		SecondaryWindow:Hide()
		print('[Secondary] Window hidden')
	end
})

ControlBox:AddButton({
	Text = 'Toggle Window',
	Func = function()
		SecondaryWindow:Toggle()
		print('[Secondary] Window toggled')
	end
})

ControlBox:AddDivider()

ControlBox:AddButton({
	Text = 'Minimize',
	Func = function()
		SecondaryWindow:Minimize()
		print('[Secondary] Window minimized')
	end
})

ControlBox:AddButton({
	Text = 'Restore',
	Func = function()
		SecondaryWindow:Restore()
		print('[Secondary] Window restored')
	end
})

ControlBox:AddDivider()

ControlBox:AddButton({
	Text = 'Change Title',
	Func = function()
		SecondaryWindow:SetTitle('New Title! ' .. os.time())
		print('[Secondary] Title changed')
	end
})

-- ==================== POSITION CONTROLS ====================
local PositionBox = Tabs.Main:AddRightGroupbox('Position Controls')

PositionBox:AddButton({
	Text = 'Move to Top Left',
	Func = function()
		SecondaryWindow:SetPosition(UDim2.fromOffset(10, 10))
	end
})

PositionBox:AddButton({
	Text = 'Move to Top Right',
	Func = function()
		SecondaryWindow:SetPosition(UDim2.fromOffset(600, 10))
	end
})

PositionBox:AddButton({
	Text = 'Move to Center',
	Func = function()
		local ViewportSize = workspace.CurrentCamera.ViewportSize
		SecondaryWindow:SetPosition(UDim2.fromOffset(
			ViewportSize.X / 2 - 150,
			ViewportSize.Y / 2 - 200
		))
	end
})

PositionBox:AddDivider()

PositionBox:AddButton({
	Text = 'Resize Small',
	Func = function()
		SecondaryWindow:SetSize(UDim2.fromOffset(250, 300))
	end
})

PositionBox:AddButton({
	Text = 'Resize Large',
	Func = function()
		SecondaryWindow:SetSize(UDim2.fromOffset(400, 500))
	end
})

-- ==================== INFO ====================
local InfoBox = Tabs.Settings:AddLeftGroupbox('Secondary Window Info')

InfoBox:AddLabel('Methods Available:', true)
InfoBox:AddLabel('• :Show()', true)
InfoBox:AddLabel('• :Hide()', true)
InfoBox:AddLabel('• :Toggle()', true)
InfoBox:AddLabel('• :Minimize()', true)
InfoBox:AddLabel('• :Restore()', true)
InfoBox:AddLabel('• :SetTitle(text)', true)
InfoBox:AddLabel('• :SetPosition(UDim2)', true)
InfoBox:AddLabel('• :SetSize(UDim2)', true)
InfoBox:AddLabel('• :GetContainer()', true)

InfoBox:AddDivider()

InfoBox:AddLabel('Features:', true)
InfoBox:AddLabel('✓ Draggable', true)
InfoBox:AddLabel('✓ Resizable (optional)', true)
InfoBox:AddLabel('✓ Minimize button', true)
InfoBox:AddLabel('✓ Keyboard shortcut', true)
InfoBox:AddLabel('✓ Theme integration', true)

-- ==================== EXAMPLE USE CASES ====================
local UseCaseBox = Tabs.Settings:AddRightGroupbox('Use Cases')

UseCaseBox:AddLabel('Perfect for:', true)
UseCaseBox:AddLabel('• ESP Preview windows', true)
UseCaseBox:AddLabel('• Player lists', true)
UseCaseBox:AddLabel('• Live stats display', true)
UseCaseBox:AddLabel('• Debug consoles', true)
UseCaseBox:AddLabel('• Color previews', true)
UseCaseBox:AddLabel('• Detached panels', true)

UseCaseBox:AddDivider()

UseCaseBox:AddLabel('Tips:', true)
UseCaseBox:AddLabel('• Use Container for content', true)
UseCaseBox:AddLabel('• Set MinimizeKey for UX', true)
UseCaseBox:AddLabel('• Resizable = optional', true)

-- Theme setup
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder('SecondaryWindowExample')
ThemeManager:ApplyTheme('Default')

print('[Secondary Window Example] Loaded!')
print('Available methods:')
print('  - SecondaryWindow:Show()')
print('  - SecondaryWindow:Hide()')
print('  - SecondaryWindow:Toggle()')
print('  - SecondaryWindow:Minimize()')
print('  - SecondaryWindow:Restore()')
print('  - SecondaryWindow:SetTitle("New Title")')
print('  - SecondaryWindow:SetPosition(UDim2.fromOffset(x, y))')
print('  - SecondaryWindow:SetSize(UDim2.fromOffset(w, h))')
print('Press [End] to minimize/restore the secondary window')
