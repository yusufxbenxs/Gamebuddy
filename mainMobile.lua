-- GameBuddy (GB) - Delta Mobile Edition (CPTS Default OFF, Default Model: gemini-3.5-flash-lite, Built-in Saved Keys Dropdown + RevertSmart + Reuse Prompt Button)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local KEY_FILE_NAME = "GameBuddy_SavedKeys.json"
local HISTORY_FILE_NAME = "GameBuddy_ChatHistory.json"
local DEFAULT_API_KEY = "" -- Blank for public safety
local savedKeysList = {}

-- State Backup Storage for Standard Reversions
local workspaceStateBackups = {}

local function loadSavedKeys()
    local success, result = pcall(function()
        if isfile and isfile(KEY_FILE_NAME) then
            return HttpService:JSONDecode(readfile(KEY_FILE_NAME))
        end
    end)
    if success and type(result) == "table" and #result > 0 then
        return result
    end
    return {DEFAULT_API_KEY}
end

local function saveKeysToFile(keysTable)
    pcall(function()
        if writefile then
            writefile(KEY_FILE_NAME, HttpService:JSONEncode(keysTable))
        end
    end)
end

local function loadChatHistoryFile()
    local success, result = pcall(function()
        if isfile and isfile(HISTORY_FILE_NAME) then
            return HttpService:JSONDecode(readfile(HISTORY_FILE_NAME))
        end
    end)
    if success and type(result) == "table" then
        return result
    end
    return nil
end

local function saveChatHistory(historyTable)
    pcall(function()
        if writefile then
            writefile(HISTORY_FILE_NAME, HttpService:JSONEncode(historyTable))
        end
    end)
end

savedKeysList = loadSavedKeys()
local ACTIVE_API_KEY = savedKeysList[1] or DEFAULT_API_KEY
local SELECTED_MODEL = "gemini-3.5-flash-lite"
local conversationHistory = {}
local rawStoredHistory = loadChatHistoryFile()

local CURRENT_EXACT_DATE = "August 24, 2026"

local SYSTEM_INSTRUCTION = string.format([[
You are GameBuddy (GB), an elite AI assistant built directly into the player's Roblox mobile executor client (Delta).
CURRENT LOCAL PLAYER CONTEXT:
- Username: %s
- Display Name: %s
- User ID: %d
- Exact Date: %s

CAPABILITIES & PROTOCOLS:
1. CODE EXECUTION ([LUA]): When requested to make workspace changes or test modifications, write Luau code and wrap it cleanly in:
[LUA]
local info = "Success"
return info
[/LUA]
Always make sure your snippet `return`s a description of what was done or verification data so it can be checked. If verification fails or errors occur, you will receive feedback and must fix your approach iteratively.

2. EXECUTION ENVIRONMENT DIFFERENCES: Keep in mind that PC executors and Mobile executors (such as Delta) run code slightly differently, and running code inside Roblox Studio operates under a completely different environment compared to external executors. Tailor your scripts for mobile/Delta executor compatibility.

3. TIME AWARENESS & SEARCH PROTOCOL: The exact date right now is %s. Your knowledge cutoff might be older (e.g., 2025). If you think the user requested something whose APIs, methods, or behaviors could have changed over time, please search the internet/knowledge base to ensure accuracy. (If the method is standard and timeless, no search is necessary, but search if it could change over time).

4. REVERSION PROTOCOLS:
- Standard "revert" / "undo": Restores properties via the snapshot backup table.
- Smart Revert ("reverts/revertsmart"): You analyze what was changed based on chat history and write a custom [LUA] script specifically engineered to intelligently undo, clean up, or reverse the effects in the workspace dynamically.
]], localPlayer.Name, localPlayer.DisplayName, localPlayer.UserId, CURRENT_EXACT_DATE, CURRENT_EXACT_DATE)

if playerGui:FindFirstChild("GameBuddyMobileGUI") then 
    playerGui.GameBuddyMobileGUI:Destroy() 
end

local sg = Instance.new("ScreenGui")
sg.Name = "GameBuddyMobileGUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 48, 0, 48)
toggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
toggleBtn.Text = "G"
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 26
toggleBtn.Active = true
toggleBtn.Parent = sg

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggleBtn

local toggleDragging, toggleDragStart, toggleStartPos, toggleMoved = false, nil, nil, false
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleMoved = false
        toggleDragStart = input.Position
        toggleStartPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then toggleDragging = false end
        end)
    end
end)

toggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if toggleDragging and toggleDragStart then
            local delta = input.Position - toggleDragStart
            if delta.Magnitude > 5 then toggleMoved = true end
            toggleBtn.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
        end
    end
end)

local window = Instance.new("Frame")
window.Size = UDim2.new(0.9, 0, 0.65, 0)
window.Position = UDim2.new(0.05, 0, 0.18, 0)
window.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
window.BorderSizePixel = 0
window.Active = true
window.Parent = sg

local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MinSize = Vector2.new(300, 380)
uiSizeConstraint.MaxSize = Vector2.new(450, 560)
uiSizeConstraint.Parent = window

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent = window

local dragging, dragInput, dragStart, startPos
window.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

window.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
header.BorderSizePixel = 0
header.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "GameBuddy Setup"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -66, 0, 6)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

local minimized = false
minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(window:GetChildren()) do
        if child ~= header and child ~= winCorner and child ~= uiSizeConstraint then
            child.Visible = not minimized
        end
    end
    window.Size = minimized and UDim2.new(0.9, 0, 0, 40) or UDim2.new(0.9, 0, 0.65, 0)
end)

toggleBtn.MouseButton1Click:Connect(function()
    if not toggleMoved then
        window.Visible = not window.Visible
    end
end)

local buildSetupUI, buildChatUI, buildMemoryPromptUI

buildSetupUI = function()
    for _, child in ipairs(window:GetChildren()) do
        if child ~= header and child ~= winCorner and child ~= uiSizeConstraint then
            child:Destroy()
        end
    end
    title.Text = "GameBuddy Setup"

    local setupScroll = Instance.new("ScrollingFrame")
    setupScroll.Size = UDim2.new(1, -16, 1, -55)
    setupScroll.Position = UDim2.new(0, 8, 0, 45)
    setupScroll.BackgroundTransparency = 1
    setupScroll.BorderSizePixel = 0
    setupScroll.ScrollBarThickness = 4
    setupScroll.CanvasSize = UDim2.new(0, 0, 0, 420)
    setupScroll.Parent = window

    local modelLbl = Instance.new("TextLabel")
    modelLbl.Size = UDim2.new(1, 0, 0, 22)
    modelLbl.BackgroundTransparency = 1
    modelLbl.Text = "Select Model Version:"
    modelLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    modelLbl.Font = Enum.Font.GothamBold
    modelLbl.TextSize = 13
    modelLbl.TextXAlignment = Enum.TextXAlignment.Left
    modelLbl.Parent = setupScroll

    local modelBtn = Instance.new("TextButton")
    modelBtn.Size = UDim2.new(1, 0, 0, 35)
    modelBtn.Position = UDim2.new(0, 0, 0, 25)
    modelBtn.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
    modelBtn.Text = "  " .. SELECTED_MODEL
    modelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    modelBtn.Font = Enum.Font.Gotham
    modelBtn.TextSize = 12
    modelBtn.TextXAlignment = Enum.TextXAlignment.Left
    modelBtn.Parent = setupScroll

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 6)
    mCorner.Parent = modelBtn

    local modelListFrame = Instance.new("ScrollingFrame")
    modelListFrame.Size = UDim2.new(1, 0, 0, 110)
    modelListFrame.Position = UDim2.new(0, 0, 0, 62)
    modelListFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    modelListFrame.BorderSizePixel = 0
    modelListFrame.Visible = false
    modelListFrame.ZIndex = 5
    modelListFrame.Parent = setupScroll

    local mLayout = Instance.new("UIListLayout")
    mLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mLayout.Parent = modelListFrame

    local models = {"gemini-3.7-flash", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-2.5-flash-lite"}
    for _, mName in ipairs(models) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1, 0, 0, 28)
        opt.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
        opt.Text = "  " .. mName
        opt.TextColor3 = Color3.fromRGB(255, 255, 255)
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 12
        opt.TextXAlignment = Enum.TextXAlignment.Left
        opt.ZIndex = 6
        opt.Parent = modelListFrame
        
        opt.MouseButton1Click:Connect(function()
            SELECTED_MODEL = mName
            modelBtn.Text = "  " .. mName
            modelListFrame.Visible = false
        end)
    end

    modelBtn.MouseButton1Click:Connect(function()
        modelListFrame.Visible = not modelListFrame.Visible
    end)

    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size = UDim2.new(1, 0, 0, 22)
    keyLbl.Position = UDim2.new(0, 0, 0, 145)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text = "Gemini API Key:"
    keyLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    keyLbl.Font = Enum.Font.GothamBold
    keyLbl.TextSize = 13
    keyLbl.TextXAlignment = Enum.TextXAlignment.Left
    keyLbl.Parent = setupScroll

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, 0, 0, 35)
    keyBox.Position = UDim2.new(0, 0, 0, 170)
    keyBox.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
    keyBox.PlaceholderText = "Paste or select API key..."
    keyBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    keyBox.Text = ACTIVE_API_KEY
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 12
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = setupScroll

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(0, 6)
    kCorner.Parent = keyBox

    local savedKeysBtn = Instance.new("TextButton")
    savedKeysBtn.Size = UDim2.new(1, 0, 0, 28)
    savedKeysBtn.Position = UDim2.new(0, 0, 0, 210)
    savedKeysBtn.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    savedKeysBtn.Text = "  📂 Saved Keys (" .. #savedKeysList .. ") v"
    savedKeysBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    savedKeysBtn.Font = Enum.Font.Gotham
    savedKeysBtn.TextSize = 11
    savedKeysBtn.TextXAlignment = Enum.TextXAlignment.Left
    savedKeysBtn.Parent = setupScroll

    local skCorner = Instance.new("UICorner")
    skCorner.CornerRadius = UDim.new(0, 6)
    skCorner.Parent = savedKeysBtn

    local savedKeysScroll = Instance.new("ScrollingFrame")
    savedKeysScroll.Size = UDim2.new(1, 0, 0, 90)
    savedKeysScroll.Position = UDim2.new(0, 0, 0, 242)
    savedKeysScroll.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    savedKeysScroll.BorderSizePixel = 0
    savedKeysScroll.Visible = false
    savedKeysScroll.ZIndex = 5
    savedKeysScroll.ScrollBarThickness = 4
    savedKeysScroll.Parent = setupScroll

    local skLayout = Instance.new("UIListLayout")
    skLayout.SortOrder = Enum.SortOrder.LayoutOrder
    skLayout.Parent = savedKeysScroll

    skLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        savedKeysScroll.CanvasSize = UDim2.new(0, 0, 0, skLayout.AbsoluteContentSize.Y)
    end)

    for _, storedKey in ipairs(savedKeysList) do
        if storedKey ~= "" then
            local keyOption = Instance.new("TextButton")
            keyOption.Size = UDim2.new(1, 0, 0, 28)
            keyOption.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
            keyOption.Text = "  " .. storedKey
            keyOption.TextColor3 = Color3.fromRGB(255, 255, 255)
            keyOption.Font = Enum.Font.Gotham
            keyOption.TextSize = 11
            keyOption.TextXAlignment = Enum.TextXAlignment.Left
            keyOption.ZIndex = 6
            keyOption.Parent = savedKeysScroll

            keyOption.MouseButton1Click:Connect(function()
                keyBox.Text = storedKey
                savedKeysScroll.Visible = false
            end)
        end
    end

    savedKeysBtn.MouseButton1Click:Connect(function()
        savedKeysScroll.Visible = not savedKeysScroll.Visible
    end)

    local startChatBtn = Instance.new("TextButton")
    startChatBtn.Size = UDim2.new(1, 0, 0, 40)
    startChatBtn.Position = UDim2.new(0, 0, 0, 345)
    startChatBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    startChatBtn.Text = "OK - Start Chat"
    startChatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startChatBtn.Font = Enum.Font.GothamBold
    startChatBtn.TextSize = 14
    startChatBtn.Parent = setupScroll

    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 8)
    startCorner.Parent = startChatBtn

    startChatBtn.MouseButton1Click:Connect(function()
        local inputtedKey = keyBox.Text:gsub("%s+", "")
        if inputtedKey == "" then return end
        
        if inputtedKey ~= savedKeysList[1] then
            ACTIVE_API_KEY = inputtedKey
            table.insert(savedKeysList, 1, inputtedKey)
            
            local uniqueKeys = {}
            local seen = {}
            for _, k in ipairs(savedKeysList) do
                if not seen[k] and k ~= "" then
                    seen[k] = true
                    table.insert(uniqueKeys, k)
                end
            end
            savedKeysList = uniqueKeys
            saveKeysToFile(savedKeysList)
        else
            ACTIVE_API_KEY = inputtedKey
        end
        
        if rawStoredHistory and #rawStoredHistory > 0 then
            buildMemoryPromptUI()
        else
            conversationHistory = {}
            buildChatUI()
        end
    end)
end

buildMemoryPromptUI = function()
    for _, child in ipairs(window:GetChildren()) do
        if child ~= header and child ~= winCorner and child ~= uiSizeConstraint then
            child:Destroy()
        end
    end
    title.Text = "GameBuddy - Memory"

    local promptContainer = Instance.new("Frame")
    promptContainer.Size = UDim2.new(1, -30, 1, -60)
    promptContainer.Position = UDim2.new(0, 15, 0, 50)
    promptContainer.BackgroundTransparency = 1
    promptContainer.Parent = window

    local promptLbl = Instance.new("TextLabel")
    promptLbl.Size = UDim2.new(1, 0, 0, 80)
    promptLbl.BackgroundTransparency = 1
    promptLbl.Text = "Would you like to load in the last chat with Gamebuddy?"
    promptLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    promptLbl.Font = Enum.Font.GothamBold
    promptLbl.TextSize = 18
    promptLbl.TextWrapped = true
    promptLbl.TextXAlignment = Enum.TextXAlignment.Center
    promptLbl.Parent = promptContainer

    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(1, 0, 0, 45)
    loadBtn.Position = UDim2.new(0, 0, 0, 110)
    loadBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    loadBtn.Text = "Load"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.TextSize = 15
    loadBtn.Parent = promptContainer

    local lCorner = Instance.new("UICorner")
    lCorner.CornerRadius = UDim.new(0, 8)
    lCorner.Parent = loadBtn

    local newBtn = Instance.new("TextButton")
    newBtn.Size = UDim2.new(1, 0, 0, 45)
    newBtn.Position = UDim2.new(0, 0, 0, 170)
    newBtn.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    newBtn.Text = "Create a new one"
    newBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    newBtn.Font = Enum.Font.GothamBold
    newBtn.TextSize = 15
    newBtn.Parent = promptContainer

    local nCorner = Instance.new("UICorner")
    nCorner.CornerRadius = UDim.new(0, 8)
    nCorner.Parent = newBtn

    loadBtn.MouseButton1Click:Connect(function()
        conversationHistory = rawStoredHistory
        buildChatUI()
    end)

    newBtn.MouseButton1Click:Connect(function()
        conversationHistory = {}
        saveChatHistory(conversationHistory)
        buildChatUI()
    end)
end

buildChatUI = function()
    for _, child in ipairs(window:GetChildren()) do
        if child ~= header and child ~= winCorner and child ~= uiSizeConstraint then
            child:Destroy()
        end
    end
    title.Text = "GameBuddy"

    local restartBtn = Instance.new("TextButton")
    restartBtn.Size = UDim2.new(0, 28, 0, 28)
    restartBtn.Position = UDim2.new(1, -98, 0, 6)
    restartBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    restartBtn.Text = "🔄"
    restartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    restartBtn.Font = Enum.Font.GothamBold
    restartBtn.TextSize = 13
    restartBtn.Parent = header

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 6)
    rCorner.Parent = restartBtn

    restartBtn.MouseButton1Click:Connect(function()
        buildSetupUI()
    end)

    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -16, 0, 38)
    inputFrame.Position = UDim2.new(0, 8, 1, -46)
    inputFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    inputFrame.Parent = window

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputFrame

    local chatBox = Instance.new("TextBox")
    chatBox.Size = UDim2.new(1, -45, 1, 0)
    chatBox.Position = UDim2.new(0, 10, 0, 0)
    chatBox.BackgroundTransparency = 1
    chatBox.PlaceholderText = "Type a command or chat..."
    chatBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    chatBox.Text = ""
    chatBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatBox.Font = Enum.Font.Gotham
    chatBox.TextSize = 13
    chatBox.ClearTextOnFocus = false
    chatBox.Parent = inputFrame

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 32, 0, 30)
    sendBtn.Position = UDim2.new(1, -35, 0, 4)
    sendBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    sendBtn.Text = ">"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 16
    sendBtn.Parent = inputFrame

    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 6)
    sendCorner.Parent = sendBtn

    local actionToolbar = Instance.new("Frame")
    actionToolbar.Size = UDim2.new(1, -16, 0, 32)
    actionToolbar.Position = UDim2.new(0, 8, 1, -84)
    actionToolbar.BackgroundTransparency = 1
    actionToolbar.Parent = window

    local cptsEnabled = false
    local cptsBtn = Instance.new("TextButton")
    cptsBtn.Size = UDim2.new(0.31, 0, 1, 0)
    cptsBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
    cptsBtn.Text = "CPTS: OFF"
    cptsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cptsBtn.Font = Enum.Font.GothamBold
    cptsBtn.TextSize = 11
    cptsBtn.Parent = actionToolbar

    local cptsCorner = Instance.new("UICorner")
    cptsCorner.CornerRadius = UDim.new(0, 6)
    cptsCorner.Parent = cptsBtn

    cptsBtn.MouseButton1Click:Connect(function()
        cptsEnabled = not cptsEnabled
        if cptsEnabled then
            cptsBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
            cptsBtn.Text = "CPTS: ON"
        else
            cptsBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
            cptsBtn.Text = "CPTS: OFF"
        end
    end)

    local openTreeBtn = Instance.new("TextButton")
    openTreeBtn.Size = UDim2.new(0.31, 0, 1, 0)
    openTreeBtn.Position = UDim2.new(0.34, 0, 0, 0)
    openTreeBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    openTreeBtn.Text = "🌳 Tree"
    openTreeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openTreeBtn.Font = Enum.Font.GothamBold
    openTreeBtn.TextSize = 11
    openTreeBtn.Parent = actionToolbar

    local treeCorner = Instance.new("UICorner")
    treeCorner.CornerRadius = UDim.new(0, 6)
    treeCorner.Parent = openTreeBtn

    local errorCheckBtn = Instance.new("TextButton")
    errorCheckBtn.Size = UDim2.new(0.31, 0, 1, 0)
    errorCheckBtn.Position = UDim2.new(0.68, 0, 0, 0)
    errorCheckBtn.BackgroundColor3 = Color3.fromRGB(211, 84, 0)
    errorCheckBtn.Text = "🔍 Error Check"
    errorCheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    errorCheckBtn.Font = Enum.Font.GothamBold
    errorCheckBtn.TextSize = 11
    errorCheckBtn.Parent = actionToolbar

    local errorCorner = Instance.new("UICorner")
    errorCorner.CornerRadius = UDim.new(0, 6)
    errorCorner.Parent = errorCheckBtn

    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Size = UDim2.new(1, -16, 1, -136)
    chatScroll.Position = UDim2.new(0, 8, 0, 45)
    chatScroll.BackgroundTransparency = 1
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 5
    chatScroll.Active = true
    chatScroll.Parent = window

    local chatLayout = Instance.new("UIListLayout")
    chatLayout.Padding = UDim.new(0, 6)
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    chatLayout.Parent = chatScroll

    chatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        chatScroll.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
    end)

    local function callGeminiAPI(userPrompt)
        local req = request or http_request or (http and http.request) or (syn and syn.request)
        if not req then return "⚠️ Error: Delta request function not available." end

        local url = string.format("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", SELECTED_MODEL, ACTIVE_API_KEY)
        table.insert(conversationHistory, { role = "user", parts = { { text = userPrompt } } })
        saveChatHistory(conversationHistory)

        local payload = {
            system_instruction = { parts = { { text = SYSTEM_INSTRUCTION } } },
            contents = conversationHistory
        }

        local success, result = pcall(function()
            return req({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if success and result and result.Body then
            local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(result.Body) end)
            if decodeSuccess and decoded and decoded.candidates and decoded.candidates[1] then
                local aiText = decoded.candidates[1].content.parts[1].text
                table.insert(conversationHistory, { role = "model", parts = { { text = aiText } } })
                saveChatHistory(conversationHistory)
                return aiText
            end
        end
        return "⚠️ Failed to connect to Gemini API."
    end

    local appendMessage
    local sendQuery

    local function captureWorkspaceBackup()
        local snapshot = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                table.insert(snapshot, {
                    instance = obj,
                    color = obj.Color,
                    material = obj.Material,
                    size = obj.Size,
                    position = obj.Position,
                    transparency = obj.Transparency
                })
            end
        end
        table.insert(workspaceStateBackups, snapshot)
    end

    local function performReversion()
        if #workspaceStateBackups == 0 then
            return "⚠️ No previous workspace states available to revert."
        end

        local latestSnapshot = table.remove(workspaceStateBackups)
        local restoredCount = 0

        for _, data in ipairs(latestSnapshot) do
            if data.instance and data.instance.Parent then
                pcall(function()
                    data.instance.Color = data.color
                    data.instance.Material = data.material
                    data.instance.Size = data.size
                    data.instance.Position = data.position
                    data.instance.Transparency = data.transparency
                    restoredCount = restoredCount + 1
                end)
            end
        end

        local notificationPrompt = string.format("System Notice: The user triggered a state reversion. %d part properties were restored back to their pre-execution backups. Acknowledge this restoration to the user.", restoredCount)
        return callGeminiAPI(notificationPrompt)
    end

    local function executeWithSelfCorrection(code, loadingBubble, originalPrompt)
        captureWorkspaceBackup()

        local maxTries = 4
        local currentTry = 1
        local activeCode = code
        local fixHistoryLog = {}

        while currentTry <= maxTries do
            local recentLogs = {}
            local logConn = LogService.MessageOut:Connect(function(msg, msgType)
                if msgType == Enum.MessageType.MessageError or msgType == Enum.MessageType.MessageWarning then
                    table.insert(recentLogs, "[" .. tostring(msgType) .. "]: " .. msg)
                end
            end)

            local func, err = loadstring("return (function()\n" .. activeCode .. "\nend)()")
            local execSuccess, execRes

            if func then
                execSuccess, execRes = pcall(func)
            else
                execSuccess = false
                execRes = "Loadstring Compile Error: " .. tostring(err)
            end

            task.wait(0.15)
            if logConn then logConn:Disconnect() end

            local errorFound = false
            local feedbackMsg = ""

            if not execSuccess then
                errorFound = true
                feedbackMsg = "Execution Error: " .. tostring(execRes)
            elseif #recentLogs > 0 then
                errorFound = true
                feedbackMsg = "Console Warnings/Errors detected: " .. table.concat(recentLogs, " | ")
            else
                local verifySuccess, verifyRes = pcall(function()
                    return tostring(execRes or "Executed successfully with no returned output.")
                end)
                if not verifySuccess then
                    errorFound = true
                    feedbackMsg = "Verification Output Error: " .. tostring(verifyRes)
                end
            end

            if not errorFound then
                local fixSummaryDesc = ""
                if #fixHistoryLog > 0 then
                    fixSummaryDesc = " This was wrong initially (" .. table.concat(fixHistoryLog, "; ") .. "), but I fixed it by iterating and correcting the approach."
                else
                    fixSummaryDesc = " Executed cleanly on the first try."
                end

                local successReport = string.format("Task successfully verified and executed on attempt %d! Execution Result: %s. Now respond to the user: confirm success clearly, and state:%s", currentTry, tostring(execRes), fixSummaryDesc)
                if loadingBubble then loadingBubble:Destroy() end
                return callGeminiAPI(successReport)
            else
                table.insert(fixHistoryLog, "Try " .. currentTry .. " failed due to: " .. feedbackMsg)
                currentTry = currentTry + 1
                
                if currentTry <= maxTries then
                    local retryText = string.format("<i>⚠️ Error: %s. Retrying (Attempt %d/%d)...</i>", feedbackMsg, currentTry, maxTries)
                    if loadingBubble then
                        local lbl = loadingBubble:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text = retryText end
                    end
                    
                    local correctionPrompt = string.format("Your previous code snippet failed with this error/warning: '%s'. Please fix the approach, write a completely new corrected [LUA] block addressing this issue, and try again.", feedbackMsg)
                    local rawCorrection = callGeminiAPI(correctionPrompt)
                    
                    local newCode = rawCorrection:match("%[LUA%](.-)%[%/LUA%]") or rawCorrection:match("```lua%s*(.-)%s*```")
                    if not newCode then
                        local sPos, ePos = rawCorrection:find("%[LUA%]"), rawCorrection:find("%[%/LUA%]")
                        if sPos and ePos then newCode = rawCorrection:sub(sPos + 5, ePos - 1) end
                    end
                    if newCode then
                        activeCode = newCode
                    else
                        if loadingBubble then loadingBubble:Destroy() end
                        return rawCorrection
                    end
                else
                    if loadingBubble then loadingBubble:Destroy() end
                    return string.format("⚠️ Failed after %d attempts. Last error: %s", maxTries, feedbackMsg)
                end
            end
        end
        if loadingBubble then loadingBubble:Destroy() end
        return "⚠️ Maximum self-correction iterations reached."
    end

    local function processResponse(res, userPrompt)
        if res:lower() == "revert" or res:lower() == "undo" then
            return performReversion()
        end

        local code = res:match("%[LUA%](.-)%[%/LUA%]") or res:match("```lua%s*(.-)%s*```")
        if not code then
            local sPos, ePos = res:find("%[LUA%]"), res:find("%[%/LUA%]")
            if sPos and ePos then code = res:sub(sPos + 5, ePos - 1) end
        end

        if code then
            local loadingBubble = appendMessage("System", "⚡ Executing script and verifying stability...", Color3.fromRGB(211, 84, 0))
            return executeWithSelfCorrection(code, loadingBubble, userPrompt)
        end
        return res
    end

    appendMessage = function(sender, text, color)
        local msgFrame = Instance.new("Frame")
        msgFrame.Size = UDim2.new(1, 0, 0, 0)
        msgFrame.BackgroundTransparency = 1
        msgFrame.AutomaticSize = Enum.AutomaticSize.Y
        msgFrame.Parent = chatScroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.Text = string.format("<b>%s:</b> %s", sender, text)
        lbl.TextColor3 = color or Color3.fromRGB(230, 230, 230)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextWrapped = true
        lbl.RichText = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = msgFrame

        chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y)
        return msgFrame
    end

    sendQuery = function(text)
        if text == "" then return end
        chatBox.Text = ""
        appendMessage("You", text, Color3.fromRGB(52, 152, 219))
        
        local loading = appendMessage("GameBuddy", "Thinking...", Color3.fromRGB(150, 150, 150))
        task.spawn(function()
            local rawReply = callGeminiAPI(text)
            local finalReply = processResponse(rawReply, text)
            if loading and loading.Parent then loading:Destroy() end
            appendMessage("GameBuddy", finalReply, Color3.fromRGB(255, 255, 255))
        end)
    end

    chatBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            sendQuery(chatBox.Text)
        end
    end)

    sendBtn.MouseButton1Click:Connect(function()
        sendQuery(chatBox.Text)
    end)
end

buildSetupUI()
