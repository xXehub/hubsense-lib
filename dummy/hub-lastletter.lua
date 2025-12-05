-- Prefer local gamesneze UI implementation if present
do
    local __HS_loaded = false
    pcall(function()
        local candidates = { 'ondevs/gamesneze.lua', 'gamesneze.lua' }
        for _, p in ipairs(candidates) do
            local ok, content = pcall(readfile, p)
            if ok and content and #content > 0 then
                loadstring(content)()
                __HS_loaded = true
                break
            end
        end
    end)
    if __HS_loaded then return end
end

local Library = loadstring(
    game:HttpGetAsync("https://raw.githubusercontent.com/focat69/gamesense/refs/heads/main/source?t=" .. tostring(tick()))
)()

-- Word Suggester Variables
local url = "https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words.txt"
local Words = {}
local loaded = false
local WordDictionary = {}
local searchCache = {}
local minCharacters = 1
local maxCharacters = 100
local currentPage = 1
local wordsPerPage = 50
local currentSearchResults = {}

-- Load Words Function
local function LoadWords()
    if loaded then return end
    
    local success, result = pcall(function()
        local res = request({Url = url, Method = "GET"})
        if res and res.Body then
            for w in res.Body:gmatch("[^\r\n]+") do
                local wordLower = w:lower()
                local wordLen = #wordLower
                
                -- Filter by min and max characters
                if wordLen >= minCharacters and wordLen <= maxCharacters then
                    table.insert(Words, wordLower)
                    local firstLetter = wordLower:sub(1,1)
                    if not WordDictionary[firstLetter] then
                        WordDictionary[firstLetter] = {}
                    end
                    table.insert(WordDictionary[firstLetter], wordLower)
                end
            end
            loaded = true
            return true
        end
    end)
    
    loaded = true
end

-- Reload Words with new filter
local function ReloadWords()
    Words = {}
    WordDictionary = {}
    searchCache = {}
    loaded = false
    currentPage = 1
    currentSearchResults = {}
    
    spawn(function()
        LoadWords()
        while not loaded do
            wait(0.1)
        end
    end)
end

-- Suggest Words Function
local function SuggestWords(input, count)
    if not loaded then 
        return {"loading words...", "please wait"}
    end
    if #Words == 0 then 
        return {"no words available", "check connection"}
    end
    
    input = input:lower()
    
    local cacheKey = input .. "_" .. count
    if searchCache[cacheKey] then
        return searchCache[cacheKey]
    end
    
    local possible = {}
    local results = {}
    
    local firstLetter = input:sub(1,1)
    local wordList = WordDictionary[firstLetter] or {}
    
    local searchList = #wordList > 0 and wordList or Words
    
    for i = 1, #searchList do
        local word = searchList[i]
        if word:sub(1, #input) == input then
            table.insert(possible, word)
            if #possible >= 1000 then break end
        end
    end
    
    table.sort(possible, function(a, b)
        return #a < #b
    end)
    
    local maxResults = math.min(count, #possible)
    for i = 1, maxResults do
        table.insert(results, possible[i])
    end
    
    if #possible > maxResults then
        for i = 1, math.min(10, #possible - maxResults) do
            local r = math.random(maxResults + 1, #possible)
            table.insert(results, possible[r])
        end
    end
    
    searchCache[cacheKey] = results
    if #searchCache > 100 then
        local keys = {}
        for k in pairs(searchCache) do
            table.insert(keys, k)
        end
        for i = 1, 30 do
            if keys[i] then
                searchCache[keys[i]] = nil
            end
        end
    end
    
    return results
end

-- Start loading words in background
spawn(LoadWords)

local Window = Library:New({
    Name = "Last Letter Hub",
    Padding = 5
})

local TabOne = Window:CreateTab({
    Name = "Examples"
})

local TabWordSuggester = Window:CreateTab({
    Name = "Word Suggester"
})

local CallbackButton = TabOne:Button({
    Name = "I will be renamed",
    Callback = function()
		print("I was clicked!")
	end
})



-- Adjust the button's callback/function
CallbackButton:SetCallback(function()
	print("I was clicked yet again")
end)


-- Adjusts the button's name
CallbackButton:SetText("Click me!") 

-- Add a Label to TabOne
local ExampleLabel = TabOne:Label({
    Message = "Hello, I am a text!"
})


-- Add a Slider to TabOne
local ExampleSlider = TabOne:Slider({
    Name = "Slider Value",
    Min = 0,
    Max = 100,
    Default = 50,
    Step = 5,
    Callback = function(value)
        print("Slider value changed to:", value)
        ExampleLabel:SetText("Slider Value: " .. tostring(value)) -- Updates label with slider value
    end
})

-- Set Slider value to 75
ExampleSlider:SetValue(75)


-- Add a Toggle to TabOne
local ExampleToggle = TabOne:Toggle({
    Name = "Enable Feature",
    State = false,
    Callback = function(state)
        print("Toggle state changed to:", state)
        ExampleLabel:SetText("Feature Enabled: " .. tostring(state))
    end
})

-- Set the toggle to 'true'
ExampleToggle:SetValue(true)

-- Add a Textbox to TabOne
local ExampleTextbox = TabOne:Textbox({
    Placeholder = "Enter your name...",
    Callback = function(text)
        ExampleLabel:SetText("Hello, " .. text .. "!")
    end
})

-- Add a Notification when Script Executes
Library:Notify({
    Description = "Script loaded successfully!",
    Duration = 3
})

-- ==================== Word Suggester Tab ====================

-- Info Label - Status loading
local InfoLabel = TabWordSuggester:Label({
    Message = "Loading words database... Please wait..."
})

-- Status Label - Untuk menampilkan hasil pencarian
local StatusLabel = TabWordSuggester:Label({
    Message = "Results will appear here..."
})

-- Load Status Label - Status detail
local LoadStatusLabel = TabWordSuggester:Label({
    Message = "Status: Initializing..."
})

-- Show/Hide Menu Toggle
local MenuVisible = true
local MenuToggle = TabWordSuggester:Toggle({
    Name = "Show/Hide Menu (INSERT key)",
    State = true,
    Callback = function(state)
        MenuVisible = state
        if state then
            Window:Show()
        else
            Window:Hide()
        end
    end
})

-- Min Characters Textbox
local minInputValue = ""
TabWordSuggester:Textbox({
    Placeholder = "Min characters (1-100, default: 1)",
    Callback = function(text)
        minInputValue = text
        if text ~= "" then
            LoadStatusLabel:SetText("Min set to: " .. text .. " (click Apply to reload)")
        end
    end
})

-- Max Characters Textbox
local maxInputValue = ""
TabWordSuggester:Textbox({
    Placeholder = "Max characters (1-100, default: 100)",
    Callback = function(text)
        maxInputValue = text
        if text ~= "" then
            LoadStatusLabel:SetText("Max set to: " .. text .. " (click Apply to reload)")
        end
    end
})

-- Apply Filter Button
TabWordSuggester:Button({
    Name = "🔄 Apply Min/Max Filter & Reload",
    Callback = function()
        local minNum = tonumber(minInputValue)
        local maxNum = tonumber(maxInputValue)
        local changed = false
        
        if minNum and minNum >= 1 and minNum <= 100 then
            minCharacters = minNum
            changed = true
        end
        
        if maxNum and maxNum >= 1 and maxNum <= 100 then
            maxCharacters = maxNum
            changed = true
        end
        
        -- Validate min < max
        if minCharacters > maxCharacters then
            maxCharacters = minCharacters
        end
        
        if changed then
            LoadStatusLabel:SetText("⏳ Reloading with Min:" .. minCharacters .. " Max:" .. maxCharacters)
            InfoLabel:SetText("Reloading words with new filter...")
            StatusLabel:SetText("Please wait...")
            
            ReloadWords()
            
            spawn(function()
                while not loaded do
                    wait(0.1)
                end
                LoadStatusLabel:SetText("✅ Ready! " .. #Words .. " words loaded")
                InfoLabel:SetText("Filtered: " .. #Words .. " words (Min:" .. minCharacters .. " Max:" .. maxCharacters .. ")")
                StatusLabel:SetText("Type in search box to find words")
                Library:Notify({
                    Description = "Filter applied: " .. #Words .. " words loaded!",
                    Duration = 3
                })
            end)
        else
            LoadStatusLabel:SetText("⚠️ Please enter valid numbers (1-100)")
        end
    end
})

-- Separator Label
TabWordSuggester:Label({
    Message = "━━━━━━━ SEARCH ━━━━━━━"
})

-- Search Input Textbox
local lastSearchText = ""
TabWordSuggester:Textbox({
    Placeholder = "🔍 Type letters to search words...",
    Callback = function(text)
        if not loaded then
            LoadStatusLabel:SetText("⏳ Please wait, loading words...")
            StatusLabel:SetText("Loading...")
            return
        end
        
        if text == "" or #text < 1 then
            LoadStatusLabel:SetText("Enter at least 1 character to search")
            StatusLabel:SetText("Type to search...")
            currentSearchResults = {}
            currentPage = 1
            return
        end
        
        lastSearchText = text
        currentPage = 1
        currentSearchResults = SuggestWords(text, 1000)
        
        if #currentSearchResults == 0 then
            LoadStatusLabel:SetText("❌ No words found for: '" .. text .. "'")
            StatusLabel:SetText("No results found")
        else
            local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
            LoadStatusLabel:SetText("✅ Found " .. #currentSearchResults .. " words | Page 1/" .. totalPages)
            
            -- Display first page results
            local startIndex = 1
            local endIndex = math.min(wordsPerPage, #currentSearchResults)
            local displayText = ""
            for i = startIndex, endIndex do
                displayText = displayText .. currentSearchResults[i]
                if i < endIndex then
                    displayText = displayText .. ", "
                end
            end
            StatusLabel:SetText(displayText)
        end
    end
})

-- Separator Label
TabWordSuggester:Label({
    Message = "━━━━━ PAGINATION ━━━━━"
})

-- Previous Page Button
TabWordSuggester:Button({
    Name = "⬅️ Previous Page",
    Callback = function()
        if #currentSearchResults == 0 then
            LoadStatusLabel:SetText("❌ No search results to paginate")
            return
        end
        
        if currentPage > 1 then
            currentPage = currentPage - 1
            local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
            local startIndex = (currentPage - 1) * wordsPerPage + 1
            local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
            
            local displayText = ""
            for i = startIndex, endIndex do
                displayText = displayText .. currentSearchResults[i]
                if i < endIndex then
                    displayText = displayText .. ", "
                end
            end
            
            StatusLabel:SetText(displayText)
            LoadStatusLabel:SetText("📄 Page " .. currentPage .. "/" .. totalPages .. " | Total: " .. #currentSearchResults .. " words")
        else
            LoadStatusLabel:SetText("⚠️ Already on first page")
        end
    end
})

-- Next Page Button
TabWordSuggester:Button({
    Name = "Next Page ➡️",
    Callback = function()
        if #currentSearchResults == 0 then
            LoadStatusLabel:SetText("❌ No search results to paginate")
            return
        end
        
        local totalPages = math.ceil(#currentSearchResults / wordsPerPage)
        
        if currentPage < totalPages then
            currentPage = currentPage + 1
            local startIndex = (currentPage - 1) * wordsPerPage + 1
            local endIndex = math.min(currentPage * wordsPerPage, #currentSearchResults)
            
            local displayText = ""
            for i = startIndex, endIndex do
                displayText = displayText .. currentSearchResults[i]
                if i < endIndex then
                    displayText = displayText .. ", "
                end
            end
            
            StatusLabel:SetText(displayText)
            LoadStatusLabel:SetText("📄 Page " .. currentPage .. "/" .. totalPages .. " | Total: " .. #currentSearchResults .. " words")
        else
            LoadStatusLabel:SetText("⚠️ Already on last page")
        end
    end
})

-- Info Footer
TabWordSuggester:Label({
    Message = "━━━━━━━━━━━━━━━━━━━"
})

-- Monitor loading status
spawn(function()
    while not loaded do
        wait(0.5)
        InfoLabel:SetText("⏳ Loading words database... Please wait...")
    end
    LoadStatusLabel:SetText("✅ Ready! " .. #Words .. " words loaded")
    InfoLabel:SetText("📚 Loaded: " .. #Words .. " words (Min:" .. minCharacters .. " Max:" .. maxCharacters .. ")")
    Library:Notify({
        Description = "Word database loaded: " .. #Words .. " words ready!",
        Duration = 4
    })
end)

-- Keybind untuk toggle menu (INSERT key)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        MenuVisible = not MenuVisible
        if MenuVisible then
            Window:Show()
            MenuToggle:SetValue(true)
        else
            Window:Hide()
            MenuToggle:SetValue(false)
        end
    end
end)


-- Destroy the UI
-- Window:Destroy() 