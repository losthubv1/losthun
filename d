-- === AUTO HEADER UPDATE SYSTEM ===
local abilityHeaders = {}
if Unit and Unit.OnChanged then
    Unit.OnChanged:Connect(function(newUnit)
        for _, hdr in ipairs(abilityHeaders) do
            if hdr and hdr.UpdateName then
                hdr:UpdateName(newUnit.Name or 'Unknown Unit')
            end
        end
    end)
end
-- === END AUTO HEADER UPDATE SYSTEM ===

-- === HEADER REGENERATION ON UNIT CHANGE (GUI-driven) ===
local player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")

abilityHeaders = abilityHeaders or {}
local watchConnections = {}
local regenDebounce = false

local function findUnitContainer()
    local success, container = pcall(function()
        local pg = player and player:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local bottom = pg:FindFirstChild("Bottom")
        if not bottom or not bottom:FindFirstChild("Frame") then return nil end
        local ch2 = bottom.Frame:GetChildren()[2]
        if not ch2 or not ch2:FindFirstChild("Frame") then return nil end
        local ch3 = ch2.Frame:GetChildren()[3]
        if not ch3 or not ch3:FindFirstChild("Frame") then return nil end
        return ch3.Frame
    end)
    if success then return container end
    return nil
end

local function getAllUnitsFromGUI()
    local out = {}
    local container = findUnitContainer()
    if not container then return out end
    for i, frame in ipairs(container:GetChildren()) do
        local f = frame:FindFirstChild("Frame")
        if f then
            local vp = f:FindFirstChild("Viewport")
            if vp and vp:FindFirstChild("WorldModel") then
                for _, unit in ipairs(vp.WorldModel:GetChildren()) do
                    table.insert(out, { name = unit.Name, ref = unit })
                end
            end
        end
    end
    return out
end

local function clearOldUI()
    for _, entry in ipairs(abilityHeaders) do
        pcall(function()
            if entry.header then
                if type(entry.header.SetVisiblity) == "function" then
                    entry.header:SetVisiblity(false)
                elseif type(entry.header.Destroy) == "function" then
                    entry.header:Destroy()
                end
            end
            if entry.dropdown then
                if type(entry.dropdown.SetVisiblity) == "function" then
                    entry.dropdown:SetVisiblity(false)
                elseif type(entry.dropdown.Destroy) == "function" then
                    entry.dropdown:Destroy()
                end
            end
            if entry.toggle then
                if type(entry.toggle.SetVisiblity) == "function" then
                    entry.toggle:SetVisiblity(false)
                elseif type(entry.toggle.Destroy) == "function" then
                    entry.toggle:Destroy()
                end
            end
        end)
    end
    abilityHeaders = {}
end

local function regenerateHeaders(unitList)
    clearOldUI()
    if not AbilitySection then return end
    for _, u in ipairs(unitList) do
        local ok, hdr = pcall(function() return AbilitySection:Header({ Text = u.name }, nil) end)
        if not ok then
            warn("Header creation failed for", u.name, hdr)
            hdr = nil
        end
        local dd = nil
        local tg = nil
        pcall(function()
            dd = AbilitySection:Dropdown({
                Name = "Condition",
                Options = { "Always", "On Boss" },
                Default = "Always",
                Callback = function(selected)
                    -- store selection per unit
                    for _, e in ipairs(abilityHeaders) do
                        if e.unitName == u.name then e.condition = selected end
                    end
                end,
            }, "ConditionDropdown")

            tg = AbilitySection:Toggle({
                Name = "Auto Ability",
                Default = false,
                Callback = function(state)
                    for _, e in ipairs(abilityHeaders) do
                        if e.unitName == u.name then e.auto = state end
                    end
                end,
            }, "AutoAbilityToggle")
        end)
        table.insert(abilityHeaders, { header = hdr, dropdown = dd, toggle = tg, unitName = u.name, unitRef = u.ref })
    end
end

local function scheduleRegen()
    if regenDebounce then return end
    regenDebounce = true
    task.spawn(function()
        task.wait(0.1)
        local units = getAllUnitsFromGUI()
        regenerateHeaders(units)
        regenDebounce = false
    end)
end

local function disconnectWatch()
    for _, conn in ipairs(watchConnections) do
        pcall(function() conn:Disconnect() end)
    end
    watchConnections = {}
end

local function watchContainer()
    disconnectWatch()
    local container = findUnitContainer()
    if not container then
        delay(0.5, watchContainer)
        return
    end
    table.insert(watchConnections, container.ChildAdded:Connect(scheduleRegen))
    table.insert(watchConnections, container.ChildRemoved:Connect(scheduleRegen))
    for _, frame in ipairs(container:GetChildren()) do
        local f = frame:FindFirstChild("Frame")
        local vp = f and f:FindFirstChild("Viewport")
        local wm = vp and vp:FindFirstChild("WorldModel")
        if wm then
            table.insert(watchConnections, wm.ChildAdded:Connect(scheduleRegen))
            table.insert(watchConnections, wm.ChildRemoved:Connect(scheduleRegen))
        end
    end
end

-- initial run
scheduleRegen()
watchContainer()

-- re-run watchContainer when PlayerGui changes
local pg = player and player:FindFirstChild("PlayerGui")
if pg then
    pg.ChildAdded:Connect(function() scheduleRegen(); watchContainer() end)
    pg.ChildRemoved:Connect(function() scheduleRegen(); watchContainer() end)
end

-- === END HEADER REGENERATION ON GUI CHANGES ===

-- Anime Ultimo Rimasto!
-- Wait for Players service and LocalPlayer to be ready
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager") -- Correct service name, re-verified

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
repeat task.wait() until LocalPlayer and LocalPlayer:IsDescendantOf(Players)

-- Load MacLib GUI
local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

-- Attempt to ensure HttpService allowed (some executors block this)
pcall(function() HttpService.HttpEnabled = true end)

-- ---------------------------
-- Filesystem: config & macros folder
-- ---------------------------
local baseFolder = "ProToolsConfigs"
local macroFolder = baseFolder .. "/Macros"

if not isfolder(baseFolder) then
    pcall(makefolder, baseFolder)
end
if not isfolder(macroFolder) then
    pcall(makefolder, macroFolder)
end

-- ---------------------------
-- Serialization helpers
-- ---------------------------
local function posToTable(pos)
    -- accepts Vector3 or CFrame or table already
    if typeof(pos) == "Vector3" then
        return { x = tonumber(string.format("%.3f", pos.X)), y = tonumber(string.format("%.3f", pos.Y)), z = tonumber(string.format("%.3f", pos.Z)) }
    elseif typeof(pos) == "CFrame" then
        local p = pos.Position
        return { x = tonumber(string.format("%.3f", p.X)), y = tonumber(string.format("%.3f", p.Y)), z = tonumber(string.format("%.3f", p.Z)) }
    elseif type(pos) == "table" and pos.x and pos.y and pos.z then
        return { x = pos.x, y = pos.y, z = pos.z }
    else
        return { x = 0, y = 0, z = 0 }
    end
end

local function cframeFromPosTable(t)
    if type(t) == "table" and t.x and t.y and t.z then
        return CFrame.new(t.x, t.y, t.z)
    end
    return CFrame.new()
end

-- ---------------------------
-- Macro load/save
-- ---------------------------
local macros = {} -- macros[name] = { { delay=number, unit=string, position={x,y,z}, action="place" } OR { delay=number, unit=string, action="upgrade", upgradeLevel=number } }

local function safe_listfiles(path)
    local ok, res = pcall(listfiles, path)
    if ok and type(res) == "table" then return res end
    return {}
end

local function loadMacros()
    macros = {}
    local files = safe_listfiles(macroFolder)
    for _, f in ipairs(files) do
        if type(f) == "string" and f:lower():sub(-5) == ".json" then
            local name = f:match("([^/\\]+)%.json$")
            if name then
                local ok, content = pcall(readfile, f)
                if ok and content then
                    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
                    if ok2 and type(data) == "table" then
                        macros[name] = data
                    else
                        -- invalid JSON -> skip
                    end
                end
            end
        end
    end
end

local function saveMacroToFile(name)
    if type(name) ~= "string" then return end
    local data = macros[name] or {}
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and encoded then
        pcall(writefile, macroFolder .. "/" .. name .. ".json", encoded)
    end
end

local function deleteMacroFile(name)
    if not name then return end
    pcall(function() delfile(macroFolder .. "/" .. name .. ".json") end)
end

-- ---------------------------
-- HUD / Money / Cost helpers - FIXED
-- ---------------------------
-- Enhanced money detection with multiple fallback methods
local function getCurrentMoney()
    -- Method 1: Direct access to LocalPlayer.Cash
    local cash = LocalPlayer:FindFirstChild("Cash")
    if cash then
        if cash:IsA("NumberValue") or cash:IsA("IntValue") then
            return cash.Value
        elseif cash:IsA("StringValue") then
            local num = tonumber(cash.Value)
            if num then
                return num
            end
        end
    end
    
    -- Method 2: Check for .Cash property directly
    local success, money = pcall(function() return LocalPlayer.Cash end)
    if success and type(money) == "number" then
        return money
    end
    
    -- Method 3: Check leaderstats
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local moneyNames = {"Cash", "Money", "Coins", "Gold", "Currency", "$"}
        for _, name in ipairs(moneyNames) do
            local cashStat = leaderstats:FindFirstChild(name)
            if cashStat and (cashStat:IsA("NumberValue") or cashStat:IsA("IntValue")) then
                return cashStat.Value
            end 
        end
    end
    
    -- Method 4: Check PlayerGui for money display
    local playerGui = LocalPlayer.PlayerGui
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("TextLabel") then
                local text = gui.Text:lower()
                if text:find("money") or text:find("cash") or text:find("coins") or text:find("%$") then
                    local amount = gui.Text:gsub("[^%d]", "")
                    local num = tonumber(amount)
                    if num and num > 0 then
                        return num
                    end
                end
            end
        end
    end
    
    return 0
end

-- NEW HELPER FUNCTION: Finds and returns the 'TotalCost' value object from a unit model in Workspace.Towers
-- It checks both inside a 'Stats' folder/ModuleScript and directly on the model.
local function findTotalCostValueObject(unitName)
    local unitModel = Workspace:FindFirstChild("Towers") and Workspace.Towers:FindFirstChild(unitName)
    if not unitModel or not unitModel:IsA("Model") then
        return nil -- Unit model not found or not a model
    end

    -- First, check within a "Stats" folder/ModuleScript
    local statsContainer = unitModel:FindFirstChild("Stats")
    if statsContainer and (statsContainer:IsA("Folder") or statsContainer:IsA("ModuleScript")) then
        local totalCost = statsContainer:FindFirstChild("TotalCost")
        if totalCost and (totalCost:IsA("NumberValue") or totalCost:IsA("IntValue")) then
            return totalCost
        end
    end

    -- Second, check for "TotalCost" directly under the unit model itself
    local totalCostDirect = unitModel:FindFirstChild("TotalCost")
    if totalCostDirect and (totalCostDirect:IsA("NumberValue") or totalCostDirect:IsA("IntValue")) then
        return totalCostDirect
    end
    
    return nil -- TotalCost not found in expected places
end

local function getUnitCost(unitName, useCurrentMultiplier)
    if not unitName then 
        return math.huge 
    end

    local baseCost = math.huge
    local totalCostMultiplier = 1 -- Default to 1 if not found

    -- FIRST: Get base cost from ReplicatedStorage.Modules.TowerInfo
    local towerInfo = ReplicatedStorage:FindFirstChild("Modules")
    if towerInfo then
        towerInfo = towerInfo:FindFirstChild("TowerInfo")
        if towerInfo then
            local unitModule = towerInfo:FindFirstChild(unitName)
            if unitModule and unitModule:IsA("ModuleScript") then
                local success, unitData = pcall(function() return require(unitModule) end)
                if success and type(unitData) == "table" then
                    if unitData[0] and unitData[0].Cost then
                        baseCost = unitData[0].Cost
                    else
                    end
                else
                end
            else
            end
        else
        end
    else
    end

    -- SECOND: Attempt to get multiplier from Workspace.Towers IF useCurrentMultiplier is true
    if useCurrentMultiplier then
        local totalCostValueObject = findTotalCostValueObject(unitName)
        if totalCostValueObject then
            totalCostMultiplier = totalCostValueObject.Value
        else
        end
    else
    end
    
    -- Calculate final cost
    if baseCost ~= math.huge then
        local finalCost = baseCost * totalCostMultiplier
        return finalCost
    else
        return math.huge
    end
end

local function getUpgradeCost(unitName, upgradeLevel)
    if not unitName or not upgradeLevel then 
        return math.huge 
    end
    
    local baseUpgradeCost = math.huge
    local totalCostMultiplier = 1 -- Default to 1

    -- Get base upgrade cost from ReplicatedStorage.Modules.TowerInfo
    local towerInfo = ReplicatedStorage:FindFirstChild("Modules")
    if towerInfo then
        towerInfo = towerInfo:FindFirstChild("TowerInfo")
        if towerInfo then
            local unitModule = towerInfo:FindFirstChild(unitName)
            if unitModule and unitModule:IsA("ModuleScript") then
                local success, unitData = pcall(function() return require(unitModule) end)
                if success and type(unitData) == "table" then
                    -- Get upgrade cost for specific level
                    if unitData[upgradeLevel] and unitData[upgradeLevel].Cost then
                        baseUpgradeCost = unitData[upgradeLevel].Cost
                    else
                    end
                else
                end
            else
            end
        else
        end
    else
    end
    
    -- Now, apply the totalCostMultiplier if it exists (for upgrade cost)
    local totalCostValueObject = findTotalCostValueObject(unitName)
    if totalCostValueObject then
        totalCostMultiplier = totalCostValueObject.Value
    else
    end

    if baseUpgradeCost ~= math.huge then
        local finalUpgradeCost = baseUpgradeCost * totalCostMultiplier
        return finalUpgradeCost
    else
        return math.huge
    end
end

-- ---------------------------
-- Map extraction helpers (MapData Module)
-- ---------------------------
local function hasType(value, match)
    if type(value) == "string" then
        return value:lower() == match:lower()
    elseif type(value) == "table" then
        for _, v in ipairs(value) do
            if type(v) == "string" and v:lower() == match:lower() then return true end
        end
    end
    return false
end

local function extractMapsByType(tbl, match)
    local out, seen = {}, {}
    if type(tbl) ~= "table" then return out end
    for k, v in pairs(tbl) do
        if type(v) == "table" and hasType(v.Type, match) then
            local name = nil
            if match == "Portal" and v.PortalData and type(v.PortalData) == "table" and v.PortalData.Map then
                name = v.PortalData.Map -- Use Map from PortalData for Portal type
            else
                name = v.Name or v.MapName or tostring(k) -- Fallback for other types
            end

            if name and not seen[name] then
                table.insert(out, name)
                seen[name] = true
            end
        end
    end
    table.sort(out)
    return out
end

-- ---------------------------
-- GUI: Window, Tabs, Sections
-- ---------------------------
local Window = MacLib:Window({
    Title = "Pro Tools",
    Subtitle = "Free | discord.gg/SVGHg9ChJe",
    Size = UDim2.fromOffset(750, 550),
    DragStyle = 2, -- Changed from 1 to 2
    DisabledWindowControls = {},
    ShowUserInfo = true,
    UserInfo = { Username = LocalPlayer.Name, UserId = LocalPlayer.UserId },
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()
local MainTab = TabGroup:Tab({ Name = "Main" }) -- Added Main Tab
local MacroTab = TabGroup:Tab({ Name = "Macro" })
local JoinerTab = TabGroup:Tab({ Name = "Joiner" })
local WebhookTab = TabGroup:Tab({ Name = "Webhook" })

-- Joiner sections
local SurvivalSection = JoinerTab:Section({ Name = "Survival Controls", Side = "Right"})
local StorySection = JoinerTab:Section({ Name = "Story Controls", Side = "Left" })
local PortalSection = JoinerTab:Section({ Name = "Portal Controls", Side = "Left" }) -- NEW Portal Section
local DungeonSection = JoinerTab:Section({ Name = "Dungeon Controls", Side = "Left" }) -- NEW Dungeon Section
local CarvernsSection = JoinerTab:Section({Name = "Carverns Controls", Side = "Left"}) -- NEW Carverns Section
local LegendSection = JoinerTab:Section({ Name = "Legendary Stage Controls", Side = "Right" })
local RaidSection = JoinerTab:Section({ Name = "Raid Controls", Side = "Right" }) -- NEW Raid Section
local HxHSection = JoinerTab:Section({ Name = "HxH Controls", Side = "Right" }) 
local RushSection = MainTab:Section({ Name = "Rush Controls", Side = "Right" }) 
local BreachSection = JoinerTab:Section({ Name = "Breach Controls", Side = "Right" }) 
-- Macro section
local MacroSection = MacroTab:Section({ Name = "Macro Controls", Side = "Right" })
local AbilitySection = MacroTab:Section({ Name = "Macro ts", Side = "Left" })
-- Main Tab sections
local MainLeftSection = MainTab:Section({ Name = "General Controls", Side = "Left" }) -- Renamed for clarity
local MainRightSection = MainTab:Section({ Name = "Automation Controls", Side = "Right" }) -- New section for automation toggles
local MainBottomSection = MainTab:Section({ Name = "Misc Controls", Side = "Left" }) 
-- ---------------------------
-- Main Tab UI & Logic
-- ---------------------------
-- Store the selected summon type
local selectedSummonType = "1x Gems"

local SummonDropdown = MainBottomSection:Dropdown({
    Name = "Summon",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"1x Gems", "10x Gems", "1x Jewels", "10x Jewels"},
    Callback = function(val)
        selectedSummonType = val
    end,
}, "SummonDropdown")

-- Variables for loop control
local summonLoop = nil

MainBottomSection:Toggle({
    Name = "Summon",
    Default = false,
    Callback = function(state)
        if state then
            if not summonLoop then
                summonLoop = task.spawn(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local Summon = ReplicatedStorage.Remotes:FindFirstChild("Summon")

                    if not Summon then
                        warn("[Summon] Remote not found!")
                        return
                    end

                    while true do
                        -- Determine args based on selected type
                        if selectedSummonType == "1x Gems" then
                            Summon:InvokeServer(1, "1")
                        elseif selectedSummonType == "10x Gems" then
                            Summon:InvokeServer(10, "1")
                        elseif selectedSummonType == "1x Jewels" then
                            Summon:InvokeServer(1, "3")
                        elseif selectedSummonType == "10x Jewels" then
                            Summon:InvokeServer(10, "3")
                        else
                            warn("[Summon] Unknown summon type:", tostring(selectedSummonType))
                        end
                        task.wait(0.5)
                    end
                end)
            end
        else
            if summonLoop then
                task.cancel(summonLoop)
                summonLoop = nil
            end
        end
    end,
}, "SummonToggle")

-- Auto Start Toggle
-- Auto Start (modified to check for button visibility)
local autoStartConnection = nil
MainLeftSection:Toggle({
    Name = "Auto Start",
    Default = false,
    Callback = function(state)
        if state then
            if not autoStartConnection then
                autoStartConnection = RunService.RenderStepped:Connect(function()
                    local lp = Players.LocalPlayer
                    local btn = nil
                    
                    pcall(function()
                        btn = lp.PlayerGui.Bottom.Frame:GetChildren()[2]:GetChildren()[6].TextButton
                    end)

                    if btn and btn.Visible then
                        local PlayerReady = ReplicatedStorage:FindFirstChild("Remotes") 
                            and ReplicatedStorage.Remotes:FindFirstChild("PlayerReady")
                        if PlayerReady then
                            PlayerReady:FireServer()
                        end
                    end
                end)
                Window:Notify({ Title = "Pro Tools", Description = "Auto Start: Enabled", Lifetime = 3 })
            end
        else
            if autoStartConnection then
                autoStartConnection:Disconnect()
                autoStartConnection = nil
                Window:Notify({ Title = "Pro Tools", Description = "Auto Start: Disabled", Lifetime = 3 })
            end
        end
    end,
}, "AutoStartToggle")



-- Auto Next Toggle (New)
local autoNextConnection = nil
local isAutoNextEnabled = false

local function getNextButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local endUI = pg:FindFirstChild("EndGameUI")
    if not endUI then return nil end

    local bg = endUI:FindFirstChild("BG")
    if not bg then return nil end

    local buttons = bg:FindFirstChild("Buttons")
    if not buttons then return nil end

    return buttons:FindFirstChild("Next")
end

local function pressNext(nextButton)
    -- Select in UI navigation
    GuiService.SelectedObject = nextButton
    task.wait()

    -- PC confirm
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

    -- Gamepad/Mobile confirm
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonA, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonA, false, game)

    task.wait(0.15) -- let activation process
    GuiService.SelectedObject = nil -- exit UI navigation mode
end

MainRightSection:Toggle({
    Name = "Auto Next",
    Default = false,
    Callback = function(state)
        isAutoNextEnabled = state
        if state then
            if not autoNextConnection then
                local lastClick = 0
                autoNextConnection = RunService.RenderStepped:Connect(function()
                    local nextButton = getNextButton()
                    if nextButton and nextButton.Visible and nextButton.Parent and nextButton.Parent.Visible then
                        if tick() - lastClick > 2 then -- 2 second cooldown
                            pressNext(nextButton)
                            lastClick = tick()
                        end
                    end
                end)
                Window:Notify({ Title = "Pro Tools", Description = "Auto Next: Enabled", Lifetime = 3 })
            end
        else
            if autoNextConnection then
                pcall(function() autoNextConnection:Disconnect() end)
                autoNextConnection = nil
                Window:Notify({ Title = "Pro Tools", Description = "Auto Next: Disabled", Lifetime = 3 })
            end
        end
    end,
}, "AutoNextToggle")



-- Auto Retry Toggle (New)
local autoRetryConnection = nil
local isAutoRetryEnabled = false

local function getRetryButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local endUI = pg:FindFirstChild("EndGameUI")
    if not endUI then return nil end

    local bg = endUI:FindFirstChild("BG")
    if not bg then return nil end

    local buttons = bg:FindFirstChild("Buttons")
    if not buttons then return nil end

    return buttons:FindFirstChild("Retry")
end

local function pressRetry(retryButton)
    -- Select it in UI navigation
    GuiService.SelectedObject = retryButton
    task.wait() -- let selection register

    -- Simulate confirm press for PC (Return key)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

    -- Simulate confirm press for gamepad/mobile navigation (ButtonA)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonA, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonA, false, game)

    task.wait(0.15) -- let activation process
    GuiService.SelectedObject = nil -- exit UI navigation mode
end

MainRightSection:Toggle({
    Name = "Auto Retry",
    Default = false,
    Callback = function(state)
        isAutoRetryEnabled = state
        if state then
            if not autoRetryConnection then
                local lastClick = 0
                autoRetryConnection = RunService.RenderStepped:Connect(function()
                    local retryButton = getRetryButton()
                    if retryButton and retryButton.Visible and retryButton.Parent and retryButton.Parent.Visible then
                        if tick() - lastClick > 2 then -- 2 second cooldown
                            pressRetry(retryButton)
                            lastClick = tick()
                        end
                    end
                end)
                Window:Notify({ Title = "Pro Tools", Description = "Auto Retry: Enabled", Lifetime = 3 })
            end
        else
            if autoRetryConnection then
                pcall(function() autoRetryConnection:Disconnect() end)
                autoRetryConnection = nil -- ✅ fixed var name
                Window:Notify({ Title = "Pro Tools", Description = "Auto Retry: Disabled", Lifetime = 3 })
            end
        end
    end,
}, "AutoRetryToggle")



-- ---------------------------
-- Joiner UI (Story + Legendary + Raids)
-- ---------------------------
local selectedStoryMap, selectedStoryAct = nil, "1"
local selectedLegendMap, selectedLegendAct = nil, "1"
local selectedRaidMap = nil -- NEW Raid map variable
local selectedRaidArc = "1" -- NEW Raid arc variable
local selectedPortalMap = nil -- NEW Portal map variable
local selectedChallenges = {} -- NEW Challenges variable (for multi-select)
local selectedTier = "1" -- NEW Tier variable, default to 1
local selectedCavern = nil -- NEW Carverns variable
local selectedCavernDifficulty = "Normal" -- NEW Carverns Difficulty variable, default to Normal

local StoryDropdown = StorySection:Dropdown({
    Name = "Story",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedStoryMap = val end,
}, "StoryDropdown")

local StoryActs = StorySection:Dropdown({
    Name = "Acts",
    Options = {"1","2","3","4","5","6"},
    Callback = function(val) selectedStoryAct = val end,
}, "StoryActsDropdown")

-- NEW Boss Rush Dropdown (inside HxHSection)
local selectedBossRushMap = nil

local BossRushDropdown = HxHSection:Dropdown({
    Name = "Boss Rush",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val)
        selectedBossRushMap = val
    end,
}, "BossRushDropdown")

-- Populate Boss Rush maps from MapData
task.spawn(function()
    local ok, mapData = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapData"))
    end)
    if ok and type(mapData) == "table" then
        local bossRushMaps = extractMapsByType(mapData, "BossRush")

        BossRushDropdown:ClearOptions()
        if #bossRushMaps > 0 then
            BossRushDropdown:InsertOptions(bossRushMaps)
            selectedBossRushMap = bossRushMaps[1]
        else
            BossRushDropdown:InsertOptions({"No Boss Rush Maps Found"})
            selectedBossRushMap = nil
        end
    else
        warn("Failed to load MapData for Boss Rush")
    end
end)


local SurvivalDropdown = SurvivalSection:Dropdown({
    Name = "Survivals",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedSurvival = val end,
}, "SurvivalDropdown")

local DungeonDropdown = DungeonSection:Dropdown({
    Name = "Dungeons",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedDungeon = val end,
}, "DungeonDropdown")

-- NEW Portal Dropdown
local PortalDropdown = PortalSection:Dropdown({ -- Moved to PortalSection
    Name = "Portals",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedPortalMap = val end,
}, "PortalDropdown")

-- NEW Challenges Dropdown - Moved inside PortalSection
local ChallengesDropdown = PortalSection:Dropdown({ -- Moved to PortalSection
    Name = "Challenges",
    Search = true,
    Multi = true, -- Multi-option as requested
    Required = false,
    Options = {"Loading..."},
    Callback = function(values) selectedChallenges = values end,
}, "ChallengesDropdown")

-- NEW Tier Dropdown - Added inside PortalSection
local TierDropdown = PortalSection:Dropdown({
    Name = "Tier",
    Options = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"},
    Callback = function(val) selectedTier = val end,
}, "TierDropdown")

-- NEW Carverns Dropdown
local CarvernsDropdown = CarvernsSection:Dropdown({
    Name = "Carverns",
    Options = {"Light", "Water", "Dark", "Nature", "Fire"},
    Callback = function(val) selectedCavern = val end,
}, "CarvernsDropdown")

-- NEW Carverns Difficulty Dropdown
local CarvernsDifficultyDropdown = CarvernsSection:Dropdown({
    Name = "Difficulty",
    Options = {"Normal", "Nightmare", "Purgatory", "Insanity"},
    Callback = function(val) selectedCavernDifficulty = val end,
}, "CarvernsDifficultyDropdown")
-- NEW Join Cavern Toggle
CarvernsSection:Toggle({
    Name = "Join Cavern",
    Default = false,
    Callback = function(state)
        if state and selectedCavern and selectedCavernDifficulty then
            local teleFolder = Workspace:FindFirstChild("TeleporterFolder")
            if not teleFolder then
                Window:Notify({ Title = "Pro Tools", Description = "TeleporterFolder not found.", Lifetime = 3, Style = "Error" })
                return
            end

            local cavernsFolder = teleFolder:FindFirstChild("ElementalCaverns")
            if not cavernsFolder then
                Window:Notify({ Title = "Pro Tools", Description = "ElementalCaverns folder not found.", Lifetime = 3, Style = "Error" })
                return
            end

            local targetDoor = nil
            for _, teleporter in ipairs(cavernsFolder:GetChildren()) do
                if teleporter:IsA("Model") then
                    local door = teleporter:FindFirstChild("Door")
                    local ui = door and door:FindFirstChild("UI")
                    local pcLabel = ui and ui:FindFirstChild("PlayerCount")
                    if pcLabel and pcLabel:IsA("TextLabel") and pcLabel.Text == "0/6 Players" then
                        targetDoor = door
                        break
                    end
                end
            end

            if not targetDoor then
                Window:Notify({ Title = "Pro Tools", Description = "No cavern teleporter with 0/6 Players found.", Lifetime = 3 })
                return
            end

            -- Simulate touch
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                firetouchinterest(hrp, targetDoor, 0)
                task.wait(0.15)
                firetouchinterest(hrp, targetDoor, 1)
            end

            task.wait(0.3) -- Wait for UI to load

            -- Fire Interact remote
            local Interact = ReplicatedStorage:FindFirstChild("Remotes") 
                and ReplicatedStorage.Remotes:FindFirstChild("Teleporter") 
                and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")
            if Interact then
                pcall(function()
                    Interact:FireServer("Select", selectedCavern, selectedCavernDifficulty)
                    task.wait(0.08)
                    Interact:FireServer("Skip")
                end)
                Window:Notify({ Title = "Pro Tools", Description = "Joined Cavern: " .. selectedCavern .. " (" .. selectedCavernDifficulty .. ")", Lifetime = 3 })
            else
                Window:Notify({ Title = "Pro Tools", Description = "Teleporter.Interact remote not found.", Lifetime = 3, Style = "Error" })
            end
        end
    end
})

local LegendDropdown = LegendSection:Dropdown({
    Name = "Legendstages",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedLegendMap = val end,
}, "LegendDropdown")

local LegendActs = LegendSection:Dropdown({
    Name = "Acts",
    Options = {"1","2","3"},
    Callback = function(val) selectedLegendAct = val end,
}, "LegendActsDropdown")

-- NEW Raid Dropdown
local RaidDropdown = RaidSection:Dropdown({
    Name = "Raids",
    Search = true,
    Multi = false,
    Required = false,
    Options = {"Loading..."},
    Callback = function(val) selectedRaidMap = val end,
}, "RaidDropdown")

-- NEW Raid Arc Dropdown
local RaidArcDropdown = RaidSection:Dropdown({
    Name = "Arc",
    Options = {"1", "2", "3", "4", "5", "6"},
    Callback = function(val) selectedRaidArc = val end,
}, "RaidArcDropdown")


-- Populate maps from ReplicatedStorage.Modules.MapData
task.spawn(function()
    local ok, success = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapData"))
    end)
    if ok and type(success) == "table" then
        local storyMaps = extractMapsByType(success, "Story")
        local dungeonMaps = extractMapsByType(success, "Dungeon")
        local legendMaps = extractMapsByType(success, "LegendaryStages")
        local raidMaps = extractMapsByType(success, "Raids") -- Fetch Raid maps
        local portalMapsFromMapData = extractMapsByType(success, "Portal") -- Fetch Portal maps from MapData
        local survivalMaps = extractMapsByType(success, "Survival")

SurvivalDropdown:ClearOptions()
if #survivalMaps > 0 then
    SurvivalDropdown:InsertOptions(survivalMaps)
    selectedSurvivalMap = survivalMaps[1]
else
    SurvivalDropdown:InsertOptions({"No Survival Maps Found"})
    selectedSurvivalMap = nil
end

        local portalMapsFromReplica = {}
        local replicaHolderSuccess, replicaHolderModule = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ReplicaHolder")) end)
        if replicaHolderSuccess and replicaHolderModule then
            local playerDataReplica = replicaHolderModule.GetReplicaOfClass("PlayerData")
            if playerDataReplica and playerDataReplica.Data and playerDataReplica.Data.PortalData then
                local seenPortalMapNames = {}
                for portalId, portalInfo in pairs(playerDataReplica.Data.PortalData) do
                    if portalInfo.PortalData and portalInfo.PortalData.Map and not seenPortalMapNames[portalInfo.PortalData.Map] then
                        table.insert(portalMapsFromReplica, portalInfo.PortalData.Map)
                        seenPortalMapNames[portalInfo.PortalData.Map] = true
                    end
                end
                table.sort(portalMapsFromReplica)
            else
                warn("PlayerData replica or PortalData not available for populating portal dropdown.")
            end
        else
            warn("ReplicaHolder module not found for populating portal dropdown.")
        end

        -- Combine and deduplicate portal maps from both sources
        local combinedPortalMaps = {}
        local seenCombinedPortalMaps = {}

        for _, mapName in ipairs(portalMapsFromMapData) do
            if not seenCombinedPortalMaps[mapName] then
                table.insert(combinedPortalMaps, mapName)
                seenCombinedPortalMaps[mapName] = true
            end
        end

        for _, mapName in ipairs(portalMapsFromReplica) do
            if not seenCombinedPortalMaps[mapName] then
                table.insert(combinedPortalMaps, mapName)
                seenCombinedPortalMaps[mapName] = true
            end
        end
        table.sort(combinedPortalMaps)

        if DungeonDropdown then
            DungeonDropdown:ClearOptions()
            if #dungeonMaps > 0 then DungeonDropdown:InsertOptions(dungeonMaps); selectedDungeonMap = dungeonMaps[1]
            else DungeonDropdown:InsertOptions({"No Dungeons Found"}); selectedDungeonMap = nil end
        end

        if StoryDropdown then
            StoryDropdown:ClearOptions()
            if #storyMaps > 0 then StoryDropdown:InsertOptions(storyMaps); selectedStoryMap = storyMaps[1]
            else StoryDropdown:InsertOptions({"No Story Maps Found"}); selectedStoryMap = nil end
        end

        if LegendDropdown then
            LegendDropdown:ClearOptions() 
            if #legendMaps > 0 then LegendDropdown:InsertOptions(legendMaps); selectedLegendMap = legendMaps[1]
            else LegendDropdown:InsertOptions({"No Legendary Stages Found"}); selectedLegendMap = nil end
        end
        
        if RaidDropdown then
            RaidDropdown:ClearOptions() -- Clear options for Raid dropdown
            if #raidMaps > 0 then RaidDropdown:InsertOptions(raidMaps); selectedRaidMap = raidMaps[1] -- Insert Raid maps
            else RaidDropdown:InsertOptions({"No Raid Maps Found"}); selectedRaidMap = nil end -- Default if no raids found
        end

        if PortalDropdown then
            PortalDropdown:ClearOptions() -- Clear options for Portal dropdown
            if #combinedPortalMaps > 0 then PortalDropdown:InsertOptions(combinedPortalMaps); selectedPortalMap = combinedPortalMaps[1] -- Insert combined Portal maps
            else PortalDropdown:InsertOptions({"No Portals Found"}); selectedPortalMap = nil end -- Default if no portals found
        end
    end

    -- Populate Challenges from ReplicatedStorage.Modules.ChallengeInfo
    local ChallengesDropdown = nil -- Declare ChallengesDropdown locally for this scope
    if PortalSection then
    if typeof(PortalSection) == "Instance" then
        ChallengesDropdown = PortalSection:FindFirstChild("ChallengesDropdown") -- Find it if it was created
    end
    end

    local challengeInfoSuccess, challengeInfoModule = pcall(function() 
        return ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ChallengeInfo", 5)
    end)

    local challengeNames = {}
    -- If ChallengeInfo is a ModuleScript, require it to get its table contents
    if challengeInfoSuccess and challengeInfoModule and challengeInfoModule:IsA("ModuleScript") then
        local successRequire, challengeData = pcall(function() return require(challengeInfoModule) end)
        if successRequire and type(challengeData) == "table" then
            for name, _ in pairs(challengeData) do -- Iterate over keys (challenge names)
                table.insert(challengeNames, name)
            end
        else
            warn("Failed to require ChallengeInfo module or it's not a table: " .. tostring(challengeData))
        end
    else
        -- Log if ChallengeInfo is not found or not a ModuleScript
        if not challengeInfoSuccess or not challengeInfoModule then
            warn("ChallengeInfo ModuleScript not found in ReplicatedStorage.Modules!")
        elseif challengeInfoModule and not challengeInfoModule:IsA("ModuleScript") then
            warn("ChallengeInfo exists but is not a ModuleScript. Type: " .. challengeInfoModule.ClassName)
        end
    end

    if ChallengesDropdown then
        ChallengesDropdown:ClearOptions()
        if #challengeNames > 0 then
            table.sort(challengeNames) -- Sort alphabetically after populating
            ChallengesDropdown:InsertOptions(challengeNames)
            -- For multi-select, initial selection might be empty or first few
            selectedChallenges = {} 
        else
            ChallengesDropdown:InsertOptions({"No Challenges Found"})
            selectedChallenges = {}
        end
    end

    -- Set initial value for Carverns dropdown
    local CarvernsDropdown = nil
    if CarvernsSection then
    if typeof(CarvernsSection) == "Instance" then
        CarvernsDropdown = CarvernsSection:FindFirstChild("CarvernsDropdown")
    end
    end
    if CarvernsDropdown then
        local carvernsOptions = {"Light", "Water", "Dark", "Nature", "Fire"}
        if #carvernsOptions > 0 then
            selectedCavern = carvernsOptions[1]
            CarvernsDropdown:SelectOption(selectedCavern)
        else
            selectedCavern = nil
        end
    end

    -- Set initial value for Carverns Difficulty dropdown
    local CarvernsDifficultyDropdown = nil
    if CarvernsSection then
    if typeof(CarvernsSection) == "Instance" then
        CarvernsDifficultyDropdown = CarvernsSection:FindFirstChild("DifficultyDropdown")
    end
    end
    if CarvernsDifficultyDropdown then
        local carvernsDifficultyOptions = {"Normal", "Nightmare", "Purgatory", "Insanity"}
        if #carvernsDifficultyOptions > 0 then
            selectedCavernDifficulty = carvernsDifficultyOptions[1]
            CarvernsDifficultyDropdown:SelectOption(selectedCavernDifficulty)
        else
            selectedCavernDifficulty = nil
        end
    end


    -- Listener for dynamic portal updates
    if replicaHolderSuccess and replicaHolderModule and PortalDropdown then
        local playerDataReplica = replicaHolderModule.GetReplicaOfClass("PlayerData")
        if playerDataReplica then
            playerDataReplica:ListenToChange("PortalData", function(newPortalData)
                local updatedPortalMapsFromReplica = {}
                local seenUpdatedPortalMapNames = {}
                for portalId, portalInfo in pairs(newPortalData) do
                    if portalInfo.PortalData and portalInfo.PortalData.Map and not seenUpdatedPortalMapNames[portalInfo.PortalData.Map] then
                        table.insert(updatedPortalMapsFromReplica, portalInfo.PortalData.Map)
                        seenUpdatedPortalMapNames[portalInfo.PortalData.Map] = true
                        end
                    end
                -- Re-extract from MapData and combine again
                local currentMapDataSuccess, currentMapDataModule = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapData")) end)
                local currentPortalMapsFromMapData = {}
                if currentMapDataSuccess and type(currentMapDataModule) == "table" then
                    currentPortalMapsFromMapData = extractMapsByType(currentMapDataModule, "Portal")
                end

                local combinedUpdatedPortalMaps = {}
                local seenCombinedUpdatedPortalMaps = {}
                for _, mapName in ipairs(currentPortalMapsFromMapData) do
                    if not seenCombinedUpdatedPortalMaps[mapName] then
                        table.insert(combinedUpdatedPortalMaps, mapName)
                        seenCombinedUpdatedPortalMaps[mapName] = true
                    end
                end
                for _, mapName in ipairs(updatedPortalMapsFromReplica) do
                    if not seenCombinedUpdatedPortalMaps[mapName] then
                        table.insert(combinedUpdatedPortalMaps, mapName)
                        seenCombinedUpdatedPortalMaps[mapName] = true
                    end
                end
                table.sort(combinedUpdatedPortalMaps)

                PortalDropdown:ClearOptions()
                if #combinedUpdatedPortalMaps > 0 then
                    PortalDropdown:InsertOptions(combinedUpdatedPortalMaps)
                    selectedPortalMap = combinedUpdatedPortalMaps[1] -- Select first new map
                else
                    PortalDropdown:InsertOptions({"No Portals Found"})
                    selectedPortalMap = nil
                end
                Window:Notify({ Title = "Pro Tools", Description = "Portal list updated.", Lifetime = 2 })
            end)
        end
    end
end)
    if ok and type(success) == "table" then
        local storyMaps = extractMapsByType(success, "Story")
        local legendMaps = extractMapsByType(success, "LegendaryStages")
        local raidMaps = extractMapsByType(success, "Raids") -- Fetch Raid maps
        -- Modified portal map extraction to use ReplicaHolder for current portal data
        local portalMapsFromReplica = {}
        local replicaHolderSuccess, replicaHolderModule = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ReplicaHolder")) end)
        if replicaHolderSuccess and replicaHolderModule then
            local playerDataReplica = replicaHolderModule.GetReplicaOfClass("PlayerData")
            if playerDataReplica and playerDataReplica.Data and playerDataReplica.Data.PortalData then
                local seenPortalMapNames = {}
                for portalId, portalInfo in pairs(playerDataReplica.Data.PortalData) do
                    if portalInfo.PortalData and portalInfo.PortalData.Map and not seenPortalMapNames[portalInfo.PortalData.Map] then
                        table.insert(portalMapsFromReplica, portalInfo.PortalData.Map)
                        seenPortalMapNames[portalInfo.PortalData.Map] = true
                    end
                end
                table.sort(portalMapsFromReplica)
            else
                warn("PlayerData replica or PortalData not available for populating portal dropdown.")
            end
        else
            warn("ReplicaHolder module not found for populating portal dropdown.")
        end

        StoryDropdown:ClearOptions()
        if #storyMaps > 0 then StoryDropdown:InsertOptions(storyMaps); selectedStoryMap = storyMaps[1]
        else StoryDropdown:InsertOptions({"No Story Maps Found"}); selectedStoryMap = nil end

        LegendDropdown:ClearOptions() 
        if #legendMaps > 0 then LegendDropdown:InsertOptions(legendMaps); selectedLegendMap = legendMaps[1]
        else LegendDropdown:InsertOptions({"No Legendary Stages Found"}); selectedLegendMap = nil end
        
RaidDropdown:ClearOptions() -- Clear options for Raid dropdown
        if #raidMaps > 0 then RaidDropdown:InsertOptions(raidMaps); selectedRaidMap = raidMaps[1] -- Insert Raid maps
        else RaidDropdown:InsertOptions({"No Raid Maps Found"}); selectedRaidMap = nil end -- Default if no raids found

        PortalDropdown:ClearOptions() -- Clear options for Portal dropdown
        if #portalMapsFromReplica > 0 then PortalDropdown:InsertOptions(portalMapsFromReplica); selectedPortalMap = portalMapsFromReplica[1] -- Insert Portal maps
        else PortalDropdown:InsertOptions({"No Portals Found"}); selectedPortalMap = nil end -- Default if no portals found
    end

    -- Populate Challenges from ReplicatedStorage.Modules.ChallengeInfo
    local challengeInfoSuccess, challengeInfoModule = pcall(function() 
        return ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ChallengeInfo", 5)
    end)

    local challengeNames = {}
    -- If ChallengeInfo is a ModuleScript, require it to get its table contents
    if challengeInfoSuccess and challengeInfoModule and challengeInfoModule:IsA("ModuleScript") then
        local successRequire, challengeData = pcall(function() return require(challengeInfoModule) end)
        if successRequire and type(challengeData) == "table" then
            for name, _ in pairs(challengeData) do -- Iterate over keys (challenge names)
                table.insert(challengeNames, name)
            end
        else
            warn("Failed to require ChallengeInfo module or it's not a table: " .. tostring(challengeData))
        end
    else
        -- Log if ChallengeInfo is not found or not a ModuleScript
        if not challengeInfoSuccess or not challengeInfoModule then
            warn("ChallengeInfo ModuleScript not found in ReplicatedStorage.Modules!")
        elseif challengeInfoModule and not challengeInfoModule:IsA("ModuleScript") then
            warn("ChallengeInfo exists but is not a ModuleScript. Type: " .. challengeInfoModule.ClassName)
        end
    end

    ChallengesDropdown:ClearOptions()
    if #challengeNames > 0 then
        table.sort(challengeNames) -- Sort alphabetically after populating
        ChallengesDropdown:InsertOptions(challengeNames)
        -- For multi-select, initial selection might be empty or first few
        selectedChallenges = {} 
    else
        ChallengesDropdown:InsertOptions({"No Challenges Found"})
        selectedChallenges = {}
    end

    -- Set initial value for Carverns dropdown
    local carvernsOptions = {"Light", "Water", "Dark", "Nature", "Fire"}
    if #carvernsOptions > 0 then
        selectedCavern = carvernsOptions[1]
    else
        selectedCavern = nil
    end

    -- Set initial value for Carverns Difficulty dropdown
    local carvernsDifficultyOptions = {"Normal", "Nightmare", "Purgatory", "Insanity"}
    if #carvernsDifficultyOptions > 0 then
        selectedCavernDifficulty = carvernsDifficultyOptions[1]
    else
        selectedCavernDifficulty = nil
    end

    -- Listener for dynamic portal updates
    if playerDataReplica then
        playerDataReplica:ListenToChange("PortalData", function(newPortalData)
            local updatedPortalMaps = {}
            local seenUpdatedPortalMapNames = {}
            for portalId, portalInfo in pairs(newPortalData) do
                if portalInfo.PortalData and portalInfo.PortalData.Map and not seenUpdatedPortalMapNames[portalInfo.PortalData.Map] then
                    table.insert(updatedPortalMaps, portalInfo.PortalData.Map)
                    seenUpdatedPortalMapNames[portalInfo.PortalData.Map] = true
                end
            end
            table.sort(updatedPortalMaps)
            PortalDropdown:ClearOptions()
            if #updatedPortalMaps > 0 then
                PortalDropdown:InsertOptions(updatedPortalMaps)
                selectedPortalMap = updatedPortalMaps[1] -- Select first new map
            else
                PortalDropdown:InsertOptions({"No Portals Found"})
                selectedPortalMap = nil
            end
            Window:Notify({ Title = "Pro Tools", Description = "Portal list updated.", Lifetime = 2 })
        end)
    end

-- Helper function to check if selected challenges match portal's challenges
local function areChallengesMatching(portalChallenges, selectedChallenges)
    local portalChallengesSet = {}
    
    -- Ensure portalChallenges is treated as a set of lowercase strings for efficient lookup
    local challengesToProcessForPortal = {}
    if type(portalChallenges) == "string" and portalChallenges ~= "" then
        table.insert(challengesToProcessForPortal, portalChallenges)
    elseif type(portalChallenges) == "table" then
        for _, c in ipairs(portalChallenges) do
            if type(c) == "string" and c ~= "" then
                table.insert(challengesToProcessForPortal, c)
            end
        end
    end

    for _, c_str in ipairs(challengesToProcessForPortal) do
        portalChallengesSet[c_str:lower()] = true
    end

    local userSelectedList = {}
    local userHasExplicitlySelectedChallenges = false
    -- MacLib's Multi dropdown passes selected options as keys with boolean `true` values
    if type(selectedChallenges) == "table" then
        for challengeName, isSelected in pairs(selectedChallenges) do
            if isSelected then
                table.insert(userSelectedList, challengeName)
                userHasExplicitlySelectedChallenges = true
            end
        end
    end
    table.sort(userSelectedList) -- Ensure sorted for consistent comparison

    -- Scenario 1: User selected NO challenges in the UI
    if not userHasExplicitlySelectedChallenges then
        -- Match if portal has no challenges (empty set). "barebones" is now treated as a specific challenge.
        if next(portalChallengesSet) == nil then
            return true
        else
            return false
        end
    else -- Scenario 2: User HAS selected specific challenges in the UI (OR logic for matches)
        -- Check if ANY of the user-selected challenges exist in the portal's challenges
        for _, selectedC in ipairs(userSelectedList) do
            if portalChallengesSet[selectedC:lower()] then -- Convert selectedC to lowercase for lookup
                return true -- Found at least one match, so it's a match
            end
        end

        return false -- No overlap found
    end
end

-- NEW: Dedicated function for Survival Teleport (find 0/4 Players like Raid)
local function doSurvivalTeleport(survivalMapName)
    if not survivalMapName then
        Window:Notify({ Title = "Pro Tools", Description = "No survival map selected.", Lifetime = 3 })
        return
    end

    local Interact = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Teleporter")
        and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")

    if not Interact then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter.Interact remote not found for Survival.", Lifetime = 5, Style = "Error" })
        return
    end

    local teleporterFolder = Workspace:FindFirstChild("TeleporterFolder")
    if not teleporterFolder then
        Window:Notify({ Title = "Pro Tools", Description = "TeleporterFolder not found in Workspace.", Lifetime = 5, Style = "Error" })
        return
    end

    local survivalFolder = teleporterFolder:FindFirstChild("Survival")
    if not survivalFolder then
        Window:Notify({ Title = "Pro Tools", Description = "Survival folder not found in TeleporterFolder.", Lifetime = 5, Style = "Error" })
        return
    end

    -- Find an available survival teleporter with "0/4 Players"
    local targetTeleporter = nil
    local doorPart = nil
    local uiContainer = nil
    local playerCountLabel = nil

    for _, teleporterModel in ipairs(survivalFolder:GetChildren()) do
        if teleporterModel:IsA("Model") then
            local currentDoorPart = teleporterModel:FindFirstChild("Door")
            local currentUiContainer = currentDoorPart and currentDoorPart:FindFirstChild("UI")
            local currentPlayerCountLabel = currentUiContainer and currentUiContainer:FindFirstChild("PlayerCount")

            if currentPlayerCountLabel and currentPlayerCountLabel.Text == "0/4 Players" then
                targetTeleporter = teleporterModel
                doorPart = currentDoorPart
                uiContainer = currentUiContainer
                playerCountLabel = currentPlayerCountLabel
                break
            end
        end
    end

    if not targetTeleporter then
        Window:Notify({ Title = "Pro Tools", Description = "No available survival teleporter with 0/4 Players found.", Lifetime = 5, Style = "Warning" })
        return
    end

    if not doorPart then
        Window:Notify({ Title = "Pro Tools", Description = "Survival Door part not found for the selected teleporter. Cannot join.", Lifetime = 5, Style = "Error" })
        return
    end

    -- Simulate player touch (move to door and back)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    local originalCFrame = hrp.CFrame
    local doorPosition = doorPart.CFrame.Position
    local touchOffset = Vector3.new(0, 3, 0)

    hrp.CFrame = CFrame.new(doorPosition + touchOffset)
    task.wait(0.15)
    hrp.CFrame = originalCFrame
    task.wait(0.1)

    -- Fire Interact Remote to select survival map (assume act/arc 1 and Normal mode; adjust if needed)
    local interactSuccess, interactError = pcall(function()
        Interact:FireServer(
            "Select",
            survivalMapName,
            1,          -- act/arc (use 1 unless the game uses a different parameter)
            "Normal",   -- mode (match how raids used "Normal")
            "Survival"  -- type
        )
    end)

    if interactSuccess then
        Window:Notify({ Title = "Pro Tools", Description = "Fired Teleporter.Interact for survival: " .. survivalMapName, Lifetime = 3 })
        task.wait(0.08)
        pcall(function() Interact:FireServer("Skip") end)
        task.wait(0.5)
    else
        Window:Notify({ Title = "Pro Tools", Description = "Failed to fire Teleporter.Interact for survival: " .. tostring(interactError), Lifetime = 5, Style = "Error" })
    end
end

-- NEW: Dedicated function for Dungeon Teleport (find 0/4 Players like Raid/Survival)
local function doDungeonTeleport(dungeonMapName)
    if not dungeonMapName then
        Window:Notify({ Title = "Pro Tools", Description = "No dungeon map selected.", Lifetime = 3 })
        return
    end

    local Interact = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Teleporter")
        and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")

    if not Interact then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter.Interact remote not found for Dungeon.", Lifetime = 5, Style = "Error" })
        return
    end

    local teleporterFolder = Workspace:FindFirstChild("TeleporterFolder")
    if not teleporterFolder then
        Window:Notify({ Title = "Pro Tools", Description = "TeleporterFolder not found in Workspace.", Lifetime = 5, Style = "Error" })
        return
    end

    local dungeonFolder = teleporterFolder:FindFirstChild("Dungeon")
    if not dungeonFolder then
        Window:Notify({ Title = "Pro Tools", Description = "Dungeon folder not found in TeleporterFolder.", Lifetime = 5, Style = "Error" })
        return
    end

    -- Find an available dungeon teleporter with "0/4 Players"
    local targetTeleporter = nil
    local doorPart = nil

    for _, teleporterModel in ipairs(dungeonFolder:GetChildren()) do
        if teleporterModel:IsA("Model") then
            local currentDoorPart = teleporterModel:FindFirstChild("Door")
            local currentUiContainer = currentDoorPart and currentDoorPart:FindFirstChild("UI")
            local currentPlayerCountLabel = currentUiContainer and currentUiContainer:FindFirstChild("PlayerCount")

            if currentPlayerCountLabel and currentPlayerCountLabel.Text == "0/4 Players" then
                targetTeleporter = teleporterModel
                doorPart = currentDoorPart
                break
            end
        end
    end

    if not targetTeleporter then
        Window:Notify({ Title = "Pro Tools", Description = "No available dungeon teleporter with 0/4 Players found.", Lifetime = 5, Style = "Warning" })
        return
    end

    if not doorPart then
        Window:Notify({ Title = "Pro Tools", Description = "Dungeon Door part not found for the selected teleporter. Cannot join.", Lifetime = 5, Style = "Error" })
        return
    end

    -- Simulate player touch
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    local originalCFrame = hrp.CFrame
    local doorPosition = doorPart.CFrame.Position
    local touchOffset = Vector3.new(0, 3, 0)

    hrp.CFrame = CFrame.new(doorPosition + touchOffset)
    task.wait(0.15)
    hrp.CFrame = originalCFrame
    task.wait(0.1)

    -- Fire Interact Remote
    local interactSuccess, interactError = pcall(function()
        Interact:FireServer(
            "Select",
            dungeonMapName,
            1,          -- act/arc
            "Normal",   -- mode
            "Dungeon"   -- type
        )
    end)

    if interactSuccess then
        Window:Notify({ Title = "Pro Tools", Description = "Fired Teleporter.Interact for dungeon: " .. dungeonMapName, Lifetime = 3 })
        task.wait(0.08)
        pcall(function() Interact:FireServer("Skip") end)
        task.wait(0.5)
    else
        Window:Notify({ Title = "Pro Tools", Description = "Failed to fire Teleporter.Interact for dungeon: " .. tostring(interactError), Lifetime = 5, Style = "Error" })
    end
end
-- Teleport selection helper (for Story and Legendary stages and Portals)
local function doTeleportSelect(mapName, actNumber, mode, typeName)
    if not mapName then return end
    local Interact = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Teleporter") and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")
    if not Interact then
        -- fallback path used earlier in examples
        Interact = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Teleporter.Interact") or ReplicatedStorage:FindFirstChild("Teleporter") and ReplicatedStorage.Teleporter:FindFirstChild("Interact")
    end
    -- prefer workspace.TeleporterFolder.Story[2] if exists (this might need refinement for Portals/Challenges)
    local tpModel = nil
    local tpFolder = Workspace:FindFirstChild("TeleporterFolder")
    if tpFolder and tpFolder:FindFirstChild("Story") and #tpFolder.Story:GetChildren() >= 2 then
        tpModel = tpFolder.Story:GetChildren()[2] -- General Story Teleporter
    elseif typeName == "Portal" and tpFolder then -- Attempt to find a general portal teleporter if specified
        for _, v in ipairs(tpFolder:GetChildren()) do
            -- Look for a model that might represent a generic portal entry
            if v:IsA("Model") and v.Name:lower():find("portal") then
                tpModel = v
                break
            end
        end
    end

    -- Fallback to any model in TeleporterFolder if specific one not found
    if not tpModel then
        if tpFolder then
            for _, v in ipairs(tpFolder:GetChildren()) do
                if v:IsA("Model") then tpModel = v break end
            end
        end
    end

    if not tpModel then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter model not found for " .. typeName .. " " .. mapName .. ".", Lifetime = 5, Style = "Error" })
        return
    end

    -- find a basepart to teleport to
    local tpPart = nil
    for _, d in ipairs(tpModel:GetDescendants()) do
        if d:IsA("BasePart") then tpPart = d break end
    end
    if not tpPart then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter part not found for " .. typeName .. " " .. mapName .. ".", Lifetime = 5, Style = "Error" })
        return
    end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    hrp.CFrame = tpPart.CFrame + Vector3.new(0, 3, 0)
    task.wait(0.15)
    if Interact and Interact.FireServer then
        pcall(function() Interact:FireServer("Select", mapName, tonumber(actNumber) or 1, mode, typeName) end)
        task.wait(0.08)
        pcall(function() Interact:FireServer("Skip") end)
    end
end

-- NEW: Dedicated function for Raid Teleport
local function doRaidTeleport(raidMapName, raidArc)
    if not raidMapName then
        Window:Notify({ Title = "Pro Tools", Description = "No raid map selected.", Lifetime = 3 })
        return
    end

    local Interact = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Teleporter") and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")
    if not Interact then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter.Interact remote not found for Raids.", Lifetime = 5, Style = "Error" })
        return
    end

    local teleporterFolder = Workspace:FindFirstChild("TeleporterFolder")
    if not teleporterFolder then
        Window:Notify({ Title = "Pro Tools", Description = "TeleporterFolder not found in Workspace.", Lifetime = 5, Style = "Error" })
        return
    end

    local raidsFolder = teleporterFolder:FindFirstChild("Raids")
    if not raidsFolder then
        Window:Notify({ Title = "Pro Tools", Description = "Raids folder not found in TeleporterFolder.", Lifetime = 5, Style = "Error" })
        return
    end

    -- Find an available raid teleporter with "0/6 Players"
    local targetTeleporter = nil
    local doorPart = nil
    local uiContainer = nil
    local playerCountLabel = nil

    for _, teleporterModel in ipairs(raidsFolder:GetChildren()) do
        if teleporterModel:IsA("Model") then
            local currentDoorPart = teleporterModel:FindFirstChild("Door")
            local currentUiContainer = currentDoorPart and currentDoorPart:FindFirstChild("UI")
            local currentPlayerCountLabel = currentUiContainer and currentUiContainer:FindFirstChild("PlayerCount")

            if currentPlayerCountLabel and currentPlayerCountLabel.Text == "0/6 Players" then
                targetTeleporter = teleporterModel
                doorPart = currentDoorPart
                uiContainer = currentUiContainer
                playerCountLabel = currentPlayerCountLabel
                break -- Found one, use it.
            end
        end
    end

    if not targetTeleporter then
        Window:Notify({ Title = "Pro Tools", Description = "No available raid teleporter with 0/6 Players found.", Lifetime = 5, Style = "Error" })
        return
    end
    
    -- Re-check these variables now that targetTeleporter is confirmed
    if not doorPart then
        Window:Notify({ Title = "Pro Tools", Description = "Raid Door part not found for the selected teleporter. Cannot join raid.", Lifetime = 5, Style = "Error" })
        return
    end

    if not uiContainer then
        Window:Notify({ Title = "Pro Tools", Description = "Raid Door UI container not found for the selected teleporter. Cannot join raid.", Lifetime = 5, Style = "Error" })
        return
    end

    if not playerCountLabel then
        Window:Notify({ Title = "Pro Tools", Description = "PlayerCount TextLabel not found in Raid Door UI for the selected teleporter. Cannot join raid.", Lifetime = 5, Style = "Error" })
        return
    end

    -- The lobby check is now integrated into the search loop
    Window:Notify({ Title = "Pro Tools", Description = "Found available raid teleporter. Proceeding to join...", Lifetime = 3 })

    -- Simulate player touch
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    local originalCFrame = hrp.CFrame
    local doorPosition = doorPart.CFrame.Position
    local touchOffset = Vector3.new(0, 3, 0) -- Adjust offset as needed to ensure touch
    
    -- Move player to touch the door
    hrp.CFrame = CFrame.new(doorPosition + touchOffset)
    task.wait(0.15) -- Consistent with other teleport delays

    -- Move player back to original position (optional, but good practice)
    hrp.CFrame = originalCFrame
    task.wait(0.1) 

    -- Fire Interact Remote
    local interactSuccess, interactError = pcall(function()
        Interact:FireServer(
            "Select",
            raidMapName,
            tonumber(raidArc) or 1, -- Arc is the 'actNumber' in this context
            "Normal", -- Assuming "Normal" mode for raids based on user's previous example
            "Raids"
        )
    end)
    if interactSuccess then
        Window:Notify({ Title = "Pro Tools", Description = "Fired Teleporter.Interact for raid: " .. raidMapName .. " Arc " .. raidArc, Lifetime = 3 })
        task.wait(0.08) -- Consistent with other teleport delays
        pcall(function() Interact:FireServer("Skip") end) -- Added skip here
        task.wait(0.5) -- Added a longer wait after the skip action
    else
        Window:Notify({ Title = "Pro Tools", Description = "Failed to fire Teleporter.Interact: " .. tostring(interactError), Lifetime = 3, Style = "Error" })
    end
end

-- Function to join challenges (existing, but note it's called internally by doPortalJoin)
local function doChallengeJoin(challengeNames)
    if not challengeNames or #challengeNames == 0 then
        Window:Notify({ Title = "Pro Tools", Description = "No challenges selected.", Lifetime = 3 })
        return
    end

    local Interact = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Teleporter") and ReplicatedStorage.Remotes.Teleporter:FindFirstChild("Interact")
    if not Interact then
        Window:Notify({ Title = "Pro Tools", Description = "Teleporter.Interact remote not found for Challenges.", Lifetime = 5, Style = "Error" })
        return
    end

    local selectedChallengeString = table.concat(challengeNames, ", ")
    Window:Notify({ Title = "Pro Tools", Description = "Attempting to join challenges: " .. selectedChallengeString, Lifetime = 3 })

    local success, errorMsg = pcall(function()
        for _, challengeName in ipairs(challengeNames) do
            Interact:FireServer("Select", challengeName, 1, "Normal", "Challenges")
            task.wait(0.1) -- Small delay between firing for multiple challenges
        end
        task.wait(0.08)
        Interact:FireServer("Skip") -- Assuming skip is always needed after selecting
        task.wait(0.5) -- Longer wait after skip
    end)

    if success then
        Window:Notify({ Title = "Pro Tools", Description = "Fired Teleporter.Interact for challenges: " .. selectedChallengeString, Lifetime = 3 })
    else
        Window:Notify({ Title = "Pro Tools", Description = "Failed to fire Teleporter.Interact for challenges: " .. tostring(errorMsg), Lifetime = 3, Style = "Error" })
    end
end

-- NEW: Function to handle joining portals using Replica system data
local function doPortalJoin(portalName, challenges, tier)
    
    local ReplicaHolder = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ReplicaHolder")
    if not ReplicaHolder or not ReplicaHolder:IsA("ModuleScript") then
        Window:Notify({ Title = "Pro Tools", Description = "ReplicaHolder module not found.", Lifetime = 5, Style = "Error" })
        return
    end

    local getReplicaSuccess, playerDataReplica = pcall(function() return require(ReplicaHolder).GetReplicaOfClass("PlayerData") end)
    if not getReplicaSuccess or not playerDataReplica or not playerDataReplica.Data then
        Window:Notify({ Title = "Pro Tools", Description = "Failed to get PlayerData replica.", Lifetime = 5, Style = "Error" })
        return
    end

    local portalData = playerDataReplica.Data.PortalData
    if not portalData then
        Window:Notify({ Title = "Pro Tools", Description = "PortalData not found in PlayerData. Are you in a game where portals exist?", Lifetime = 5, Style = "Error" })
        return
    end

    local targetPortalId = nil

    for portalId, info in pairs(portalData) do
        local currentPortalMapName = info.PortalData and info.PortalData.Map -- Get the actual map name
        local currentPortalTier = info.PortalData and info.PortalData.Tier
        local currentPortalChallenges = info.PortalData and info.PortalData.Challenges -- CORRECTED: Changed to .Challenges (plural)
        
        local tierMatch = (currentPortalTier == tonumber(tier))
        local nameMatch = (currentPortalMapName == portalName) -- Match against the actual map name
        local challengesMatch = areChallengesMatching(currentPortalChallenges, challenges) -- CORRECTED: Pass .Challenges
        
        if nameMatch and tierMatch and challengesMatch then
            targetPortalId = portalId
            break
        end
    end

    if not targetPortalId then
        Window:Notify({ Title = "Pro Tools", Description = "No matching portal found with selected criteria.", Lifetime = 5, Style = "Warning" })
        return
    end

    -- First, activate/select the portal using InvokeServer
    local ActivateRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Portals") and ReplicatedStorage.Remotes.Portals:FindFirstChild("Activate")
    if not ActivateRemote or not ActivateRemote:IsA("RemoteFunction") then 
        Window:Notify({ Title = "Pro Tools", Description = "Portals.Activate RemoteFunction not found for selection.", Lifetime = 5, Style = "Error" })
        return
    end

    Window:Notify({ Title = "Pro Tools", Description = "Found portal '" .. portalName .. "'. Attempting to activate...", Lifetime = 3 })
    local activateSuccess, activateResult = pcall(function()
        return ActivateRemote:InvokeServer(targetPortalId)
    end)

    if not activateSuccess then
        Window:Notify({ Title = "Pro Tools", Description = "Failed to activate portal: " .. tostring(activateResult), Lifetime = 5, Style = "Error" })
        return
    end
    Window:Notify({ Title = "Pro Tools", Description = "Successfully activated portal: " .. portalName, Lifetime = 3 })
    task.wait(0.1) -- Short wait after activation

    -- Then, fire the Start remote to begin the portal
    local StartRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Portals") and ReplicatedStorage.Remotes.Portals:FindFirstChild("Start")
    if not StartRemote or not StartRemote:IsA("RemoteEvent") then 
        Window:Notify({ Title = "Pro Tools", Description = "Portals.Start RemoteEvent not found for starting.", Lifetime = 5, Style = "Error" })
        return
    end

    Window:Notify({ Title = "Pro Tools", Description = "Attempting to start portal: " .. portalName .. "...", Lifetime = 3 })
    local startSuccess, startResult = pcall(function()
        StartRemote:FireServer() 
    end)

    if startSuccess then
        Window:Notify({ Title = "Pro Tools", Description = "Successfully requested to start portal: " .. portalName, Lifetime = 3 })
    else
        Window:Notify({ Title = "Pro Tools", Description = "Failed to send start request for portal: " .. tostring(startResult), Lifetime = 5, Style = "Error" })
    end
end


StorySection:Toggle({
    Name = "Join Story",
    Default = false,
    Callback = function(state)
        if state and selectedStoryMap then
            doTeleportSelect(selectedStoryMap, selectedStoryAct, "Normal", "Story")
        end
    end
})

-- NEW Join Portal Toggle
PortalSection:Toggle({ 
    Name = "Join Portal",
    Default = false,
    Callback = function(state)
        if state then
            if not selectedPortalMap then
                Window:Notify({ Title = "Pro Tools", Description = "Please select a portal map to join.", Lifetime = 3, Style = "Warning" })
                return
            end
            
            -- Call the new portal join function
            doPortalJoin(selectedPortalMap, selectedChallenges, selectedTier)
        else
            -- No specific "stop joining portal" action needed other than stopping the toggle state
            Window:Notify({ Title = "Pro Tools", Description = "Portal Join toggle off.", Lifetime = 3 })
        end
    end
})

-- Toggle to join Boss Rush
HxHSection:Toggle({
    Name = "Join BossRush",
    Default = false,
    Callback = function(state)
        if state then
            if selectedBossRushMap then
                local StartBossRush = ReplicatedStorage:FindFirstChild("Remotes")
                    and ReplicatedStorage.Remotes:FindFirstChild("Snej")
                    and ReplicatedStorage.Remotes.Snej:FindFirstChild("StartBossRush")

                if StartBossRush then
                    pcall(function()
                        StartBossRush:FireServer(selectedBossRushMap)
                    end)
                    Window:Notify({
                        Title = "Pro Tools",
                        Description = "Joining Boss Rush: " .. tostring(selectedBossRushMap),
                        Lifetime = 3
                    })
                else
                    warn("StartBossRush remote not found!")
                    Window:Notify({
                        Title = "Pro Tools",
                        Description = "StartBossRush remote not found.",
                        Lifetime = 3,
                        Style = "Error"
                    })
                end
            else
                Window:Notify({
                    Title = "Pro Tools",
                    Description = "No Boss Rush map selected.",
                    Lifetime = 3,
                    Style = "Warning"
                })
            end
        end
    end
})

-- Toggle to stick to random ZoneDisplay until gone
local teleportingToZone = false

RushSection:Toggle({
    Name = "AutoTp AntiMagic",
    Default = false,
    Callback = function(state)
        teleportingToZone = state

        task.spawn(function()
            while teleportingToZone do
                local zonesFolder = workspace:FindFirstChild("EffectZones")
                local zones = {}
                if zonesFolder then
                    for _, obj in ipairs(zonesFolder:GetChildren()) do
                        if obj.Name == "ZoneDisplay" and obj:IsA("BasePart") then
                            table.insert(zones, obj)
                        end
                    end
                end

                if #zones > 0 then
                    -- pick a random zone
                    local chosenZone = zones[math.random(1, #zones)]

                    -- keep sticking to it until it's gone
                    while teleportingToZone and chosenZone and chosenZone.Parent == zonesFolder do
                        local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.CFrame = chosenZone.CFrame + Vector3.new(0, 3, 0)
                        end
                        task.wait(0.5)
                    end
                else
                    task.wait(0.5) -- wait before rechecking
                end
            end
        end)
    end
})

-- Auto Orbs toggle
local autoOrbsEnabled = false

RushSection:Toggle({
    Name = "Auto Orbs",
    Default = false,
    Callback = function(state)
        autoOrbsEnabled = state

        task.spawn(function()
            while autoOrbsEnabled do
                local orbFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ActiveOrbs")
                if orbFolder then
                    for _, model in ipairs(orbFolder:GetChildren()) do
                        if model:IsA("Model") then
                            local part = model:FindFirstChild("Part")
                            if part and part:FindFirstChildOfClass("ProximityPrompt") then
                                local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                                pcall(function()
                                    fireproximityprompt(prompt)
                                end)
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end
})

-- Auto Shinjuku Breach toggle
local autoBreachEnabled = false
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

BreachSection:Toggle({
    Name = "Auto Shinjuku Breach",
    Default = false,
    Callback = function(state)
        autoBreachEnabled = state

        task.spawn(function()
            while autoBreachEnabled do
                local lobby = workspace:FindFirstChild("Lobby")

                if lobby and lobby:FindFirstChild("Breaches") then
                    for _, breachPart in ipairs(lobby.Breaches:GetChildren()) do
                        if breachPart:IsA("BasePart") then
                            local breach = breachPart:FindFirstChild("Breach")
                            if breach and breach:IsA("BasePart") then
                                local prompt = breach:FindFirstChildOfClass("ProximityPrompt")
                                if prompt then
                                    -- Fire proximity prompt
                                    pcall(function()
                                        fireproximityprompt(prompt)
                                    end)

                                    -- Fire Enter remote
                                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                                    local EnterRemote = ReplicatedStorage:FindFirstChild("Remotes")
                                        and ReplicatedStorage.Remotes:FindFirstChild("Breach")
                                        and ReplicatedStorage.Remotes.Breach:FindFirstChild("Enter")

                                    if EnterRemote then
                                        pcall(function()
                                            EnterRemote:FireServer(breachPart)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                else
                    -- If Lobby doesn't exist, check time and teleport to game at xx:01, xx:21, xx:41
                    local minutes = tonumber(os.date("%M"))
                    local seconds = tonumber(os.date("%S"))
                    if (minutes % 20 == 1) and seconds <= 5 then
                        pcall(function()
                            TeleportService:Teleport(12886143095, Players.LocalPlayer)
                        end)
                        task.wait(6) -- debounce to avoid multiple triggers in same window
                    end
                end

                task.wait(0.5)
            end
        end)
    end
})


SurvivalSection:Toggle({
    Name = "Join Survival",
    Default = false,
    Callback = function(state)
        -- prefer selectedSurvival or selectedSurvivalMap depending on which your UI uses
        local mapToUse = selectedSurvival or selectedSurvivalMap
        if state then
            if not mapToUse then
                Window:Notify({ Title = "Pro Tools", Description = "Please select a survival map to join.", Lifetime = 3, Style = "Warning" })
                return
            end
            doSurvivalTeleport(mapToUse)
        else
            Window:Notify({ Title = "Pro Tools", Description = "Survival Join toggle off.", Lifetime = 2 })
        end
    end
})

DungeonSection:Toggle({
    Name = "Join Dungeon",
    Default = false,
    Callback = function(state)
        local mapToUse = selectedDungeon or selectedDungeonMap
        if state then
            if not mapToUse then
                Window:Notify({ Title = "Pro Tools", Description = "Please select a dungeon map to join.", Lifetime = 3, Style = "Warning" })
                return
            end
            doDungeonTeleport(mapToUse)
        else
            Window:Notify({ Title = "Pro Tools", Description = "Dungeon Join toggle off.", Lifetime = 2 })
        end
    end
})

LegendSection:Toggle({
    Name = "Join Legendary Stage",
    Default = false,
    Callback = function(state)
        if state and selectedLegendMap then
            doTeleportSelect(selectedLegendMap, selectedLegendAct, "Purgatory", "LegendaryStages")
        end
    end
})

-- NEW Join Raid Toggle (now uses selectedRaidArc and new logic)
RaidSection:Toggle({
    Name = "Join Raid",
    Default = false,
    Callback = function(state)
        if state and selectedRaidMap then
            doRaidTeleport(selectedRaidMap, selectedRaidArc)
        end
    end
})


-- ---------------------------
-- Macro UI & logic
-- ---------------------------

local selectedMacro = nil
local isMacroLooping = false -- New variable to control macro loop state (toggle ON/OFF)
local isMacroRunningCycle = false -- New variable to indicate if a macro cycle is currently in progress
local currentMacroPlaybackTask = nil -- To hold the running task for macro playback

local MacroSelectDropdown = MacroSection:Dropdown({
    Name = "Select Macro",
    Search = true,
    Multi = false,
    Required = false,
    Options = {},
    Callback = function(val) selectedMacro = val end,
}, "MacroSelect")

local function refreshMacroDropdownUI()
    local list = {}
    for name in pairs(macros) do table.insert(list, name) end
    table.sort(list)
    MacroSelectDropdown:ClearOptions()
    if #list > 0 then
        MacroSelectDropdown:InsertOptions(list)
        selectedMacro = list[1]
    else
        MacroSelectDropdown:InsertOptions({"No Macros Saved"})
        selectedMacro = nil
    end
end

MacroSection:Input({
    Name = "Create Macro",
    Placeholder = "Enter macro name...",
    AcceptedCharacters = "All",
    Callback = function(input)
        if not input or input == "" then return end
        if macros[input] then
            Window:Notify({ Title = "Pro Tools", Description = "Macro already exists.", Lifetime = 3 })
            return
        end
        macros[input] = {}
        saveMacroToFile(input)
        refreshMacroDropdownUI()
        Window:Notify({ Title = "Pro Tools", Description = "Macro created: "..input, Lifetime = 3 })
    end
}, "CreateMacroInput")

-- Recording state
local recordConn = nil
local upgradeConn = nil
local sellConn = nil -- New connection for recording individual sells
-- local abilityHookedInvokeServer = nil -- Removed ability hook variable as it cannot be directly assigned
local isRecording = false
local recordStart = 0
local lastRecord = 0
local trackedTowers = {} -- Keep track of towers we've placed to monitor upgrades

-- Fixed owner checking function
local function ownerIsLocal(tower)
    if not tower then return false end
    
    -- Wait for Owner to exist with timeout
    local owner = tower:FindFirstChild("Owner")
    local timeout = tick() + 2 -- 2 second timeout
    
    while not owner and tick() < timeout do
        task.wait(0.1)
        owner = tower:FindFirstChild("Owner")
    end
    
    if not owner then 
        return false 
    end
    
    local ownerValue = owner.Value
    if not ownerValue then 
        return false 
    end
    
    -- If it's a Player instance
    if typeof(ownerValue) == "Instance" and ownerValue:IsA("Player") then
        isMatch = (ownerValue == LocalPlayer)
    else
        -- If it's a string or other value, compare as strings
        local ownerStr = tostring(ownerValue)
        local playerNameMatch = (ownerStr == LocalPlayer.Name)
        local playerIdMatch = (ownerStr == tostring(LocalPlayer.UserId))
        isMatch = playerNameMatch or playerIdMatch
    end
    
    return isMatch
end

-- NEW HELPER FUNCTION: Waits for a specific tower to appear in Workspace.Towers
-- It checks by unit name, position (optional, for placement verification), and required upgrade level.
-- It will stop if macro looping is disabled or EndGameUI appears.
local function waitForTowerInWorkspace(unitName, targetPosition, requiredLevel, timeoutSeconds)
    -- If timeoutSeconds is 0, interpret it as math.huge for indefinite wait
    local actualTimeout = (timeoutSeconds == 0) and math.huge or timeoutSeconds 
    local startTime = tick()
    
    -- Provide a finite timeout for WaitForChild to get the 'Towers' folder itself.
    -- The indefinite waiting for the specific unit is handled by the outer while loop.
    local towersFolder = Workspace:WaitForChild("Towers", 5) -- 5 seconds to find the Towers folder
    if not towersFolder then 
        Window:Notify({ Title = "Pro Tools", Description = "Error: 'Towers' folder not found in Workspace.", Lifetime = 5, Style = "Error" })
        return nil 
    end

    while (actualTimeout == math.huge or tick() - startTime < actualTimeout) and isMacroLooping do 
        -- Check for EndGameUI.BG visibility to stop macro at each step
        local endGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
        if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
            isMacroRunningCycle = false 
            return nil 
        end

        for _, tower in ipairs(towersFolder:GetChildren()) do
            if tower.Name == unitName and ownerIsLocal(tower) then
                local towerPos = nil
                local success, pivot = pcall(function() return tower:GetPivot() end)
                if success and typeof(pivot) == "CFrame" then
                    towerPos = pivot.Position
                elseif tower.PrimaryPart then
                    towerPos = tower.PrimaryPart.Position
                end

                local distance = targetPosition and (towerPos - Vector3.new(targetPosition.x, targetPosition.y, targetPosition.z)).Magnitude or 0

                if not targetPosition or distance < 5 then -- Within 5 studs of the target position or no position constraint
                    local currentLevelValue = tower:FindFirstChild("Upgrade")
                    if requiredLevel ~= nil then 
                        if currentLevelValue and currentLevelValue:IsA("IntValue") and currentLevelValue.Value >= requiredLevel then
                            return tower
                        end
                    else 
                        return tower
                    end
                end
            end
        end
        task.wait(0.2) -- Check every 0.2 seconds
    end
    return nil -- Tower not found within timeout
end


local function startRecordingForSelectedMacro()
    if not selectedMacro then
        Window:Notify({ Title = "Pro Tools", Description = "Select a macro first.", Lifetime = 3 })
        return
    end

    -- disconnect previous connections
    if recordConn then
        pcall(function() recordConn:Disconnect() end)
        recordConn = nil
    end
    if upgradeConn then
        pcall(function() upgradeConn:Disconnect() end)
        upgradeConn = nil
    end
    if sellConn then
        pcall(function() sellConn:Disconnect() end)
        sellConn = nil
    end
    -- Removed ability hook disconnection as it cannot be hooked
    -- if abilityHookedInvokeServer then
    --     local currentAbilityRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Ability")
    --     if currentAbilityRemote and currentAbilityRemote.InvokeServer == abilityHookedInvokeServer.hooked then
    --         currentAbilityRemote.InvokeServer = abilityHookedInvokeServer.original -- Restore original
    --     end
    --     abilityHookedInvokeServer = nil
    -- end


    macros[selectedMacro] = {}
    trackedTowers = {}
    saveMacroToFile(selectedMacro)

    isRecording = true
    recordStart = nil -- Will be set when first tower is placed
    lastRecord = nil

    if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Recording: Ready | Money: $%s", getCurrentMoney())) end
    Window:Notify({ Title = "Pro Tools", Description = "Recording started (places + upgrades + sells). Abilities cannot be automatically recorded.", Lifetime = 5 })

    -- wait for towers folder
    local towersFolder = Workspace:WaitForChild("Towers", 10)
    if not towersFolder then
        Window:Notify({ Title = "Pro Tools", Description = "Towers folder not found.", Lifetime = 3 })
        isRecording = false
        if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Error (Towers Folder Missing) | Money: $%s", getCurrentMoney())) end
        return
    end

    -- Record tower placements
    recordConn = towersFolder.ChildAdded:Connect(function(tower)
        if not isRecording then return end
        if not tower then return end

        -- Check ownership using the fixed function
        if ownerIsLocal(tower) then
            -- get position: prefer PrimaryPart, fallback to GetPivot
            local posVec = nil
            if tower.PrimaryPart then
                posVec = tower.PrimaryPart.Position
            else
                local pivotResult = nil
                local ok = pcall(function() pivotResult = tower:GetPivot() end) 
                if ok and pivotResult and typeof(pivotResult) == "CFrame" then
                    posVec = pivotResult.Position
                end
            end 
            
            if posVec then
                local currentTime = tick()
                
                -- Set timing reference on first tower placement
                if not recordStart then
                    recordStart = currentTime
                    lastRecord = currentTime
                end
                
                local delay = math.max(0.01, currentTime - lastRecord)
                lastRecord = currentTime

                -- Capture the current TotalCost multiplier at the time of recording
                local currentTotalCostMultiplier = 1
                local totalCostValueObject = findTotalCostValueObject(tower.Name)
                if totalCostValueObject then
                    currentTotalCostMultiplier = totalCostValueObject.Value
                else
                end
                
                local step = {
                    delay = delay,
                    unit = tower.Name,
                    position = posToTable(posVec),
                    action = "place",
                    recordedTotalCostMultiplier = currentTotalCostMultiplier -- Store the multiplier
                }
                table.insert(macros[selectedMacro], step)
                saveMacroToFile(selectedMacro)
                
                if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Recording: Placed %s | Money: $%s", tower.Name, getCurrentMoney())) end

                -- Track this tower for upgrade monitoring
                trackedTowers[tower] = {name = tower.Name, lastUpgradeLevel = 0}
                
                -- Monitor upgrades for this tower
                local upgradeValue = tower:FindFirstChild("Upgrade")
                if upgradeValue and upgradeValue:IsA("IntValue") then
                    local towerUpgradeConn = upgradeValue.Changed:Connect(function(newLevel)
                        if not isRecording then return end
                        if trackedTowers[tower] and newLevel > trackedTowers[tower].lastUpgradeLevel then
                            local upgradeTime = tick()
                            local delay = math.max(0.01, upgradeTime - lastRecord)
                            lastRecord = upgradeTime
                            
                            local upgradeStep = {
                                delay = delay,
                                unit = tower.Name,
                                action = "upgrade",
                                upgradeLevel = newLevel
                            }
                            table.insert(macros[selectedMacro], upgradeStep)
                            saveMacroToFile(selectedMacro)
                            trackedTowers[tower].lastUpgradeLevel = newLevel
                            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Recording: Upgraded %s to Lvl %s | Money: $%s", tower.Name, newLevel, getCurrentMoney())) end
                        end
                    end)
                    
                    -- Clean up connection when tower is removed (this one for internal tracking)
                    tower.AncestryChanged:Connect(function()
                        if not tower.Parent then
                            pcall(function() towerUpgradeConn:Disconnect() end)
                            trackedTowers[tower] = nil
                        end
                    end)
                end
            end
        end
    end)

    -- Record individual tower sells
    sellConn = towersFolder.ChildRemoved:Connect(function(tower)
        if not isRecording then return end
        -- Check if this was a tower we were tracking as "placed"
        if trackedTowers[tower] then
            local currentTime = tick()
            local delay = math.max(0.01, currentTime - lastRecord)
            lastRecord = currentTime
            
            local step = {
                delay = delay,
                unit = tower.Name, -- Record which unit was sold
                action = "sell"
            }
            table.insert(macros[selectedMacro], step)
            saveMacroToFile(selectedMacro)
            trackedTowers[tower] = nil -- No longer track this tower

            -- Safely get the tower name for the notification
            local unitNameForNotification = tower.Name or "an unknown unit"
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Recording: Sold %s | Money: $%s", unitNameForNotification, getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Recorded sell action for: " .. unitNameForNotification, Lifetime = 2 })
        end
    end)

    -- Ability recording hook removed due to direct `InvokeServer` assignment issues.
    -- The game/environment likely protects this property from client-side script modification.
    -- Playback of 'ability' actions in the macro should still function if manually added to the macro file.
end

local function stopRecording()
    if recordConn then
        pcall(function() recordConn:Disconnect() end)
        recordConn = nil
    end
    if upgradeConn then
        pcall(function() upgradeConn:Disconnect() end)
        upgradeConn = nil
    end
    if sellConn then
        pcall(function() sellConn:Disconnect() end)
        sellConn = nil
    end
    -- Removed ability hook disconnection
    -- if abilityHookedInvokeServer then
    --     local AbilityRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Ability")
    --     if AbilityRemote and AbilityRemote.InvokeServer == abilityHookedInvokeServer.hooked then
    --         AbilityRemote.InvokeServer = abilityHookedInvokeServer.original -- Restore original
    --     end
    --     abilityHookedInvokeServer = nil
    -- end
    
    -- Clear tracked towers
    trackedTowers = {}
    isRecording = false
    if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Idle | Money: $%s", getCurrentMoney())) end
    Window:Notify({ Title = "Pro Tools", Description = "Recording stopped.", Lifetime = 3 })
end

MacroSection:Button({
    Name = "Record Macro",
    Callback = function()
        startRecordingForSelectedMacro()
    end
}, "RecordMacroButton")

MacroSection:Button({
    Name = "Stop Record Macro",
    Callback = function()
        stopRecording()
    end
}, "StopRecordMacroButton")

local PlayMacroToggleRef = nil -- Reference to the actual toggle object
local macroStatusLabel = nil -- Reference to the new status label

-- Helper function to check visibility of the specific game start button by exact path
local function isGameStartButtonVisible()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end

    local bottomFrame = playerGui:FindFirstChild("Bottom")
    if not bottomFrame then return false end

    -- Handle ScreenGui vs. GuiObject visibility property
    if bottomFrame:IsA("ScreenGui") then
        if not bottomFrame.Enabled then return false end
    elseif bottomFrame:IsA("GuiObject") then
        if not bottomFrame.Visible then return false end
    else
        return false -- Not a recognized GUI type for visibility check
    end

    local frame = bottomFrame:FindFirstChild("Frame")
    if not frame or not frame.Visible then return false end

    -- It's crucial to ensure these children exist before accessing their properties
    local children = frame:GetChildren()
    local child2 = children[2]
    if not child2 or not child2:IsA("GuiObject") or not child2.Visible then return false end

    local textButton = child2:GetChildren()[6]
    if not textButton or not textButton:IsA("TextButton") or not textButton.Visible then return false end
    
    -- If all checks pass, the button and its ancestors are visible/enabled
    return true
end


-- Function to execute a single cycle of the macro
local function executeMacroCycle()
    if not selectedMacro or not macros[selectedMacro] or #macros[selectedMacro] == 0 then
        Window:Notify({ Title = "Pro Tools", Description = "No macro to play. Playback aborted.", Lifetime = 3 })
        isMacroRunningCycle = false -- No cycle is running
        isMacroLooping = false -- Disable looping if no macro selected
        if PlayMacroToggleRef then PlayMacroToggleRef:UpdateState(false) end -- Ensure UI matches state
        if macroStatusLabel then macroStatusLabel:UpdateName("Macro: Idle | Money: $" .. getCurrentMoney()) end -- Ensure label is reset
        return
    end

    -- If a cycle is already running, cancel the old one before starting a new one
    if currentMacroPlaybackTask then
        task.cancel(currentMacroPlaybackTask)
        currentMacroPlaybackTask = nil
    end

    isMacroRunningCycle = true -- A cycle is now in progress
    local totalMacroSteps = #macros[selectedMacro]
    if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Running (%s) | Money: $%s", selectedMacro, getCurrentMoney())) end

    currentMacroPlaybackTask = task.spawn(function()
        -- --- NEW: Wait for game to start UI to become invisible ---
        while isMacroLooping and isGameStartButtonVisible() do
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Waiting for game to start... | Money: $%s", getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Waiting for game to start (UI button visible).", Lifetime = 1, Style = "Warning" })
            task.wait(1)
        end
        -- If macro looping was stopped while waiting, exit
        if not isMacroLooping then
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Stopped by user. | Money: $%s", getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Macro stopped by user during game start wait.", Lifetime = 3 })
            isMacroRunningCycle = false
            return
        end
        -- --------------------------------------------------------

        -- Get remotes (re-declared inside to ensure they are available when cycle starts)
        local PlaceTowerRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if PlaceTowerRemote then
            PlaceTowerRemote = PlaceTowerRemote:FindFirstChild("PlaceTower")
        end
        
        local UpgradeRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if UpgradeRemote then
            UpgradeRemote = ReplicatedStorage.Remotes:FindFirstChild("Upgrade")  
        end

        local SellRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if SellRemote then
            SellRemote = ReplicatedStorage.Remotes:FindFirstChild("Sell")
        end

        local AbilityRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if AbilityRemote then
            AbilityRemote = ReplicatedStorage.Remotes:FindFirstChild("Ability")
        end
        
        if not PlaceTowerRemote or not UpgradeRemote or not SellRemote or not AbilityRemote then
            Window:Notify({ Title = "Pro Tools", Description = "Required remotes (PlaceTower, Upgrade, Sell, Ability) not found. Playback aborted.", Lifetime = 5, Style = "Error" })
            isMacroRunningCycle = false -- No cycle running
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Error (Missing Remotes) | Money: $%s", getCurrentMoney())) end
            return
        end

        Window:Notify({ Title = "Pro Tools", Description = "Executing macro cycle: "..selectedMacro, Lifetime = 3 })

        -- Now tracking placed towers by name and position to reliably re-find them
        local placedTowers = {} -- Stores {name = "UnitName", position = {x,y,z}}

        local macroInterruptedByEndGame = false

        for i, step in ipairs(macros[selectedMacro]) do
            -- Check for EndGameUI.BG visibility to stop macro at each step
            local endGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
            if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                Window:Notify({ Title = "Pro Tools", Description = "EndGameUI detected. Stopping current macro cycle.", Lifetime = 3 })
                macroInterruptedByEndGame = true
                break -- Exit current macro cycle execution
            end

            if not isMacroLooping then -- Check if toggle was turned off externally
                break -- Exit current macro cycle execution
            end
            
            local stepDelay = tonumber(step.delay) or 0.05
            local startTime = tick()
            local targetTime = startTime + stepDelay

            -- Update label with remaining time during delay
            while tick() < targetTime do
                local remaining = targetTime - tick()
                local statusText = string.format("Macro: %s (%d/%d) | Next: %.1fs | Money: $%s", 
                                                step.action, i, totalMacroSteps, remaining, getCurrentMoney())
                if macroStatusLabel then macroStatusLabel:UpdateName(statusText) end
                task.wait(0.1) -- Update every 0.1 seconds
                if not isMacroLooping then break end -- Check again if looping was disabled during wait
                -- Also check for EndGameUI during delay
                local currentEndGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
                if currentEndGameUIParent and currentEndGameUIParent:FindFirstChild("BG") and currentEndGameUIParent.BG.Visible then
                    macroInterruptedByEndGame = true
                    break
                end
            end
            if macroInterruptedByEndGame or not isMacroLooping then break end

            if step.action == "place" then
                if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Placing %s (%d/%d) | Money: $%s", step.unit, i, totalMacroSteps, getCurrentMoney())) end
                
                -- Use the recorded multiplier for cost calculation
                local recordedMultiplier = step.recordedTotalCostMultiplier or 1 -- Default to 1 if not found (for old macros)
                local baseCost = getUnitCost(step.unit, false) -- Get base cost without applying current multiplier
                local finalCost = baseCost * recordedMultiplier

                -- Wait for sufficient money before placing
                while isMacroLooping and getCurrentMoney() < finalCost and finalCost ~= math.huge do
                    Window:Notify({ Title = "Pro Tools", Description = "Waiting for $" .. finalCost .. " to place " .. step.unit .. ". Current: $" .. getCurrentMoney(), Lifetime = 1, Style = "Warning" })
                    task.wait(1) 
                    if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                        Window:Notify({ Title = "Pro Tools", Description = "EndGameUI detected during money wait. Stopping macro.", Lifetime = 3 })
                        macroInterruptedByEndGame = true
                        break 
                    end
                    if not isMacroLooping then break end 
                end
                if macroInterruptedByEndGame or not isMacroLooping then break end 

                if finalCost == math.huge then
                    Window:Notify({ Title = "Pro Tools", Description = "Warning: Could not determine cost for " .. step.unit .. ". Attempting to place anyway.", Lifetime = 3, Style = "Warning" })
                end

                -- Place tower - Keep trying until successfully placed or macro stops
                local placedSuccessfully = false
                while isMacroLooping and not placedSuccessfully and not macroInterruptedByEndGame do
                    local position = step.position
                    local cf = CFrame.new(position.x, position.y, position.z)
                    
                    local success, error = pcall(function() 
                        PlaceTowerRemote:FireServer(step.unit, cf)
                    end)
                    
                    if success then
                        if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Confirming %s placement (%d/%d) | Money: $%s", step.unit, i, totalMacroSteps, getCurrentMoney())) end
                        local placedTowerInstance = waitForTowerInWorkspace(step.unit, position, 0, math.huge) -- Indefinite retry timeout (math.huge)
                        
                        if placedTowerInstance then
                            table.insert(placedTowers, {name = step.unit, position = position})
                            Window:Notify({ Title = "Pro Tools", Description = "Successfully placed and tracked " .. step.unit .. ".", Lifetime = 2 })
                            placedSuccessfully = true
                        else
                            -- If waitForTowerInWorkspace returns nil, it.means macro was interrupted (game end or user stop)
                            -- In this case, we break out of the current action's loop
                            break 
                        end
                    else
                        Window:Notify({ Title = "Pro Tools", Description = "Failed to send place request for " .. step.unit .. ": " .. tostring(error) .. ". Retrying placement...", Lifetime = 3, Style = "Error" })
                        task.wait(1) -- Wait a bit before retrying the place request
                    end

                    -- Check for interruption conditions within the retry loop
                    endGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
                    if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                        macroInterruptedByEndGame = true
                        break
                    end
                    if not isMacroLooping then break end
                end
                if macroInterruptedByEndGame or not isMacroLooping then break end
                
            elseif step.action == "upgrade" then
                if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Upgrading %s to level %s (%d/%d) | Money: $%s", step.unit, step.upgradeLevel, i, totalMacroSteps, getCurrentMoney())) end
                local towerToUpgradeInfo = nil
                local towerIndexInPlacedTowers = nil
                for j = #placedTowers, 1, -1 do
                    local info = placedTowers[j]
                    if info and info.name == step.unit then
                        towerToUpgradeInfo = info
                        towerIndexInPlacedTowers = j
                        break
                    end
                end

                if not towerToUpgradeInfo then
                    Window:Notify({ Title = "Pro Tools", Description = "Cannot upgrade " .. step.unit .. ": No record of placed unit found. Skipping.", Lifetime = 3, Style = "Warning" })
                else
                    -- Keep trying to upgrade until successful or macro stops
                    local upgradedSuccessfully = false
                    while isMacroLooping and not upgradedSuccessfully and not macroInterruptedByEndGame do
                        if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Confirming %s for upgrade (%d/%d) | Money: $%s", step.unit, i, totalMacroSteps, getCurrentMoney())) end
                        local actualTowerInstance = waitForTowerInWorkspace(step.unit, towerToUpgradeInfo.position, step.upgradeLevel - 1, math.huge) -- Indefinite retry
                        
                        if not actualTowerInstance then
                            -- If waitForTowerInWorkspace returns nil, it.means macro was interrupted (game end or user stop)
                            -- In this case, we break out of the current action's loop
                            break 
                        else
                            local upgradeCost = getUpgradeCost(step.unit, step.upgradeLevel)
                            
                            -- Wait for sufficient money before upgrading
                            while isMacroLooping and getCurrentMoney() < upgradeCost and upgradeCost ~= math.huge do -- Changed cost to upgradeCost
                                Window:Notify({ Title = "Pro Tools", Description = "Waiting for $" .. upgradeCost .. " to upgrade " .. step.unit .. ". Current: $" .. getCurrentMoney(), Lifetime = 1, Style = "Warning" })
                                task.wait(1) 
                                if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                                    macroInterruptedByEndGame = true
                                    break
                                end
                                if not isMacroLooping then break end
                            end
                            if macroInterruptedByEndGame or not isMacroLooping then break end

                            if upgradeCost == math.huge then
                                Window:Notify({ Title = "Pro Tools", Description = "Warning: Could not determine cost for upgrade " .. step.unit .. ". Attempting to upgrade anyway.", Lifetime = 3, Style = "Warning" })
                            end

                            local success, error = pcall(function() 
                                UpgradeRemote:InvokeServer(actualTowerInstance)
                            end)
                            if not success then
                                Window:Notify({ Title = "Pro Tools", Description = "Failed to send upgrade request for " .. step.unit .. ".. Retrying upgrade attempt...", Lifetime = 3, Style = "Error" })
                                task.wait(1) -- Wait before retrying upgrade attempt
                            else
                                Window:Notify({ Title = "Pro Tools", Description = "Successfully requested upgrade for " .. step.unit .. ".", Lifetime = 2 })
                                upgradedSuccessfully = true
                            end
                        end

                        -- Check for interruption conditions within the retry loop
                        endGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
                        if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                            macroInterruptedByEndGame = true
                            break
                        end
                        if not isMacroLooping then break end
                    end
                end
                if macroInterruptedByEndGame or not isMacroLooping then break end

            elseif step.action == "sell" then 
                if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Selling %s (%d/%d) | Money: $%s", step.unit, i, totalMacroSteps, getCurrentMoney())) end
                Window:Notify({ Title = "Pro Tools", Description = "Selling unit: " .. step.unit .. " as per macro...", Lifetime = 2 })
                local towerToSellInfo = nil
                local towerIndexInPlacedTowers = nil
                for j = #placedTowers, 1, -1 do
                    local info = placedTowers[j]
                    if info and info.name == step.unit then
                        towerToSellInfo = info
                        towerIndexInPlacedTowers = j
                        break
                    end
                end
                
                if not towerToSellInfo then
                    Window:Notify({ Title = "Pro Tools", Description = "Could not find record of " .. step.unit .. " to sell during macro playback. Skipping.", Lifetime = 3, Style = "Warning" })
                else
                    -- Keep trying to sell until successful or macro stops
                    local soldSuccessfully = false
                    while isMacroLooping and not soldSuccessfully and not macroInterruptedByEndGame do
                        if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Confirming %s for selling (%d/%d) | Money: $%s", step.unit, i, totalMacroSteps, getCurrentMoney())) end
                        local actualTowerInstance = waitForTowerInWorkspace(step.unit, towerToSellInfo.position, nil, math.huge) -- Indefinite retry
                        
                        if not actualTowerInstance then
                            -- If waitForTowerInWorkspace returns nil, it.means macro was interrupted (game end or user stop)
                            -- In this case, we break out of the current action's loop
                            break 
                        else
                            if SellRemote then
                                pcall(function()
                                    SellRemote:InvokeServer(actualTowerInstance)
                                end)
                                if towerIndexInPlacedTowers then table.remove(placedTowers, towerIndexInPlacedTowers) end 
                                soldSuccessfully = true
                            else
                                Window:Notify({ Title = "Pro Tools", Description = "Sell remote not available during playback. Retrying sell attempt...", Lifetime = 3, Style = "Error" })
                                task.wait(1) -- Wait before retrying sell attempt
                            end
                        end

                        -- Check for interruption conditions within the retry loop
                        endGameUIParent = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
                        if endGameUIParent and endGameUIParent:FindFirstChild("BG") and endGameUIParent.BG.Visible then
                            macroInterruptedByEndGame = true
                            break
                        end
                        if not isMacroLooping then break end
                    end
                end
                if macroInterruptedByEndGame or not isMacroLooping then break end

            elseif step.action == "ability" then
                if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Using Ability '%s' on %s (%d/%d) | Money: $%s", step.abilityName, step.unit, i, totalMacroSteps, getCurrentMoney())) end
                Window:Notify({ Title = "Pro Tools", Description = "Using ability: " .. step.abilityName .. " on " .. step.unit .. "...", Lifetime = 2 })
                
                -- Find the unit instance to pass to InvokeServer
                local unitInstance = waitForTowerInWorkspace(step.unit, nil, nil, 5) -- No specific position/level needed, just existence. 5s timeout.
                
                if unitInstance then
                    local success, result = pcall(function()
                        return AbilityRemote:InvokeServer(unitInstance, step.abilityName)
                    end)
                    if not success then
                        Window:Notify({ Title = "Pro Tools", Description = "Failed to invoke ability '" .. step.abilityName .. "' on " .. step.unit .. ": " .. tostring(result), Lifetime = 3, Style = "Error" })
                    else
                        Window:Notify({ Title = "Pro Tools", Description = "Successfully used ability '" .. step.abilityName .. "' on " .. unitInstance.Name .. ".", Lifetime = 2 })
                    end
                else
                    Window:Notify({ Title = "Pro Tools", Description = "Could not find unit '" .. step.unit .. "' to use ability '" .. step.abilityName .. "' on. Skipping.", Lifetime = 3, Style = "Warning" })
                end
            end
            
            -- Removed the direct task.wait(0.1) here as the loop above handles delays and breaks
        end
        
        isMacroRunningCycle = false -- Cycle has finished or was interrupted

        if isMacroLooping and not macroInterruptedByEndGame then 
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Cycle completed. Waiting for next game... | Money: $%s", getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Macro cycle completed! Waiting for next game start...", Lifetime = 3 })
        elseif macroInterruptedByEndGame then
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Stopped (Game Ended). Waiting for next game... | Money: $%s", getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Macro stopped due to EndGameUI. Waiting for next game start...", Lifetime = 3 })
        else 
            if macroStatusLabel then macroMacroStatusLabel:UpdateName(string.format("Macro: Stopped by user. | Money: $%s", getCurrentMoney())) end
            Window:Notify({ Title = "Pro Tools", Description = "Macro loop stopped by user.", Lifetime = 3 })
        end

        currentMacroPlaybackTask = nil -- Clear the task reference when it finishes
    end)
end

-- Modified Play Macro to be a Toggle with Loop functionality
PlayMacroToggleRef = MacroSection:Toggle({ 
    Name = "Play Macro (Loop)",
    Default = false,
    Callback = function(state)
        isMacroLooping = state 
        if state then
            if not isMacroRunningCycle then
                executeMacroCycle()
            else
                Window:Notify({ Title = "Pro Tools", Description = "Macro loop enabled. Cycle already running.", Lifetime = 3 })
            end
        else
            Window:Notify({ Title = "Pro Tools", Description = "Stopping macro loop.", Lifetime = 3 })
            if currentMacroPlaybackTask then
                task.cancel(currentMacroPlaybackTask)
                currentMacroPlaybackTask = nil
            end
            isMacroRunningCycle = false 
            if macroStatusLabel then macroStatusLabel:UpdateName(string.format("Macro: Stopped by user. | Money: $%s", getCurrentMoney())) end
        end
    end
}, "PlayMacroToggle")

-- Listen for GameStartedClient event to start/restart macro if looping is enabled
local GameStartedClient = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GameStartedClient")
if GameStartedClient then
    GameStartedClient.OnClientEvent:Connect(function()
        -- Only start a new cycle if looping is enabled AND no cycle is currently in progress
        if isMacroLooping and not isMacroRunningCycle then
            -- The executeMacroCycle function now handles the waiting, so we just call it.
            executeMacroCycle() 
            Window:Notify({ Title = "Pro Tools", Description = "Game started signal received. Attempting to resume macro loop.", Lifetime = 2 })
        end
    end)
end


MacroSection:Button({
    Name = "Delete Macro",
    Callback = function()
        if not selectedMacro or not macros[selectedMacro] then
            Window:Notify({ Title = "Pro Tools", Description = "No macro selected to delete.", Lifetime = 3 })
            return
        end
        macros[selectedMacro] = nil
        deleteMacroFile(selectedMacro)
        refreshMacroDropdownUI()
        Window:Notify({ Title = "Pro Tools", Description = "Deleted macro: "..selectedMacro, Lifetime = 3 })
    end
}, "DeleteMacroButton")

-- Add the new Macro Status Label
macroStatusLabel = MacroSection:Label({
    Text = "Macro: Idle" -- Initial text, will be updated by executeMacroCycle and toggles
}, "MacroStatusLabel")


-- Debug button was removed as requested.

-- ---------------------------
-- Webhook Tab Features
-- ---------------------------
local WebhookSection = WebhookTab:Section({ Name = "Discord Webhook" })

-- Webhook settings
local webhookURL = ""
local webhookEnabled = false

-- Webhook URL input
WebhookSection:Input({
    Name = "Discord Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    AcceptedCharacters = "All",
    Callback = function(value)
        webhookURL = value
    end,
    onChanged = function(value)
        webhookURL = value
    end
}, "WebhookURLInput")

-- Enable webhook toggle
WebhookSection:Toggle({
    Name = "Enable Webhook",
    Default = false,
    Callback = function(state)
        webhookEnabled = state
    end
})

-- Test webhook button
WebhookSection:Button({
    Name = "Test Webhook",
    Callback = function()
        if webhookURL == "" then
            warn("No webhook URL set!")
            return
        end
        local httpService = game:GetService("HttpService")
        local body = httpService:JSONEncode({
            content = "**Webhook test successful!**",
            username = "Game Bot"
        })
        local success, err = pcall(function()
            request({
                Url = webhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
        if success then
            print("Test webhook sent to:", webhookURL)
        else
            warn("Failed to send test webhook:", err)
        end
    end
})


-- ---------------------------
-- Init
-- ---------------------------
loadMacros()
refreshMacroDropdownUI()

-- Display startup message
Window:Notify({ 
    Title = "Pro Tools", 
    Description = "Script loaded successfully! Current money: $" .. getCurrentMoney(), 
    Lifetime = 5 
})


-- === AUTO-GENERATED MACRO HEADERS (FIXED) ===
pcall(function()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end

    -- Make sure MacroSection exists (created earlier by the script)
    if not (typeof(AbilitySection) == "table" or typeof(AbilitySection) == "Instance") then
        warn("[AutoHeaders] MacroSection not found. Make sure this block runs after MacroSection is defined.")
        return
    end

    -- Global getUnit that finds unit model by name in any WorldModel under PlayerGui
    getgenv().getUnit = function(unitName)
        if not unitName then return nil end
        for _, world in ipairs(pg:GetDescendants()) do
            if world.Name == "WorldModel" and world:IsA("Folder") then
                local found = world:FindFirstChild(unitName)
                if found then return found end
            end
        end
        return nil
    end

    -- Collect up to 6 unique unit names from any WorldModel inside PlayerGui viewports
    local uniqueUnits = {}
    local seen = {}
    for _, world in ipairs(pg:GetDescendants()) do
        if world.Name == "WorldModel" and world.Parent and world.Parent:IsA("ViewportFrame") then
            for _, unit in ipairs(world:GetChildren()) do
                if not seen[unit.Name] then
                    table.insert(uniqueUnits, { name = unit.Name, world = world })
                    seen[unit.Name] = true
                    if #uniqueUnits >= 6 then break end
                end
            end
        end
        if #uniqueUnits >= 6 then break end
    end

    if #uniqueUnits == 0 then
        warn("[AutoHeaders] No units found in PlayerGui WorldModel instances.")
        return
    end

    -- Create headers safely (capture header object, then set Settings)
    for _, u in ipairs(uniqueUnits) do
        local ok, err = pcall(function()
            local hdr = AbilitySection:Header({ Text = u.name }, nil)
            AbilitySection:Dropdown({
                Name = 'Condition',
                Options = { 'Always', 'On Boss' },
                Default = 'Always',
                Callback = function(selected)
                end
            })
            AbilitySection:Toggle({
                Name = 'Auto Ability',
                Default = false,
                Callback = function(state)
                end
            })
            if abilityHeaders then table.insert(abilityHeaders, hdr) end
            if hdr then
                if type(hdr.UpdateName) == 'function' then pcall(function() hdr:UpdateName(u.name) end) end
                if type(hdr.SetVisibility) == 'function' then pcall(function() hdr:SetVisibility(true) end) end
                hdr.Settings = {
                    Callback = function()
                        local model = getgenv().getUnit(u.name)
                    end
                }
            else
                warn("[AutoHeaders] Header creation returned nil for unit:", u.name)
            end
        end)
        if not ok then
            warn("[AutoHeaders] Failed to create header for", u.name, err)
        end
    end
end)
-- === END AUTO-GENERATED MACRO HEADERS (FIXED) ===


-- === DEBUG & EQUIP HOOK (NAMECALL + POLLING) ===

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    if method == "InvokeServer" and tostring(self) == "Equip" then
        local args = {...}
        task.spawn(function()
            local tries = 0
            local units = {}
            repeat
                task.wait(0.2)
                units = getAllUnitsFromGUI()
                tries += 1
            until #units > 0 or tries >= 25 -- max 5 seconds
            for i, u in ipairs(units) do
            end
            regenerateHeaders(units)
        end)
    elseif method == "InvokeServer" and tostring(self) == "Unequip" then
        local args = {...}
        task.spawn(function()
            local tries = 0
            local units = {}
            repeat
                task.wait(0.2)
                units = getAllUnitsFromGUI()
                tries += 1
            until #units > 0 or tries >= 25 -- max 5 seconds
            for i, u in ipairs(units) do
            end
            regenerateHeaders(units)
        end)
    end
    return oldNamecall(self, ...)
end

setreadonly(mt, true)
-- === END DEBUG & EQUIP HOOK (NAMECALL + POLLING) ===


-- === PLACE ANYWHERE TOGGLE ===
if MainRightSection then
    MainRightSection:Toggle({
        Name = "Place Anywhere",
        Default = false,
        Callback = function(state)
            if state then
                local placeOn = workspace:FindFirstChild("PlaceOn")
                if placeOn and placeOn:FindFirstChild("Air") then
                    placeOn.Air:Destroy()
                else
                end

                if placeOn and placeOn:FindFirstChild("Ground") then
                    local ground = placeOn.Ground
                    for _, child in ipairs(ground:GetChildren()) do
                        child.Parent = placeOn
                    end
                    ground:Destroy()
                else
                end
            end
        end
    })
else
    warn("[DEBUG] MainSection not found, Place Anywhere toggle not created.")
end
-- === END PLACE ANYWHERE TOGGLE ===
