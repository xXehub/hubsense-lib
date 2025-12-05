# 🪟 LinoriaLib Update Summary - Secondary Window Feature

## 📦 What's New?

LinoriaLib sekarang support **Secondary Window** - independent child window yang bisa dipisah dari main window! Perfect untuk ESP Preview, player lists, debug console, dan panel tambahan.

## 🎯 Implementation Overview

```
┌─────────────────────────┐         ┌─────────────────────┐
│   Main Window (Hub)     │         │  Secondary Window   │
│  ┌───────────────────┐  │         │  ┌───────────────┐  │
│  │ Word Search      │  │         │  │ ESP Preview   │  │
│  │ - Search Input   │  │  ◄────► │  │ - Player Box  │  │
│  │ - Results Table  │  │         │  │ - Name Label  │  │
│  └───────────────────┘  │         │  │ - Health Bar  │  │
│  ┌───────────────────┐  │         │  └───────────────┘  │
│  │ ESP Settings     │  │         │  [Minimize] [_]     │
│  │ - Show Box       │  │         └─────────────────────┘
│  │ - Show Name      │  │              ↑ Draggable
│  │ - Colors         │  │              ↑ Resizable
│  └───────────────────┘  │              ↑ Minimize/Restore
│  ┌───────────────────┐  │
│  │ Preview Controls │  │
│  │ - Show Window    │  │
│  │ - Hide Window    │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

## ✨ Key Features

### 1. **Independent Window**
- Separate dari main window
- Bisa di-drag ke mana aja
- Tidak blocking main window

### 2. **Minimize/Restore**
```lua
-- Built-in minimize button di title bar
[_]  ← Click to minimize
[+]  ← Click to restore

-- Atau pakai keyboard
Press [End] → Toggle minimize/restore
```

### 3. **Resizable (Optional)**
```lua
Resizable = true;
MinSize = Vector2.new(250, 300);
```

### 4. **Easy API**
```lua
local Window = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(680, 50);
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

Window:Show()      -- Show window
Window:Hide()      -- Hide window
Window:Toggle()    -- Toggle visibility
Window:Minimize()  -- Minimize
Window:Restore()   -- Restore
```

## 🔄 Changes Made

### 1. **LinoriaLib.lua**
```diff
+ Added: Library:CreateSecondaryWindow(Config)
+ Features:
  - Draggable window with title bar
  - Minimize button with icon
  - Resizable support (optional)
  - Keyboard shortcut for minimize
  - Theme integration
  - Clean API methods
  
+ Methods:
  - :Show() / :Hide() / :Toggle()
  - :Minimize() / :Restore()
  - :SetTitle(text)
  - :SetPosition(UDim2)
  - :SetSize(UDim2)
  - :GetContainer()
```

### 2. **main.lua**
```diff
- Removed: ESP Preview inside main window groupbox
+ Added: Secondary window for ESP Preview
+ Features:
  - Separate draggable window
  - Press [End] to minimize
  - Resizable (250x300 minimum)
  - Show/Hide controls in main window
  - Full ESP preview with player model
```

### 3. **New Files**
```
✨ secondary-window-example.lua
   - Complete standalone example
   - All methods demonstrated
   - Position/size controls
   - Info and use cases

📚 SECONDARY-WINDOW-DOCS.md
   - Full documentation
   - API reference
   - Examples and tips
   - Troubleshooting guide
```

## 📊 Comparison

### Before: ESP Preview in Main Window
```
❌ Takes up space in groupbox
❌ Limited height (200px max)
❌ Can't move independently
❌ Can't minimize separately
❌ Clutters main window
```

### After: ESP Preview in Secondary Window
```
✅ Separate independent window
✅ Any size (resizable)
✅ Drag anywhere on screen
✅ Minimize with [End] key
✅ Main window stays clean
✅ Professional multi-window UI
```

## 🎨 Visual Design

### Secondary Window Structure
```
┌─────────────────────────────┐
│ Title Bar                [_]│  ← Minimize button
├─────────────────────────────┤
│                             │
│  Content Container          │  ← Your content here
│                             │
│  • Player model             │
│  • ESP boxes                │
│  • Labels                   │
│  • Any UI elements          │
│                             │
└─────────────────────────────┘
     ↑ Draggable by title bar
```

### Minimized State
```
┌─────────────────────────────┐
│ Title Bar                [+]│  ← Restore button
└─────────────────────────────┘
    ↑ Only title bar visible
```

## 💻 Usage Example

### Basic Setup
```lua
-- Create secondary window
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(680, 50);
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

-- Get container
local Container = ESPWindow:GetContainer()

-- Add your content
local PreviewFrame = Library:Create('Frame', {
    Size = UDim2.new(1, 0, 1, 0);
    Parent = Container;
})

-- Control from main window
ControlBox:AddButton({
    Text = 'Show ESP Preview';
    Func = function()
        ESPWindow:Show()
    end
})
```

### Advanced: Multiple Windows
```lua
-- ESP Preview
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(580, 50);
})

-- Player List
local PlayerWindow = Library:CreateSecondaryWindow({
    Title = 'Player List';
    Position = UDim2.fromOffset(880, 50);
})

-- Debug Console
local DebugWindow = Library:CreateSecondaryWindow({
    Title = 'Debug';
    Position = UDim2.fromOffset(580, 470);
})
```

## 🎯 Use Cases

### Perfect For:
1. **ESP Preview** - Live ESP settings preview
2. **Player Lists** - Scrollable player management
3. **Debug Console** - Real-time logs and output
4. **Stats Display** - Live game statistics
5. **Color Preview** - Theme/color picker preview
6. **Inventory Display** - Item lists and management
7. **Any detached panel** - General purpose UI

## 🚀 Benefits

| Feature | Benefit |
|---------|---------|
| **Independent** | Doesn't clutter main window |
| **Draggable** | Position anywhere on screen |
| **Minimizable** | Save screen space |
| **Resizable** | Adjust to your needs |
| **Keyboard Shortcut** | Quick access (End key) |
| **Theme Integration** | Auto-matches UI theme |
| **Clean API** | Easy to implement |
| **Professional** | Multi-window desktop-like UI |

## 📝 Code Stats

### LinoriaLib.lua
```
+ Added: ~220 lines
+ Method: CreateSecondaryWindow()
+ Features: 9 public methods
+ Integration: Seamless with existing code
```

### main.lua
```
+ Added: ~180 lines (ESP Preview in secondary window)
- Removed: ~50 lines (old integrated preview)
+ Result: Cleaner, more professional UI
```

## 🎓 Learning Resources

1. **SECONDARY-WINDOW-DOCS.md** - Complete documentation
2. **secondary-window-example.lua** - Standalone working example
3. **main.lua** - Real-world implementation (ESP Preview)

## 🔥 Quick Start

```lua
-- 1. Load library
local Library = loadstring(game:HttpGet(repo .. 'LinoriaLib.lua'))()

-- 2. Create main window
local Window = Library:CreateWindow({
    Title = 'Main Hub';
    Size = UDim2.fromOffset(550, 450);
})

-- 3. Create secondary window
local SecondaryWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(580, 50);
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

-- 4. Add content
local Container = SecondaryWindow:GetContainer()
-- Add your UI elements to Container

-- 5. Done! 🎉
```

## 📦 Files Summary

```
Updated Files:
├── LinoriaLib.lua              [+220 lines] ← CreateSecondaryWindow()
├── main.lua                    [+130 lines] ← ESP Preview implementation
│
New Files:
├── secondary-window-example.lua             ← Complete example
├── SECONDARY-WINDOW-DOCS.md                 ← Full documentation
└── (This file)                              ← Summary & overview
```

## 🎉 Result

Sekarang LinoriaLib punya **full multi-window support**! 

✅ Main window untuk controls  
✅ Secondary window untuk preview/lists  
✅ Draggable, resizable, minimizable  
✅ Clean, professional, desktop-like UI  
✅ Easy API, 5 lines of code  

**Perfect for modern hub UIs!** 🚀

---

## 🙏 Credits

- **LinoriaLib** - Original UI library
- **hubsense** - Word Suggester Hub implementation
- **ESP Preview** - Real-world use case demonstration

---

Made with ❤️ for better Roblox UI development
