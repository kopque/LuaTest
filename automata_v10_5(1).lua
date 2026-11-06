-- =========================================================================
--   AUTOMATA HUB v12.0 - BLOX FRUITS
-- =========================================================================
-- AVISO: as partes específicas do jogo (remotes, nomes de pastas, bosses,
-- ID da lua) vêm de scripts da comunidade e NÃO foram testadas no jogo.
-- Tudo roda dentro de pcall: se algo falhar, o console (F9) mostra o motivo
-- e o resto do script continua funcionando.
-- Ajuste as CONSTANTES abaixo se o jogo mudar.

local VERSAO = "12.0"

-- =========================================================================
-- LOG / SERVIÇOS
-- =========================================================================
local function registrarLog(modulo, mensagem, erro)
    local sufixo = erro and (" | Erro: " .. tostring(erro)) or ""
    warn(string.format("[%s] [%s] %s%s", os.date("%X"), string.upper(modulo), mensagem, sufixo))
end

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
        local ok, servico = pcall(game.GetService, game, k)
        if ok and servico then t[k] = servico return servico end
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
local HttpService = Services.HttpService
local TeleportService = Services.TeleportService

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- CONSTANTES EDITÁVEIS
-- =========================================================================
local LUA_CHEIA_IDS = { ["9709149431"] = true }   -- MoonTextureId (não confirmado)

local BOSSES = {
    ["Gorilla King"] = true, ["Bobby"] = true, ["Yeti"] = true, ["Mob Leader"] = true,
    ["Vice Admiral"] = true, ["Saber Expert"] = true, ["Warden"] = true, ["Chief Warden"] = true,
    ["Swan"] = true, ["Magma Admiral"] = true, ["Fishman Lord"] = true, ["Wysper"] = true,
    ["Thunder God"] = true, ["Cyborg"] = true, ["Diamond"] = true, ["Jeremy"] = true,
    ["Fajita"] = true, ["Don Swan"] = true, ["Smoke Admiral"] = true,
    ["Awakened Ice Admiral"] = true, ["Tide Keeper"] = true, ["Stone"] = true,
    ["Island Empress"] = true, ["Kilo Admiral"] = true, ["Captain Elephant"] = true,
    ["Beautiful Pirate"] = true,
}
local ELITES = { ["Diablo"] = true, ["Deandre"] = true, ["Urban"] = true }
local SEA_INIMIGOS = { ["Shark"] = true, ["Terrorshark"] = true, ["PirateBrigade"] = true, ["PirateBasic"] = true }
-- "Posessed Mummy" é escrito assim mesmo no jogo
local BONES_MOBS = { ["Reborn Skeleton"] = true, ["Living Zombie"] = true, ["Demonic Soul"] = true, ["Posessed Mummy"] = true }

local ARMAS = { "Melee", "Sword", "Gun", "Blox Fruit" }      -- ToolTips das ferramentas
local ARMAS_MAESTRIA = { "Sword", "Gun" }
local RAIDS = { "Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Rumble", "Magma", "Buddha", "Sand", "Dough" }
local BARCOS = { "PirateBrigade", "MarineBrigade", "PirateGrandBrigade", "MarineGrandBrigade", "Dinghy" }
local NOME_MIRAGE = "MysticIsland"
local NOME_KITSUNE = "KitsuneIsland"
local TECLAS_SKILL = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local CODIGOS = {
    "Sub2UncleKizaru", "Sub2Fer999", "Enyu_is_Pro", "JCWK", "StarcodeHeo", "Bluxxy",
    "fudd10_v2", "FUDD10", "BIGNEWS", "THEGREATACE", "Sub2Daigrock", "Axiore",
    "TantaiGaming", "Sub2NoobMaster123", "Sub2OfficialNoobie", "kittgaming", "Magicbus",
} -- podem estar expirados; códigos inválidos são ignorados

local function listaOrdenada(conjunto)
    local l = {}
    for nome in pairs(conjunto) do table.insert(l, nome) end
    table.sort(l)
    return l
end
local LISTA_BOSSES = listaOrdenada(BOSSES)

-- =========================================================================
-- JANITOR (limpeza ao re-executar)
-- =========================================================================
local ID_UNICO_SCRIPT = "Automata_Hub_Janitor_v12"
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

local genv = (getgenv and getgenv()) or _G
if genv[ID_UNICO_SCRIPT] then genv[ID_UNICO_SCRIPT]:LimparTudo() end
genv[ID_UNICO_SCRIPT] = Janitor.new()
local ScriptJanitor = genv[ID_UNICO_SCRIPT]

local Estado = { rodando = true, modo = "ocioso", inicio = os.clock() }

-- =========================================================================
-- CONFIGURAÇÃO
-- =========================================================================
local Cfg = {}
do
    local valores = {
        -- Main
        AutoFarm = false, AutoFarmNearest = false, AutoBones = false, AutoRandomBone = false,
        FastAttack = false, BringMob = false, AttackDistance = 6.5, Weapon = "Melee",
        -- Mastery
        AutoMastery = false, AutoMasteryFruit = false, MasteryWeapon = "Sword", MasteryHealth = 20,
        -- Bosses
        AutoBossesAll = false, AutoBossSel = false, BossSelecionado = LISTA_BOSSES[1], AutoElite = false,
        -- Sea
        AutoSeaEvent = false, Barco = BARCOS[1], SemNevoa = false,
        -- Raids
        RaidSelecionada = RAIDS[1], AutoBuyChip = false, AutoStartRaid = false,
        AutoRaid = false, AutoNextIsland = false, AutoAwake = false,
        -- Frutas
        AutoRandomFruit = false, IntervaloFruta = 7200, AutoStoreFruit = false, AutoTweenFruit = false,
        FruitSniper = false, FrutaAlvo = "", FruitNotifier = false, WebhookUrl = "", FruitESP = false,
        -- Stats
        AutoStatMelee = false, AutoStatDefense = false, AutoStatSword = false,
        AutoStatGun = false, AutoStatFruit = false, QuantidadePontos = 1,
        -- Teleport
        IlhaSelecionada = nil, NpcSelecionado = nil,
        -- Eventos / Visual / Sistema
        FullMoonNotifier = true, MirageNotifier = false, ChestHop = false, ChestHopServer = false,
        WhiteScreen = false, AutoBuso = false, AntiAFK = true, AutoRejoin = true, Debug = false,
        EmMovimento = false,
    }
    function Cfg:Get(k) return valores[k] end
    function Cfg:Set(k, v) valores[k] = v end
    function Cfg:Reset()
        for k, v in pairs(valores) do
            if type(v) == "boolean" then valores[k] = false end
        end
    end
end

-- =========================================================================
-- UTILITÁRIOS
-- =========================================================================
local function notificar(titulo, texto)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = titulo, Text = texto, Duration = 5 })
    end)
end

local function obterCommF()
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("CommF_")
    if not remote then error("Remotes.CommF_ não encontrado (o jogo é o Blox Fruits?)", 0) end
    return remote
end

local function meuRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function pastaEnemies() return Workspace:FindFirstChild("Enemies") end

-- Junta pastas ignorando nil (ipairs para no primeiro nil!)
local function listaPastas(...)
    local r = {}
    for i = 1, select("#", ...) do
        local p = select(i, ...)
        if p then table.insert(r, p) end
    end
    return r
end

local function locations()
    local origem = Workspace:FindFirstChild("_WorldOrigin")
    return origem and origem:FindFirstChild("Locations")
end

local function spawnsPasta()
    local origem = Workspace:FindFirstChild("_WorldOrigin")
    return origem and origem:FindFirstChild("EnemySpawns")
end

-- CFrame do spawn mais próximo cujo nome contém algum nome do conjunto
local function spawnMaisProximo(conjunto)
    local spawns, root = spawnsPasta(), meuRoot()
    if not spawns or not root then return nil end
    local melhor, menor = nil, math.huge
    for _, s in ipairs(spawns:GetChildren()) do
        for nome in pairs(conjunto) do
            if string.find(s.Name, nome, 1, true) then
                local cf = s:GetPivot()
                local d = (cf.Position - root.Position).Magnitude
                if d < menor then menor, melhor = d, cf end
            end
        end
    end
    return melhor
end

local function existeSpawn(nome)
    local spawns = spawnsPasta()
    if not spawns then return true end -- sem a pasta, não dá para filtrar
    for _, s in ipairs(spawns:GetChildren()) do
        if string.find(s.Name, nome, 1, true) then return true end
    end
    return false
end

-- =========================================================================
-- COMBATE
-- =========================================================================
local CombatManager = {}

function CombatManager:ObterAlvo(pastas, filtro, raio)
    local root = meuRoot()
    if not root then return nil end
    local melhor, menor = nil, raio or 2000
    for _, pasta in ipairs(pastas) do
        for _, ent in ipairs(pasta:GetChildren()) do
            if filtro(ent) then
                local r = ent:FindFirstChild("HumanoidRootPart")
                local h = ent:FindFirstChildOfClass("Humanoid")
                if r and h and h.Health > 0 then
                    local d = (r.Position - root.Position).Magnitude
                    if d < menor then menor, melhor = d, ent end
                end
            end
        end
    end
    return melhor
end

local function escolherFerramenta(char, backpack, tooltip)
    if tooltip then
        for _, container in ipairs({ char, backpack }) do
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == tooltip then return t end
            end
        end
    end
    return char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
end

function CombatManager:Atacar(char, hum, backpack, tooltip)
    local ferramenta = escolherFerramenta(char, backpack, tooltip)
    if ferramenta and ferramenta.Parent ~= char then
        hum:EquipTool(ferramenta)
        task.wait(0.05)
    end
    if ferramenta and ferramenta.Parent == char then
        if VirtualUser then
            pcall(function()
                local cam = Workspace.CurrentCamera
                local cf = cam and cam.CFrame or CFrame.new()
                VirtualUser:Button1Down(Vector2.new(0, 0), cf)
                task.wait(Cfg:Get("FastAttack") and 0.01 or 0.05)
                VirtualUser:Button1Up(Vector2.new(0, 0), cf)
            end)
        end
        pcall(function() ferramenta:Activate() end)
    end
end

function CombatManager:UsarHabilidades()
    if not VirtualInputManager then return end
    for _, tecla in ipairs(TECLAS_SKILL) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, tecla, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, tecla, false, game)
        end)
    end
end

local simRadiusOk = false
local function trazerMobs(alvo, centro)
    if not simRadiusOk then
        simRadiusOk = true
        pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", 1e9) end)
    end
    local pasta = pastaEnemies()
    if not pasta then return end
    for _, m in ipairs(pasta:GetChildren()) do
        if m ~= alvo and m.Name == alvo.Name then
            local r = m:FindFirstChild("HumanoidRootPart")
            local h = m:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 and (r.Position - centro.Position).Magnitude < 250 then
                pcall(function()
                    r.CanCollide = false
                    r.CFrame = centro
                end)
            end
        end
    end
end

-- =========================================================================
-- MOVIMENTAÇÃO (um tween por vez)
-- =========================================================================
local MovementService = { _ocupado = false }

function MovementService:Interpola(destino, velocidade, aindaAtivo)
    if self._ocupado then return false end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end

    self._ocupado = true
    Cfg:Set("EmMovimento", true)

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
    Cfg:Set("EmMovimento", false)

    if not ok then error(erro, 0) end
    return root.Parent ~= nil and (root.Position - destino.Position).Magnitude <= 8
end

local function teleportar(cf, velocidade)
    task.spawn(function()
        local ok, res = pcall(function() return MovementService:Interpola(cf, velocidade or 250) end)
        if not ok then registrarErro("Teleport", res)
        elseif not res then notificar("Teleport", "Não chegou ao destino (movimento em andamento ou personagem morto).") end
    end)
end

-- =========================================================================
-- QUEST DO AUTO FARM LEVEL (usa ReplicatedStorage.Quests; melhor esforço)
-- =========================================================================
local Quest = { nome = nil, indice = nil, mob = nil, ultimo = 0 }

local function questAtiva()
    local ok, v = pcall(function() return LocalPlayer.PlayerGui.Main.Quest.Visible end)
    return ok and v == true
end

function Quest:Atualizar()
    local data = LocalPlayer:FindFirstChild("Data")
    local lv = data and data:FindFirstChild("Level")
    local mod = ReplicatedStorage:FindFirstChild("Quests")
    if not lv or not mod then return end
    local okReq, tabela = pcall(require, mod)
    if not okReq or type(tabela) ~= "table" then return end

    local function melhorQuest(exigirSpawn)
        local nomeQ, idxQ, mobQ, reqQ = nil, nil, nil, -1
        for nome, lista in pairs(tabela) do
            if type(lista) == "table" then
                for idx, q in pairs(lista) do
                    if type(q) == "table" and type(q.Task) == "table" and type(q.LevelReq) == "number"
                        and q.LevelReq <= lv.Value and q.LevelReq > reqQ then
                        local mob, qtd = next(q.Task)
                        -- tarefas com 1 alvo costumam ser bosses: ignora
                        if mob and type(qtd) == "number" and qtd > 1 and not BOSSES[mob]
                            and (not exigirSpawn or existeSpawn(mob)) then
                            nomeQ, idxQ, mobQ, reqQ = nome, idx, mob, q.LevelReq
                        end
                    end
                end
            end
        end
        return nomeQ, idxQ, mobQ
    end

    local n, i, m = melhorQuest(true)
    if not n then n, i, m = melhorQuest(false) end
    self.nome, self.indice, self.mob = n, i, m
end

function Quest:Garantir()
    if os.clock() - self.ultimo < 5 then return end
    self.ultimo = os.clock()
    local antes = self.nome
    self:Atualizar()
    if not self.nome then return end
    local ativa = questAtiva()
    if self.nome ~= antes or not ativa then
        if antes and self.nome ~= antes and ativa then
            pcall(function() obterCommF():InvokeServer("AbandonQuest") end)
        end
        local ok, err = pcall(function() obterCommF():InvokeServer("StartQuest", self.nome, self.indice) end)
        if not ok then registrarErro("Quest", err) end
    end
end

-- =========================================================================
-- DESPACHANTE DE COMBATE (prioridade: topo da lista primeiro)
-- =========================================================================
local function nomeEm(conjunto) return function(ent) return conjunto[ent.Name] == true end end
local function qualquer() return true end
local function soEnemies() return listaPastas(pastaEnemies()) end

local function proximaIlhaRaid()
    if not Cfg:Get("AutoNextIsland") then return nil end
    local locs = locations()
    if not locs then return nil end
    for i = 5, 1, -1 do
        local ilha = locs:FindFirstChild("Island " .. i)
        if ilha then return ilha:GetPivot() end
    end
    return nil
end

local MODOS = {
    { nome = "Boss (todos)", chaves = { "AutoBossesAll" }, filtro = nomeEm(BOSSES), raio = 5000, pastas = soEnemies },
    { nome = "Boss (selecionado)", chaves = { "AutoBossSel" }, raio = 5000, pastas = soEnemies,
      filtro = function(e) return e.Name == Cfg:Get("BossSelecionado") end },
    { nome = "Elite", chaves = { "AutoElite" }, filtro = nomeEm(ELITES), raio = 5000, pastas = soEnemies },
    { nome = "Sea Event", chaves = { "AutoSeaEvent" }, raio = 5000,
      pastas = function() return listaPastas(Workspace:FindFirstChild("SeaBeasts"), pastaEnemies()) end,
      filtro = function(e) return (e.Parent and e.Parent.Name == "SeaBeasts") or SEA_INIMIGOS[e.Name] == true end },
    { nome = "Raid", chaves = { "AutoRaid" }, filtro = qualquer, raio = 1500, pastas = soEnemies,
      fallback = proximaIlhaRaid },
    { nome = "Mastery", chaves = { "AutoMastery", "AutoMasteryFruit" }, filtro = qualquer, raio = 2000,
      pastas = soEnemies, mastery = true },
    { nome = "Bones", chaves = { "AutoBones" }, filtro = nomeEm(BONES_MOBS), raio = 3000, pastas = soEnemies,
      fallback = function() return spawnMaisProximo(BONES_MOBS) end },
    { nome = "Level", chaves = { "AutoFarm" }, raio = 3000, pastas = soEnemies,
      preparar = function() Quest:Garantir() end,
      filtro = function(e) return Quest.mob ~= nil and e.Name == Quest.mob end,
      fallback = function() return Quest.mob and spawnMaisProximo({ [Quest.mob] = true }) or nil end },
    { nome = "Nearest", chaves = { "AutoFarmNearest" }, filtro = qualquer, raio = 500, pastas = soEnemies },
}

local function modoAtivo(modo)
    for _, chave in ipairs(modo.chaves) do
        if Cfg:Get(chave) then return true end
    end
    return false
end

local function algumModoAtivo()
    for _, modo in ipairs(MODOS) do
        if modoAtivo(modo) then return true end
    end
    return false
end

-- Ataca o alvo: aproxima por tween e depois "gruda" acima dele até morrer
local function combater(modo, alvo, char, myRoot, myHum, backpack)
    local rootAlvo = alvo:FindFirstChild("HumanoidRootPart")
    local humAlvo = alvo:FindFirstChildOfClass("Humanoid")
    if not rootAlvo or not humAlvo then return end
    local ativo = function() return modoAtivo(modo) end

    local dist = tonumber(Cfg:Get("AttackDistance")) or 6.5
    local destino = rootAlvo.CFrame * CFrame.new(0, dist, 0)
    if (myRoot.Position - destino.Position).Magnitude > 12 then
        if not MovementService:Interpola(destino, 75, ativo) then return end
    end

    Cfg:Set("EmMovimento", true)
    local inicio = os.clock()
    while Estado.rodando and ativo() and os.clock() - inicio < 5 do
        if myHum.Health <= 0 or not alvo.Parent or humAlvo.Health <= 0 or not rootAlvo.Parent or not myRoot.Parent then
            break
        end
        dist = tonumber(Cfg:Get("AttackDistance")) or 6.5
        myRoot.CFrame = CFrame.new(rootAlvo.Position + Vector3.new(0, dist, 0))
        myRoot.AssemblyLinearVelocity = Vector3.zero
        if Cfg:Get("BringMob") then trazerMobs(alvo, rootAlvo.CFrame) end

        local tooltip, skills = Cfg:Get("Weapon"), false
        if modo.mastery then
            local pct = humAlvo.Health / math.max(humAlvo.MaxHealth, 1) * 100
            if pct <= (tonumber(Cfg:Get("MasteryHealth")) or 20) then
                tooltip = Cfg:Get("AutoMasteryFruit") and "Blox Fruit" or Cfg:Get("MasteryWeapon")
                skills = true
            end
        end
        CombatManager:Atacar(char, myHum, backpack, tooltip)
        if skills then CombatManager:UsarHabilidades() end
        task.wait()
    end
    Cfg:Set("EmMovimento", false)
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
            Estado.modo = modo.nome
            if modo.preparar then pcall(modo.preparar) end
            local alvo = CombatManager:ObterAlvo(modo.pastas(), modo.filtro, modo.raio)
            if alvo then
                combater(modo, alvo, char, myRoot, myHum, backpack)
                return
            end
            if modo.fallback then
                local ok, cf = pcall(modo.fallback)
                if ok and cf then
                    MovementService:Interpola(cf + Vector3.new(0, 20, 0), 90, function() return modoAtivo(modo) end)
                    return
                end
            end
        end
    end
    Estado.modo = "ocioso"
    task.wait(0.4)
end

task.spawn(function()
    while Estado.rodando do
        if algumModoAtivo() then
            local ok, err = pcall(cicloCombate)
            if not ok then registrarErro("Combate", err) end
        else
            Estado.modo = "ocioso"
        end
        task.wait(0.1)
    end
end)

-- =========================================================================
-- LOOPS GENÉRICOS (a função pode devolver o intervalo até a próxima volta)
-- =========================================================================
local function loopToggle(chave, modulo, fn)
    task.spawn(function()
        while Estado.rodando do
            local espera = 1
            if Cfg:Get(chave) then
                local ok, res = pcall(fn)
                if not ok then registrarErro(modulo, res)
                elseif type(res) == "number" then espera = res end
            end
            task.wait(espera)
        end
    end)
end

-- Frutas: compra / guarda / coleta ------------------------------------------
loopToggle("AutoRandomFruit", "Fruta", function()
    local r = obterCommF():InvokeServer("Cousin", "Buy")
    registrarLog("Fruta", "Resposta do jogo: " .. tostring(r))
    return tonumber(Cfg:Get("IntervaloFruta")) or 7200
end)

loopToggle("AutoRandomBone", "Bones", function()
    local r = obterCommF():InvokeServer("Bones", "Buy", 1, 1)
    registrarLog("Bones", "Resposta do jogo: " .. tostring(r))
    return 5
end)

loopToggle("AutoElite", "Elite", function()
    local r = obterCommF():InvokeServer("EliteHunter")
    registrarLog("Elite", "Resposta do jogo: " .. tostring(r))
    return 30
end)

loopToggle("AutoStoreFruit", "Guardar", function()
    -- não guarda a fruta se você a usa para farmar
    if Cfg:Get("AutoMasteryFruit") or Cfg:Get("Weapon") == "Blox Fruit" then return 3 end
    local char, backpack = LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({ backpack, char }) do
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then
                    local nome = t:GetAttribute("OriginalName") or t.Name
                    obterCommF():InvokeServer("StoreFruit", nome, t)
                end
            end
        end
    end
    return 3
end)

local function frutasNoMapa()
    local l = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and string.find(string.lower(obj.Name), "fruit") and obj:FindFirstChild("Handle") then
            table.insert(l, obj)
        end
    end
    return l
end

loopToggle("AutoTweenFruit", "TweenFruta", function()
    local root = meuRoot()
    if not root then return 1 end
    local melhor, menor = nil, math.huge
    for _, f in ipairs(frutasNoMapa()) do
        local d = (f.Handle.Position - root.Position).Magnitude
        if d < menor then menor, melhor = d, f end
    end
    if melhor then
        MovementService:Interpola(melhor.Handle.CFrame, 150, function() return Cfg:Get("AutoTweenFruit") and melhor.Parent ~= nil end)
    end
    return 1
end)

local function trazerTodasFrutas()
    local root = meuRoot()
    if not root then return end
    for _, f in ipairs(frutasNoMapa()) do
        pcall(function()
            if firetouchinterest then
                firetouchinterest(root, f.Handle, 0)
                firetouchinterest(root, f.Handle, 1)
            else
                f.Handle.CFrame = root.CFrame
            end
        end)
    end
end

loopToggle("FruitSniper", "Sniper", function()
    local alvo = string.lower(tostring(Cfg:Get("FrutaAlvo") or ""))
    if alvo == "" then return 5 end
    local lista = obterCommF():InvokeServer("GetFruits")
    if type(lista) == "table" then
        for _, f in pairs(lista) do
            if type(f) == "table" and f.OnSale and string.find(string.lower(tostring(f.Name)), alvo, 1, true) then
                local r = obterCommF():InvokeServer("PurchaseRawFruit", f.Name)
                registrarLog("Sniper", "Compra de " .. tostring(f.Name) .. ": " .. tostring(r))
                notificar("Fruit Sniper", "Tentou comprar " .. tostring(f.Name))
            end
        end
    end
    return 5
end)

-- Webhook do Discord ---------------------------------------------------------
local function enviarWebhook(texto)
    local url = Cfg:Get("WebhookUrl")
    if type(url) ~= "string" or not string.find(url, "^https://") or not string.find(url, "discord", 1, true) then return end
    local req = (syn and syn.request) or http_request or request
    if not req then return end
    pcall(req, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({ content = texto }),
    })
end

do
    local vistos = setmetatable({}, { __mode = "k" })
    loopToggle("FruitNotifier", "Notifier", function()
        for _, f in ipairs(frutasNoMapa()) do
            if not vistos[f] then
                vistos[f] = true
                enviarWebhook("Fruta no mapa: " .. f.Name)
                notificar("Fruta spawnou", f.Name)
            end
        end
        return 3
    end)
end

-- Stats ----------------------------------------------------------------------
local STATS = {
    { "AutoStatMelee", "Melee" }, { "AutoStatDefense", "Defense" }, { "AutoStatSword", "Sword" },
    { "AutoStatGun", "Gun" }, { "AutoStatFruit", "Demon Fruit" },
}
task.spawn(function()
    while Estado.rodando do
        local ok, err = pcall(function()
            local data = LocalPlayer:FindFirstChild("Data")
            local pts = data and data:FindFirstChild("Points")
            if not pts then return end
            for _, s in ipairs(STATS) do
                if Cfg:Get(s[1]) and pts.Value > 0 then
                    local qtd = math.min(tonumber(Cfg:Get("QuantidadePontos")) or 1, pts.Value)
                    obterCommF():InvokeServer("AddPoint", s[2], qtd)
                end
            end
        end)
        if not ok then registrarErro("Stats", err) end
        task.wait(2)
    end
end)

-- Raids ----------------------------------------------------------------------
loopToggle("AutoBuyChip", "Chip", function()
    obterCommF():InvokeServer("RaidsNpc", "Select", Cfg:Get("RaidSelecionada"))
    return 5
end)

loopToggle("AutoStartRaid", "StartRaid", function()
    local mapa = Workspace:FindFirstChild("Map")
    if not mapa or not fireclickdetector then return 6 end
    for _, d in ipairs(mapa:GetDescendants()) do
        if d:IsA("ClickDetector") and d:FindFirstAncestor("RaidSummon2") then
            fireclickdetector(d)
            break
        end
    end
    return 6
end)

loopToggle("AutoAwake", "Awake", function()
    obterCommF():InvokeServer("Awakener", "Awaken")
    return 10
end)

-- Haki / sistema -------------------------------------------------------------
loopToggle("AutoBuso", "Buso", function()
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("HasBuso") then obterCommF():InvokeServer("Buso") end
    return 2
end)

local function comprarBarco()
    task.spawn(function()
        local ok, r = pcall(function() return obterCommF():InvokeServer("BuyBoat", Cfg:Get("Barco")) end)
        if not ok then registrarErro("Barco", r) else registrarLog("Barco", "Resposta do jogo: " .. tostring(r)) end
    end)
end

local function resgatarCodigos()
    task.spawn(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local remote = remotes and remotes:FindFirstChild("Redeem")
        if not remote then notificar("Códigos", "Remote Redeem não encontrado.") return end
        for _, codigo in ipairs(CODIGOS) do
            pcall(function() remote:InvokeServer(codigo) end)
            task.wait(0.6)
        end
        notificar("Códigos", "Tentativa de resgate concluída.")
    end)
end

local function serverHop()
    task.spawn(function()
        local ok, err = pcall(function()
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
            local dados = HttpService:JSONDecode(game:HttpGet(url))
            local candidatos = {}
            for _, s in ipairs(dados.data or {}) do
                if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers - 1 then
                    table.insert(candidatos, s.id)
                end
            end
            if #candidatos == 0 then error("nenhum servidor disponível", 0) end
            TeleportService:TeleportToPlaceInstance(game.PlaceId, candidatos[math.random(#candidatos)], LocalPlayer)
        end)
        if not ok then registrarErro("ServerHop", err) notificar("Server Hop", "Falhou: " .. tostring(err)) end
    end)
end

-- Visuais --------------------------------------------------------------------
local function aplicarWhiteScreen(ligado)
    pcall(function() RunService:Set3dRenderingEnabled(not ligado) end)
end

local fogOriginal = nil
local function aplicarSemNevoa(ligado)
    pcall(function()
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if ligado then
            if not fogOriginal then fogOriginal = { fim = Lighting.FogEnd, dens = atm and atm.Density } end
            Lighting.FogEnd = 1e6
            if atm then atm.Density = 0 end
        elseif fogOriginal then
            Lighting.FogEnd = fogOriginal.fim
            if atm and fogOriginal.dens then atm.Density = fogOriginal.dens end
            fogOriginal = nil
        end
    end)
end

local function irParaIlhaMapa(nome)
    local mapa = Workspace:FindFirstChild("Map")
    local ilha = (mapa and mapa:FindFirstChild(nome)) or Workspace:FindFirstChild(nome, true)
    if not ilha then notificar("Evento", nome .. " não está no servidor agora.") return end
    teleportar(ilha:GetPivot() + Vector3.new(0, 80, 0))
end

local function listarIlhas()
    local l, locs = {}, locations()
    if locs then for _, c in ipairs(locs:GetChildren()) do table.insert(l, c.Name) end end
    table.sort(l)
    return #l > 0 and l or { "(nenhuma)" }
end

local function listarNPCs()
    local l, pasta = {}, Workspace:FindFirstChild("NPCs")
    if pasta then for _, c in ipairs(pasta:GetChildren()) do table.insert(l, c.Name) end end
    table.sort(l)
    return #l > 0 and l or { "(nenhum)" }
end

local function irParaIlhaSelecionada()
    local locs, nome = locations(), Cfg:Get("IlhaSelecionada")
    local ilha = locs and nome and locs:FindFirstChild(nome)
    if ilha then teleportar(ilha:GetPivot() + Vector3.new(0, 50, 0)) else notificar("Teleport", "Escolha uma ilha primeiro.") end
end

local function irParaNpcSelecionado()
    local pasta, nome = Workspace:FindFirstChild("NPCs"), Cfg:Get("NpcSelecionado")
    local npc = pasta and nome and pasta:FindFirstChild(nome)
    if npc then teleportar(npc:GetPivot() + Vector3.new(0, 4, 0)) else notificar("Teleport", "Escolha um NPC primeiro.") end
end

-- =========================================================================
-- ESP DE FRUTAS
-- =========================================================================
task.spawn(function()
    local hls = {}
    local function limpar()
        for obj, h in pairs(hls) do
            pcall(function() h:Destroy() end)
            hls[obj] = nil
        end
    end
    ScriptJanitor:Adicionar({ Destroy = limpar }, "Destroy")

    while Estado.rodando do
        if Cfg:Get("FruitESP") then
            local ok, err = pcall(function()
                for obj, h in pairs(hls) do
                    if not obj.Parent then pcall(function() h:Destroy() end) hls[obj] = nil end
                end
                for _, obj in ipairs(frutasNoMapa()) do
                    if not hls[obj] then
                        local hl = Instance.new("Highlight")
                        hl.Adornee = obj
                        hl.FillColor = Color3.fromRGB(0, 255, 128)
                        hl.Parent = obj
                        hls[obj] = hl
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
-- AVISOS: LUA CHEIA E MIRAGE
-- =========================================================================
task.spawn(function()
    local ultimoId, estavaCheia = nil, false
    while Estado.rodando do
        if Cfg:Get("FullMoonNotifier") then
            local ok, err = pcall(function()
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if not sky then return end
                local id = string.match(tostring(sky.MoonTextureId), "%d+")
                if id ~= ultimoId then
                    ultimoId = id
                    registrarLog("Lua", "MoonTextureId atual: " .. tostring(id))
                end
                local cheia = id ~= nil and LUA_CHEIA_IDS[id] == true
                if cheia and not estavaCheia then notificar("LUA CHEIA ATIVA!", "A Lua Cheia está no céu agora.")
                elseif estavaCheia and not cheia then notificar("Lua Cheia terminou", "A lua mudou de fase.") end
                estavaCheia = cheia
            end)
            if not ok then registrarErro("Lua", err) end
        end
        task.wait(5)
    end
end)

do
    local avisou = false
    loopToggle("MirageNotifier", "Mirage", function()
        local mapa = Workspace:FindFirstChild("Map")
        local existe = (mapa and mapa:FindFirstChild(NOME_MIRAGE)) ~= nil
        if existe and not avisou then notificar("Mirage Island", "A ilha Mirage apareceu neste servidor!") end
        avisou = existe
        return 10
    end)
end

-- =========================================================================
-- NOCLIP (só enquanto há movimento; restaura a colisão depois)
-- =========================================================================
task.spawn(function()
    local originais, partes = {}, {}
    local personagemAtual, ultimoRefresh = nil, 0

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
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        for i = 1, #partes do
            if partes[i].Parent then partes[i].CanCollide = false end
        end
    end

    ScriptJanitor:Adicionar({ Destroy = restaurar }, "Destroy")

    while Estado.rodando do
        local char = LocalPlayer.Character
        if Cfg:Get("EmMovimento") and char then
            pcall(frame, char)
        elseif next(originais) then
            restaurar()
        end
        RunService.Stepped:Wait()
    end
end)

-- =========================================================================
-- CHEST HOP
-- =========================================================================
local visitados = setmetatable({}, { __mode = "k" })
local function chestAtivo() return Cfg:Get("ChestHop") end

local function cicloBaus()
    local myRoot = meuRoot()
    if not myRoot then return nil end
    local agora, lista = os.clock(), {}
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
    return #lista
end

task.spawn(function()
    while Estado.rodando do
        if chestAtivo() then
            local ok, res = pcall(cicloBaus)
            if not ok then registrarErro("ChestHop", res)
            elseif res == 0 and Cfg:Get("ChestHopServer") then serverHop() task.wait(15) end
        end
        task.wait(1)
    end
end)

-- =========================================================================
-- ANTI-AFK E REJOIN AUTOMÁTICO
-- =========================================================================
ScriptJanitor:Adicionar(LocalPlayer.Idled:Connect(function()
    if Cfg:Get("AntiAFK") and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end))

task.spawn(function()
    local ok = pcall(function()
        local gui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = gui and gui:WaitForChild("promptOverlay", 10)
        if not overlay then return end
        ScriptJanitor:Adicionar(overlay.ChildAdded:Connect(function(c)
            if c.Name == "ErrorPrompt" and Cfg:Get("AutoRejoin") then
                task.wait(2)
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
        end))
    end)
    if not ok then registrarLog("Rejoin", "Não foi possível monitorar quedas de conexão") end
end)

-- =========================================================================
-- ENCERRAMENTO (roda ao re-executar)
-- =========================================================================
ScriptJanitor:Adicionar({ Destroy = function()
    Estado.rodando = false
    Cfg:Reset()
    aplicarWhiteScreen(false)
    aplicarSemNevoa(false)
end }, "Destroy")

-- =========================================================================
-- CONTROLES (usados pela UI Rayfield e pela UI simples)
-- tipos: toggle | slider | dropdown | botao | input
-- =========================================================================
local CONTROLES = {
    -- MAIN
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Level", chave = "AutoFarm" },
    { aba = "Main", tipo = "dropdown", nome = "Select Weapon", chave = "Weapon", opcoes = ARMAS },
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Nearest", chave = "AutoFarmNearest" },
    { aba = "Main", tipo = "toggle", nome = "Fast Attack", chave = "FastAttack" },
    { aba = "Main", tipo = "slider", nome = "Attack Distance", chave = "AttackDistance", min = 3, max = 20, passo = 1 },
    { aba = "Main", tipo = "toggle", nome = "Bring Mob", chave = "BringMob" },
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Bones", chave = "AutoBones" },
    { aba = "Main", tipo = "toggle", nome = "Auto Random Bone", chave = "AutoRandomBone" },
    { aba = "Main", tipo = "toggle", nome = "Auto Buso", chave = "AutoBuso" },

    -- MASTERY
    { aba = "Mastery", tipo = "toggle", nome = "Auto Mastery Weapon", chave = "AutoMastery" },
    { aba = "Mastery", tipo = "dropdown", nome = "Select Mastery Weapon", chave = "MasteryWeapon", opcoes = ARMAS_MAESTRIA },
    { aba = "Mastery", tipo = "toggle", nome = "Auto Mastery Fruit", chave = "AutoMasteryFruit" },
    { aba = "Mastery", tipo = "slider", nome = "Mastery Health %", chave = "MasteryHealth", min = 5, max = 60, passo = 5 },

    -- BOSSES
    { aba = "Bosses", tipo = "toggle", nome = "Auto Farm All Bosses", chave = "AutoBossesAll" },
    { aba = "Bosses", tipo = "dropdown", nome = "Select Boss", chave = "BossSelecionado", opcoes = LISTA_BOSSES },
    { aba = "Bosses", tipo = "toggle", nome = "Auto Farm Selected Boss", chave = "AutoBossSel" },
    { aba = "Bosses", tipo = "toggle", nome = "Auto Elite Hunter", chave = "AutoElite" },

    -- SEA EVENTS
    { aba = "Sea", tipo = "dropdown", nome = "Select Boat", chave = "Barco", opcoes = BARCOS },
    { aba = "Sea", tipo = "botao", nome = "Comprar Barco", acao = comprarBarco },
    { aba = "Sea", tipo = "toggle", nome = "Auto Attack Sea Events", chave = "AutoSeaEvent" },
    { aba = "Sea", tipo = "toggle", nome = "Remover Névoa (Zona 6)", chave = "SemNevoa", aoMudar = aplicarSemNevoa },

    -- RAIDS
    { aba = "Raids", tipo = "dropdown", nome = "Select Raid", chave = "RaidSelecionada", opcoes = RAIDS },
    { aba = "Raids", tipo = "toggle", nome = "Auto Buy Chip", chave = "AutoBuyChip" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Start Raid", chave = "AutoStartRaid" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Kill Aura (Raid)", chave = "AutoRaid" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Next Island", chave = "AutoNextIsland" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Awake Fruit", chave = "AutoAwake" },

    -- FRUITS
    { aba = "Frutas", tipo = "toggle", nome = "Auto Random Fruit", chave = "AutoRandomFruit" },
    { aba = "Frutas", tipo = "slider", nome = "Intervalo Random Fruit (s)", chave = "IntervaloFruta", min = 30, max = 7200, passo = 30 },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Store Fruit", chave = "AutoStoreFruit" },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Tween Fruit", chave = "AutoTweenFruit" },
    { aba = "Frutas", tipo = "botao", nome = "Bring All Fruits", acao = trazerTodasFrutas },
    { aba = "Frutas", tipo = "toggle", nome = "Fruit ESP", chave = "FruitESP" },
    { aba = "Frutas", tipo = "input", nome = "Fruit Sniper: nome da fruta", chave = "FrutaAlvo" },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Buy Fruit (Sniper)", chave = "FruitSniper" },
    { aba = "Frutas", tipo = "input", nome = "Discord Webhook URL", chave = "WebhookUrl" },
    { aba = "Frutas", tipo = "toggle", nome = "Fruit Notifier (Webhook)", chave = "FruitNotifier" },

    -- STATS
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Melee", chave = "AutoStatMelee" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Defense", chave = "AutoStatDefense" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Sword", chave = "AutoStatSword" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Gun", chave = "AutoStatGun" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Blox Fruit", chave = "AutoStatFruit" },
    { aba = "Stats", tipo = "slider", nome = "Point Amount", chave = "QuantidadePontos", min = 1, max = 10, passo = 1 },

    -- TELEPORT
    { aba = "Teleport", tipo = "dropdown", nome = "Select Island", chave = "IlhaSelecionada", opcoes = listarIlhas },
    { aba = "Teleport", tipo = "botao", nome = "Teleport to Island", acao = irParaIlhaSelecionada },
    { aba = "Teleport", tipo = "dropdown", nome = "Select NPC", chave = "NpcSelecionado", opcoes = listarNPCs },
    { aba = "Teleport", tipo = "botao", nome = "Teleport to NPC", acao = irParaNpcSelecionado },

    -- EVENTOS
    { aba = "Eventos", tipo = "toggle", nome = "Aviso de Lua Cheia", chave = "FullMoonNotifier" },
    { aba = "Eventos", tipo = "toggle", nome = "Aviso de Mirage Island", chave = "MirageNotifier" },
    { aba = "Eventos", tipo = "botao", nome = "Mirage Island Teleport", acao = function() irParaIlhaMapa(NOME_MIRAGE) end },
    { aba = "Eventos", tipo = "botao", nome = "Kitsune Island Teleport", acao = function() irParaIlhaMapa(NOME_KITSUNE) end },
    { aba = "Eventos", tipo = "toggle", nome = "Chest Hop (Coletar Baús)", chave = "ChestHop" },
    { aba = "Eventos", tipo = "toggle", nome = "Chest Hop: trocar de servidor ao acabar", chave = "ChestHopServer" },

    -- SISTEMA
    { aba = "Sistema", tipo = "toggle", nome = "White Screen (CPU/Bateria)", chave = "WhiteScreen", aoMudar = aplicarWhiteScreen },
    { aba = "Sistema", tipo = "toggle", nome = "Debug Screen", chave = "Debug" },
    { aba = "Sistema", tipo = "toggle", nome = "Anti-AFK", chave = "AntiAFK" },
    { aba = "Sistema", tipo = "toggle", nome = "Auto Rejoin (queda de conexão)", chave = "AutoRejoin" },
    { aba = "Sistema", tipo = "botao", nome = "Server Hop", acao = serverHop },
    { aba = "Sistema", tipo = "botao", nome = "Auto Redeem All Codes", acao = resgatarCodigos },
}

local function definir(c, valor)
    Cfg:Set(c.chave, valor)
    if c.aoMudar then pcall(c.aoMudar, valor) end
end

local function opcoesDe(c)
    local o = c.opcoes
    if type(o) == "function" then o = o() end
    return o
end

-- valores iniciais dos dropdowns dinâmicos (ilha/NPC)
for _, c in ipairs(CONTROLES) do
    if c.tipo == "dropdown" and Cfg:Get(c.chave) == nil then
        Cfg:Set(c.chave, opcoesDe(c)[1])
    end
end

-- =========================================================================
-- HUD DE DEBUG + BOTÃO FLUTUANTE
-- =========================================================================
local function montarGui(gui)
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local function arredondar(inst, raio)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, raio or 6)
    c.Parent = inst
end

local function formatarTempo(s)
    s = math.floor(s)
    return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local function criarDebugHud()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutomataHud"
    gui.ResetOnSpawn = false
    montarGui(gui)
    ScriptJanitor:Adicionar(gui, "Destroy")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 210, 0, 74)
    label.Position = UDim2.new(1, -220, 0, 10)
    label.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    label.BackgroundTransparency = 0.25
    label.TextColor3 = Color3.fromRGB(230, 230, 240)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Visible = false
    label.Parent = gui
    arredondar(label)

    task.spawn(function()
        while Estado.rodando do
            label.Visible = Cfg:Get("Debug") == true
            if label.Visible then
                local lv, beli, frag = "?", "?", "?"
                pcall(function()
                    local d = LocalPlayer.Data
                    lv, beli, frag = d.Level.Value, d.Beli.Value, d.Fragments.Value
                end)
                label.Text = string.format(" Sessão: %s\n Modo: %s\n Level: %s\n Beli: %s | Frag: %s",
                    formatarTempo(os.clock() - Estado.inicio), Estado.modo, tostring(lv), tostring(beli), tostring(frag))
            end
            task.wait(1)
        end
    end)
end

local function criarBotaoFlutuante(aoClicar)
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutomataToggle"
    gui.ResetOnSpawn = false
    montarGui(gui)
    ScriptJanitor:Adicionar(gui, "Destroy")

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 44)
    b.Position = UDim2.new(0, 10, 0.5, -22)
    b.Text = "A"
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = Color3.fromRGB(110, 70, 220)
    b.Parent = gui
    arredondar(b, 22)
    ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(aoClicar))
end

-- =========================================================================
-- UI 1: RAYFIELD
-- =========================================================================
local Rayfield = nil
local rayfieldVisivel = true

local function construirRayfield()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

    local Window = Rayfield:CreateWindow({
        Name = "AUTOMATA HUB v" .. VERSAO,
        LoadingTitle = "Carregando...",
        LoadingSubtitle = "Blox Fruits",
        Theme = "Amethyst",
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
            aba:CreateToggle({ Name = c.nome, CurrentValue = Cfg:Get(c.chave) == true,
                Callback = function(v) definir(c, v) end })
        elseif c.tipo == "slider" then
            aba:CreateSlider({ Name = c.nome, Range = { c.min, c.max }, Increment = c.passo,
                CurrentValue = Cfg:Get(c.chave), Callback = function(v) definir(c, v) end })
        elseif c.tipo == "dropdown" then
            aba:CreateDropdown({ Name = c.nome, Options = opcoesDe(c), MultipleOptions = false,
                CurrentOption = { tostring(Cfg:Get(c.chave)) },
                Callback = function(op) definir(c, type(op) == "table" and op[1] or op) end })
        elseif c.tipo == "botao" then
            aba:CreateButton({ Name = c.nome, Callback = function() task.spawn(c.acao) end })
        elseif c.tipo == "input" then
            aba:CreateInput({ Name = c.nome, PlaceholderText = "digite aqui", RemoveTextAfterFocusLost = false,
                Callback = function(t) definir(c, t) end })
        end
    end
end

-- =========================================================================
-- UI 2: SIMPLES COM ABAS (usada se o Rayfield não carregar)
-- =========================================================================
local fallbackFrame = nil

local function tornarArrastavel(frame, alca)
    local dragging, dragInput, dragStart, startPos
    ScriptJanitor:Adicionar(alca.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
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

local function novoBotao(pai, texto, cor, altura)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, altura or 32)
    b.Text = texto
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.BackgroundColor3 = cor or Color3.fromRGB(40, 40, 55)
    b.Parent = pai
    arredondar(b)
    return b
end

local function construirUIFallback()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutomataFallbackUI"
    gui.ResetOnSpawn = false
    montarGui(gui)
    ScriptJanitor:Adicionar(gui, "Destroy")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 380)
    Frame.Position = UDim2.new(0.05, 0, 0.2, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    Frame.Active = true
    Frame.Parent = gui
    arredondar(Frame, 8)
    fallbackFrame = Frame

    local Titulo = Instance.new("TextLabel")
    Titulo.Size = UDim2.new(1, 0, 0, 34)
    Titulo.BackgroundColor3 = Color3.fromRGB(110, 70, 220)
    Titulo.Text = "AUTOMATA HUB v" .. VERSAO
    Titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
    Titulo.Font = Enum.Font.GothamBold
    Titulo.TextSize = 14
    Titulo.Parent = Frame
    arredondar(Titulo, 8)
    tornarArrastavel(Frame, Titulo)

    local BarraAbas = Instance.new("ScrollingFrame")
    BarraAbas.Size = UDim2.new(1, -8, 0, 34)
    BarraAbas.Position = UDim2.new(0, 4, 0, 38)
    BarraAbas.BackgroundTransparency = 1
    BarraAbas.ScrollBarThickness = 0
    BarraAbas.CanvasSize = UDim2.new(0, 0, 0, 0)
    BarraAbas.AutomaticCanvasSize = Enum.AutomaticSize.X
    BarraAbas.ScrollingDirection = Enum.ScrollingDirection.X
    BarraAbas.Parent = Frame
    local layoutAbas = Instance.new("UIListLayout")
    layoutAbas.FillDirection = Enum.FillDirection.Horizontal
    layoutAbas.Padding = UDim.new(0, 4)
    layoutAbas.Parent = BarraAbas

    local paginas, botoesAba = {}, {}
    local function mostrar(nome)
        for n, p in pairs(paginas) do p.Visible = (n == nome) end
        for n, b in pairs(botoesAba) do
            b.BackgroundColor3 = (n == nome) and Color3.fromRGB(110, 70, 220) or Color3.fromRGB(40, 40, 55)
        end
    end

    local function pagina(nome)
        if paginas[nome] then return paginas[nome] end
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 1, 0)
        btn.Text = nome
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btn.Parent = BarraAbas
        arredondar(btn)
        botoesAba[nome] = btn
        ScriptJanitor:Adicionar(btn.MouseButton1Click:Connect(function() mostrar(nome) end))

        local p = Instance.new("ScrollingFrame")
        p.Size = UDim2.new(1, -8, 1, -80)
        p.Position = UDim2.new(0, 4, 0, 76)
        p.BackgroundTransparency = 1
        p.ScrollBarThickness = 4
        p.CanvasSize = UDim2.new(0, 0, 0, 0)
        p.AutomaticCanvasSize = Enum.AutomaticSize.Y
        p.Visible = false
        p.Parent = Frame
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 6)
        lay.Parent = p
        paginas[nome] = p
        return p
    end

    local primeira = nil
    for _, c in ipairs(CONTROLES) do
        local p = pagina(c.aba)
        primeira = primeira or c.aba

        if c.tipo == "toggle" then
            local b = novoBotao(p, "", nil)
            local function visual()
                local on = Cfg:Get(c.chave) == true
                b.Text = c.nome .. ": " .. (on and "ON" or "OFF")
                b.BackgroundColor3 = on and Color3.fromRGB(46, 160, 100) or Color3.fromRGB(150, 50, 50)
            end
            visual()
            ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(function()
                definir(c, not (Cfg:Get(c.chave) == true))
                visual()
            end))

        elseif c.tipo == "slider" then
            local linha = Instance.new("Frame")
            linha.Size = UDim2.new(1, -12, 0, 32)
            linha.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            linha.Parent = p
            arredondar(linha)
            local rotulo = Instance.new("TextLabel")
            rotulo.Size = UDim2.new(1, -80, 1, 0)
            rotulo.BackgroundTransparency = 1
            rotulo.TextColor3 = Color3.fromRGB(255, 255, 255)
            rotulo.Font = Enum.Font.GothamBold
            rotulo.TextSize = 12
            rotulo.Parent = linha
            local function visual() rotulo.Text = c.nome .. ": " .. tostring(Cfg:Get(c.chave)) end
            visual()
            local function ajustar(delta)
                local v = (tonumber(Cfg:Get(c.chave)) or c.min) + delta
                definir(c, math.clamp(v, c.min, c.max))
                visual()
            end
            for i, info in ipairs({ { "-", -c.passo }, { "+", c.passo } }) do
                local bt = Instance.new("TextButton")
                bt.Size = UDim2.new(0, 34, 1, 0)
                bt.Position = UDim2.new(1, -76 + (i - 1) * 38, 0, 0)
                bt.Text = info[1]
                bt.Font = Enum.Font.GothamBold
                bt.TextColor3 = Color3.fromRGB(255, 255, 255)
                bt.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                bt.Parent = linha
                arredondar(bt)
                ScriptJanitor:Adicionar(bt.MouseButton1Click:Connect(function() ajustar(info[2]) end))
            end

        elseif c.tipo == "dropdown" then
            local b = novoBotao(p, "", Color3.fromRGB(45, 45, 70))
            local opcoes = opcoesDe(c)
            local function visual() b.Text = c.nome .. ": " .. tostring(Cfg:Get(c.chave)) .. "  >" end
            visual()
            ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(function()
                local idx = table.find(opcoes, Cfg:Get(c.chave)) or 0
                definir(c, opcoes[(idx % #opcoes) + 1])
                visual()
            end))

        elseif c.tipo == "botao" then
            local b = novoBotao(p, c.nome, Color3.fromRGB(70, 90, 170))
            ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(function() task.spawn(c.acao) end))

        elseif c.tipo == "input" then
            local linha = Instance.new("Frame")
            linha.Size = UDim2.new(1, -12, 0, 50)
            linha.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            linha.Parent = p
            arredondar(linha)
            local rotulo = Instance.new("TextLabel")
            rotulo.Size = UDim2.new(1, 0, 0, 20)
            rotulo.BackgroundTransparency = 1
            rotulo.Text = c.nome
            rotulo.TextColor3 = Color3.fromRGB(255, 255, 255)
            rotulo.Font = Enum.Font.GothamBold
            rotulo.TextSize = 12
            rotulo.Parent = linha
            local caixa = Instance.new("TextBox")
            caixa.Size = UDim2.new(1, -12, 0, 24)
            caixa.Position = UDim2.new(0, 6, 0, 22)
            caixa.Text = tostring(Cfg:Get(c.chave) or "")
            caixa.PlaceholderText = "digite aqui"
            caixa.ClearTextOnFocus = false
            caixa.TextColor3 = Color3.fromRGB(255, 255, 255)
            caixa.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            caixa.Font = Enum.Font.Gotham
            caixa.TextSize = 12
            caixa.Parent = linha
            arredondar(caixa)
            ScriptJanitor:Adicionar(caixa.FocusLost:Connect(function() definir(c, caixa.Text) end))
        end
    end
    if primeira then mostrar(primeira) end
end

-- =========================================================================
-- INICIALIZAÇÃO: tenta Rayfield; se falhar, usa a UI simples
-- =========================================================================
criarDebugHud()

task.spawn(function()
    local ok, err = pcall(construirRayfield)
    if ok then
        ScriptJanitor:Adicionar({ Destroy = function() pcall(function() Rayfield:Destroy() end) end }, "Destroy")
        criarBotaoFlutuante(function()
            rayfieldVisivel = not rayfieldVisivel
            pcall(function() Rayfield:SetVisibility(rayfieldVisivel) end)
        end)
    else
        registrarLog("UI", "Rayfield indisponível, usando UI simples", err)
        if Rayfield then pcall(function() Rayfield:Destroy() end) Rayfield = nil end
        local ok2, err2 = pcall(construirUIFallback)
        if not ok2 then
            registrarLog("UI", "UI simples também falhou", err2)
        else
            criarBotaoFlutuante(function()
                if fallbackFrame then fallbackFrame.Visible = not fallbackFrame.Visible end
            end)
        end
    end
end)

task.delay(1, function()
    notificar("AUTOMATA v" .. VERSAO, "Script carregado.")
end)