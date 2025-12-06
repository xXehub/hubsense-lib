-- Debug Script for Last Letter Game
-- Focus: Finding Leave button and detecting seated state

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

print("=== LAST LETTER DEBUG v2 ===")

--[[
    DISCOVERED INFO:
    - Leave Button: PlayerGui.PreGame.Frame.Leave
    - Humanoid.Sit = false even when seated (game uses different system)
    - No Seat class instances (seats are regular parts)
    - PreGame GUI appears when at table
]]

-- Check if player is at a table by checking PreGame GUI
local function isAtTable()
    local preGame = PlayerGui:FindFirstChild("PreGame")
    if preGame then
        local frame = preGame:FindFirstChild("Frame")
        if frame and frame.Visible then
            return true, preGame
        end
    end
    return false, nil
end

-- Get Leave button from PreGame GUI
local function getLeaveButton()
    local preGame = PlayerGui:FindFirstChild("PreGame")
    if preGame then
        local frame = preGame:FindFirstChild("Frame")
        if frame then
            local leave = frame:FindFirstChild("Leave")
            if leave then
                return leave
            end
        end
    end
    return nil
end

-- Scan PreGame GUI structure
local function scanPreGameGUI()
    print("\n[SCANNING] PreGame GUI...")
    
    local preGame = PlayerGui:FindFirstChild("PreGame")
    if not preGame then
        print("  PreGame GUI not found (not at table)")
        return
    end
    
    print("  [FOUND] PreGame GUI!")
    
    for _, desc in ipairs(preGame:GetDescendants()) do
        if desc:IsA("TextButton") then
            print("  [BUTTON] " .. desc.Name .. " = '" .. desc.Text .. "' (Visible: " .. tostring(desc.Visible) .. ")")
        elseif desc:IsA("Frame") then
            print("  [FRAME] " .. desc.Name .. " (Visible: " .. tostring(desc.Visible) .. ")")
        elseif desc:IsA("TextLabel") and desc.Text ~= "" then
            print("  [LABEL] " .. desc.Name .. " = '" .. desc.Text .. "'")
        end
    end
    
    local leave = getLeaveButton()
    if leave then
        print("\n>>> LEAVE BUTTON FOUND: " .. leave:GetFullName() .. " <<<")
    end
end

-- Monitor PreGame GUI appearing/disappearing
local function monitorPreGame()
    -- Monitor for PreGame GUI added
    PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "PreGame" then
            print("\n>>> PREGAME GUI APPEARED (Joined table) <<<")
            task.wait(0.2)
            scanPreGameGUI()
        end
    end)
    
    -- Monitor for PreGame GUI removed
    PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "PreGame" then
            print("\n>>> PREGAME GUI REMOVED (Left table) <<<")
        end
    end)
end

-- Test clicking Leave button
local function testLeaveButton()
    local leave = getLeaveButton()
    if leave then
        print("\n[TEST] Leave button found, attempting click...")
        
        -- Method 1: firesignal
        local ok1 = pcall(function()
            firesignal(leave, "MouseButton1Click")
        end)
        print("  firesignal MouseButton1Click: " .. tostring(ok1))
        
        -- Method 2: firesignal Activated
        local ok2 = pcall(function()
            firesignal(leave, "Activated")
        end)
        print("  firesignal Activated: " .. tostring(ok2))
        
        -- Method 3: fireclickdetector if available
        local ok3 = pcall(function()
            fireclickdetector(leave)
        end)
        print("  fireclickdetector: " .. tostring(ok3))
        
        return true
    else
        print("[TEST] Leave button not found")
        return false
    end
end

-- Check if at table using PreGame GUI (more reliable than Humanoid.Sit)
local function checkTableStatus()
    print("\n[TABLE STATUS]")
    
    local atTable, preGame = isAtTable()
    print("  At Table: " .. tostring(atTable))
    
    if atTable and preGame then
        local frame = preGame:FindFirstChild("Frame")
        if frame then
            -- Try to find player count info in PreGame
            for _, desc in ipairs(frame:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" then
                    local text = desc.Text
                    if text:find("/") or text:find("Waiting") or text:find("player") then
                        print("  Info: " .. text)
                    end
                end
            end
        end
    end
    
    -- Also check InGame
    local inGame = PlayerGui:FindFirstChild("InGame")
    if inGame then
        local gameFrame = inGame:FindFirstChild("Frame")
        if gameFrame and gameFrame.Visible then
            print("  In Active Game: true")
        end
    end
end

-- List all GUIs currently in PlayerGui
local function listAllGUIs()
    print("\n[ALL GUIS]")
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local visible = "?"
            if gui:FindFirstChild("Frame") then
                visible = tostring(gui.Frame.Visible)
            end
            print("  " .. gui.Name .. " (Frame visible: " .. visible .. ")")
        end
    end
end

-- Run initial scans
print("\n[INITIAL SCAN]")
listAllGUIs()
scanPreGameGUI()
checkTableStatus()

-- Start monitoring
monitorPreGame()

-- Periodic status check
task.spawn(function()
    while true do
        task.wait(3)
        local atTable = isAtTable()
        if atTable then
            print("\n[PERIODIC] At table, Leave button check...")
            local leave = getLeaveButton()
            if leave then
                print("  Leave button: " .. leave:GetFullName())
                print("  Visible: " .. tostring(leave.Visible))
            end
        end
    end
end)

print("\n=== Debug v2 running ===")
print("Key info:")
print("  - PreGame GUI = at table (waiting)")
print("  - Leave button: PlayerGui.PreGame.Frame.Leave")
print("  - Use testLeaveButton() to test clicking")

-- Make test function global for manual testing
getgenv().testLeave = testLeaveButton
getgenv().scanTable = scanPreGameGUI
