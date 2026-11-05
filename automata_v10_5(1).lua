-- =========================================================================
--   UNIVERSAL AUTOMATA v10.5 - PRODUCTION RESILIENT ENGINE (CONSOLIDADO)
-- =========================================================================

local function registrarLog(modulo, mensagem, erro)
    local sufixo = erro and (" | Erro: " .. tostring(erro)) or ""
    print(string.format("[%s] [%s] %s%s", os.date("%X"), string.upper(modulo), mensagem, sufixo))
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
local CoreGui = Services.CoreGui
local StarterGui = Services.StarterGui
local UserInputService = Services.UserInputService

local LocalPlayer = Players.LocalPlayer

local NewInstance = function(classe, pai)
    local o = Instance.new(classe)
    if pai then o.Parent = pai end
    return o
end
local ColorFromRGB = Color3.fromRGB

local ID_UNICO_SCRIPT = "UltraTech_Automata_Core_Janitor_v10_5"
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
-- CONFIGURAÇÃO ENCAPSULADA
-- =========================================================================
local ConfigStore = {}
do
    local estadoInterno = {
        AutoFarm = false,
        EmMovimento = false,
        TweenSpeed = 75
    }

    function ConfigStore:Get(chave)
        return estadoInterno[chave]
    end

    function ConfigStore:Set(chave, valor)
        estadoInterno[chave] = valor
    end
end

ScriptJanitor:Adicionar({ Destroy = function()
    ConfigStore:Set("AutoFarm", false)
    ConfigStore:Set("EmMovimento", false)
end }, "Destroy")

-- =========================================================================
-- GERENCIADOR DE COMBATE E FILTRAGEM ESPACIAL RESTRETA
-- =========================================================================
local CombatManager = {}
function CombatManager:ObterInimigoMaisProximo(myPosition)
    local pastaInimigos = Workspace:FindFirstChild("Enemies")
    if not pastaInimigos then return nil end

    local listaInimigos = pastaInimigos:GetChildren()
    local alvoMaisProximo = nil
    local menorDistancia = 1500

    for i = 1, #listaInimigos do
        local entidade = listaInimigos[i]
        local root = entidade:FindFirstChild("HumanoidRootPart")
        local hum = entidade:FindFirstChildOfClass("Humanoid")

        if root and hum and hum.Health > 0 then
            local distancia = (root.Position - myPosition).Magnitude
            if distancia < menorDistancia then
                menorDistancia = distancia
                alvoMaisProximo = entidade
            end
        end
    end
    return alvoMaisProximo
end

-- =========================================================================
-- MOTOR DE MOVIMENTAÇÃO DINÂMICA
-- =========================================================================
local MovementService = {}
function MovementService:Interpola(alvoInimigo, velocidade)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end

    local alvoRoot = alvoInimigo:FindFirstChild("HumanoidRootPart")
    local alvoHum = alvoInimigo:FindFirstChildOfClass("Humanoid")
    if not alvoRoot or not alvoHum or alvoHum.Health <= 0 then return false end

    local finalizado = false
    local t = nil
    local offsetAlvo = CFrame.new(0, 6.5, 0)
    local alvoPosicaoCFrame = alvoRoot.CFrame * offsetAlvo

    ConfigStore:Set("EmMovimento", true)

    local sucessoTween, erroTween = pcall(function()
        local distancia = (root.Position - alvoPosicaoCFrame.Position).Magnitude
        local tempoEstimado = distancia / velocidade

        local info = TweenInfo.new(tempoEstimado, Enum.EasingStyle.Linear)
        t = TweenService:Create(root, info, { CFrame = alvoPosicaoCFrame })

        t.Completed:Connect(function(estado)
            if estado == Enum.PlaybackState.Completed then
                finalizado = true
            end
        end)

        t:Play()

        local tempoGasto = 0
        while not finalizado and ConfigStore:Get("AutoFarm") and char and root and alvoRoot and alvoRoot.Parent and alvoHum.Health > 0 and hum.Health > 0 do
            task.wait(0.1)
            tempoGasto = tempoGasto + 0.1

            local novaPosicaoAlvo = alvoRoot.CFrame * offsetAlvo
            if (novaPosicaoAlvo.Position - alvoPosicaoCFrame.Position).Magnitude > 5 then
                break
            end
            if tempoGasto > (tempoEstimado + 2) then break end
        end
    end)

    ConfigStore:Set("EmMovimento", false)
    if t then t:Cancel() t:Destroy() end
    if not sucessoTween then error(erroTween, 0) end

    return finalizado
end

-- =========================================================================
-- INTERFACE GRÁFICA
-- =========================================================================
local ScreenGui = NewInstance("ScreenGui")
ScreenGui.Name = "PragmaticCoreUI"
ScreenGui.ResetOnSpawn = false

local sucessoUI = pcall(function() ScreenGui.Parent = CoreGui end)
if not sucessoUI then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
ScriptJanitor:Adicionar(ScreenGui, "Destroy")

local MainFrame = NewInstance("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 240, 0, 110)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = ColorFromRGB(15, 15, 20)
MainFrame.Active = true

do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    ScriptJanitor:Adicionar(MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position

            local releaseEvent
            releaseEvent = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if releaseEvent then releaseEvent:Disconnect() end
                end
            end)
        end
    end))

    ScriptJanitor:Adicionar(MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    ScriptJanitor:Adicionar(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end))
end

local Titulo = NewInstance("TextLabel", MainFrame)
Titulo.Size = UDim2.new(1, 0, 0, 40)
Titulo.BackgroundColor3 = ColorFromRGB(25, 25, 35)
Titulo.Text = "🛡️ PRAGMATIC HUB v10.5"
Titulo.TextColor3 = ColorFromRGB(255, 255, 255)
Titulo.Font = Enum.Font.SourceSansBold

local function criarBotao(txt, pos, cb)
    local b = NewInstance("TextButton", MainFrame)
    b.Size = UDim2.new(0, 200, 0, 35)
    b.Position = pos
    b.Text = txt
    b.BackgroundColor3 = ColorFromRGB(30, 30, 40)
    b.TextColor3 = ColorFromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    NewInstance("UICorner", b).CornerRadius = UDim.new(0, 6)
    ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(cb))
    return b
end

local BtnFarm
BtnFarm = criarBotao("FARM: DESATIVADO", UDim2.new(0, 20, 0, 55), function()
    local novoEstado = not ConfigStore:Get("AutoFarm")
    ConfigStore:Set("AutoFarm", novoEstado)
    BtnFarm.Text = novoEstado and "FARM: ATIVO" or "FARM: DESATIVADO"
    BtnFarm.BackgroundColor3 = novoEstado and ColorFromRGB(46, 204, 113) or ColorFromRGB(192, 57, 43)
end)

-- =========================================================================
-- MOTOR DE NOCLIP
-- =========================================================================
task.spawn(function()
    local ativoNoclip = true
    local originais = {}
    local partes = {}
    local personagemAtual = nil
    local ultimoRefresh = 0

    local function restaurarColisao()
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

    local function processarNoclipFrame(char)
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

    ScriptJanitor:Adicionar({ Destroy = function()
        ativoNoclip = false
        restaurarColisao()
    end }, "Destroy")

    while ativoNoclip do
        local char = LocalPlayer.Character
        if ConfigStore:Get("AutoFarm") and ConfigStore:Get("EmMovimento") and char then
            pcall(processarNoclipFrame, char)
        elseif next(originais) then
            restaurarColisao()
        end
        RunService.Stepped:Wait()
    end
end)

-- =========================================================================
-- LOOP DE COMBATE
-- =========================================================================
task.spawn(function()
    local executandoHub = true
    local contadorFalhas = 0
    ScriptJanitor:Adicionar({ Destroy = function() executandoHub = false end }, "Destroy")

    local function cicloPrincipalCombate()
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        local myHum = char and char:FindFirstChildOfClass("Humanoid")
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

        if myRoot and myHum and myHum.Health > 0 and backpack then
            local inimigoAlvo = CombatManager:ObterInimigoMaisProximo(myRoot.Position)
            if inimigoAlvo then
                local rootAlvo = inimigoAlvo:FindFirstChild("HumanoidRootPart")
                local humAlvo = inimigoAlvo:FindFirstChildOfClass("Humanoid")
                if rootAlvo and humAlvo and humAlvo.Health > 0 then
                    local chegouComSucesso = MovementService:Interpola(inimigoAlvo, ConfigStore:Get("TweenSpeed"))
                    local offsetPos = CFrame.new(0, 6.5, 0)
                    local targetCFrame = rootAlvo.CFrame * offsetPos
                    if chegouComSucesso and ConfigStore:Get("AutoFarm") and (myRoot.Position - targetCFrame.Position).Magnitude < 8 then
                        local ferramenta = char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
                        if ferramenta then
                            if ferramenta.Parent == backpack then
                                myHum:EquipTool(ferramenta)
                                task.wait(0.05)
                            end
                            if ferramenta.Parent == char then
                                ferramenta:Activate()
                            end
                        end
                    end
                else
                    task.wait(0.1)
                end
            else
                task.wait(0.4)
            end
        else
            task.wait(0.5)
        end
    end

    while executandoHub do
        if ConfigStore:Get("AutoFarm") then
            local sucesso, erroInterno = pcall(cicloPrincipalCombate)
            if sucesso then
                contadorFalhas = 0
            else
                contadorFalhas = contadorFalhas + 1
                registrarLog("EngineLoop", "Erro detectado na execução de combate", erroInterno)
                if contadorFalhas >= 5 then
                    ConfigStore:Set("AutoFarm", false)
                    contadorFalhas = 0
                    BtnFarm.Text = "FARM: DESATIVADO"
                    BtnFarm.BackgroundColor3 = ColorFromRGB(192, 57, 43)
                    registrarLog("EngineLoop", "Disjuntor acionado. AutoFarm desligado.", nil)
                end
            end
        end
        task.wait(0.1)
    end
end)

task.delay(1, function()
    pcall(function()
        if StarterGui then
            StarterGui:SetCore("SendNotification", {
                Title = "AUTOMATA v10.5",
                Text = "Malha de produção implantada.",
                Duration = 3
            })
        end
    end)
end)
