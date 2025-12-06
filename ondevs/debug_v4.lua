-- Debug Script for Last Letter Game v4
-- Focus: Word Submission Detection - Correct/Wrong Answer Debug

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

print("=== LAST LETTER DEBUG v4 ===")
print("Purpose: Debug word submission and correct/wrong detection")

-- ==================== STATE TRACKING ====================
local WordHistory = {}
local LastWord = ""
local LastTurnState = false
local LastInputText = ""

-- ==================== CORE FUNCTIONS ====================

local function isInGame()
    local inGame = PlayerGui:FindFirstChild("InGame")
    if inGame then
        local frame = inGame:FindFirstChild("Frame")
        if frame and frame.Visible then
            return true, inGame, frame
        end
    end
    return false, nil, nil
end

-- Get current displayed word (robust version)
local function getCurrentWord()
    local inGameActive, inGame, frame = isInGame()
    if not frame then return nil end
    
    local currentWordContainer = frame:FindFirstChild("CurrentWord")
    if currentWordContainer then
        local letterLabels = {}
        local maxIndex = 0
        
        -- Method 1: Direct children
        for _, child in ipairs(currentWordContainer:GetChildren()) do
            if child:IsA("Frame") then
                local num = tonumber(child.Name)
                if num then
                    local letterLabel = child:FindFirstChild("Letter")
                    if letterLabel and letterLabel:IsA("TextLabel") then
                        local text = letterLabel.Text
                        if text and text ~= "" and text ~= "..." then
                            letterLabels[num] = text:upper()
                            if num > maxIndex then maxIndex = num end
                        end
                    end
                end
            end
        end
        
        -- Build word
        local word = ""
        for i = 1, maxIndex do
            word = word .. (letterLabels[i] or "")
        end
        
        if word ~= "" then return word end
    end
    
    return nil
end

-- Check if it's our turn (Type label visible)
local function isMyTurn()
    local inGameActive, inGame, frame = isInGame()
    if not frame then return false end
    
    local typeLabel = frame:FindFirstChild("Type")
    if typeLabel and typeLabel:IsA("TextLabel") then
        return typeLabel.Visible
    end
    
    return false
end

-- Get TextBox input
local function getInputBox()
    local inGameActive, inGame, frame = isInGame()
    if not frame then return nil end
    
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextBox") then
            return {
                Box = desc,
                Text = desc.Text,
                Focused = desc:IsFocused()
            }
        end
    end
    
    return nil
end

-- Scan for result/error messages
local function scanForMessages()
    local messages = {}
    
    local inGameActive, inGame, frame = isInGame()
    if frame then
        for _, desc in ipairs(frame:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible then
                local text = desc.Text:lower()
                local name = desc.Name:lower()
                
                -- Check for result-related content
                if text:find("invalid") or text:find("wrong") or text:find("not a word") 
                    or text:find("already") or text:find("doesn't exist")
                    or text:find("try again") or text:find("incorrect")
                    or text:find("correct") or text:find("nice") or text:find("good")
                    or name:find("error") or name:find("result") or name:find("feedback") then
                    table.insert(messages, {
                        Name = desc.Name,
                        Text = desc.Text,
                        Path = desc:GetFullName()
                    })
                end
            end
        end
    end
    
    -- Check Notification GUI
    local notification = PlayerGui:FindFirstChild("Notification")
    if notification then
        for _, desc in ipairs(notification:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text ~= "" then
                table.insert(messages, {
                    Name = desc.Name,
                    Text = desc.Text,
                    Path = desc:GetFullName(),
                    IsNotification = true
                })
            end
        end
    end
    
    return messages
end

-- ==================== DEBUG WORD SUBMISSION ====================

local function debugSubmission()
    print("\n" .. string.rep("=", 50))
    print("WORD SUBMISSION DEBUG")
    print(string.rep("=", 50))
    
    local startWord = getCurrentWord()
    local myTurn = isMyTurn()
    local input = getInputBox()
    
    print("\n[INITIAL STATE]")
    print("  Current Word: '" .. (startWord or "nil") .. "'")
    print("  Is My Turn: " .. tostring(myTurn))
    print("  Input Text: '" .. (input and input.Text or "nil") .. "'")
    
    print("\n[WATCHING for 5 seconds...]")
    print("  Submit a word and watch what happens")
    
    local startTime = tick()
    local foundResult = false
    
    while tick() - startTime < 5 do
        task.wait(0.2)
        
        -- Check word change
        local newWord = getCurrentWord()
        if newWord and newWord ~= startWord then
            print("\n[WORD CHANGED] '" .. (startWord or "") .. "' -> '" .. newWord .. "'")
            print("  >>> SUCCESS! <<<")
            foundResult = true
            break
        end
        
        -- Check for error messages
        local msgs = scanForMessages()
        for _, m in ipairs(msgs) do
            local text = m.Text:lower()
            if text:find("invalid") or text:find("wrong") or text:find("not") then
                print("\n[ERROR MESSAGE] '" .. m.Text .. "'")
                print("  >>> WRONG! <<<")
                foundResult = true
                break
            end
        end
        
        if foundResult then break end
    end
    
    if not foundResult then
        local finalWord = getCurrentWord()
        print("\n[TIMEOUT] No change detected")
        print("  Word still: '" .. (finalWord or "nil") .. "'")
        
        if finalWord == startWord then
            print("  >>> Likely WRONG (no change) <<<")
        end
    end
    
    print(string.rep("=", 50))
end

-- ==================== FULL STATE DEBUG ====================

local function debugFullState()
    print("\n" .. string.rep("=", 60))
    print("LAST LETTER - FULL STATE DEBUG")
    print(string.rep("=", 60))
    
    local inGameActive = isInGame()
    print("\nIn Game: " .. tostring(inGameActive))
    
    if not inGameActive then
        print("(Not in game)")
        return
    end
    
    local word = getCurrentWord()
    print("\nCurrent Word: '" .. (word or "nil") .. "'")
    if word then
        print("  Last Letter: '" .. word:sub(-1):upper() .. "'")
        print("  Length: " .. #word)
    end
    
    print("\nIs My Turn: " .. tostring(isMyTurn()))
    
    local input = getInputBox()
    print("\nInput Box:")
    if input then
        print("  Text: '" .. input.Text .. "'")
        print("  Focused: " .. tostring(input.Focused))
    else
        print("  Not found")
    end
    
    local msgs = scanForMessages()
    print("\nMessages Found: " .. #msgs)
    for i, m in ipairs(msgs) do
        print("  " .. i .. ". [" .. m.Name .. "] '" .. m.Text .. "'")
    end
    
    print("\nWord History (last 10):")
    local start = math.max(1, #WordHistory - 9)
    for i = start, #WordHistory do
        print("  " .. i .. ". " .. WordHistory[i])
    end
    
    print(string.rep("=", 60))
end

-- ==================== LIVE MONITORING ====================

local function monitor()
    local inGameActive = isInGame()
    if not inGameActive then return end
    
    -- Word change
    local word = getCurrentWord()
    if word and word ~= LastWord then
        print("\n[WORD] '" .. LastWord .. "' -> '" .. word .. "'")
        table.insert(WordHistory, word)
        LastWord = word
    end
    
    -- Turn change - THIS IS THE KEY FOR SUCCESS/WRONG DETECTION
    local myTurn = isMyTurn()
    if myTurn ~= LastTurnState then
        if myTurn then
            print("\n>>> YOUR TURN START! <<< Word: '" .. (word or "?") .. "'")
        else
            print("\n>>> YOUR TURN END! <<< (SUCCESS if you submitted)")
        end
        LastTurnState = myTurn
    end
    
    -- Input change
    local input = getInputBox()
    if input and input.Text ~= LastInputText then
        if input.Text ~= "" and #input.Text > 0 then
            print("[TYPING] '" .. input.Text .. "'")
        end
        LastInputText = input.Text
    end
end

-- ==================== GLOBAL FUNCTIONS ====================

getgenv().debugFull = debugFullState
getgenv().debugSubmit = debugSubmission
getgenv().debugWord = function()
    local w = getCurrentWord()
    print("[WORD] '" .. (w or "nil") .. "'")
    return w
end
getgenv().debugTurn = function()
    local t = isMyTurn()
    print("[TURN] Is My Turn: " .. tostring(t))
    return t
end
getgenv().debugInput = function()
    local i = getInputBox()
    if i then
        print("[INPUT] '" .. i.Text .. "' Focused: " .. tostring(i.Focused))
    else
        print("[INPUT] Not found")
    end
    return i
end
getgenv().debugMsgs = function()
    local m = scanForMessages()
    print("[MESSAGES] " .. #m .. " found")
    for i, msg in ipairs(m) do
        print("  " .. i .. ". '" .. msg.Text .. "'")
    end
    return m
end

-- ==================== START ====================

task.spawn(function()
    while true do
        task.wait(0.3)
        pcall(monitor)
    end
end)

print("\n=== Debug v4 Running ===")
print("Commands:")
print("  debugFull() - Full state")
print("  debugSubmit() - Watch submission result")
print("  debugWord() - Current word")
print("  debugTurn() - Check turn")
print("  debugInput() - Input box")
print("  debugMsgs() - Scan messages")
print("")
print("Monitoring active!")

task.wait(0.5)
debugFullState()
