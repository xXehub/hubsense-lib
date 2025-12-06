-- Debug script untuk menganalisis word database
-- Jalankan ini di Roblox executor untuk melihat statistik kata

print("=== WORD DATABASE ANALYZER ===")
print("")

-- Load words dari GitHub (sama seperti main.lua)
local WordsURL = "https://raw.githubusercontent.com/xXehub/lastletter-database/main/words.txt"

local function LoadWords()
    print("[Debug] Loading words from GitHub...")
    
    local success, result = pcall(function()
        return game:HttpGet(WordsURL)
    end)
    
    if not success then
        print("[Debug] ERROR: Failed to load words - " .. tostring(result))
        return nil
    end
    
    local words = {}
    local wordsByLength = {}
    local wordsByLetter = {}
    
    for word in result:gmatch("[^\r\n]+") do
        word = word:gsub("%s+", ""):lower()
        if #word >= 2 and word:match("^[a-z]+$") then
            table.insert(words, word)
            
            -- Group by length
            local len = #word
            if not wordsByLength[len] then
                wordsByLength[len] = {}
            end
            table.insert(wordsByLength[len], word)
            
            -- Group by first letter
            local firstLetter = word:sub(1, 1)
            if not wordsByLetter[firstLetter] then
                wordsByLetter[firstLetter] = {}
            end
            table.insert(wordsByLetter[firstLetter], word)
        end
    end
    
    return words, wordsByLength, wordsByLetter
end

local words, wordsByLength, wordsByLetter = LoadWords()

if not words then
    print("[Debug] Failed to load words!")
    return
end

print("[Debug] Total words loaded: " .. #words)
print("")

-- Analyze word lengths
print("=== WORD LENGTH DISTRIBUTION ===")
local lengths = {}
for len, _ in pairs(wordsByLength) do
    table.insert(lengths, len)
end
table.sort(lengths)

for _, len in ipairs(lengths) do
    local count = #wordsByLength[len]
    local bar = string.rep("█", math.min(50, math.floor(count / 1000)))
    print(string.format("Length %2d: %6d words %s", len, count, bar))
end
print("")

-- Analyze first letters
print("=== FIRST LETTER DISTRIBUTION ===")
local letters = {}
for letter, _ in pairs(wordsByLetter) do
    table.insert(letters, letter)
end
table.sort(letters)

for _, letter in ipairs(letters) do
    local count = #wordsByLetter[letter]
    local bar = string.rep("█", math.min(50, math.floor(count / 500)))
    print(string.format("Letter %s: %6d words %s", letter:upper(), count, bar))
end
print("")

-- Common English words list (untuk filter legit mode)
local COMMON_WORDS = {
    -- Very common 3-letter words
    "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
    "her", "was", "one", "our", "out", "day", "get", "has", "him", "his",
    "how", "its", "may", "new", "now", "old", "see", "two", "way", "who",
    "boy", "did", "own", "say", "she", "too", "use", "dad", "mom", "run",
    "eat", "big", "let", "put", "end", "far", "got", "why", "ask", "men",
    
    -- Common 4-letter words
    "that", "with", "have", "this", "will", "your", "from", "they", "been",
    "call", "come", "find", "give", "good", "just", "know", "long", "look",
    "make", "more", "much", "some", "than", "them", "then", "time", "very",
    "when", "work", "year", "also", "back", "each", "even", "hand", "here",
    "high", "last", "life", "most", "name", "next", "only", "over", "same",
    "tell", "want", "well", "book", "word", "read", "play", "home", "love",
    "take", "help", "keep", "turn", "city", "game", "food", "part", "best",
    
    -- Common 5-letter words
    "about", "after", "again", "being", "could", "every", "first", "found",
    "great", "house", "large", "never", "other", "place", "point", "right",
    "shall", "small", "sound", "still", "study", "their", "there", "these",
    "thing", "think", "three", "water", "where", "which", "while", "world",
    "would", "write", "years", "young", "today", "music", "money", "paper",
    "party", "power", "price", "table", "watch", "woman", "level", "local",
    "night", "order", "phone", "plant", "state", "story", "thank", "using",
    
    -- Common 6-letter words
    "always", "before", "change", "course", "during", "family", "friend",
    "mother", "father", "people", "public", "really", "school", "should",
    "simple", "social", "system", "though", "around", "become", "better",
    "called", "coming", "follow", "having", "little", "living", "market",
    "member", "moment", "number", "office", "rather", "reason", "return",
    "second", "single", "taking", "trying", "within", "action", "answer",
    
    -- Common 7+ letter words
    "another", "because", "between", "certain", "country", "example",
    "general", "however", "nothing", "present", "problem", "program",
    "provide", "several", "student", "through", "without", "working",
    "company", "control", "already", "against", "believe", "brought",
    "different", "important", "something", "sometimes", "everything",
    "understand", "government", "information", "development"
}

-- Create lookup table
local commonLookup = {}
for _, word in ipairs(COMMON_WORDS) do
    commonLookup[word:lower()] = true
end

-- Check how many words in database are "common"
print("=== COMMON WORDS ANALYSIS ===")
local commonInDb = 0
local commonByLength = {}

for _, word in ipairs(words) do
    if commonLookup[word] then
        commonInDb = commonInDb + 1
        local len = #word
        commonByLength[len] = (commonByLength[len] or 0) + 1
    end
end

print("Common words in database: " .. commonInDb .. " / " .. #COMMON_WORDS)
print("")

-- Sample random words from each length
print("=== SAMPLE WORDS BY LENGTH ===")
for len = 3, 10 do
    local wordList = wordsByLength[len]
    if wordList and #wordList > 0 then
        local samples = {}
        for i = 1, math.min(5, #wordList) do
            local idx = math.random(1, #wordList)
            table.insert(samples, wordList[idx])
        end
        print(string.format("Length %d: %s", len, table.concat(samples, ", ")))
    end
end
print("")

-- Alternative: Use word frequency/simplicity heuristics
print("=== WORD SIMPLICITY HEURISTICS ===")
print("Idea: Simple words tend to have:")
print("  - Shorter length (3-7 chars)")
print("  - Common letter patterns")
print("  - No double consonants")
print("  - End in common suffixes (-ing, -ed, -ly, -tion)")
print("")

-- Test simplicity scoring
local function ScoreSimplicity(word)
    local score = 100
    
    -- Length penalty (prefer 4-7 chars)
    local len = #word
    if len < 4 then score = score - 10 end
    if len > 7 then score = score - (len - 7) * 5 end
    if len > 10 then score = score - 20 end
    
    -- Common endings bonus
    if word:match("ing$") then score = score + 15 end
    if word:match("ed$") then score = score + 10 end
    if word:match("ly$") then score = score + 10 end
    if word:match("er$") then score = score + 5 end
    if word:match("est$") then score = score + 5 end
    if word:match("tion$") then score = score + 10 end
    if word:match("ness$") then score = score + 5 end
    
    -- Vowel ratio (words with good vowel distribution are easier)
    local vowels = select(2, word:gsub("[aeiou]", ""))
    local vowelRatio = vowels / len
    if vowelRatio >= 0.3 and vowelRatio <= 0.5 then
        score = score + 10
    end
    
    -- Penalty for rare letters
    if word:match("[qxz]") then score = score - 15 end
    if word:match("[jkv]") then score = score - 5 end
    
    -- Penalty for double consonants (less common)
    if word:match("([bcdfghjklmnpqrstvwxyz])%1") then
        score = score - 5
    end
    
    -- Bonus for starting with common letters
    local first = word:sub(1, 1)
    if first:match("[satcbpm]") then score = score + 5 end
    
    return score
end

-- Test on sample words
print("=== SIMPLICITY SCORE EXAMPLES ===")
local testWords = {"the", "running", "xylophone", "cat", "dog", "beautiful", "quickly", "pizza", "rhythm", "action"}
for _, word in ipairs(testWords) do
    local score = ScoreSimplicity(word)
    print(string.format("  '%s': %d", word, score))
end
print("")

-- Find simplest words for each starting letter
print("=== TOP SIMPLE WORDS BY LETTER ===")
for _, letter in ipairs({"a", "b", "c", "s", "t", "e", "i", "o"}) do
    local wordList = wordsByLetter[letter]
    if wordList then
        -- Score all words
        local scored = {}
        for i, word in ipairs(wordList) do
            if i <= 1000 then -- Limit for speed
                table.insert(scored, {word = word, score = ScoreSimplicity(word)})
            end
        end
        
        -- Sort by score
        table.sort(scored, function(a, b) return a.score > b.score end)
        
        -- Get top 5
        local top = {}
        for i = 1, math.min(5, #scored) do
            table.insert(top, scored[i].word)
        end
        
        print(string.format("  %s: %s", letter:upper(), table.concat(top, ", ")))
    end
end

print("")
print("=== DEBUG COMPLETE ===")
