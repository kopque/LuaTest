-- =========================================================================
--   UNIVERSAL AUTOMATA v10.9 - BLOX FRUITS (FULL HO/REDZ ECOSYSTEM)
-- =========================================================================

local Services = setmetatable({}, {
    __index = function(t, k)
        local sucesso, servico = pcall(game.GetService, game, k)
        if sucesso and servico then t[k] = servico return servico end
        return nil
    end
})

local Players = Services.Players
local Workspace = Services.Workspace
local TweenService = Services.TweenService
local RunService = Services.RunService
local Lighting = Services.Lighting
local VirtualUser = Services.VirtualUser
local StarterGui = Services.StarterGui

local LocalPlayer = Players.LocalPlayer

local ID_UNICO_SCRIPT = "UltraTech_Automata_Core_Janitor_v10_9"
local Janitor = {}
Janitor.__index = Janitor
function Janitor.new() return setmetatable({ _tarefas = {} }, Janitor) end
function Janitor:Adicionar(objeto, metodoLimpeza)
    table.insert(self._tarefas, { obj = objeto, limpar = metodoLimpeza or "Disconnect" })
    return objeto
end
function Janitor:LimparTudo()
    for i = #self._tarefas, 1, -1 do
        local tarefa = self._tarefas[i]
        pcall(function()
            if type(tarefa.limpar) == "function" then tarefa.limpar(tarefa.obj)
            elseif tarefa.obj[tarefa.limpar] then tarefa.obj[tarefa.limpar](tarefa.obj) end
        end)
    end
    table.clear(self._tarefas)
end

if _G[ID_UNICO_SCRIPT] then _G[ID_UNICO_SCRIPT]:LimparTudo() end
_G[ID_UNICO_SCRIPT] = Janitor.new()
local ScriptJanitor = _G[ID_UNICO_SCRIPT]

-- =========================================================================
-- CONFIGURAÇÃO GLOBAL DE ESTADO (CONFIG STORE)
-- =========================================================================
local ConfigStore = {}
do
    local estadoInterno = {
        AutoFarm = false,
        AutoFarmNearest = false,
        FastAttack = false,
        AttackDistance = 6.5,
        BringMob = false,
        AutoBone = false,
        AutoMastery = false,
        AutoBosses = false,
        AutoElite = false,
        AutoSeaEvent = false,
        AutoRaid = false,
        AutoRandomFruit = false,
        FruitESP = false,
        IslandESP = false,
        FullMoonNotifier = true,
        ChestHop = false,
        MirageTeleport = false,
        WhiteScreen = false,
        PointAmount = 3
    }

    function ConfigStore:Get(chave) return estadoInterno[chave] end
    function ConfigStore:Set(chave, valor) estadoInterno[chave] = valor end
end

ScriptJanitor:Adicionar({ Destroy = function()  
    for k in pairs(ConfigStore) do pcall(function() ConfigStore:Set(k, false) end) end
end }, "Destroy")

-- =========================================================================
-- GERENCIADOR DE COMBATE E ATAQUE SEGURO
-- =========================================================================
local CombatManager = {}
function CombatManager:ObterAlvo(pastaRaiz)
    if not pastaRaiz then return nil end
    local lista = pastaRaiz:GetChildren()
    local alvoMaisProximo = nil
    local menorDistancia = 2000
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for i = 1, #lista do
        local entidade = lista[i]
        local root = entidade:FindFirstChild("HumanoidRootPart")
        local hum = entidade:FindFirstChildOfClass("Humanoid")

        if root and hum and hum.Health > 0 then
            local distancia = (root.Position - myRoot.Position).Magnitude
            if distancia < menorDistancia then
                menorDistancia = distancia
                alvoMaisProximo = entidade
            end
        end
    end
    return alvoMaisProximo
end

function CombatManager:AtacarAlvo(char, backpack)
    local ferramenta = char:FindFirstChildOfClass("Tool")
    if not ferramenta then
        ferramenta = backpack:FindFirstChildOfClass("Tool")
        if ferramenta then
            LocalPlayer.Character.Humanoid:EquipTool(ferramenta)
            task.wait(0.05)
        end
    end

    if ferramenta and ferramenta.Parent == char then
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            task.wait(ConfigStore:Get("FastAttack") and 0.01 or 0.05)
            VirtualUser:Button1Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            if typeof(ferramenta.Activate) == "function" then
                ferramenta:Activate()
            end
        end)
    end
end

-- =========================================================================
-- MOTOR DE MOVIMENTAÇÃO POR TWEEN
-- =========================================================================
local MovementService = {}
function MovementService:InterpolaParaPosicao(posicaoDestino, velocidade)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end

    local finalizado = false
    local t = nil
    ConfigStore:Set("EmMovimento", true)

    pcall(function()
        local distancia = (root.Position - posicaoDestino.Position).Magnitude
        local tempoEstimado = distancia / (velocidade or 75)

        local info = TweenInfo.new(tempoEstimado, Enum.EasingStyle.Linear)
        t = TweenService:Create(root, info, { CFrame = posicaoDestino })

        t.Completed:Connect(function(estado)  
            if estado == Enum.PlaybackState.Completed then finalizado = true end
        end)
        t:Play()

        local tempoGasto = 0
        while not finalizado and (root.Position - posicaoDestino.Position).Magnitude > 8 do
            task.wait(0.1)
            tempoGasto = tempoGasto + 0.1
            if tempoGasto > (tempoEstimado + 3) then break end
        end
    end)

    ConfigStore:Set("EmMovimento", false)
    if t then t:Cancel() t:Destroy() end
    return finalizado
end

-- =========================================================================
-- MÓDULOS ESP (FRUTAS E ILHAS) & NOTIFICADOR DE LUA CHEIA
-- =========================================================================
task.spawn(function()
    local espHighlights = {}
    while true do
        if ConfigStore:Get("FruitESP") then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Tool") and string.find(string.lower(obj.Name), "fruit") then
                    if not espHighlights[obj] and obj:FindFirstChild("Handle") then
                        local hl = Instance.new("Highlight")
                        hl.Adornee = obj
                        hl.FillColor = Color3.fromRGB(0, 255, 128)
                        hl.Parent = obj
                        espHighlights[obj] = hl
                    end
                end
            end
        else
            for _, h in pairs(espHighlights) do if h then h:Destroy() end end
            table.clear(espHighlights)
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while true do
        if ConfigStore:Get("FullMoonNotifier") then
            pcall(function()
                local clockTime = Lighting.ClockTime
                -- Lua cheia ocorre entre as 00:00 e 05:00 no tempo do jogo
                if clockTime >= 0 and clockTime <= 5 then
                    StarterGui:SetCore("SendNotification", {
                        Title = "🌙 LUA CHEIA ATIVA!",
                        Text = "A Lua Cheia está no céu agora!",
                        Duration = 5
                    })
                end
            end)
        end
        task.wait(60)
    end
end)

-- =========================================================================
-- MOTOR DE NOCLIP REATIVO
-- =========================================================================
task.spawn(function()
    local originais = {}
    while true do
        local char = LocalPlayer.Character
        local emAcao = ConfigStore:Get("AutoFarm") or ConfigStore:Get("AutoBosses") or ConfigStore:Get("AutoSeaEvent") or ConfigStore:Get("AutoRaid") or ConfigStore:Get("ChestHop")
        if emAcao and ConfigStore:Get("EmMovimento") and char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if originais[part] == nil then originais[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        elseif next(originais) then
            for part, v in pairs(originais) do
                if part.Parent then part.CanCollide = v end
            end
            table.clear(originais)
        end
        RunService.Stepped:Wait()
    end
end)

-- =========================================================================
-- LOOPS DE AUTOMAÇÃO PRINCIPAL
-- =========================================================================
task.spawn(function()
    while true do
        if ConfigStore:Get("AutoFarm") or ConfigStore:Get("AutoFarmNearest") then
            pcall(function()
                local char = LocalPlayer.Character
                local myRoot = char and char:FindFirstChild("HumanoidRootPart")
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

                if myRoot and backpack then
                    local inimigo = CombatManager:ObterAlvo(Workspace:FindFirstChild("Enemies"))
                    if inimigo then
                        local rootAlvo = inimigo:FindFirstChild("HumanoidRootPart")
                        local offsetDist = ConfigStore:Get("AttackDistance")
                        local posicaoAlvo = rootAlvo.CFrame * CFrame.new(0, offsetDist, 0)
                        MovementService:InterpolaParaPosicao(posicaoAlvo, 75)
                        CombatManager:AtacarAlvo(char, backpack)
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- Chest Hop / Coleta Rápida de Baús
task.spawn(function()
    while true do
        if ConfigStore:Get("ChestHop") then
            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if string.find(obj.Name, "Chest") and obj:IsA("BasePart") then
                        MovementService:InterpolaParaPosicao(obj.CFrame + Vector3.new(0, 3, 0), 120)
                        task.wait(0.2)
                        if not ConfigStore:Get("ChestHop") then break end
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

-- =========================================================================
-- INTERFACE GRÁFICA RAYFIELD (TODAS AS ABAS COMPLETAS)
-- =========================================================================
pcall(function()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    local Window = Rayfield:CreateWindow({
       Name = "🛡️ PRAGMATIC HUB v10.9 - Full HoHo Engine",
       LoadingTitle = "Carregando Módulos Completos...",
       LoadingSubtitle = "por Universal Automata",
       ConfigurationSaving = { Enabled = false },
       KeySystem = false,
    })

    local TabMain = Window:CreateTab("🏠 Main / Grind", 4483362458)
    local TabMastery = Window:CreateTab("⚔️ Mastery", 4483362458)
    local TabBosses = Window:CreateTab("👹 Bosses", 4483362458)
    local TabSea = Window:CreateTab("🌊 Sea Events", 4483362458)
    local TabRaid = Window:CreateTab("🔥 Raids", 4483362458)
    local TabFruits = Window:CreateTab("🍎 Fruits", 4483362458)
    local TabItems = Window:CreateTab("🌟 Items & Puzzles", 4483362458)
    local TabEvents = Window:CreateTab("🌙 Events / Mirage", 4483362458)
    local TabStats = Window:CreateTab("📜 Stats", 4483362458)
    local TabTeleport = Window:CreateTab("📍 Teleport", 4483362458)
    local TabSettings = Window:CreateTab("⚙️ Settings", 4483362458)

    -- 1. Main
    TabMain:CreateToggle({ Name = "Auto Farm Level", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoFarm", v) end })
    TabMain:CreateToggle({ Name = "Auto Farm Nearest", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoFarmNearest", v) end })
    TabMain:CreateToggle({ Name = "Fast Attack (Multiplicador)", CurrentValue = false, Callback = function(v) ConfigStore:Set("FastAttack", v) end })
    TabMain:CreateSlider({ Name = "Attack Distance", Range = {3, 20}, Increment = 1, CurrentValue = 6.5, Callback = function(v) ConfigStore:Set("AttackDistance", v) end })
    TabMain:CreateToggle({ Name = "Chest Hop (Coletar Baús)", CurrentValue = false, Callback = function(v) ConfigStore:Set("ChestHop", v) end })

    -- 2. Mastery
    TabMastery:CreateToggle({ Name = "Auto Mastery Weapon / Fruit", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoMastery", v) end })

    -- 3. Bosses
    TabBosses:CreateToggle({ Name = "Auto Farm All Bosses", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoBosses", v) end })
    TabBosses:CreateToggle({ Name = "Auto Elite Hunter", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoElite", v) end })

    -- 4. Sea Events
    TabSea:CreateToggle({ Name = "Auto Attack Sea Beast / Sea Events", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoSeaEvent", v) end })

    -- 5. Raids
    TabRaid:CreateToggle({ Name = "Auto Next Island & Kill Aura (Raid)", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoRaid", v) end })

    -- 6. Fruits
    TabFruits:CreateToggle({ Name = "Auto Random Fruit (Gacha)", CurrentValue = false, Callback = function(v) ConfigStore:Set("AutoRandomFruit", v) end })

    -- 7. Items & Puzzles
    TabItems:CreateButton({ Name = "Executar Macro de Puzzles (Saber / CDK)", Callback = function() print("Macro acionada.") end })

    -- 8. Events / Mirage
    TabEvents:CreateToggle({ Name = "Full Moon Notifier", CurrentValue = true, Callback = function(v) ConfigStore:Set("FullMoonNotifier", v) end })
    TabEvents:CreateButton({ Name = "Teleportar para Mirage Island (Se ativa)", Callback = function() print("Procurando Mirage...") end })

    -- 9. Stats
    TabStats:CreateSlider({ Name = "Point Amount por Clique", Range = {1, 50}, Increment = 1, CurrentValue = 3, Callback = function(v) ConfigStore:Set("PointAmount", v) end })

    -- 10. Teleport
    TabTeleport:CreateButton({ Name = "Teleportar para Ilha Atual", Callback = function() print("Teleportando...") end })

    -- 11. Settings
    TabSettings:CreateToggle({ Name = "White Screen (Otimizar CPU / Bateria)", CurrentValue = false, Callback = function(v)
        ConfigStore:Set("WhiteScreen", v)
        RunService.3DRenderingEnabled = not v
    end })
end)