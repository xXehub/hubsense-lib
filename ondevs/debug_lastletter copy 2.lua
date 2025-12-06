-- Debug Script for Last Letter Game (Clean Version)
-- Focus: Detecting game events without spam

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

print("=== LAST LETTER DEBUG (Clean) ===")
print("Waiting for InGame GUI...")

-- Track InGame GUI
local function setupInGameMonitor()
    local inGame = PlayerGui:WaitForChild("InGame", 10)
    if not inGame then 
        print("[ERROR] InGame GUI not found!")
        return 
    end
    
    local frame = inGame:WaitForChild("Frame", 10)
    if not frame then
        print("[ERROR] InGame.Frame not found!")
        return
    end
    
    print("[FOUND] InGame.Frame")
    
    -- Monitor visibility (game start/end)
    frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if frame.Visible then
            print(">>> GAME STARTED <<<")
        else
            print(">>> GAME ENDED <<<")
        end
    end)
    
    -- Monitor CurrentWord for your turn
    local currentWord = frame:FindFirstChild("CurrentWord")
    if currentWord then
        print("[FOUND] CurrentWord container")
        currentWord:GetPropertyChangedSignal("Visible"):Connect(function()
            if currentWord.Visible then
                print(">>> YOUR TURN - Word Display Visible <<<")
                -- Print current letters
                local letters = {}
                for _, child in ipairs(currentWord:GetChildren()) do
                    local letterLabel = child:FindFirstChild("Letter")
                    if letterLabel and letterLabel:IsA("TextLabel") then
                        table.insert(letters, letterLabel.Text)
                    end
                end
                print("Current Letters: " .. table.concat(letters, ""))
            end
        end)
    end
    
    -- Monitor Choices for answer options
    local choices = frame:FindFirstChild("Choices")
    if choices then
        print("[FOUND] Choices container")
        for i = 1, 4 do
            local choice = choices:FindFirstChild(tostring(i))
            if choice then
                -- Check for button activation
                if choice:IsA("TextButton") or choice:IsA("ImageButton") then
                    choice.Activated:Connect(function()
                        print("[CLICKED] Choice " .. i .. ": " .. (choice.Text or ""))
                    end)
                end
            end
        end
    end
    
    -- Monitor for popup/notification frames
    local function checkPopup(popup)
        if popup.Name == "Result" or popup.Name == "Popup" or popup.Name == "Notification" then
            print("[POPUP] " .. popup.Name .. " appeared")
            -- Try to get text
            for _, child in ipairs(popup:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text ~= "" then
                    print("  Text: " .. child.Text)
                end
            end
        end
    end
    
    frame.ChildAdded:Connect(function(child)
        print("[NEW ELEMENT] " .. child.Name .. " (Class: " .. child.ClassName .. ")")
        checkPopup(child)
    end)
    
    -- Check existing children
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("Frame") then
            print("[EXISTING] " .. child.Name)
        end
    end
end

-- Monitor for specific game events (only key TextLabels)
local function monitorKeyLabels()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return end
    
    -- Look for timer
    local timer = frame:FindFirstChild("Timer")
    if timer and timer:IsA("TextLabel") then
        print("[FOUND] Timer: " .. timer.Text)
        timer:GetPropertyChangedSignal("Text"):Connect(function()
            local text = timer.Text
            if text == "0" or text:lower():find("time") then
                print(">>> TIMES UP <<<")
            end
        end)
    end
    
    -- Look for result/status label
    local status = frame:FindFirstChild("Status") or frame:FindFirstChild("Result")
    if status and status:IsA("TextLabel") then
        print("[FOUND] Status/Result label")
        status:GetPropertyChangedSignal("Text"):Connect(function()
            local text = status.Text:lower()
            if text:find("wrong") or text:find("incorrect") or text:find("salah") then
                print(">>> WRONG ANSWER <<<")
            elseif text:find("correct") or text:find("benar") or text:find("right") then
                print(">>> CORRECT ANSWER <<<")
            end
        end)
    end
end

-- Monitor Join buttons (SurfaceGui on Tables)
local function monitorJoinButtons()
    local workspace = game:GetService("Workspace")
    local tables = workspace:FindFirstChild("Tables") or workspace:FindFirstChild("GameTables")
    
    if tables then
        print("[FOUND] Tables folder in Workspace")
        for _, table in ipairs(tables:GetChildren()) do
            local surfaceGui = table:FindFirstChildOfClass("SurfaceGui")
            if surfaceGui then
                print("  [TABLE] " .. table.Name .. " has SurfaceGui")
                -- Find join button
                for _, desc in ipairs(surfaceGui:GetDescendants()) do
                    if (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
                        if desc.Name:lower():find("join") or (desc.Text and desc.Text:lower():find("join")) then
                            print("    [JOIN BUTTON] " .. desc.Name)
                        end
                    end
                end
            end
        end
    else
        print("[NOT FOUND] Tables folder - scanning workspace...")
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then
                local sg = child:FindFirstChildOfClass("SurfaceGui")
                if sg then
                    print("  [SURFACEGUI] in " .. child.Name)
                end
            end
        end
    end
end

-- Main setup
task.spawn(function()
    setupInGameMonitor()
    monitorKeyLabels()
end)

task.spawn(function()
    task.wait(1)
    monitorJoinButtons()
end)

print("=== Debug script running (clean version) ===")
print("Join a Last Letter game to see events!")
