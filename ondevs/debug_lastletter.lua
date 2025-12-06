-- Debug Script for Last Letter Game v3
-- Focus: Complete game state debugging for Auto Answer development

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

print("=== LAST LETTER DEBUG v3 ===")
print("Purpose: Debug game state for Auto Answer feature")

--[[
    DISCOVERED INFO (v2):
    - Leave Button: PlayerGui.PreGame.Frame.Leave
    - Humanoid.Sit = false even when seated (game uses different system)
    - No Seat class instances (seats are regular parts)
    - PreGame GUI appears when at table (waiting)
    - InGame GUI appears when game is active
    
    TO DISCOVER (v3):
    - Current word being displayed
    - Word choices/input method
    - Turn indicator
    - Lives/health system
    - Submitted word detection
    - Correct/wrong word feedback
    - Elimination detection
]]

-- ==================== STATE VARIABLES ====================
local GameState = {
    AtTable = false,
    InGame = false,
    IsMyTurn = false,
    CurrentWord = "",
    LastLetter = "",
    Lives = 0,
    MaxLives = 0,
    TurnNumber = 0,
    PlayersAlive = 0,
    IsEliminated = false,
    LastSubmittedWord = "",
    LastWordResult = "", -- "correct", "wrong", "timeout"
}

-- ==================== GUI DETECTION FUNCTIONS ====================

-- Check if player is at a table (PreGame visible)
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

-- Check if player is in active game (InGame visible)
local function isInGame()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if inGame then
        local frame = inGame:FindFirstChild("Frame")
        if frame and frame.Visible then
            return true, inGame
        end
    end
    return false, nil
end

-- ==================== INGAME GUI SCANNER ====================

-- Scan InGame GUI structure completely
local function scanInGameGUI()
    print("\n[SCANNING] InGame GUI Structure...")
    
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then
        print("  InGame GUI not found (not in game)")
        return nil
    end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame or not frame.Visible then
        print("  InGame.Frame not visible")
        return nil
    end
    
    print("  [FOUND] InGame GUI!")
    print("")
    
    -- Scan all descendants with hierarchy
    local function scanWithIndent(parent, indent)
        for _, child in ipairs(parent:GetChildren()) do
            local prefix = string.rep("  ", indent)
            local info = child.ClassName
            
            if child:IsA("TextLabel") then
                info = info .. " Text='" .. child.Text .. "'"
            elseif child:IsA("TextButton") then
                info = info .. " Text='" .. child.Text .. "' Visible=" .. tostring(child.Visible)
            elseif child:IsA("TextBox") then
                info = info .. " Text='" .. child.Text .. "' PlaceholderText='" .. (child.PlaceholderText or "") .. "'"
            elseif child:IsA("Frame") then
                info = info .. " Visible=" .. tostring(child.Visible)
            elseif child:IsA("ImageLabel") then
                info = info .. " Image=" .. tostring(child.Image):sub(1, 30)
            end
            
            print(prefix .. "[" .. child.Name .. "] " .. info)
            scanWithIndent(child, indent + 1)
        end
    end
    
    scanWithIndent(frame, 1)
    
    return frame
end

-- ==================== GAME STATE DETECTION ====================

-- Get current word from InGame GUI
local function getCurrentWord()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return nil end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return nil end
    
    -- Look for CurrentWord container
    local currentWordContainer = frame:FindFirstChild("CurrentWord")
    if currentWordContainer then
        local word = ""
        -- Letters might be in numbered children (1, 2, 3, etc.)
        local letterLabels = {}
        for _, child in ipairs(currentWordContainer:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then
                local num = tonumber(child.Name)
                if num then
                    -- Find the Letter TextLabel inside
                    local letterLabel = child:FindFirstChild("Letter")
                    if letterLabel and letterLabel:IsA("TextLabel") then
                        letterLabels[num] = letterLabel.Text
                    elseif child:IsA("TextLabel") then
                        letterLabels[num] = child.Text
                    end
                end
            end
        end
        
        -- Build word from sorted letters
        local maxIndex = 0
        for k in pairs(letterLabels) do
            if k > maxIndex then maxIndex = k end
        end
        
        for i = 1, maxIndex do
            word = word .. (letterLabels[i] or "")
        end
        
        return word
    end
    
    -- Alternative: look for any label with the word
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name:lower():find("word") then
            if desc.Text ~= "" and not desc.Text:find("Current") then
                return desc.Text
            end
        end
    end
    
    return nil
end

-- Get word choices (if game shows multiple choice buttons)
local function getWordChoices()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return {} end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return {} end
    
    local choices = {}
    
    -- Look for Choices container
    local choicesContainer = frame:FindFirstChild("Choices")
    if choicesContainer then
        for _, child in ipairs(choicesContainer:GetChildren()) do
            if child:IsA("TextButton") and child.Visible then
                table.insert(choices, {
                    Button = child,
                    Text = child.Text,
                    Name = child.Name
                })
            end
        end
    end
    
    -- Also check for any visible TextButtons in frame
    if #choices == 0 then
        for _, desc in ipairs(frame:GetDescendants()) do
            if desc:IsA("TextButton") and desc.Visible and desc.Text ~= "" then
                -- Skip non-game buttons
                if desc.Text:lower() ~= "leave" and desc.Text:lower() ~= "invite" then
                    table.insert(choices, {
                        Button = desc,
                        Text = desc.Text,
                        Name = desc.Name
                    })
                end
            end
        end
    end
    
    return choices
end

-- Get lives/tries remaining
local function getLives()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return 0, 0 end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return 0, 0 end
    
    -- Look for Tries container (hearts/lives)
    local triesContainer = frame:FindFirstChild("Tries")
    if triesContainer then
        local lives = 0
        local maxLives = 0
        
        for _, child in ipairs(triesContainer:GetChildren()) do
            if child:IsA("ImageLabel") or child:IsA("Frame") then
                maxLives = maxLives + 1
                -- Check if heart is "full" (visible, not transparent, etc.)
                if child.Visible then
                    if child:IsA("ImageLabel") then
                        -- Check transparency or image to see if "alive"
                        if child.ImageTransparency < 0.5 then
                            lives = lives + 1
                        end
                    else
                        lives = lives + 1
                    end
                end
            end
        end
        
        return lives, maxLives
    end
    
    return 0, 0
end

-- Get timer value
local function getTimer()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return nil end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return nil end
    
    -- Look for Timer label
    local timer = frame:FindFirstChild("Timer")
    if timer and timer:IsA("TextLabel") then
        return timer.Text
    end
    
    -- Search for timer in descendants
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name:lower():find("timer") then
            return desc.Text
        end
    end
    
    return nil
end

-- Get turn indicator (whose turn, circle indicator, etc.)
local function getTurnInfo()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return nil end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return nil end
    
    local turnInfo = {
        IsMyTurn = false,
        CircleVisible = false,
        TurnText = ""
    }
    
    -- Look for Circle (turn indicator)
    local circle = frame:FindFirstChild("Circle")
    if circle then
        turnInfo.CircleVisible = circle.Visible
        -- If circle is visible and positioned over player, it's their turn
        if circle.Visible then
            turnInfo.IsMyTurn = true
        end
    end
    
    -- Look for turn-related text
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local text = desc.Text:lower()
            if text:find("your turn") or text:find("type") or text:find("answer") then
                turnInfo.TurnText = desc.Text
                turnInfo.IsMyTurn = true
            end
        end
    end
    
    return turnInfo
end

-- Check for TextBox (typing input)
local function getInputBox()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if not inGame then return nil end
    
    local frame = inGame:FindFirstChild("Frame")
    if not frame then return nil end
    
    -- Search for TextBox
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextBox") then
            return {
                Box = desc,
                Text = desc.Text,
                Placeholder = desc.PlaceholderText,
                Focused = desc:IsFocused()
            }
        end
    end
    
    return nil
end

-- ==================== NOTIFICATION/RESULT DETECTION ====================

-- Get notification messages (correct/wrong word, elimination, etc.)
local function getNotification()
    local notification = PlayerGui:FindFirstChild("Notification")
    if not notification then return nil end
    
    local frame = notification:FindFirstChild("Frame")
    if frame then
        for _, desc in ipairs(frame:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text ~= "" then
                return {
                    Text = desc.Text,
                    Visible = desc.Visible
                }
            end
        end
    end
    
    return nil
end

-- ==================== COMPLETE GAME STATE ====================

local function updateGameState()
    local atTable, preGame = isAtTable()
    local inGameActive, inGame = isInGame()
    
    GameState.AtTable = atTable
    GameState.InGame = inGameActive
    
    if inGameActive then
        -- Get current word
        GameState.CurrentWord = getCurrentWord() or ""
        if #GameState.CurrentWord > 0 then
            GameState.LastLetter = GameState.CurrentWord:sub(-1):upper()
        end
        
        -- Get lives
        GameState.Lives, GameState.MaxLives = getLives()
        GameState.IsEliminated = GameState.Lives <= 0 and GameState.MaxLives > 0
        
        -- Get turn info
        local turnInfo = getTurnInfo()
        if turnInfo then
            GameState.IsMyTurn = turnInfo.IsMyTurn
        end
    end
    
    return GameState
end

-- ==================== PRINT GAME STATUS ====================

local function printGameStatus()
    local state = updateGameState()
    
    print("\n========== GAME STATUS ==========")
    print("At Table: " .. tostring(state.AtTable))
    print("In Game: " .. tostring(state.InGame))
    
    if state.InGame then
        print("")
        print("[GAME INFO]")
        print("  Current Word: '" .. state.CurrentWord .. "'")
        print("  Last Letter: '" .. state.LastLetter .. "'")
        print("  Lives: " .. state.Lives .. "/" .. state.MaxLives)
        print("  Is My Turn: " .. tostring(state.IsMyTurn))
        print("  Is Eliminated: " .. tostring(state.IsEliminated))
        
        -- Get choices
        local choices = getWordChoices()
        if #choices > 0 then
            print("")
            print("[WORD CHOICES]")
            for i, choice in ipairs(choices) do
                print("  " .. i .. ". " .. choice.Text .. " (" .. choice.Name .. ")")
            end
        end
        
        -- Get input box
        local inputBox = getInputBox()
        if inputBox then
            print("")
            print("[INPUT BOX]")
            print("  Current Text: '" .. inputBox.Text .. "'")
            print("  Placeholder: '" .. (inputBox.Placeholder or "") .. "'")
            print("  Focused: " .. tostring(inputBox.Focused))
        end
        
        -- Get timer
        local timer = getTimer()
        if timer then
            print("")
            print("[TIMER] " .. timer)
        end
    end
    
    -- Get notification
    local notif = getNotification()
    if notif and notif.Visible then
        print("")
        print("[NOTIFICATION] " .. notif.Text)
    end
    
    print("==================================")
end

-- ==================== MONITORING ====================

-- State tracking to prevent spam
local lastState = {
    CurrentWord = "",
    Lives = -1,
    InGame = false,
    Notification = "",
    IsMyTurn = false,
    TurnWord = "", -- Track which word triggered turn notification
    Eliminated = false,
}

local function monitorChanges()
    local state = updateGameState()
    
    -- Detect game start (only once)
    if state.InGame and not lastState.InGame then
        print("\n========================================")
        print(">>> GAME STARTED! <<<")
        print("========================================")
        task.wait(0.3)
        scanInGameGUI()
    end
    
    -- Detect game end (only once)
    if not state.InGame and lastState.InGame then
        print("\n========================================")
        print(">>> GAME ENDED! <<<")
        print("========================================")
        -- Reset state for next game
        lastState.TurnWord = ""
        lastState.Eliminated = false
    end
    lastState.InGame = state.InGame
    
    if state.InGame then
        -- Detect word change (new round) - only when word actually changes
        if state.CurrentWord ~= "" and state.CurrentWord ~= lastState.CurrentWord then
            print("\n[NEW WORD] '" .. state.CurrentWord .. "' -> Last Letter: '" .. state.LastLetter .. "'")
            lastState.CurrentWord = state.CurrentWord
            lastState.TurnWord = "" -- Reset turn tracking for new word
        end
        
        -- Detect lives change - only when actually changes
        if state.Lives ~= lastState.Lives and lastState.Lives >= 0 then
            if state.Lives < lastState.Lives then
                print("[LIFE LOST] " .. state.Lives .. "/" .. state.MaxLives .. " remaining")
            elseif state.Lives > lastState.Lives then
                print("[LIFE GAINED] " .. state.Lives .. "/" .. state.MaxLives)
            end
        end
        lastState.Lives = state.Lives
        
        -- Detect elimination (only once)
        if state.IsEliminated and not lastState.Eliminated then
            print("\n>>> ELIMINATED! <<<")
            lastState.Eliminated = true
        end
        
        -- Detect MY TURN - only trigger once per word
        -- Use TurnWord to track if we already announced this turn
        if state.IsMyTurn and state.CurrentWord ~= lastState.TurnWord then
            lastState.TurnWord = state.CurrentWord -- Mark this word as announced
            
            print("\n----------------------------------------")
            print("[YOUR TURN] Word: '" .. state.CurrentWord .. "' | Need: '" .. state.LastLetter .. "...'")
            
            -- Show timer if available
            local timer = getTimer()
            if timer then
                print("[TIMER] " .. timer)
            end
            
            -- Show choices once
            local choices = getWordChoices()
            if #choices > 0 then
                local choiceTexts = {}
                for _, c in ipairs(choices) do
                    table.insert(choiceTexts, c.Text)
                end
                print("[CHOICES] " .. table.concat(choiceTexts, ", "))
            end
            print("----------------------------------------")
        end
        
        -- Detect turn ended (was my turn, now it's not)
        if not state.IsMyTurn and lastState.IsMyTurn then
            -- Only log if there was an active turn
            if lastState.TurnWord ~= "" then
                print("[TURN ENDED]")
            end
        end
        lastState.IsMyTurn = state.IsMyTurn
    end
    
    -- Detect notification - only when text changes and not empty
    local notif = getNotification()
    if notif and notif.Text ~= "" and notif.Text ~= lastState.Notification then
        local text = notif.Text:lower()
        if text:find("correct") then
            print("[RESULT] ✓ Correct!")
        elseif text:find("wrong") or text:find("invalid") then
            print("[RESULT] ✗ Wrong!")
        elseif text:find("timeout") or text:find("time") then
            print("[RESULT] ⏱ Timeout!")
        else
            print("[NOTIFICATION] " .. notif.Text)
        end
        lastState.Notification = notif.Text
    end
end

-- ==================== PREGAME MONITORING ====================

local function monitorPreGame()
    PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "PreGame" then
            print("\n>>> JOINED TABLE (PreGame appeared) <<<")
        elseif child.Name == "InGame" then
            print("\n>>> INGAME GUI ADDED <<<")
            task.wait(0.3)
            scanInGameGUI()
        end
    end)
    
    PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "PreGame" then
            print("\n>>> LEFT TABLE (PreGame removed) <<<")
        elseif child.Name == "InGame" then
            print("\n>>> INGAME GUI REMOVED <<<")
        end
    end)
end

-- ==================== INITIAL SCAN ====================

print("\n[INITIAL SCAN]")

-- List all GUIs
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

-- Scan InGame if active
local inGameActive = isInGame()
if inGameActive then
    scanInGameGUI()
end

-- Print initial status
printGameStatus()

-- Start monitoring
monitorPreGame()

-- Periodic monitoring
task.spawn(function()
    while true do
        task.wait(0.5)
        monitorChanges()
    end
end)

-- ==================== GLOBAL FUNCTIONS FOR MANUAL TESTING ====================

getgenv().debugStatus = printGameStatus
getgenv().debugScan = scanInGameGUI
getgenv().debugChoices = function()
    local choices = getWordChoices()
    print("\n[WORD CHOICES]")
    for i, c in ipairs(choices) do
        print("  " .. i .. ". " .. c.Text .. " [" .. c.Name .. "] Path: " .. c.Button:GetFullName())
    end
    return choices
end
getgenv().debugWord = function()
    local word = getCurrentWord()
    print("\n[CURRENT WORD] '" .. (word or "nil") .. "'")
    if word and #word > 0 then
        print("[LAST LETTER] '" .. word:sub(-1):upper() .. "'")
    end
    return word
end
getgenv().debugLives = function()
    local lives, max = getLives()
    print("\n[LIVES] " .. lives .. "/" .. max)
    return lives, max
end
getgenv().debugInput = function()
    local input = getInputBox()
    if input then
        print("\n[INPUT BOX]")
        print("  Path: " .. input.Box:GetFullName())
        print("  Text: '" .. input.Text .. "'")
        print("  Placeholder: '" .. (input.Placeholder or "") .. "'")
    else
        print("\n[INPUT BOX] Not found")
    end
    return input
end
getgenv().debugTimer = function()
    local timer = getTimer()
    print("\n[TIMER] " .. (timer or "nil"))
    return timer
end
getgenv().debugTurn = function()
    local turn = getTurnInfo()
    if turn then
        print("\n[TURN INFO]")
        print("  Is My Turn: " .. tostring(turn.IsMyTurn))
        print("  Circle Visible: " .. tostring(turn.CircleVisible))
        print("  Turn Text: '" .. turn.TurnText .. "'")
    end
    return turn
end

print("\n=== Debug v3 Running ===")
print("Global functions available:")
print("  debugStatus() - Print full game status")
print("  debugScan() - Scan InGame GUI structure")
print("  debugChoices() - List word choices")
print("  debugWord() - Get current word")
print("  debugLives() - Get lives")
print("  debugInput() - Get input box info")
print("  debugTimer() - Get timer")
print("  debugTurn() - Get turn info")
print("")
print("Monitoring active - will print changes automatically!")
