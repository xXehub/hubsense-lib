# 📌 Sticky Mode - Secondary Window Update

## 🎯 What's New?

Secondary window sekarang punya **Sticky Mode** - otomatis follow parent window kemana pun di-drag! Window anak akan selalu stay di samping parent dengan jarak tetap.

## ✨ Sticky Mode Features

### Before (Independent Mode)
```
┌──────────────┐          ┌──────────────┐
│ Main Window  │          │ ESP Preview  │
│              │          │              │
└──────────────┘          └──────────────┘
     ↕️ Drag                    ↕️ Drag
  (Independent)            (Independent)
```

### After (Sticky Mode)
```
┌──────────────┐  📌  ┌──────────────┐
│ Main Window  │─────→│ ESP Preview  │
│              │      │              │
└──────────────┘      └──────────────┘
     ↕️ Drag both windows move together!
  (Parent controls child position)
```

## 🔧 Configuration

### Sticky Mode (Default)
```lua
local SecondaryWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    ParentWindow = Window;           -- ✅ Set parent window
    StickyMode = true;               -- ✅ Enable sticky (default)
    OffsetFromParent = Vector2.new(10, 0);  -- Gap: 10px right, 0px down
    Size = UDim2.fromOffset(280, 350);
})
```

### Independent Mode (Optional)
```lua
local SecondaryWindow = Library:CreateSecondaryWindow({
    Title = 'Debug Window';
    ParentWindow = Window;
    StickyMode = false;              -- ❌ Disable sticky
    Position = UDim2.fromOffset(100, 500);  -- Manual position
    Size = UDim2.fromOffset(400, 200);
})
-- Window can be dragged independently
```

## 📐 Offset Options

### Right Side (Default)
```lua
OffsetFromParent = Vector2.new(10, 0)  -- 10px gap on right

Main Window [660px]  →  [10px gap]  →  ESP Preview
```

### Left Side
```lua
OffsetFromParent = Vector2.new(-290, 0)  -- Negative offset = left side

ESP Preview  ←  [10px gap]  ←  Main Window
```

### Below Parent
```lua
OffsetFromParent = Vector2.new(0, 10)  -- Below with 10px gap

┌──────────────┐
│ Main Window  │
└──────────────┘
    [10px gap]
┌──────────────┐
│ ESP Preview  │
└──────────────┘
```

### Custom Position
```lua
OffsetFromParent = Vector2.new(50, 100)  -- 50px right, 100px down
```

## 🎮 Behavior

### Sticky Mode = true
- ❌ **Cannot drag** secondary window independently
- ✅ **Auto-follows** parent window position
- ✅ **Maintains offset** distance always
- ✅ **Updates** when parent resizes
- ✅ **Perfect sync** with parent movement

### Sticky Mode = false
- ✅ **Can drag** secondary window freely
- ❌ **Does NOT follow** parent
- ✅ **Independent** positioning
- ⚠️ **Manual** position management needed

## 💻 Real Implementation

### main.lua Example
```lua
-- Create main window
local Window = Library:CreateWindow({
    Title = 'hubsense | sakkarepmu';
    Center = true;
    Size = UDim2.fromOffset(660, 560);
})

-- Create sticky secondary window
local SecondaryWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    ParentWindow = Window;              -- Link to parent
    StickyMode = true;                  -- Enable sticky
    OffsetFromParent = Vector2.new(10, 0);  -- 10px right
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

-- ESP Preview now follows main window everywhere! 📌
```

## 🔄 How It Works

### Position Calculation
```lua
-- Secondary window position = Parent position + Parent width + Offset
SecondaryWindow.X = Parent.X + Parent.Width + Offset.X
SecondaryWindow.Y = Parent.Y + Offset.Y

-- Example with real values:
-- Parent at (100, 50) with width 660px
-- Offset = (10, 0)
-- Result: Secondary at (770, 50)
```

### Auto-Update Connections
```lua
-- Listens to parent changes
ParentHolder:GetPropertyChangedSignal('Position'):Connect(UpdatePosition)
ParentHolder:GetPropertyChangedSignal('Size'):Connect(UpdatePosition)

-- Every time parent moves or resizes → secondary updates automatically!
```

## 📊 Comparison

| Feature | Sticky Mode | Independent Mode |
|---------|-------------|------------------|
| **Draggable** | ❌ No | ✅ Yes |
| **Follows Parent** | ✅ Yes | ❌ No |
| **Offset Maintained** | ✅ Yes | ❌ Manual |
| **Auto-Position** | ✅ Yes | ❌ Manual |
| **Use Case** | ESP Preview, Stats | Debug Console, Logs |

## 🎯 Use Cases

### Perfect for Sticky Mode:
1. **ESP Preview** - Always visible next to controls
2. **Color Preview** - Live preview while adjusting
3. **Player Info** - Quick glance info panel
4. **Stats Display** - Real-time stats next to main UI
5. **Settings Preview** - See changes live

### Better for Independent Mode:
1. **Debug Console** - Movable to any screen area
2. **Log Window** - Position freely for monitoring
3. **Inventory** - Drag to second monitor
4. **Multi-tool Panels** - Flexible positioning

## ⚙️ Advanced Configuration

### Multiple Sticky Windows
```lua
-- ESP Preview on right
local ESPWindow = Library:CreateSecondaryWindow({
    ParentWindow = Window;
    OffsetFromParent = Vector2.new(10, 0);  -- Right
})

-- Stats on left
local StatsWindow = Library:CreateSecondaryWindow({
    ParentWindow = Window;
    OffsetFromParent = Vector2.new(-310, 0);  -- Left
})

-- Debug below
local DebugWindow = Library:CreateSecondaryWindow({
    ParentWindow = Window;
    OffsetFromParent = Vector2.new(0, 570);  -- Below
})
```

### Dynamic Offset Change
```lua
-- Change offset at runtime
function SecondaryWindow:SetOffset(NewOffset)
    self.OffsetFromParent = NewOffset;
    if self.UpdatePosition then
        self:UpdatePosition();
    end;
end;

-- Usage
SecondaryWindow:SetOffset(Vector2.new(50, 0))  -- Move further right
```

## 🎨 Visual Guide

### Sticky Mode Layout
```
┌─────────────────────────────────┐    ┌──────────────────┐
│ hubsense | Main Window          │ 📌 │ ESP Preview  [_] │
├─────────────────────────────────┤    ├──────────────────┤
│ Main │ Visual │ Configuration   │    │                  │
├─────────────────────────────────┤    │   [ESP Model]    │
│                                 │    │                  │
│  ┌────────────┐ ┌─────────────┐│    │   Name: Player   │
│  │Word Search │ │ESP Settings ││    │   HP: 75         │
│  └────────────┘ └─────────────┘│    │                  │
│                                 │    │   < Weapon >     │
└─────────────────────────────────┘    └──────────────────┘
         ↕️ Drag here                          ↕️ Follows
    [660px wide]     [10px gap]        [280px wide]
```

### Drag Behavior
```
Before Drag:
Main(100, 50) → ESP(770, 50)

After Dragging Main to (300, 100):
Main(300, 100) → ESP(970, 100)  ← Auto-updated!

Offset maintained: 10px gap always
```

## 🐛 Troubleshooting

### Secondary window not following?
```lua
-- Check if StickyMode is enabled
if SecondaryWindow.StickyMode then
    print('Sticky mode is ON')
else
    print('Sticky mode is OFF')
end

-- Manually update position
if SecondaryWindow.UpdatePosition then
    SecondaryWindow:UpdatePosition()
end
```

### Wrong position?
```lua
-- Check offset
print(SecondaryWindow.OffsetFromParent)

-- Adjust offset
SecondaryWindow:SetOffset(Vector2.new(20, 0))  -- Increase gap
```

### Want to disable sticky temporarily?
```lua
-- Not recommended, but possible by removing connections
-- Better to use StickyMode = false from start
```

## ✨ Benefits

| Before | After |
|--------|-------|
| Manual positioning | ✅ Auto-positioning |
| Windows drift apart | ✅ Always aligned |
| Drag both separately | ✅ Drag once, both move |
| Complex positioning logic | ✅ Simple offset config |
| Hard to maintain layout | ✅ Perfect layout always |

## 🎓 Key Takeaways

1. **Sticky Mode = true** (Default) - Secondary follows parent automatically
2. **OffsetFromParent** - Controls gap between windows
3. **Not Draggable** when sticky - Prevents drift from parent
4. **Auto-Updates** - Position syncs on parent move/resize
5. **Perfect for ESP Preview** - Always visible, never lost

---

**Now your secondary windows stick perfectly to the main window! 📌🚀**
