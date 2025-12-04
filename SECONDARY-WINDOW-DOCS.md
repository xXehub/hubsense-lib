# LinoriaLib - Secondary Window Feature

## 🪟 Overview

LinoriaLib sekarang support **Secondary Window** (child window) yang terpisah dari main window. Perfect untuk ESP Preview, player lists, debug console, atau panel tambahan yang bisa di-drag, minimize, dan resize.

## ✨ Features

- **Independent Window**: Separate draggable window dari main window
- **Minimize/Restore**: Built-in minimize button di title bar
- **Keyboard Shortcut**: Set custom key untuk minimize (default: End)
- **Resizable**: Optional resize functionality dengan min size
- **Theme Integration**: Auto-match dengan library theme
- **Clean API**: Simple methods untuk show/hide/toggle

## 🎯 Use Cases

Perfect untuk:
- 🎨 **ESP Preview** - Live preview ESP settings
- 👥 **Player Lists** - Detached player management
- 📊 **Stats Display** - Real-time game statistics
- 🐛 **Debug Console** - Separate debug output window
- 🎨 **Color Preview** - Live color/theme preview
- 📋 **Any detached panel** - General purpose secondary UI

## 🚀 Usage

### Basic Setup

```lua
local SecondaryWindow = Library:CreateSecondaryWindow({
    Title = 'My Secondary Window';
    Position = UDim2.fromOffset(680, 50);
    Size = UDim2.fromOffset(300, 400);
    Resizable = true;
    MinSize = Vector2.new(250, 300);
    MinimizeKey = 'End';
    AutoShow = true;
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Title` | string | 'Secondary Window' | Window title text |
| `Position` | UDim2 | `UDim2.fromOffset(750, 50)` | Initial position |
| `Size` | UDim2 | `UDim2.fromOffset(300, 400)` | Initial size |
| `Resizable` | boolean | false | Enable resize functionality |
| `MinSize` | Vector2 | `Vector2.new(250, 200)` | Minimum size when resizing |
| `MinimizeKey` | string/boolean | true | Key to minimize (e.g., 'End') |
| `AutoShow` | boolean | true | Show window on creation |

### Available Methods

#### 1. Show/Hide Window
```lua
SecondaryWindow:Show()    -- Show window
SecondaryWindow:Hide()    -- Hide window
SecondaryWindow:Toggle()  -- Toggle visibility
```

#### 2. Minimize/Restore
```lua
SecondaryWindow:Minimize()  -- Minimize to title bar only
SecondaryWindow:Restore()   -- Restore to full size
```

#### 3. Change Properties
```lua
-- Change title
SecondaryWindow:SetTitle('New Title')

-- Change position
SecondaryWindow:SetPosition(UDim2.fromOffset(100, 100))

-- Change size
SecondaryWindow:SetSize(UDim2.fromOffset(400, 500))
```

#### 4. Get Container
```lua
-- Get container to add content
local Container = SecondaryWindow:GetContainer()

-- Add content to container
local Label = Library:CreateLabel({
    Text = 'Hello!';
    Parent = Container;
})
```

### Properties

```lua
SecondaryWindow.Visible     -- boolean: Is window visible?
SecondaryWindow.Minimized   -- boolean: Is window minimized?
SecondaryWindow.Holder      -- Frame: Main window frame
SecondaryWindow.Container   -- Frame: Content container
```

## 📝 Complete Example

### ESP Preview in Secondary Window

```lua
local repo = 'https://raw.githubusercontent.com/xXehub/hubsense-lib/refs/heads/main/ondevs/'
local Library = loadstring(game:HttpGet(repo .. 'LinoriaLib.lua'))()

-- Main window
local Window = Library:CreateWindow({
    Title = 'Main Hub';
    Size = UDim2.fromOffset(550, 450);
})

-- Secondary window for ESP Preview
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(580, 50);
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

-- Get container
local Container = ESPWindow:GetContainer()

-- Add ESP preview content
local PreviewFrame = Library:Create('Frame', {
    BackgroundColor3 = Library.BackgroundColor;
    Size = UDim2.new(1, 0, 1, 0);
    Parent = Container;
})

-- Add player model preview, boxes, etc...
local PlayerBox = Library:Create('Frame', {
    BackgroundTransparency = 1;
    BorderColor3 = Color3.fromRGB(255, 0, 0);
    BorderSizePixel = 2;
    Position = UDim2.new(0.5, -32, 0.5, -50);
    Size = UDim2.new(0, 64, 0, 100);
    Parent = PreviewFrame;
})

-- Add controls in main window
local Tabs = {
    ESP = Window:AddTab('ESP')
}

local ControlBox = Tabs.ESP:AddLeftGroupbox('Preview Window')

ControlBox:AddButton({
    Text = 'Show Preview';
    Func = function()
        ESPWindow:Show()
    end
})

ControlBox:AddButton({
    Text = 'Hide Preview';
    Func = function()
        ESPWindow:Hide()
    end
})
```

### Player List in Secondary Window

```lua
local PlayerWindow = Library:CreateSecondaryWindow({
    Title = 'Player List';
    Position = UDim2.fromOffset(580, 50);
    Size = UDim2.fromOffset(250, 400);
    MinimizeKey = 'PageDown';
})

local Container = PlayerWindow:GetContainer()

-- Add scrolling frame for player list
local ScrollFrame = Library:Create('ScrollingFrame', {
    BackgroundColor3 = Library.BackgroundColor;
    Size = UDim2.new(1, 0, 1, 0);
    CanvasSize = UDim2.new(0, 0, 0, 0);
    ScrollBarThickness = 4;
    Parent = Container;
})

-- Auto-populate with players
for _, player in pairs(game.Players:GetPlayers()) do
    local PlayerLabel = Library:CreateLabel({
        Text = player.Name;
        Size = UDim2.new(1, -10, 0, 20);
        Parent = ScrollFrame;
    })
end
```

## 🎨 Visual Structure

```
SecondaryWindow
├── Outer (Black border, draggable)
│   └── Inner (Main color + accent border)
│       ├── TitleBar
│       │   ├── WindowLabel (Title text)
│       │   └── MinimizeButton ('_' / '+')
│       └── ContentOuter (Background color)
│           └── ContentInner
│               └── Container (Your content here)
```

## 🔧 Integration with Main Window

### Method 1: Control Buttons
```lua
local ControlBox = Tabs.Visual:AddRightGroupbox('ESP Preview')

ControlBox:AddButton({
    Text = 'Show Preview Window';
    Func = function()
        ESPWindow:Show()
    end
})
```

### Method 2: Toggle
```lua
ControlBox:AddToggle('ShowESPWindow', {
    Text = 'Show ESP Preview';
    Default = true;
    Callback = function(Value)
        if Value then
            ESPWindow:Show()
        else
            ESPWindow:Hide()
        end
    end
})
```

### Method 3: Keybind
```lua
-- Set custom minimize key
local ESPWindow = Library:CreateSecondaryWindow({
    MinimizeKey = 'End';  -- Press End to minimize
})

-- Or handle manually
Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
    if Input.KeyCode == Enum.KeyCode.F1 then
        ESPWindow:Toggle()
    end
end))
```

## 🚀 Advanced Usage

### Auto-Position Next to Main Window

```lua
local MainWindow = Library:CreateWindow({
    Position = UDim2.fromOffset(100, 50);
    Size = UDim2.fromOffset(550, 600);
})

-- Position secondary window to the right of main window
local SecondaryWindow = Library:CreateSecondaryWindow({
    Position = UDim2.fromOffset(
        100 + 550 + 10,  -- MainX + MainWidth + Gap
        50               -- Same Y as main
    );
    Size = UDim2.fromOffset(280, 600);  -- Same height
})
```

### Dynamic Content Updates

```lua
local Container = SecondaryWindow:GetContainer()

-- Create dynamic label
local StatusLabel = Library:CreateLabel({
    Text = 'Status: Idle';
    Parent = Container;
})

-- Update in real-time
game:GetService('RunService').Heartbeat:Connect(function()
    StatusLabel.Text = 'FPS: ' .. math.floor(1 / game:GetService('RunService').RenderStepped:Wait())
end)
```

### Multiple Secondary Windows

```lua
-- ESP Preview window
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(580, 50);
})

-- Player list window
local PlayerWindow = Library:CreateSecondaryWindow({
    Title = 'Players';
    Position = UDim2.fromOffset(880, 50);
})

-- Debug console window
local DebugWindow = Library:CreateSecondaryWindow({
    Title = 'Debug Console';
    Position = UDim2.fromOffset(580, 470);
})
```

## 🎯 Comparison: Before vs After

### Before (No Secondary Window)
```lua
-- ❌ ESP Preview crammed inside main window
-- ❌ Takes up valuable space in groupbox
-- ❌ Can't move independently
-- ❌ Can't minimize separately
local PreviewBox = Tabs.Visual:AddRightGroupbox('ESP Preview')
PreviewBox:AddESPPreview({
    Height = 200;  -- Limited height
})
```

### After (With Secondary Window)
```lua
-- ✅ Separate draggable window
-- ✅ Can be positioned anywhere
-- ✅ Resizable to any size
-- ✅ Independent minimize/restore
-- ✅ Doesn't take main window space
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
})
```

## 📦 Files Modified

1. **LinoriaLib.lua** - Added `Library:CreateSecondaryWindow(Config)` method
2. **main.lua** - Refactored ESP Preview to use secondary window
3. **secondary-window-example.lua** - Complete working example

## 💡 Tips & Best Practices

1. **Positioning**: Position secondary window to the right/left of main window with ~10px gap
2. **Size**: Keep reasonable size (250-400px wide, 300-600px tall)
3. **Minimize Key**: Use keys like End, PageDown, Home for minimize shortcuts
4. **Resizable**: Enable for windows that benefit from dynamic sizing (previews, lists)
5. **AutoShow**: Set false if you want user to manually open window
6. **Title**: Use clear, descriptive titles ('ESP Preview', 'Player List', etc.)

## 🐛 Troubleshooting

### Window not showing?
```lua
-- Check if AutoShow is true
SecondaryWindow:Show()  -- Manually show

-- Check position (might be off-screen)
SecondaryWindow:SetPosition(UDim2.fromOffset(100, 100))
```

### Content not appearing?
```lua
-- Make sure you're adding to Container, not Holder
local Container = SecondaryWindow:GetContainer()  -- ✅ Correct
local Frame = SecondaryWindow.Holder             -- ❌ Wrong

-- Add content
YourElement.Parent = Container  -- ✅
```

### Can't resize?
```lua
-- Enable resizable in config
local Window = Library:CreateSecondaryWindow({
    Resizable = true;        -- ✅ Enable
    MinSize = Vector2.new(250, 300);
})
```

## 📚 See Also

- `secondary-window-example.lua` - Complete standalone example
- `main.lua` - ESP Preview implementation using secondary window
- `LinoriaLib.lua` - Library source code

## 🎉 Benefits

✅ **Clean UI**: Main window stays uncluttered  
✅ **Flexible**: Position anywhere on screen  
✅ **Independent**: Minimize/hide separately  
✅ **Resizable**: Adjust size to your needs  
✅ **Professional**: Native window look & feel  
✅ **Easy to Use**: Simple API, 5 lines of code  
