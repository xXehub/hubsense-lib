-- ESP Preview Widget Example
-- Demo cara menggunakan AddESPPreview dari LinoriaLib

local repo = 'https://raw.githubusercontent.com/xXehub/hubsense-lib/refs/heads/main/ondevs/'
local Library = loadstring(game:HttpGet(repo .. 'LinoriaLib.lua'))()

-- Create window
local Window = Library:CreateWindow({
	Title = 'ESP Preview Example',
	Center = true,
	AutoShow = true,
	Size = UDim2.fromOffset(500, 400)
})

-- Create tabs
local Tabs = {
	Visual = Window:AddTab('Visual')
}

-- ==================== ESP SETTINGS ====================
local ESPSettings = {
	ShowName = true,
	ShowDistance = true,
	ShowHealth = true,
	ShowBox = true,
	BoxColor = Color3.fromRGB(255, 0, 0),
	NameColor = Color3.fromRGB(255, 255, 255),
	HealthBarColor = Color3.fromRGB(0, 255, 0)
}

-- ==================== ESP PREVIEW GROUPBOX ====================
local PreviewBox = Tabs.Visual:AddLeftGroupbox('ESP Preview')

-- Tambahkan ESP Preview menggunakan method native LinoriaLib
local MyESPPreview = PreviewBox:AddESPPreview({
	Height = 220; -- Tinggi preview (default 200)
	PlayerName = game.Players.LocalPlayer.DisplayName or 'Player'; -- Nama yang ditampilkan
	DistanceText = '< Weapon >'; -- Text untuk distance label
	HealthText = '75'; -- Text untuk health
	Settings = {
		ShowBox = ESPSettings.ShowBox;
		ShowName = ESPSettings.ShowName;
		ShowDistance = ESPSettings.ShowDistance;
		ShowHealth = ESPSettings.ShowHealth;
		BoxColor = ESPSettings.BoxColor;
		NameColor = ESPSettings.NameColor;
		HealthBarColor = ESPSettings.HealthBarColor;
	};
	OnUpdate = function(Settings)
		-- Callback ketika preview di-update
		print('[ESP Preview] Updated:', Settings)
	end;
})

PreviewBox:AddDivider()

-- Toggle untuk show/hide preview
PreviewBox:AddToggle('ShowPreview', {
	Text = 'Show Preview',
	Default = true,
	Tooltip = 'Toggle preview visibility',
	Callback = function(Value)
		MyESPPreview:SetVisible(Value)
	end
})

-- ==================== ESP CONTROLS ====================
local ControlBox = Tabs.Visual:AddRightGroupbox('ESP Controls')

ControlBox:AddToggle('ShowBox', {
	Text = 'Show Box',
	Default = true,
	Callback = function(Value)
		ESPSettings.ShowBox = Value
		MyESPPreview:Update({ShowBox = Value})
	end
})

ControlBox:AddToggle('ShowName', {
	Text = 'Show Name',
	Default = true,
	Callback = function(Value)
		ESPSettings.ShowName = Value
		MyESPPreview:Update({ShowName = Value})
	end
})

ControlBox:AddToggle('ShowDistance', {
	Text = 'Show Distance',
	Default = true,
	Callback = function(Value)
		ESPSettings.ShowDistance = Value
		MyESPPreview:Update({ShowDistance = Value})
	end
})

ControlBox:AddToggle('ShowHealth', {
	Text = 'Show Health',
	Default = true,
	Callback = function(Value)
		ESPSettings.ShowHealth = Value
		MyESPPreview:Update({ShowHealth = Value})
	end
})

ControlBox:AddDivider()

-- ==================== ESP COLORS ====================
local ColorBox = Tabs.Visual:AddRightGroupbox('ESP Colors')

ColorBox:AddLabel('Box Color:'):AddColorPicker('BoxColor', {
	Default = Color3.fromRGB(255, 0, 0),
	Title = 'Box Color',
	Callback = function(Value)
		ESPSettings.BoxColor = Value
		MyESPPreview:Update({BoxColor = Value})
	end
})

ColorBox:AddLabel('Name Color:'):AddColorPicker('NameColor', {
	Default = Color3.fromRGB(255, 255, 255),
	Title = 'Name Color',
	Callback = function(Value)
		ESPSettings.NameColor = Value
		MyESPPreview:Update({NameColor = Value})
	end
})

ColorBox:AddLabel('Health Color:'):AddColorPicker('HealthColor', {
	Default = Color3.fromRGB(0, 255, 0),
	Title = 'Health Bar Color',
	Callback = function(Value)
		ESPSettings.HealthBarColor = Value
		MyESPPreview:Update({HealthBarColor = Value})
	end
})

ColorBox:AddDivider()

-- ==================== EXTRA METHODS ====================
local ExtrasBox = Tabs.Visual:AddLeftGroupbox('Extra Methods')

ExtrasBox:AddButton({
	Text = 'Change Player Name',
	Func = function()
		MyESPPreview:SetPlayerName('CustomName')
		print('Player name changed to: CustomName')
	end
})

ExtrasBox:AddButton({
	Text = 'Set Health to 50',
	Func = function()
		MyESPPreview:SetHealth(50)
		print('Health set to: 50')
	end
})

ExtrasBox:AddButton({
	Text = 'Set Health to 100',
	Func = function()
		MyESPPreview:SetHealth(100)
		print('Health set to: 100')
	end
})

ExtrasBox:AddDivider()

ExtrasBox:AddLabel('Methods Available:', true)
ExtrasBox:AddLabel('• :Update(Settings)', true)
ExtrasBox:AddLabel('• :SetVisible(bool)', true)
ExtrasBox:AddLabel('• :SetPlayerName(str)', true)
ExtrasBox:AddLabel('• :SetHealth(number)', true)

print('[ESP Preview Example] Loaded successfully!')
print('[ESP Preview] Widget methods:')
print('  - MyESPPreview:Update({ShowBox = true, BoxColor = Color3.new()})')
print('  - MyESPPreview:SetVisible(true/false)')
print('  - MyESPPreview:SetPlayerName("Name")')
print('  - MyESPPreview:SetHealth(75)')
