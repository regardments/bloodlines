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
	localPlayer.CharacterAdded:Connect(function()
		task.spawn(function()
			local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
			if not playerGui then
				return
			end

			local clientGui = playerGui:FindFirstChild("ClientGui")
			if not clientGui then
				return
			end

			local mainframe = clientGui:FindFirstChild("Mainframe")
			if not mainframe then
				return
			end

			local playerList = mainframe:FindFirstChild("PlayerList")
			if not playerList then
				return
			end

			local list = playerList:FindFirstChild("List")
			if not list then
				return
			end

			local lastSpectating
			local lastSpectatingObject

			local function spectate(player, obj)
				local playerData = getPlayerData(player)
				if not playerData then
					return
				end

				if not player or lastSpectating == player then
					if lastSpectatingObject then
						lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
						lastSpectatingObject = nil
					end

					lastSpectating = nil

					local humanoid = localPlayerData.humanoid
					if humanoid then
						workspace.CurrentCamera.CameraSubject = humanoid
					end

					return
				end

				if lastSpectatingObject then
					lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
				end

				lastSpectatingObject = obj
				lastSpectating = player

				if player ~= localPlayer then
					obj.PlayerName.TextColor3 = Color3.fromRGB(255, 0, 0)
				end

				workspace.CurrentCamera.CameraSubject = playerData.humanoid
			end

			local function onListChildAdded(obj)
				task.spawn(function()
					local playerName = obj:WaitForChild("RealName", 10)
					if not playerName then
						return
					end

					obj.InputBegan:Connect(function(inputObject)
						if inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
							local humanoid = localPlayerData.humanoid
							if not humanoid then
								return spectate()
							end

							local player = Players:FindFirstChild(playerName.Value)
							if not player then
								return spectate()
							end

							spectate(player, obj)
						end
					end)
				end)
			end

			for _, v in ipairs(list:GetChildren()) do
				task.spawn(onListChildAdded, v)
			end

			list.ChildAdded:Connect(onListChildAdded)
		end)
	end)
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
			if not rootPart or tick() - lastRanAt < 0.1 then
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
			myRootPart.CFrame = target.CFrame * CFrame.new(0, 0, 2)
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
				humanoid.WalkSpeed = flag("Walk Speed Value")
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

		if dataFunction then
			dataFunction:InvokeServer("Pay", 1, itemName, 1)
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

do
	function funcs.openWipeShop()
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local clientGui = playerGui and playerGui:FindFirstChild("ClientGui")
		local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
		local rest = mainframe and mainframe:FindFirstChild("Rest")
		local destroyFrame = rest and rest:FindFirstChild("DestroyFrame")

		if destroyFrame then
			destroyFrame.Visible = true
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

local Window = Library:CreateWindow({
	Title = "Regardments | Bloodlines",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
})

local Main = Window:AddTab("Main")
local Combat = Window:AddTab("Combat")
local ESPTab = Window:AddTab("ESP")
local QoL = Window:AddTab("Quality Of Life")
local Visuals = Window:AddTab("Visuals")
local UISettings = Window:AddTab("UI Settings")

-- ── MAIN ──────────────────────────────────────────────
local movement = Main:AddLeftGroupbox("Movement")
local localCheats = Main:AddRightGroupbox("Local Cheats")

movement:AddToggle("Walk Speed", { Text = "Walk Speed", Callback = funcs.speed })
local walkSpeedDepbox = movement:AddDependencyBox()
walkSpeedDepbox:AddSlider("Walk Speed Value", {
	Text = "Walk Speed Value",
	Min = 0,
	Max = 500,
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

local noClipToggle = movement:AddToggle("No Clip", { Text = "No Clip", Callback = funcs.noClip })
noClipToggle:AddKeyPicker("NoClip Key", {
	Text = "NoClip Keybind",
	Default = "None",
	Mode = "Toggle",
	SyncToggleState = true,
})

movement:AddToggle("No Fall Damage", { Text = "No Fall Damage" })
movement:AddToggle("No Kill Bricks", { Text = "No Kill Bricks", Callback = funcs.noKillBricks })
movement:AddToggle("Auto Pickup", { Text = "Auto Pickup", Callback = funcs.autoPickup })

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

-- ── COMBAT ────────────────────────────────────────────
local chakraSense = Combat:AddLeftGroupbox("Chakra Sense")

chakraSense:AddToggle("Chakra Sense Spoof", { Text = "Chakra Sense", Callback = funcs.chakraSpoof })
chakraSense:AddToggle("Sense Detector", { Text = "Sense Detector", Callback = funcs.chakraSenseDetect })

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
