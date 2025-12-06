# Last Letter Game - Script Documentation

## 📋 Game Structure (Discovered via Debugging)

### Workspace Structure
```
Workspace
└── Tables/
    ├── 1 (Model)
    ├── 2 (Model)
    ├── ... (up to 16 tables)
    └── 16 (Model)
        ├── [BasePart] - Physical table/seats (NOT Seat class!)
        ├── Prompt (Part)
        │   ├── ProximityPrompt (ActionText: "Join", KeyboardKey: "E")
        │   └── BillboardGui
        │       ├── NbOfPlayers (TextLabel) - e.g., "2/4", "1/2"
        │       ├── Starting (TextLabel) - e.g., "Waiting for 1 player...", "APPLE"
        │       └── CurrentWord (TextLabel) - "Current word:"
        └── Billboard (Part)
            └── BillboardGui
                └── (Same structure as above)
```

### PlayerGui Structure
```
PlayerGui
├── PreGame/                          ← APPEARS WHEN AT TABLE (waiting)
│   └── Frame (Visible: true)
│       ├── Leave (TextButton)        ← LEAVE BUTTON!
│       ├── Invite (TextButton)
│       └── [Other elements]
├── InGame/                           ← APPEARS WHEN GAME ACTIVE
│   └── Frame (Visible when playing)
│       ├── CurrentWord/
│       │   ├── 1/ → Letter (TextLabel)
│       │   └── ...
│       ├── Choices/
│       │   ├── 1 (TextButton)
│       │   ├── 2 (TextButton)
│       │   ├── 3 (TextButton)
│       │   └── 4 (TextButton)
│       ├── Tries (Frame)
│       ├── Circle (Frame)
│       └── Timer (TextLabel)
├── Notification/
│   └── Frame/TextLabel
├── DisplayMatch/
│   └── Frame/Matches/
└── Play/
    └── Frame/Title = "Gamemodes"
```

---

## 🎯 KEY DISCOVERIES

### Detecting "At Table" State
**IMPORTANT:** `Humanoid.Sit` = `false` even when seated! Game uses different system.

**Correct way to detect:**
```lua
-- Check if PreGame GUI exists and Frame is visible
local function isAtTable()
    local preGame = PlayerGui:FindFirstChild("PreGame")
    if preGame then
        local frame = preGame:FindFirstChild("Frame")
        return frame and frame.Visible
    end
    return false
end
```

### Leave Button Path
```
PlayerGui.PreGame.Frame.Leave (TextButton)
```

### Clicking Leave Button
```lua
local leave = PlayerGui.PreGame.Frame.Leave
firesignal(leave, "MouseButton1Click")
-- or
firesignal(leave, "Activated")
```

### Seat Detection
- ❌ `Humanoid.Sit` - Always false (game doesn't use standard Roblox seats)
- ❌ `Humanoid.SeatPart` - Always nil
- ❌ `Seat` class - None exist (Total seats found: 0)
- ✅ `PreGame GUI visible` - Correct way to detect!

---

## 🎮 Game Flow

### Table States
| State | NbOfPlayers | Starting | Meaning |
|-------|-------------|----------|---------|
| Empty | "0/4" | "Waiting for 4 players..." | No players, waiting |
| Filling | "2/4" | "Waiting for 2 players..." | Has players, waiting for more |
| Full (waiting) | "4/4" | "Waiting..." | Full, about to start |
| In Game | "4/4" | "APPLE" (word) | Game running |

### Join Detection
- **Waiting for players**: `Starting:lower():find("waiting")` = true
- **Game started**: `Starting` shows a word (e.g., "APPLE", "ZEBRA")
- **Full table**: `current >= max` from "X/Y" pattern

---

## 🔧 Auto Join Functions

### `GetAvailableTable()`
Scans all tables and returns the best one to join.

**Logic:**
1. Loop through `Workspace.Tables` children
2. For each table (Model):
   - Find `BillboardGui` → get `NbOfPlayers` and `Starting` labels
   - Find `ProximityPrompt` for joining
   - Find `BasePart` for teleport target
3. Filter criteria:
   - ✅ `current < max` (not full)
   - ✅ `Starting:lower():find("waiting")` (game not started)
   - ❌ Skip full tables
   - ❌ Skip tables with game in progress
4. Sort by player count (highest first)
5. Random pick from tables with same player count

**Returns:**
```lua
{
    Table = Model,           -- The table Model
    Prompt = ProximityPrompt,-- For triggering join
    SeatPart = BasePart,     -- For teleport target
    Players = "2/4",         -- Player count string
    Status = "Waiting...",   -- Starting label text
    CurrentPlayers = 2,      -- Number of current players
    MaxPlayers = 4           -- Max players allowed
}
```

### `TeleportToTable(tableInfo)`
Teleports player near the table.

**Logic:**
1. Get player's HumanoidRootPart
2. Find target part (SeatPart or any BasePart in table)
3. Teleport to `targetPart.CFrame * CFrame.new(0, 3, -2)`

### `TriggerProximityPrompt(prompt)`
Fires the ProximityPrompt to join table.

**Methods (in order):**
1. `fireproximityprompt(prompt)` - Executor function (most reliable)
2. `prompt:Fire()` - Direct fire (some executors)
3. `prompt:InputHoldBegin/End()` - Manual trigger (requires being near)

### `JoinTable(tableInfo)`
Complete join process.

**Steps:**
1. Call `TeleportToTable()` - Move player near table
2. `task.wait(0.3)` - Wait for teleport
3. Call `TriggerProximityPrompt()` - Trigger join

### `StartAutoJoin()`
Main auto-join loop.

**Logic:**
```
while AutoJoinEnabled:
    if InGame.Frame.Visible:
        skip (already playing)
    
    if IsAtTable():  -- Uses PreGame GUI check
        currentTable = GetCurrentTableInfo()
        if currentTable.CurrentPlayers <= 1:
            -- ALONE at table!
            betterTable = GetAvailableTable(minPlayers=2)
            if betterTable:
                LeaveTable()  -- Click Leave button
                JoinTable(betterTable)
            else:
                stay (no better option)
        else:
            stay (table has other players)
    else:
        -- Not at table, find one to join
        tableInfo = GetAvailableTable(minPlayers=2)
        if not tableInfo:
            tableInfo = GetAvailableTable(minPlayers=1)  -- Fallback
        if tableInfo:
            JoinTable(tableInfo)
    
    wait(AutoJoinDelay)
```

### `LeaveTable()`
Clicks the Leave button to exit current table.

**Methods tried (in order):**
1. `getconnections(button.MouseButton1Click)` + Fire - Most reliable for exploits
2. `getconnections(button.Activated)` + Fire
3. `firesignal(button, "MouseButton1Click")`
4. `firesignal(button, "Activated")`
5. `fireclick(button)`
6. `VirtualInputManager:SendMouseButtonEvent()` - Synthesize mouse click
7. `mouse1click()` + `mousemoveabs()` - Cursor simulation
8. `InputBegan/InputEnded` events

---

## 🎯 Key Discoveries

### ProximityPrompt Path
```
Workspace.Tables.[1-16].[Part].ProximityPrompt
```
- ActionText: "Join"
- KeyboardKeyCode: E
- Requires player to be within range OR use `fireproximityprompt()`

### BillboardGui Labels
```lua
-- Get player count
local nbPlayers = billboardGui:FindFirstChild("NbOfPlayers", true)
-- Returns: "2/4", "0/2", "4/4"

-- Get game status
local starting = billboardGui:FindFirstChild("Starting", true)
-- Returns: "Waiting for X player(s)..." OR current word like "APPLE"
```

### Game State Detection
```lua
-- Check if in active game
local inGame = PlayerGui:FindFirstChild("InGame")
local isPlaying = inGame and inGame.Frame and inGame.Frame.Visible

-- Check if seated at table
local isSeated = Humanoid and Humanoid.Sit
```

---

## 📝 UI Controls (in Main > Game Features)

| Control | Type | Description |
|---------|------|-------------|
| Auto Join Game | Toggle | Enable/disable auto join loop |
| Scan Delay | Slider (0.5-5s) | Time between scans |
| Scan Tables Now | Button | Manual scan, shows debug info |
| Join Available Table | Button | Instant teleport + join |
| Status Label | Label | Shows current state |

---

## 🐛 Common Issues & Solutions

### Issue: Always joins same table
**Cause:** First match returned, no randomization
**Solution:** Collect all available tables, sort by player count, random pick from best

### Issue: Joins full/started tables
**Cause:** Only checking player count, not game state
**Solution:** Also check if `Starting` contains "waiting"

### Issue: ProximityPrompt not triggering
**Cause:** Player too far from table
**Solution:** Teleport to table first, then trigger prompt

### Issue: Script spam loops
**Cause:** `continue` keyword not compatible with some Lua versions
**Solution:** Use `shouldSkip` flag pattern instead

---

## 🔗 Remote Events (for future reference)

```
ReplicatedStorage.Modules.Packet.RemoteEvent
```
- Uses buffer-based packet system
- Not needed for basic auto-join (ProximityPrompt is sufficient)

---

## 📊 Debug Output Examples

```
[Auto Join Debug] Available: 5 (3/4) - Waiting for 1 player...
[Auto Join Debug] Available: 12 (3/4) - Waiting for 1 player...
[Auto Join Debug] Skipped 9 - FULL (4/4)
[Auto Join Debug] Skipped 3 - Game started (APPLE)
[Auto Join] Selected: 12 (3/4) from 2 best tables
[Auto Join] Teleported to: 12
[Auto Join Debug] Using fireproximityprompt
[Auto Join] Successfully joined: 12
```
