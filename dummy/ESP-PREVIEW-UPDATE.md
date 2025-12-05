# LinoriaLib Update - ESP Preview Widget

## 📦 What's New?

LinoriaLib sekarang sudah include **native ESP Preview widget** yang terintegrasi sempurna dengan style UI library!

## ✨ Features

- **Native Integration**: ESP Preview sekarang bagian dari LinoriaLib, bukan manual instance creation
- **Consistent Styling**: Otomatis match dengan theme dan colors dari library
- **Clean API**: Methods yang simple dan easy to use
- **Real-time Updates**: Instant color/visibility updates
- **Customizable**: Height, player name, health, distance text bisa di-set

## 🎯 Usage

### Basic Setup

```lua
local PreviewBox = Tabs.Visual:AddLeftGroupbox('ESP Preview')

local MyPreview = PreviewBox:AddESPPreview({
    Height = 200;                    -- Preview height (default: 200)
    PlayerName = 'PlayerName';       -- Display name
    DistanceText = '< Weapon >';     -- Distance label text
    HealthText = '75';               -- Health text
    Settings = {
        ShowBox = true;
        ShowName = true;
        ShowDistance = true;
        ShowHealth = true;
        BoxColor = Color3.fromRGB(255, 0, 0);
        NameColor = Color3.fromRGB(255, 255, 255);
        HealthBarColor = Color3.fromRGB(0, 255, 0);
    };
    OnUpdate = function(Settings)
        -- Callback when preview updates
        print('Preview updated!', Settings)
    end;
})
```

### Available Methods

#### 1. Update Settings
```lua
MyPreview:Update({
    ShowBox = false;
    BoxColor = Color3.fromRGB(0, 255, 0);
    ShowHealth = true;
})
```

#### 2. Toggle Visibility
```lua
MyPreview:SetVisible(true)  -- Show
MyPreview:SetVisible(false) -- Hide
```

#### 3. Change Player Name
```lua
MyPreview:SetPlayerName('CustomName')
```

#### 4. Update Health
```lua
MyPreview:SetHealth(75)  -- Sets health to 75%
MyPreview:SetHealth(100) -- Full health
MyPreview:SetHealth(25)  -- Low health
```

## 🔧 Integration Example

```lua
-- ESP Settings
local ESPSettings = {
    ShowBox = true,
    BoxColor = Color3.fromRGB(255, 0, 0),
    -- ... other settings
}

-- Create Preview
local Preview = ESPBox:AddESPPreview({
    Height = 220;
    Settings = ESPSettings;
})

-- Add color picker that updates preview
ColorBox:AddLabel('Box Color:'):AddColorPicker('BoxColor', {
    Default = ESPSettings.BoxColor,
    Callback = function(Value)
        ESPSettings.BoxColor = Value
        Preview:Update({BoxColor = Value})
    end
})

-- Add toggle that updates preview
ControlBox:AddToggle('ShowBox', {
    Text = 'Show Box',
    Default = true,
    Callback = function(Value)
        ESPSettings.ShowBox = Value
        Preview:Update({ShowBox = Value})
    end
})
```

## 📝 Settings Reference

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `ShowBox` | boolean | true | Show/hide player box outline |
| `ShowName` | boolean | true | Show/hide player name |
| `ShowDistance` | boolean | true | Show/hide distance label |
| `ShowHealth` | boolean | true | Show/hide health bar |
| `BoxColor` | Color3 | Red | Box outline color |
| `NameColor` | Color3 | White | Player name color |
| `HealthBarColor` | Color3 | Green | Health bar color |

## 🎨 Visual Structure

```
PreviewOuter (Black border)
└── PreviewInner (Background color)
    └── ContentFrame (Main color)
        ├── BoxTop (Player box outline)
        │   ├── HeadCircle (Head)
        │   ├── BodyRect (Body)
        │   ├── LeftLeg
        │   └── RightLeg
        ├── NameLabel (Above box)
        ├── DistanceLabel (Below box)
        └── HealthBar (Left side)
            ├── HealthBarBG (Background)
            ├── HealthBar (Fill)
            └── HealthText (Numeric)
```

## 🚀 Advantages

### Before (Manual Creation)
```lua
-- ❌ Manual instance creation
-- ❌ Complex positioning logic
-- ❌ Manual parent finding with spawn()
-- ❌ Inconsistent styling
-- ❌ Race conditions with toggle creation
local function CreateESPPreview(parentContainer)
    local PreviewFrame = Instance.new('Frame')
    PreviewFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    -- ... 200+ lines of manual creation
end

spawn(function()
    wait(0.3)
    -- Find container manually
    CreateESPPreview(container)
    wait(0.1)
    -- Add toggle after
end)
```

### After (Native Widget)
```lua
-- ✅ One-liner creation
-- ✅ Auto-styling with theme
-- ✅ No race conditions
-- ✅ Clean API
local Preview = PreviewBox:AddESPPreview({
    Height = 200;
    Settings = ESPSettings;
})
```

## 🔄 Migration Guide

### Old Code (main.lua before)
```lua
spawn(function()
    wait(0.3)
    local success, container = pcall(function()
        -- Manual container finding
    end)
    if success then
        CreateESPPreview(container)
    end
end)
```

### New Code (main.lua after)
```lua
-- Direct creation, no spawn needed
ESPPreviewFrame = ESPPreviewBox:AddESPPreview({
    Height = 200;
    PlayerName = game.Players.LocalPlayer.DisplayName;
    Settings = ESPSettings;
})
```

## 📦 Files Modified

1. **LinoriaLib.lua** - Added `Funcs:AddESPPreview(Info)` method (lines ~2827)
2. **main.lua** - Refactored to use native widget instead of manual creation
3. **esp-preview-example.lua** - Example file showing usage

## 🎯 Benefits

✅ **Cleaner Code**: 200+ lines → ~20 lines  
✅ **Consistent UI**: Auto-matches library theme  
✅ **No Bugs**: Eliminates race conditions  
✅ **Easy Updates**: Simple method calls  
✅ **Professional**: Native widget feel  

## 🔍 Example Project

Check `esp-preview-example.lua` for a complete working example with:
- ESP Preview creation
- Toggle controls
- Color pickers
- Real-time updates
- Method demonstrations

## 📚 See Also

- `main.lua` - Full hub implementation with ESP Preview
- `LinoriaLib.lua` - Library source code
- `esp-preview-example.lua` - Standalone example
