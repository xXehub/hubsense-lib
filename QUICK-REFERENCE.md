# 🪟 Secondary Window Feature - Quick Reference

## 🎯 Before vs After

### BEFORE: Single Window
```
┌──────────────────────────────────────────────┐
│ hubsense | Main Window            [_][□][×] │
├──────────────────────────────────────────────┤
│ Main  │ Visual  │ Configuration              │
├──────────────────────────────────────────────┤
│                                              │
│ ┌─────────────┐  ┌──────────────────────┐   │
│ │ Word Search │  │ ESP Preview          │   │
│ │             │  │ ┌────────────────┐   │   │
│ │ Search: ___ │  │ │                │   │   │
│ │             │  │ │   [Player]     │   │   │
│ │ Results:    │  │ │   75 HP        │   │   │
│ │ 1. cat      │  │ │                │   │   │
│ │ 2. dog      │  │ └────────────────┘   │   │
│ └─────────────┘  │ Limited height 200px │   │
│                  └──────────────────────┘   │
│ ┌─────────────┐  ┌──────────────────────┐   │
│ │ ESP Settings│  │ ESP Colors           │   │
│ │ ☑ Show Box  │  │ Box: [Red]           │   │
│ │ ☑ Show Name │  │ Name: [White]        │   │
│ └─────────────┘  └──────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
        ❌ Preview crammed inside
        ❌ Limited space (200px max)
        ❌ Cluttered main window
```

### AFTER: Multi-Window
```
┌──────────────────────────────────┐  ┌────────────────────────┐
│ hubsense | Main Window  [_][□][×]│  │ ESP Preview        [_] │
├──────────────────────────────────┤  ├────────────────────────┤
│ Main  │ Visual  │ Configuration  │  │                        │
├──────────────────────────────────┤  │     ┌──────────┐       │
│                                  │  │     │          │       │
│ ┌──────────────┐ ┌─────────────┐│  │     │          │       │
│ │ Word Search  │ │ESP Preview  ││  │     │  [Player]│       │
│ │              │ │Window       ││  │     │          │       │
│ │ Search: ____ │ │             ││  │     │   Name   │       │
│ │              │ │ [Show]      ││  │     │          │       │
│ │ Results:     │ │ [Hide]      ││  │  75 │          │       │
│ │ 1. cat       │ │             ││  │ HP  │          │       │
│ │ 2. dog       │ │ Press [End] ││  │     │          │       │
│ │ 3. test      │ │ to minimize ││  │     │  Weapon  │       │
│ └──────────────┘ └─────────────┘│  │     └──────────┘       │
│                                  │  │                        │
│ ┌──────────────┐ ┌─────────────┐│  │ Resizable • Draggable  │
│ │ ESP Settings │ │ ESP Colors  ││  └────────────────────────┘
│ │ ☑ Show Box   │ │ Box: [Red]  ││         ↑ Independent
│ │ ☑ Show Name  │ │Name: [White]││         ↑ Any size
│ └──────────────┘ └─────────────┘│         ↑ Minimize with [End]
└──────────────────────────────────┘
    ✅ Clean main window
    ✅ Independent preview window
    ✅ Resizable to any size
    ✅ Drag anywhere
```

## 🚀 Quick Usage

```lua
-- Create secondary window (5 lines!)
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Size = UDim2.fromOffset(280, 350);
    Resizable = true;
    MinimizeKey = 'End';
})

-- Get container and add content
local Container = ESPWindow:GetContainer()
YourFrame.Parent = Container

-- Control it
ESPWindow:Show()      -- Show
ESPWindow:Hide()      -- Hide
ESPWindow:Minimize()  -- Minimize
```

## 📋 Methods Cheat Sheet

| Method | Description |
|--------|-------------|
| `:Show()` | Show window |
| `:Hide()` | Hide window |
| `:Toggle()` | Toggle visibility |
| `:Minimize()` | Minimize to title bar |
| `:Restore()` | Restore from minimized |
| `:SetTitle(text)` | Change window title |
| `:SetPosition(UDim2)` | Move window |
| `:SetSize(UDim2)` | Resize window |
| `:GetContainer()` | Get content container |

## 🎯 Common Patterns

### Pattern 1: ESP Preview
```lua
local ESPWindow = Library:CreateSecondaryWindow({
    Title = 'ESP Preview';
    Position = UDim2.fromOffset(680, 50);
    Size = UDim2.fromOffset(280, 350);
})
```

### Pattern 2: Player List
```lua
local PlayerWindow = Library:CreateSecondaryWindow({
    Title = 'Players';
    Position = UDim2.fromOffset(680, 50);
    Size = UDim2.fromOffset(250, 400);
    MinimizeKey = 'PageDown';
})
```

### Pattern 3: Debug Console
```lua
local DebugWindow = Library:CreateSecondaryWindow({
    Title = 'Debug Console';
    Position = UDim2.fromOffset(100, 500);
    Size = UDim2.fromOffset(500, 200);
    Resizable = true;
})
```

## 🎨 Window States

### Normal State
```
┌─────────────────────────┐
│ Title              [_] │  ← Click to minimize
├─────────────────────────┤
│                         │
│     Your Content        │
│                         │
└─────────────────────────┘
```

### Minimized State
```
┌─────────────────────────┐
│ Title              [+] │  ← Click to restore
└─────────────────────────┘
```

### Hidden State
```
(Window completely hidden)
Press keybind or call :Show() to display
```

## 📦 Files Reference

| File | Purpose |
|------|---------|
| `LinoriaLib.lua` | Core library with CreateSecondaryWindow() |
| `main.lua` | Real implementation (ESP Preview) |
| `secondary-window-example.lua` | Standalone example |
| `SECONDARY-WINDOW-DOCS.md` | Full documentation |
| `UPDATE-SUMMARY.md` | Complete feature overview |

## 💡 Pro Tips

1. **Positioning**: Place secondary window 10px to the right of main window
2. **Size**: Keep between 250-400px wide for best UX
3. **Minimize Key**: Use End, PageDown, Home for easy access
4. **Resizable**: Enable for windows with dynamic content
5. **Title**: Use clear, descriptive titles

## ⚡ Performance

- Lightweight: ~220 lines of code
- No impact on main window
- Efficient dragging/resizing
- Theme-integrated (auto-updates)

## 🎓 Learn More

- 📚 **SECONDARY-WINDOW-DOCS.md** - Full documentation
- 💻 **secondary-window-example.lua** - Complete working example
- 🔍 **main.lua** - Real-world implementation

---

**Ready to use! Just update your LinoriaLib and start creating secondary windows! 🚀**
