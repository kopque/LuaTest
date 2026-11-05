-- =========================================================================
--   UNIVERSAL AUTOMATA v10.4 - PRODUCTION REFACTORED COM UI PROFISSIONAL
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

local ID_UNICO_SCRIPT = "UltraTech_Automata_Core_Janitor_v10_4"
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
        TweenSpeed = 75,
        FruitESP = false
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
    ConfigStore:Set("FruitESP", false)
end }, "Destroy")

-- =========================================================================
-- GERENCIADOR DE COMBATE E FILTRAGEM ESPACIAL
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

    local sucessoTween = pcall(function()
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

    return finalizado
end

-- =========================================================================
-- MÓDULO ESP DE FRUTAS (COM SUPORTE A LIGA/DESLIGA)
-- =========================================================================
task.spawn(function()
    local espHighlights = {}

    local function limparESP()
        for _, h in pairs(espHighlights) do
            if h then h:Destroy() end
        end
        table.clear(espHighlights)
    end

    local function gerenciarESP()
        while true do
            if ConfigStore:Get("FruitESP") then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj:IsA("Tool") and string.find(string.lower(obj.Name), "fruit") then
                        if not espHighlights[obj] and obj:FindFirstChild("Handle") then
                            local hl = Instance.new("Highlight")
                            hl.Name = "FruitESP_Highlight"
                            hl.Adornee = obj
                            hl.FillColor = Color3.fromRGB(0, 255, 128)
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.Parent = obj
                            espHighlights[obj] = hl
                        end
                    end
                end
            else
                limparESP()
            end
            task.wait(1)
        end
    end
    task.spawn(gerenciarESP)
    ScriptJanitor:Adicionar({ Destroy = limparESP }, "Destroy")
end)

-- =========================================================================
-- MOTOR DE NOCLIP REATIVO
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

    ScriptJanitor:Adicionar({ Destroy = function() ativoNoclip = false restaurarColisao() end }, "Destroy")
    
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
-- LOOP DE COMBATE SEGURO (CORREÇÃO DO BUG DO INVENTÁRIO)
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
                    local targetCFrame = rootAlvo.CFrame * CFrame.new(0, 6.5, 0)
                    
                    if chegouComSucesso and ConfigStore:Get("AutoFarm") and (myRoot.Position - targetCFrame.Position).Magnitude < 12 then
                        -- Seleção segura de ferramenta sem simular teclas erradas que abrem o inventário
                        local ferramenta = char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
                        if ferramenta then
                            if ferramenta.Parent == backpack then
                                myHum:EquipTool(ferramenta)
                                task.wait(0.05)
                            end
                            if ferramenta.Parent == char then
                                pcall(function() ferramenta:Activate() end)
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
            if not sucesso then
                contadorFalhas = contadorFalhas + 1
                registrarLog("EngineLoop", "Erro no combate", erroInterno)
                if contadorFalhas >= 5 then
                    ConfigStore:Set("AutoFarm", false)
                    contadorFalhas = 0
                    registrarLog("EngineLoop", "Disjuntor acionado. AutoFarm desligado.", nil)
                end
            else
                contadorFalhas = 0
            end
        end
        task.wait(0.1)
    end
end)

-- =========================================================================
-- INTERFACE GRÁFICA PROFISSIONAL (RAYFIELD UI)
-- =========================================================================
pcall(function()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    local Window = Rayfield:CreateWindow({
       Name = "🛡️ PRAGMATIC HUB v10.4 - Blox Fruits",
       LoadingTitle = "A carregar Automatização...",
       LoadingSubtitle = "por Universal Automata",
       ConfigurationSaving = {
          Enabled = false,
       },
       KeySystem = false,
    })

    local TabFarm = Window:CreateTab("⚔️ Auto Farm", 4483362458)
    local TabVisual = Window:CreateTab("👁️ Visual / ESP", 4483362458)
    local TabSettings = Window:CreateTab("⚙️ Definições", 4483362458)

    -- Secção Auto Farm
    TabFarm:CreateToggle({
       Name = "Ativar Auto Farm",
       CurrentValue = false,
       Flag = "ToggleAutoFarm",
       Callback = function(Value)
          ConfigStore:Set("AutoFarm", Value)
       end,
    })

    TabFarm:CreateSlider({
       Name = "Velocidade do Tween (Studs/s)",
       Range = {20, 150},
       Increment = 5,
       CurrentValue = 75,
       Flag = "SliderSpeed",
       Callback = function(Value)
          ConfigStore:Set("TweenSpeed", Value)
       end,
    })

    -- Secção Visual / ESP
    TabVisual:CreateToggle({
       Name = "Ativar ESP de Frutas",
       CurrentValue = false,
       Flag = "ToggleFruitESP",
       Callback = function(Value)
          ConfigStore:Set("FruitESP", Value)
       end,
    })

    -- Secção Definições
    TabSettings:CreateButton({
       Name = "Descarregar / Fechar Hub",
       Callback = function()
          ScriptJanitor:LimparTudo()
          Rayfield:Destroy()
       end,
    })
end)

task.delay(1, function()
    pcall(function()
        if StarterGui then
            StarterGui:SetCore("SendNotification", {
                Title = "AUTOMATA v10.4",
                Text = "Interface e módulos carregados com sucesso!",
                Duration = 4
            })
        end
    end)
end)