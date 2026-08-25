-- GameBuddy (GB) - Mobile Edition (Delta Executor, Default Model: gemini-3.5-flash-lite, Saved Keys + Fixed Reuse Button)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local KEY_FILE_NAME = "GameBuddy_Mobile_SavedKeys.json"
local HISTORY_FILE_NAME = "GameBuddy_Mobile_ChatHistory.json"
local DEFAULT_API_KEY = ""
local savedKeysList = {}
local workspaceStateBackups = {}

local function loadSavedKeys()
    local success, result = pcall(function()
        if isfile and isfile(KEY_FILE_NAME) then return HttpService:JSONDecode(readfile(KEY_FILE_NAME)) end
    end)
    if success and type(result) == "table" and #result > 0 then return result end
    return {DEFAULT_API_KEY}
end

local function saveKeysToFile(keysTable)
    pcall(function() if writefile then writefile(KEY_FILE_NAME, HttpService:JSONEncode(keysTable)) end end)
end

local function loadChatHistoryFile()
    local success, result = pcall(function()
        if isfile and isfile(HISTORY_FILE_NAME) then return HttpService:JSONDecode(readfile(HISTORY_FILE_NAME)) end
    end)
    if success and type(result) == "table" then return result end
    return nil
end

local function saveChatHistory(historyTable)
    pcall(function() if writefile then writefile(HISTORY_FILE_NAME, HttpService:JSONEncode(historyTable)) end end)
end

savedKeysList = loadSavedKeys()
local ACTIVE_API_KEY = savedKeysList[1] or DEFAULT_API_KEY
local SELECTED_MODEL = "gemini-3.5-flash-lite"
local conversationHistory = {}
local rawStoredHistory = loadChatHistoryFile()
local CURRENT_EXACT_DATE = "August 25, 2026"

local SYSTEM_INSTRUCTION = string.format([[
You are GameBuddy (GB), an elite AI mobile assistant built into Delta Executor.
User: %s | ID: %d | Date: %s
Write code inside [LUA] ... [/LUA] tags when requested.
]], localPlayer.Name, localPlayer.UserId, CURRENT_EXACT_DATE)

if CoreGui:FindFirstChild("GameBuddyMobileGUI") then CoreGui.GameBuddyMobileGUI:Destroy() end

local sg = Instance.new("ScreenGui", CoreGui)
sg.Name = "GameBuddyMobileGUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999

local toggleBtn = Instance.new("TextButton", sg)
toggleBtn.Size = UDim2.new(0, 42, 0, 42)
toggleBtn.Position = UDim2.new(0.02, 0, 0.15, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
toggleBtn.Text = "GB"
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 16
toggleBtn.Active = true
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

local window = Instance.new("Frame", sg)
window.Size = UDim2.new(0, 360, 0, 440)
window.Position = UDim2.new(0.5, -180, 0.5, -220)
window.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
window.BorderSizePixel = 0
window.Active = true
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 10)

-- Dragging support for mobile touch inputs
local dragging, dragStart, startPos
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

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

toggleBtn.MouseButton1Click:Connect(function() window.Visible = not window.Visible end)

local header = Instance.new("Frame", window)
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(28, 31, 40)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -75, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "GameBuddy (Delta Mobile)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local buildSetupUI, buildChatUI, buildMemoryPromptUI

buildSetupUI = function()
    for _, child in ipairs(window:GetChildren()) do
        if child ~= header then child:Destroy() end
    end
    title.Text = "Setup (Delta Mobile)"

    local setupScroll = Instance.new("ScrollingFrame", window)
    setupScroll.Size = UDim2.new(1, -12, 1, -45)
    setupScroll.Position = UDim2.new(0, 6, 0, 40)
    setupScroll.BackgroundTransparency = 1
    setupScroll.CanvasSize = UDim2.new(0, 0, 0, 320)

    local mbl = Instance.new("TextLabel", setupScroll)
    mbl.Size = UDim2.new(1, 0, 0, 20)
    mbl.Text = "Model:"
    mbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    mbl.Font = Enum.Font.GothamBold
    mbl.TextSize = 12
    mbl.TextXAlignment = Enum.TextXAlignment.Left

    local mbtn = Instance.new("TextButton", setupScroll)
    mbtn.Size = UDim2.new(1, 0, 0, 32)
    mbtn.Position = UDim2.new(0, 0, 0, 22)
    mbtn.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
    mbtn.Text = "  " .. SELECTED_MODEL
    mbtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mbtn.Font = Enum.Font.Gotham
    mbtn.TextSize = 11
    mbtn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", mbtn).CornerRadius = UDim.new(0, 6)

    local kbl = Instance.new("TextLabel", setupScroll)
    kbl.Size = UDim2.new(1, 0, 0, 20)
    kbl.Position = UDim2.new(0, 0, 0, 62)
    kbl.Text = "Gemini API Key:"
    kbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    kbl.Font = Enum.Font.GothamBold
    kbl.TextSize = 12
    kbl.TextXAlignment = Enum.TextXAlignment.Left

    local kbox = Instance.new("TextBox", setupScroll)
    kbox.Size = UDim2.new(1, 0, 0, 32)
    kbox.Position = UDim2.new(0, 0, 0, 84)
    kbox.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
    kbox.Text = ACTIVE_API_KEY
    kbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    kbox.Font = Enum.Font.Gotham
    kbox.TextSize = 11
    Instance.new("UICorner", kbox).CornerRadius = UDim.new(0, 6)

    local startBtn = Instance.new("TextButton", setupScroll)
    startBtn.Size = UDim2.new(1, 0, 0, 38)
    startBtn.Position = UDim2.new(0, 0, 0, 130)
    startBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    startBtn.Text = "Start Chat"
    startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 13
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

    startBtn.MouseButton1Click:Connect(function()
        local k = kbox.Text:gsub("%s+", "")
        if k ~= "" then ACTIVE_API_KEY = k end
        if rawStoredHistory and #rawStoredHistory > 0 then buildMemoryPromptUI() else conversationHistory = {}; buildChatUI() end
    end)
end

buildMemoryPromptUI = function()
    for _, child in ipairs(window:GetChildren()) do if child ~= header then child:Destroy() end end
    title.Text = "Memory (Mobile)"

    local f = Instance.new("Frame", window)
    f.Size = UDim2.new(1, -20, 1, -50)
    f.Position = UDim2.new(0, 10, 0, 45)
    f.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, 0, 0, 60)
    lbl.Text = "Restore past chat session?"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 15
    lbl.TextWrapped = true

    local lBtn = Instance.new("TextButton", f)
    lBtn.Size = UDim2.new(1, 0, 0, 40)
    lBtn.Position = UDim2.new(0, 0, 0, 75)
    lBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    lBtn.Text = "Load"
    lBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", lBtn).CornerRadius = UDim.new(0, 6)

    local nBtn = Instance.new("TextButton", f)
    nBtn.Size = UDim2.new(1, 0, 0, 40)
    nBtn.Position = UDim2.new(0, 0, 0, 125)
    nBtn.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    nBtn.Text = "New Chat"
    nBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    nBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", nBtn).CornerRadius = UDim.new(0, 6)

    lBtn.MouseButton1Click:Connect(function() conversationHistory = rawStoredHistory; buildChatUI() end)
    nBtn.MouseButton1Click:Connect(function() conversationHistory = {}; saveChatHistory(conversationHistory); buildChatUI() end)
end

buildChatUI = function()
    for _, child in ipairs(window:GetChildren()) do if child ~= header then child:Destroy() end end
    title.Text = "GameBuddy (Delta Mobile)"

    local restartBtn = Instance.new("TextButton", header)
    restartBtn.Size = UDim2.new(0, 24, 0, 24)
    restartBtn.Position = UDim2.new(1, -58, 0, 6)
    restartBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
    restartBtn.Text = "🔄"
    restartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", restartBtn).CornerRadius = UDim.new(0, 4)
    restartBtn.MouseButton1Click:Connect(function() buildSetupUI() end)

    local inputFrame = Instance.new("Frame", window)
    inputFrame.Size = UDim2.new(1, -12, 0, 36)
    inputFrame.Position = UDim2.new(0, 6, 1, -42)
    inputFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 6)

    local chatBox = Instance.new("TextBox", inputFrame)
    chatBox.Size = UDim2.new(1, -38, 1, 0)
    chatBox.Position = UDim2.new(0, 6, 0, 0)
    chatBox.BackgroundTransparency = 1
    chatBox.PlaceholderText = "Type message..."
    chatBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    chatBox.Text = ""
    chatBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatBox.Font = Enum.Font.Gotham
    chatBox.TextSize = 12

    local sendBtn = Instance.new("TextButton", inputFrame)
    sendBtn.Size = UDim2.new(0, 28, 0, 28)
    sendBtn.Position = UDim2.new(1, -32, 0, 4)
    sendBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    sendBtn.Text = ">"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 4)

    local chatScroll = Instance.new("ScrollingFrame", window)
    chatScroll.Size = UDim2.new(1, -12, 1, -92)
    chatScroll.Position = UDim2.new(0, 6, 0, 42)
    chatScroll.BackgroundTransparency = 1
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 4

    local chatLayout = Instance.new("UIListLayout", chatScroll)
    chatLayout.Padding = UDim.new(0, 6)
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    chatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        chatScroll.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
    end)

    local function callGeminiAPI(userPrompt)
        local req = request or http_request or (http and http.request) or (syn and syn.request)
        if not req then return "⚠️ Request not supported." end
        table.insert(conversationHistory, { role = "user", parts = { { text = userPrompt } } })
        saveChatHistory(conversationHistory)

        local success, result = pcall(function()
            return req({
                Url = string.format("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", SELECTED_MODEL, ACTIVE_API_KEY),
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ system_instruction = { parts = { { text = SYSTEM_INSTRUCTION } } }, contents = conversationHistory })
            })
        end)
        if success and result and result.Body then
            local dec, data = pcall(function() return HttpService:JSONDecode(result.Body) end)
            if dec and data and data.candidates then
                local txt = data.candidates[1].content.parts[1].text
                table.insert(conversationHistory, { role = "model", parts = { { text = txt } } })
                saveChatHistory(conversationHistory)
                return txt
            end
        end
        return "⚠️ API Connection Error."
    end

    local appendMessage
    local function processResponse(res)
        local code = res:match("%[LUA%](.-)%[%/LUA%]") or res:match("```lua%s*(.-)%s*```")
        if code then
            local f, err = loadstring(code)
            if f then
                local s, r = pcall(f)
                return s and ("Executed: " .. tostring(r)) or ("Error: " .. tostring(r))
            else
                return "Compile Error: " .. tostring(err)
            end
        end
        return res
    end

    appendMessage = function(sender, text, isUser)
        local bubble = Instance.new("Frame", chatScroll)
        bubble.Size = UDim2.new(1, 0, 0, 0)
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.BackgroundColor3 = isUser and Color3.fromRGB(41, 128, 185) or Color3.fromRGB(35, 39, 50)
        Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel", bubble)
        lbl.Size = UDim2.new(1, isUser and -24 or -28, 1, -8)
        lbl.Position = UDim2.new(0, 6, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.format("<b>%s:</b> %s", sender, text)
        lbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextWrapped = true

        if not isUser then
            local reuseBtn = Instance.new("TextButton", bubble)
            reuseBtn.Size = UDim2.new(0, 18, 0, 18)
            reuseBtn.Position = UDim2.new(1, -22, 0, 4)
            reuseBtn.BackgroundTransparency = 1
            reuseBtn.Text = "📋"
            reuseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            reuseBtn.Font = Enum.Font.Gotham
            reuseBtn.TextSize = 11

            reuseBtn.MouseButton1Click:Connect(function()
                -- Fixed on mobile as well
                chatBox.Text = text:gsub("<[^<>]+>", ""):gsub("&lt;", "<"):gsub("&gt;", ">")
            end)
        end

        task.defer(function() chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y) end)
    end

    local function sendQuery()
        local txt = chatBox.Text
        if txt:match("^%s*$") then return end
        chatBox.Text = ""
        appendMessage(localPlayer.Name, txt, true)
        task.spawn(function()
            local res = callGeminiAPI(txt)
            appendMessage("GameBuddy", processResponse(res), false)
        end)
    end

    sendBtn.MouseButton1Click:Connect(sendQuery)
    chatBox.FocusLost:Connect(function(e) if e then sendQuery() end end)

    if #conversationHistory > 0 then
        for _, msg in ipairs(conversationHistory) do
            appendMessage((msg.role == "user") and localPlayer.Name or "GameBuddy", msg.parts[1].text, msg.role == "user")
        end
    else
        appendMessage("GameBuddy", "Hello " .. localPlayer.Name .. "! Ready to assist you in Delta.", false)
    end
end

if rawStoredHistory and #rawStoredHistory > 0 then buildMemoryPromptUI() else buildChatUI() end
