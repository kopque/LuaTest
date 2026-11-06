-- =========================================================================
--   UNIVERSAL AUTOMATA v10.9 (CORRIGIDO) - BLOX FRUITS
-- =========================================================================
-- AVISO: as partes específicas do jogo (remotes, nomes de bosses, ID da lua)
-- vieram de pesquisa em scripts da comunidade e NÃO foram testadas no jogo.
-- Se algo não funcionar, veja o console: os módulos registram o que recebem.

local function registrarLog(modulo, mensagem, erro)
    local sufixo = erro and (" | Erro: " .. tostring(erro)) or ""
    warn(string.format("[%s] [%s] %s%s", os.date("%X"), string.upper(modulo), mensagem, sufixo))
end

-- Evita spam no console quando um loop falha repetidamente
local ultimoErro = {}
local function registrarErro(modulo, erro)
    local agora = os.clock()
    if agora - (ultimoErro[modulo] or -10) >= 3 then
        ultimoErro[modulo] = agora
        registrarLog(modulo, "Erro interceptado", erro)
    end
end

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
local VirtualInputManager = Services.VirtualInputManager
local ReplicatedStorage = Services.ReplicatedStorage
local StarterGui = Services.StarterGui
local UserInputService = Services.UserInputService
local CoreGui = Services.CoreGui

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- CONSTANTES EDITÁVEIS (ajuste aqui se o jogo mudar)
-- =========================================================================
-- Lua Cheia: ID de MoonTextureId citado em script da comunidade (não confirmado).
-- O console mostra o ID atual da lua sempre que ele muda, para você conferir.
local LUA_CHEIA_IDS = { ["9709149431"] = true }

-- Nomes (de memória/comunidade, podem estar incompletos ou desatualizados)
local BOSSES = {
    ["Gorilla King"] = true, ["Bobby"] = true, ["Yeti"] = true, ["Mob Leader"] = true,
    ["Vice Admiral"] = true, ["Saber Expert"] = true, ["Warden"] = true, ["Chief Warden"] = true,
    ["Swan"] = true, ["Magma Admiral"] = true, ["Fishman Lord"] = true, ["Wysper"] = true,
    ["Thunder God"] = true, ["Cyborg"] = true,
    ["Diamond"] = true, ["Jeremy"] = true, ["Fajita"] = true, ["Don Swan"] = true,
    ["Smoke Admiral"] = true, ["Awakened Ice Admiral"] = true, ["Tide Keeper"] = true,
    ["Stone"] = true, ["Island Empress"] = true, ["Kilo Admiral"] = true,
    ["Captain Elephant"] = true, ["Beautiful Pirate"] = true,
}
local ELITES = { ["Diablo"] = true, ["Deandre"] = true, ["Urban"] = true }
-- SeaBeasts é uma pasta própria; estes ficam em Workspace.Enemies
local SEA_INIMIGOS = { ["Shark"] = true, ["Terrorshark"] = true, ["PirateBrigade"] = true, ["PirateBasic"] = true }

local TOOLTIP_MASTERY = "Blox Fruit"   -- ToolTip da ferramenta usada no Auto Mastery
local INTERVALO_FRUTA = 60             -- segundos entre compras de fruta aleatória
local INTERVALO_ELITE = 30             -- segundos entre pedidos da quest de Elite
local TECLAS_MASTERY = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }

-- =========================================================================
-- JANITOR
-- =========================================================================
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

-- Flag que encerra TODOS os loops quando o script é re-executado
local Estado = { rodando = true }

-- =========================================================================
-- CONFIGURAÇÃO GLOBAL DE ESTADO
-- =========================================================================
local ConfigStore = {}
do
    local estadoInterno = {
        AutoFarm = false,
        AutoFarmNearest = false,
        FastAttack = false,
        AttackDistance = 6.5,
        AutoMastery = false,
        AutoBosses = false,
        AutoElite = false,
        AutoSeaEvent = false,
        AutoRaid = false,
        AutoRandomFruit = false,
        FruitESP = false,
        FullMoonNotifier = true,
        ChestHop = false,
        WhiteScreen = false,
        EmMovimento = false,
    }

    function ConfigStore:Get(chave) return estadoInterno[chave] end
    function ConfigStore:Set(chave, valor) estadoInterno[chave] = valor end

    -- Desliga todos os toggles (booleanos). Não mexe em números.
    function ConfigStore:Reset()
        for k, v in pairs(estadoInterno) do
            if type(v) == "boolean" then estadoInterno[k] = false end
        end
    end
end

local function aplicarWhiteScreen(ligado)
    pcall(function() RunService:Set3dRenderingEnabled(not ligado) end)
end

-- Encerramento: roda quando o script é re-executado
ScriptJanitor:Adicionar({ Destroy = function()
    Estado.rodando = false
    ConfigStore:Reset()
    aplicarWhiteScreen(false)
end }, "Destroy")

-- =========================================================================
-- REMOTE DO JOGO (ReplicatedStorage.Remotes.CommF_)
-- =========================================================================
local function obterCommF()
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("CommF_")
    if not remote then error("Remotes.CommF_ não encontrado (o jogo é o Blox Fruits?)", 0) end
    return remote
end

-- =========================================================================
-- GERENCIADOR DE COMBATE
-- =========================================================================
local CombatManager = {}

-- pastas: lista de pastas (nil é ignorado) | filtro(ent) -> bool | raio em studs
function CombatManager:ObterAlvo(pastas, filtro, raio)
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local alvoMaisProximo = nil
    local menorDistancia = raio or 2000

    for _, pasta in ipairs(pastas) do
        local lista = pasta:GetChildren()
        for i = 1, #lista do
            local entidade = lista[i]
            if filtro(entidade) then
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
        end
    end
    return alvoMaisProximo
end

local function escolherFerramenta(char, backpack, tooltip)
    if tooltip then
        for _, local_ in ipairs({ char, backpack }) do
            for _, t in ipairs(local_:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == tooltip then return t end
            end
        end
    end
    return char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
end

function CombatManager:AtacarAlvo(char, hum, backpack, tooltip)
    local ferramenta = escolherFerramenta(char, backpack, tooltip)
    if ferramenta and ferramenta.Parent ~= char then
        hum:EquipTool(ferramenta)
        task.wait(0.05)
    end

    if ferramenta and ferramenta.Parent == char then
        if VirtualUser then
            pcall(function()
                local camera = Workspace.CurrentCamera
                local cf = camera and camera.CFrame or CFrame.new(0, 0, 0)
                VirtualUser:Button1Down(Vector2.new(0, 0), cf)
                task.wait(ConfigStore:Get("FastAttack") and 0.01 or 0.05)
                VirtualUser:Button1Up(Vector2.new(0, 0), cf)
            end)
        end
        pcall(function() ferramenta:Activate() end)
    end
end

function CombatManager:UsarHabilidades()
    if not VirtualInputManager then return end
    for _, tecla in ipairs(TECLAS_MASTERY) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, tecla, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, tecla, false, game)
        end)
    end
end

-- =========================================================================
-- MOVIMENTAÇÃO POR TWEEN (um movimento por vez)
-- =========================================================================
local MovementService = { _ocupado = false }

-- Retorna true se terminou a até 8 studs do destino.
-- aindaAtivo (opcional): função que, ao retornar false, cancela o movimento.
function MovementService:Interpola(destino, velocidade, aindaAtivo)
    if self._ocupado then return false end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end

    self._ocupado = true
    ConfigStore:Set("EmMovimento", true)

    local tween = nil
    local ok, erro = pcall(function()
        local distancia = (root.Position - destino.Position).Magnitude
        local tempo = distancia / math.max(velocidade or 75, 1)

        tween = TweenService:Create(root, TweenInfo.new(tempo, Enum.EasingStyle.Linear), { CFrame = destino })
        tween:Play()

        local gasto = 0
        while Estado.rodando
            and (aindaAtivo == nil or aindaAtivo())
            and hum.Health > 0
            and root.Parent
            and (root.Position - destino.Position).Magnitude > 8 do
            task.wait(0.1)
            gasto = gasto + 0.1
            if gasto > tempo + 3 then break end
        end
    end)

    if tween then pcall(function() tween:Cancel() tween:Destroy() end) end
    self._ocupado = false
    ConfigStore:Set("EmMovimento", false)

    if not ok then error(erro, 0) end
    return root.Parent ~= nil and (root.Position - destino.Position).Magnitude <= 8
end

-- =========================================================================
-- ESP DE FRUTAS
-- =========================================================================
task.spawn(function()
    local espHighlights = {}

    local function limpar()
        for obj, h in pairs(espHighlights) do
            pcall(function() h:Destroy() end)
            espHighlights[obj] = nil
        end
    end
    ScriptJanitor:Adicionar({ Destroy = limpar }, "Destroy")

    while Estado.rodando do
        if ConfigStore:Get("FruitESP") then
            local ok, err = pcall(function()
                for obj, h in pairs(espHighlights) do
                    if not obj.Parent then
                        pcall(function() h:Destroy() end)
                        espHighlights[obj] = nil
                    end
                end
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
            end)
            if not ok then registrarErro("ESP", err) end
        else
            limpar()
        end
        task.wait(1)
    end
end)

-- =========================================================================
-- AVISO DE LUA CHEIA (compara o MoonTextureId do céu com LUA_CHEIA_IDS)
-- =========================================================================
local function notificar(titulo, texto)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = titulo, Text = texto, Duration = 5 })
    end)
end

task.spawn(function()
    local ultimoId = nil
    local estavaCheia = false
    while Estado.rodando do
        if ConfigStore:Get("FullMoonNotifier") then
            local ok, err = pcall(function()
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if not sky then return end
                local id = string.match(tostring(sky.MoonTextureId), "%d+")

                if id ~= ultimoId then
                    ultimoId = id
                    -- permite conferir/corrigir LUA_CHEIA_IDS se o jogo mudou
                    registrarLog("Lua", "MoonTextureId atual: " .. tostring(id))
                end

                local cheia = id ~= nil and LUA_CHEIA_IDS[id] == true
                if cheia and not estavaCheia then
                    notificar("LUA CHEIA ATIVA!", "A Lua Cheia está no céu agora.")
                elseif estavaCheia and not cheia then
                    notificar("Lua Cheia terminou", "A lua mudou de fase.")
                end
                estavaCheia = cheia
            end)
            if not ok then registrarErro("Lua", err) end
        end
        task.wait(5)
    end
end)

-- =========================================================================
-- COMBATE: UM DESPACHANTE COM PRIORIDADE
-- (Bosses > Elite > Sea Events > Raid > Mastery > Farm)
-- =========================================================================
local function pastaEnemies() return Workspace:FindFirstChild("Enemies") end
local function nomeEm(conjunto) return function(ent) return conjunto[ent.Name] == true end end
local function qualquer() return true end

local MODOS = {
    { nome = "Bosses", chaves = { "AutoBosses" }, filtro = nomeEm(BOSSES), raio = 5000,
      pastas = function() return { pastaEnemies() } end },
    { nome = "Elite", chaves = { "AutoElite" }, filtro = nomeEm(ELITES), raio = 5000,
      pastas = function() return { pastaEnemies() } end },
    { nome = "SeaEvent", chaves = { "AutoSeaEvent" }, raio = 5000,
      pastas = function() return { Workspace:FindFirstChild("SeaBeasts"), pastaEnemies() } end,
      filtro = function(ent) return (ent.Parent and ent.Parent.Name == "SeaBeasts") or SEA_INIMIGOS[ent.Name] == true end },
    { nome = "Raid", chaves = { "AutoRaid" }, filtro = qualquer, raio = 5000,
      pastas = function() return { pastaEnemies() } end },
    { nome = "Mastery", chaves = { "AutoMastery" }, filtro = qualquer, raio = 2000,
      tooltip = TOOLTIP_MASTERY, habilidades = true,
      pastas = function() return { pastaEnemies() } end },
    { nome = "Farm", chaves = { "AutoFarm", "AutoFarmNearest" }, filtro = qualquer, raio = 2000,
      pastas = function() return { pastaEnemies() } end },
}

local function modoAtivo(modo)
    for _, chave in ipairs(modo.chaves) do
        if ConfigStore:Get(chave) then return true end
    end
    return false
end

local function algumModoAtivo()
    for _, modo in ipairs(MODOS) do
        if modoAtivo(modo) then return true end
    end
    return false
end

local function cicloCombate()
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local myHum = char and char:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    if not (myRoot and myHum and myHum.Health > 0 and backpack) then
        task.wait(0.5)
        return
    end

    for _, modo in ipairs(MODOS) do
        if modoAtivo(modo) then
            local pastas = {}
            for _, p in ipairs(modo.pastas()) do
                if p then table.insert(pastas, p) end
            end
            local alvo = CombatManager:ObterAlvo(pastas, modo.filtro, modo.raio)
            if alvo then
                local rootAlvo = alvo:FindFirstChild("HumanoidRootPart")
                if not rootAlvo then return end

                local distancia = tonumber(ConfigStore:Get("AttackDistance")) or 6.5
                local destino = rootAlvo.CFrame * CFrame.new(0, distancia, 0)
                local ativo = function() return modoAtivo(modo) end

                local chegou = MovementService:Interpola(destino, 75, ativo)
                if chegou and ativo() then
                    CombatManager:AtacarAlvo(char, myHum, backpack, modo.tooltip)
                    if modo.habilidades then CombatManager:UsarHabilidades() end
                end
                return
            end
        end
    end

    task.wait(0.4) -- nenhum modo ligado encontrou alvo
end

task.spawn(function()
    while Estado.rodando do
        if algumModoAtivo() then
            local ok, err = pcall(cicloCombate)
            if not ok then registrarErro("Combate", err) end
        end
        task.wait(0.1)
    end
end)

-- =========================================================================
-- AUTO RANDOM FRUIT  (CommF_:InvokeServer("Cousin", "Buy"))
-- =========================================================================
task.spawn(function()
    while Estado.rodando do
        if ConfigStore:Get("AutoRandomFruit") then
            local ok, err = pcall(function()
                local resposta = obterCommF():InvokeServer("Cousin", "Buy")
                registrarLog("Fruta", "Resposta do jogo: " .. tostring(resposta))
            end)
            if not ok then registrarErro("Fruta", err) end
            task.wait(INTERVALO_FRUTA)
        else
            task.wait(1)
        end
    end
end)

-- =========================================================================
-- AUTO ELITE HUNTER: pede a quest (o combate ao Elite é feito pelo despachante)
-- =========================================================================
task.spawn(function()
    while Estado.rodando do
        if ConfigStore:Get("AutoElite") then
            local ok, err = pcall(function()
                local resposta = obterCommF():InvokeServer("EliteHunter")
                registrarLog("Elite", "Resposta do jogo: " .. tostring(resposta))
            end)
            if not ok then registrarErro("Elite", err) end
            task.wait(INTERVALO_ELITE)
        else
            task.wait(1)
        end
    end
end)

-- =========================================================================
-- NOCLIP (só enquanto há movimento; restaura a colisão depois)
-- =========================================================================
task.spawn(function()
    local originais = {}
    local partes = {}
    local personagemAtual = nil
    local ultimoRefresh = 0

    local function restaurar()
        for part, v in pairs(originais) do
            if part.Parent then part.CanCollide = v end
        end
        table.clear(originais)
        table.clear(partes)
        personagemAtual = nil
    end

    local function atualizarPartes(char)
        table.clear(partes)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(partes, part)
                if originais[part] == nil then originais[part] = part.CanCollide end
            end
        end
        ultimoRefresh = os.clock()
    end

    local function frame(char)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if char ~= personagemAtual then
            table.clear(originais)
            personagemAtual = char
            atualizarPartes(char)
        elseif os.clock() - ultimoRefresh > 2 then
            atualizarPartes(char)
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        for i = 1, #partes do
            if partes[i].Parent then partes[i].CanCollide = false end
        end
    end

    ScriptJanitor:Adicionar({ Destroy = restaurar }, "Destroy")

    while Estado.rodando do
        local char = LocalPlayer.Character
        local emAcao = algumModoAtivo() or ConfigStore:Get("ChestHop")
        if emAcao and ConfigStore:Get("EmMovimento") and char then
            pcall(frame, char)
        elseif next(originais) then
            restaurar()
        end
        RunService.Stepped:Wait()
    end
end)

-- =========================================================================
-- CHEST HOP (baú mais próximo primeiro; não repete o mesmo por 60s)
-- =========================================================================
local visitados = setmetatable({}, { __mode = "k" })
local function chestAtivo() return ConfigStore:Get("ChestHop") end

local function cicloBaus()
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local agora = os.clock()
    local lista = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and string.find(obj.Name, "Chest")
            and not (obj.Parent and obj.Parent:FindFirstChildOfClass("Humanoid"))
            and (visitados[obj] == nil or agora - visitados[obj] > 60) then
            table.insert(lista, obj)
        end
    end

    table.sort(lista, function(a, b)
        return (a.Position - myRoot.Position).Magnitude < (b.Position - myRoot.Position).Magnitude
    end)

    for _, obj in ipairs(lista) do
        if not chestAtivo() or not Estado.rodando then break end
        if obj.Parent then
            local chegou = MovementService:Interpola(obj.CFrame + Vector3.new(0, 3, 0), 120, chestAtivo)
            if chegou then visitados[obj] = os.clock() end
            task.wait(0.2)
        end
    end
end

task.spawn(function()
    while Estado.rodando do
        if chestAtivo() then
            local ok, err = pcall(cicloBaus)
            if not ok then registrarErro("ChestHop", err) end
        end
        task.wait(1)
    end
end)

-- =========================================================================
-- DEFINIÇÃO DOS CONTROLES (usada pela UI Rayfield e pela UI simples)
-- =========================================================================
local CONTROLES = {
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Level", chave = "AutoFarm" },
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Nearest", chave = "AutoFarmNearest" },
    { aba = "Main", tipo = "toggle", nome = "Fast Attack", chave = "FastAttack" },
    { aba = "Main", tipo = "slider", nome = "Attack Distance", chave = "AttackDistance", min = 3, max = 20, passo = 1 },
    { aba = "Main", tipo = "toggle", nome = "Chest Hop (Coletar Baús)", chave = "ChestHop" },

    { aba = "Combate", tipo = "toggle", nome = "Auto Mastery (usa Z X C V)", chave = "AutoMastery" },
    { aba = "Combate", tipo = "toggle", nome = "Auto Bosses (lista editável)", chave = "AutoBosses" },
    { aba = "Combate", tipo = "toggle", nome = "Auto Elite Hunter", chave = "AutoElite" },
    { aba = "Combate", tipo = "toggle", nome = "Auto Sea Events", chave = "AutoSeaEvent" },
    { aba = "Combate", tipo = "toggle", nome = "Auto Raid (só combate, inicie o raid)", chave = "AutoRaid" },

    { aba = "Frutas", tipo = "toggle", nome = "Auto Random Fruit (1x/min)", chave = "AutoRandomFruit" },
    { aba = "Frutas", tipo = "toggle", nome = "Fruit ESP", chave = "FruitESP" },

    { aba = "Visual", tipo = "toggle", nome = "Aviso de Lua Cheia", chave = "FullMoonNotifier" },
    { aba = "Visual", tipo = "toggle", nome = "White Screen (Otimizar CPU / Bateria)", chave = "WhiteScreen", aoMudar = aplicarWhiteScreen },
}

local function definir(controle, valor)
    ConfigStore:Set(controle.chave, valor)
    if controle.aoMudar then pcall(controle.aoMudar, valor) end
end

-- =========================================================================
-- UI 1: RAYFIELD
-- =========================================================================
local Rayfield = nil
local function construirRayfield()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

    local Window = Rayfield:CreateWindow({
        Name = "PRAGMATIC HUB v10.9",
        LoadingTitle = "Carregando...",
        LoadingSubtitle = "Universal Automata",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false,
    })

    local abas = {}
    for _, c in ipairs(CONTROLES) do
        local aba = abas[c.aba]
        if not aba then
            aba = Window:CreateTab(c.aba, 4483362458)
            abas[c.aba] = aba
        end
        if c.tipo == "toggle" then
            aba:CreateToggle({
                Name = c.nome,
                CurrentValue = ConfigStore:Get(c.chave) == true,
                Callback = function(v) definir(c, v) end,
            })
        else
            aba:CreateSlider({
                Name = c.nome,
                Range = { c.min, c.max },
                Increment = c.passo,
                CurrentValue = ConfigStore:Get(c.chave),
                Callback = function(v) definir(c, v) end,
            })
        end
    end
end

-- =========================================================================
-- UI 2: SIMPLES (usada se o Rayfield não carregar, ex.: emulador/celular)
-- =========================================================================
local function montarGui(gui)
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function arredondar(inst)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inst
end

local function tornarArrastavel(frame, alca)
    local dragging, dragInput, dragStart, startPos
    ScriptJanitor:Adicionar(alca.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            local liberar
            liberar = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if liberar then liberar:Disconnect() end
                end
            end)
        end
    end))
    ScriptJanitor:Adicionar(alca.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    ScriptJanitor:Adicionar(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

local function construirUIFallback()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PragmaticCoreUI"
    ScreenGui.ResetOnSpawn = false
    montarGui(ScreenGui)
    ScriptJanitor:Adicionar(ScreenGui, "Destroy")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 270, 0, 340)
    Frame.Position = UDim2.new(0.05, 0, 0.2, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Frame.Active = true
    Frame.Parent = ScreenGui
    arredondar(Frame)

    local Titulo = Instance.new("TextLabel")
    Titulo.Size = UDim2.new(1, -40, 0, 40)
    Titulo.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Titulo.Text = "PRAGMATIC HUB v10.9"
    Titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
    Titulo.Font = Enum.Font.SourceSansBold
    Titulo.Parent = Frame
    tornarArrastavel(Frame, Titulo)

    local Corpo = Instance.new("ScrollingFrame")
    Corpo.Size = UDim2.new(1, 0, 0, 300)
    Corpo.Position = UDim2.new(0, 0, 0, 40)
    Corpo.BackgroundTransparency = 1
    Corpo.ScrollBarThickness = 4
    Corpo.CanvasSize = UDim2.new(0, 0, 0, #CONTROLES * 38 + 10)
    Corpo.Parent = Frame

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.Parent = Corpo

    local Minimizar = Instance.new("TextButton")
    Minimizar.Size = UDim2.new(0, 40, 0, 40)
    Minimizar.Position = UDim2.new(1, -40, 0, 0)
    Minimizar.Text = "-"
    Minimizar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Minimizar.TextColor3 = Color3.fromRGB(255, 255, 255)
    Minimizar.Font = Enum.Font.SourceSansBold
    Minimizar.Parent = Frame
    ScriptJanitor:Adicionar(Minimizar.MouseButton1Click:Connect(function()
        Corpo.Visible = not Corpo.Visible
        Frame.Size = Corpo.Visible and UDim2.new(0, 270, 0, 340) or UDim2.new(0, 270, 0, 40)
    end))

    for _, c in ipairs(CONTROLES) do
        if c.tipo == "toggle" then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -12, 0, 32)
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.Font = Enum.Font.SourceSansBold
            b.Parent = Corpo
            arredondar(b)
            local function visual()
                local ligado = ConfigStore:Get(c.chave) == true
                b.Text = c.nome .. ": " .. (ligado and "ON" or "OFF")
                b.BackgroundColor3 = ligado and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(192, 57, 43)
            end
            visual()
            ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(function()
                definir(c, not (ConfigStore:Get(c.chave) == true))
                visual()
            end))
        else
            local linha = Instance.new("Frame")
            linha.Size = UDim2.new(1, -12, 0, 32)
            linha.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            linha.Parent = Corpo
            arredondar(linha)

            local rotulo = Instance.new("TextLabel")
            rotulo.Size = UDim2.new(1, -80, 1, 0)
            rotulo.BackgroundTransparency = 1
            rotulo.TextColor3 = Color3.fromRGB(255, 255, 255)
            rotulo.Font = Enum.Font.SourceSansBold
            rotulo.Parent = linha

            local function visual()
                rotulo.Text = c.nome .. ": " .. tostring(ConfigStore:Get(c.chave))
            end
            visual()

            local function ajustar(delta)
                local v = (tonumber(ConfigStore:Get(c.chave)) or c.min) + delta
                definir(c, math.clamp(v, c.min, c.max))
                visual()
            end

            local menos = Instance.new("TextButton")
            menos.Size = UDim2.new(0, 36, 1, 0)
            menos.Position = UDim2.new(1, -76, 0, 0)
            menos.Text = "-"
            menos.Parent = linha
            ScriptJanitor:Adicionar(menos.MouseButton1Click:Connect(function() ajustar(-c.passo) end))

            local mais = Instance.new("TextButton")
            mais.Size = UDim2.new(0, 36, 1, 0)
            mais.Position = UDim2.new(1, -38, 0, 0)
            mais.Text = "+"
            mais.Parent = linha
            ScriptJanitor:Adicionar(mais.MouseButton1Click:Connect(function() ajustar(c.passo) end))
        end
    end
end

-- Tenta o Rayfield; se falhar por qualquer motivo, cai na UI simples
task.spawn(function()
    local ok, err = pcall(construirRayfield)
    if ok then
        ScriptJanitor:Adicionar({ Destroy = function()
            pcall(function() Rayfield:Destroy() end)
        end }, "Destroy")
    else
        registrarLog("UI", "Rayfield indisponível, usando UI simples", err)
        if Rayfield then pcall(function() Rayfield:Destroy() end) Rayfield = nil end
        local ok2, err2 = pcall(construirUIFallback)
        if not ok2 then registrarLog("UI", "UI simples também falhou", err2) end
    end
end)

task.delay(1, function()
    notificar("AUTOMATA v10.9", "Script carregado.")
end)