-- =========================================================================
--   AUTOMATA HUB v13.0 - BLOX FRUITS
-- =========================================================================
-- AVISO: as partes específicas do jogo (remotes, nomes de pastas, bosses,
-- ID da lua, nomes das ilhas de evento) vêm de scripts da comunidade e NÃO
-- foram testadas no jogo. Tudo roda dentro de pcall: se algo falhar, o
-- console (F9) mostra o motivo e o resto do script continua funcionando.
-- Ajuste as CONSTANTES abaixo se o jogo mudar.
--
-- NOVIDADES v13.0
--  * UI própria com abas na ESQUERDA (o Rayfield foi removido)
--  * Seleção de Sea (1/2/3) + viagem entre seas
--  * Seleção de missões (lista por sea) + Auto Missão selecionada
--  * Bosses separados por sea
--  * ESP completo: frutas (com nome), ilhas, eventos, players, bosses,
--    baús, flores, NPCs, barcos, sea beasts
--  * Avisos: Mirage, Kitsune, Pré-História, Lua Cheia, boss, fruta,
--    resultado do Fruit Sniper + botão de teste do Webhook
--  * Loja (estilos de luta, haki), jogador (speed, pulo infinito...), etc.

local VERSAO = "13.0"

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

-- PlaceIds de cada sea (inclui os IDs novos); se nenhum bater, o script
-- tenta descobrir pelo nome das ilhas.
local SEA_POR_PLACE = {
    [2753915549] = 1, [85211729168715] = 1,
    [4442272183] = 2, [79091703265657] = 2,
    [7449423635] = 3, [100117331123089] = 3,
}
local ILHAS_DO_SEA = {
    [3] = { "Port Town", "Hydra Island", "Great Tree", "Floating Turtle", "Castle on the Sea", "Haunted Castle", "Tiki Outpost" },
    [2] = { "Kingdom of Rose", "Green Zone", "Graveyard", "Cursed Ship", "Forgotten Island", "Dark Arena", "Hot and Cold", "Ice Castle" },
}

-- Bosses separados por sea (nomes com "The " na frente também funcionam)
local BOSSES_POR_SEA = {
    [1] = { "Gorilla King", "Bobby", "The Saw", "Yeti", "Mob Leader", "Vice Admiral", "Saber Expert",
            "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God",
            "Cyborg", "Greybeard" },
    [2] = { "Diamond", "Jeremy", "Fajita", "Don Swan", "Smoke Admiral", "Awakened Ice Admiral",
            "Tide Keeper", "Cursed Captain", "Darkbeard", "Order" },
    [3] = { "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate",
            "Longma", "Cake Queen", "Soul Reaper", "Dough King" },
}
local ELITES_LISTA = { "Diablo", "Deandre", "Urban" }  -- Elite Hunter só existe no Sea 3

local SEA_INIMIGOS = { ["Shark"] = true, ["Terrorshark"] = true, ["PirateBrigade"] = true, ["PirateBasic"] = true }
-- "Posessed Mummy" é escrito assim mesmo no jogo
local BONES_MOBS = { ["Reborn Skeleton"] = true, ["Living Zombie"] = true, ["Demonic Soul"] = true, ["Posessed Mummy"] = true }

local ARMAS = { "Melee", "Sword", "Gun", "Blox Fruit" }      -- ToolTips das ferramentas
local ARMAS_MAESTRIA = { "Sword", "Gun" }
local RAIDS = { "Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Rumble", "Magma", "Buddha", "Sand", "Dough" }
local BARCOS = { "PirateBrigade", "MarineBrigade", "PirateGrandBrigade", "MarineGrandBrigade", "Dinghy" }
local TECLAS_SKILL = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local CODIGOS = {
    "Sub2UncleKizaru", "Sub2Fer999", "Enyu_is_Pro", "JCWK", "StarcodeHeo", "Bluxxy",
    "fudd10_v2", "FUDD10", "BIGNEWS", "THEGREATACE", "Sub2Daigrock", "Axiore",
    "TantaiGaming", "Sub2NoobMaster123", "Sub2OfficialNoobie", "kittgaming", "Magicbus",
} -- podem estar expirados; códigos inválidos são ignorados

-- Ilhas de evento: o script procura estas palavras no nome dos filhos de
-- Workspace.Map e Workspace._WorldOrigin.Locations.
local EVENTOS_ILHA = {
    { chave = "MirageNotifier", titulo = "Mirage Island", palavras = { "mirage", "mystic" } },
    { chave = "KitsuneNotifier", titulo = "Kitsune Island", palavras = { "kitsune" } },
    { chave = "PrehistoricNotifier", titulo = "Prehistoric Island", palavras = { "prehistoric" } },
}
-- Itens de evento que o ESP tenta achar DENTRO das ilhas de evento (melhor esforço)
local ITENS_EVENTO = { { "gear", "Blue Gear" }, { "ember", "Azure Ember" }, { "egg", "Dragon Egg" } }

-- Estilos de luta (remotes da loja)
local ESTILOS = {
    ["Black Leg"] = "BuyBlackLeg", ["Electro"] = "BuyElectro", ["Fishman Karate"] = "BuyFishmanKarate",
    ["Dragon Claw"] = "BuyDragonClaw", ["Superhuman"] = "BuySuperhuman", ["Death Step"] = "BuyDeathStep",
    ["Sharkman Karate"] = "BuySharkmanKarate", ["Electric Claw"] = "BuyElectricClaw",
    ["Dragon Talon"] = "BuyDragonTalon", ["Godhuman"] = "BuyGodhuman", ["Sanguine Art"] = "BuySanguineArt",
}
local TRAVEL_REMOTES = { "TravelMain", "TravelDressrosa", "TravelZou" }   -- Sea 1, 2, 3

-- Raridade aproximada das frutas (só afeta a cor/rótulo do ESP)
local RARIDADES = {
    { nome = "Mítica", cor = Color3.fromRGB(255, 70, 70),
      chaves = { "dragon", "leopard", "kitsune", "venom", "control", "spirit", "dough", "shadow", "gas", "yeti", "mammoth", "t-rex", "trex" } },
    { nome = "Lendária", cor = Color3.fromRGB(190, 90, 255),
      chaves = { "quake", "buddha", "love", "creation", "spider", "sound", "phoenix", "portal", "rumble", "pain", "blizzard", "gravity" } },
    { nome = "Rara", cor = Color3.fromRGB(80, 160, 255),
      chaves = { "light", "rubber", "ghost", "magma" } },
    { nome = "Incomum", cor = Color3.fromRGB(90, 220, 120),
      chaves = { "flame", "ice", "sand", "dark", "eagle", "falcon", "diamond" } },
    { nome = "Comum", cor = Color3.fromRGB(210, 210, 210),
      chaves = { "rocket", "spin", "blade", "spring", "bomb", "smoke", "spike" } },
}

-- =========================================================================
-- HELPERS DE NOME / SEA
-- =========================================================================
local function norm(n)
    n = string.lower(tostring(n or ""))
    n = string.gsub(n, "^the ", "")
    return n
end

local function trim(s)
    s = tostring(s or "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local BOSS_SET, ALL_BOSS_SET, ELITE_SET, LISTA_BOSSES_SEA = {}, {}, {}, {}
for sea, lista in pairs(BOSSES_POR_SEA) do
    BOSS_SET[sea] = {}
    local ordenada = {}
    for _, nome in ipairs(lista) do
        BOSS_SET[sea][norm(nome)] = true
        ALL_BOSS_SET[norm(nome)] = true
        table.insert(ordenada, nome)
    end
    table.sort(ordenada)
    LISTA_BOSSES_SEA[sea] = ordenada
end
for _, nome in ipairs(ELITES_LISTA) do ELITE_SET[norm(nome)] = true end

-- =========================================================================
-- JANITOR (limpeza ao re-executar)
-- =========================================================================
local ID_UNICO_SCRIPT = "Automata_Hub_Janitor_v13"
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
-- versões antigas (v12) também são limpas
if genv["Automata_Hub_Janitor_v12"] then pcall(function() genv["Automata_Hub_Janitor_v12"]:LimparTudo() end) end
genv[ID_UNICO_SCRIPT] = Janitor.new()
local ScriptJanitor = genv[ID_UNICO_SCRIPT]

local Estado = { rodando = true, modo = "ocioso", inicio = os.clock() }

-- =========================================================================
-- CONFIGURAÇÃO
-- =========================================================================
local SEA_AUTO = "Auto (sea atual)"
local OPCOES_SEA = { SEA_AUTO, "Sea 1", "Sea 2", "Sea 3" }

local Cfg = {}
do
    local valores = {
        -- Main
        AutoFarm = false, AutoFarmNearest = false, AutoBones = false, AutoRandomBone = false,
        FastAttack = false, BringMob = false, AttackDistance = 6.5, Weapon = "Melee",
        -- Mastery
        AutoMastery = false, AutoMasteryFruit = false, MasteryWeapon = "Sword", MasteryHealth = 20,
        -- Sea / Missões
        SeaSelecionado = SEA_AUTO, QuestSelecionada = nil, AutoQuestSel = false,
        -- Bosses
        AutoBossesAll = false, AutoBossSel = false, BossSelecionado = nil, AutoElite = false,
        -- Sea events
        AutoSeaEvent = false, Barco = BARCOS[1], SemNevoa = false,
        -- Raids
        RaidSelecionada = RAIDS[1], AutoBuyChip = false, AutoStartRaid = false,
        AutoRaid = false, AutoNextIsland = false, AutoAwake = false,
        -- Frutas
        AutoRandomFruit = false, IntervaloFruta = 7200, AutoStoreFruit = false, AutoTweenFruit = false,
        FruitSniper = false, FrutaAlvo = "", FruitNotifier = true,
        -- Webhook
        WebhookUrl = "", WebhookAtivo = false,
        -- ESP
        FruitESP = false, EspIlha = false, EspEvento = false, EspPlayer = false, EspBoss = false,
        EspBau = false, EspFlor = false, EspNpc = false, EspBarco = false, EspSeaBeast = false,
        EspDistancia = true, EspMaxDist = 15000, EspTamanho = 14,
        -- Stats
        AutoStatMelee = false, AutoStatDefense = false, AutoStatSword = false,
        AutoStatGun = false, AutoStatFruit = false, QuantidadePontos = 1,
        -- Teleport
        IlhaSelecionada = nil, NpcSelecionado = nil,
        -- Loja
        EstiloSelecionado = "Superhuman",
        -- Avisos / Eventos
        FullMoonNotifier = true, BossNotifier = false,
        MirageNotifier = true, KitsuneNotifier = true, PrehistoricNotifier = true,
        ChestHop = false, ChestHopServer = false,
        -- Jogador
        WalkSpeedOn = false, WalkSpeed = 60, InfJump = false, InfEnergy = false,
        FullBright = false, WalkWater = false, FpsBoost = false, NoClipManual = false,
        -- Sistema
        WhiteScreen = false, AutoBuso = false, AntiAFK = true, AutoRejoin = true, Debug = false,
        JobIdAlvo = "",
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
        StarterGui:SetCore("SendNotification", { Title = tostring(titulo), Text = tostring(texto), Duration = 6 })
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

-- Posição de qualquer instância (Model, Part ou Folder com partes dentro)
local function pivotDe(inst)
    if not inst then return nil end
    if inst:IsA("PVInstance") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok then return cf end
    end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then return d.CFrame end
    end
    return nil
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

-- ---- Sea ----------------------------------------------------------------
local seaCache = nil
local function seaAtual()
    if seaCache then return seaCache end
    local porPlace = SEA_POR_PLACE[game.PlaceId]
    if porPlace then seaCache = porPlace return porPlace end
    local locs = locations()
    if not locs then return 1 end -- ainda não carregou: tenta de novo depois
    for _, sea in ipairs({ 3, 2 }) do
        for _, nome in ipairs(ILHAS_DO_SEA[sea]) do
            if locs:FindFirstChild(nome) then seaCache = sea return sea end
        end
    end
    seaCache = 1
    return 1
end

local function seaEfetivo()
    local sel = Cfg:Get("SeaSelecionado")
    local n = type(sel) == "string" and tonumber(string.match(sel, "^Sea (%d)$"))
    return n or seaAtual()
end

local function listaBossesDoSea(sea)
    return LISTA_BOSSES_SEA[sea] or LISTA_BOSSES_SEA[1]
end

-- ---- Banco de missões (ReplicatedStorage.Quests) ------------------------
local QuestDB = { itens = nil }

function QuestDB:Carregar()
    if self.itens then return self.itens end
    local mod = ReplicatedStorage:FindFirstChild("Quests")
    if not mod then return nil end
    local ok, tabela = pcall(require, mod)
    if not ok or type(tabela) ~= "table" then return nil end
    local itens = {}
    for nome, lista in pairs(tabela) do
        if type(lista) == "table" then
            for idx, q in pairs(lista) do
                if type(q) == "table" and type(q.Task) == "table" and type(q.LevelReq) == "number" then
                    local mob, qtd = next(q.Task)
                    if mob then
                        local sea = (q.LevelReq >= 1500 and 3) or (q.LevelReq >= 700 and 2) or 1
                        local rotulo = string.format("Lv %d - %s (%s/%s)", q.LevelReq, tostring(mob), tostring(nome), tostring(idx))
                        itens[rotulo] = { nome = nome, idx = idx, mob = mob, nivel = q.LevelReq, sea = sea, qtd = qtd }
                    end
                end
            end
        end
    end
    self.itens = itens
    return itens
end

function QuestDB:Lista(sea)
    local itens = self:Carregar()
    local l = {}
    if itens then
        for rotulo, d in pairs(itens) do
            if d.sea == sea then table.insert(l, rotulo) end
        end
        table.sort(l, function(a, b)
            local da, db = itens[a], itens[b]
            if da.nivel ~= db.nivel then return da.nivel < db.nivel end
            return a < b
        end)
    end
    if #l == 0 then return { "(nenhuma missão encontrada)" } end
    return l
end

function QuestDB:Dados(rotulo)
    local itens = self:Carregar()
    return itens and rotulo and itens[rotulo] or nil
end

-- Tabela para agrupar funções de recurso (evita estourar o limite de 200 locals)
local F = {}

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

-- Remotes de ataque do jogo (Modules.Net). Blox Fruits NÃO registra dano por
-- clique virtual: o servidor só aceita RegisterAttack + RegisterHit.
local AtaqueNet = { atk = nil, hit = nil, ultimo = 0 }

local function obterNetAtaque()
    if AtaqueNet.atk and AtaqueNet.atk.Parent and AtaqueNet.hit and AtaqueNet.hit.Parent then
        return AtaqueNet.atk, AtaqueNet.hit
    end
    local mods = ReplicatedStorage:FindFirstChild("Modules")
    local net = mods and mods:FindFirstChild("Net")
    if not net then return nil end
    AtaqueNet.atk = net:FindFirstChild("RE/RegisterAttack")
    AtaqueNet.hit = net:FindFirstChild("RE/RegisterHit")
    return AtaqueNet.atk, AtaqueNet.hit
end

function CombatManager:Golpear(alvo)
    local atk, hit = obterNetAtaque()
    if not atk or not hit then return false end
    local root = meuRoot()
    local pasta = pastaEnemies()
    if not root or not pasta or not alvo then return false end

    local lista = {}
    local function adicionar(m)
        local r = m:FindFirstChild("HumanoidRootPart")
        local h = m:FindFirstChildOfClass("Humanoid")
        if r and h and h.Health > 0 then table.insert(lista, { m, r }) end
    end
    adicionar(alvo)
    for _, m in ipairs(pasta:GetChildren()) do
        if m ~= alvo then
            local r = m:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - root.Position).Magnitude <= 60 then adicionar(m) end
        end
    end
    if #lista == 0 then return false end

    local parte = alvo:FindFirstChild("Head") or alvo:FindFirstChild("HumanoidRootPart")
    pcall(function() atk:FireServer(0) end)
    pcall(function() hit:FireServer(parte, lista) end)
    return true
end

function CombatManager:Atacar(char, hum, backpack, tooltip, alvo)
    local ferramenta = escolherFerramenta(char, backpack, tooltip)
    if ferramenta and ferramenta.Parent ~= char then
        hum:EquipTool(ferramenta)
        task.wait(0.05)
    end
    if not (ferramenta and ferramenta.Parent == char) then return end

    -- limita a frequência (Fast Attack = quase todo frame)
    local intervalo = Cfg:Get("FastAttack") and 0.03 or 0.12
    if os.clock() - AtaqueNet.ultimo < intervalo then return end
    AtaqueNet.ultimo = os.clock()

    CombatManager:Golpear(alvo)
    -- animação / fallback. NÃO usamos mais VirtualUser:Button1Down(0,0):
    -- isso clicava no canto superior esquerdo da tela e apertava os botões da UI.
    pcall(function() ferramenta:Activate() end)
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
-- MISSÕES
-- =========================================================================
local function questAtiva()
    local ok, v = pcall(function() return LocalPlayer.PlayerGui.Main.Quest.Visible end)
    return ok and v == true
end

local function iniciarQuest(nome, idx, abandonarAntes)
    if abandonarAntes and questAtiva() then
        pcall(function() obterCommF():InvokeServer("AbandonQuest") end)
    end
    local ok, err = pcall(function() obterCommF():InvokeServer("StartQuest", nome, idx) end)
    if not ok then registrarErro("Quest", err) end
end

-- Quest automática do Auto Farm Level (escolhe pela quantidade de level)
local Quest = { nome = nil, indice = nil, mob = nil, ultimo = 0 }

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
                        if mob and type(qtd) == "number" and qtd > 1 and not ALL_BOSS_SET[norm(mob)]
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
        iniciarQuest(self.nome, self.indice, antes ~= nil and self.nome ~= antes)
    end
end

-- Quest escolhida pelo usuário na aba "Missões"
local QuestSel = { chave = nil, ultimo = 0 }

local function dadosQuestSel()
    return QuestDB:Dados(Cfg:Get("QuestSelecionada"))
end

function QuestSel:Garantir()
    if os.clock() - self.ultimo < 5 then return end
    self.ultimo = os.clock()
    local d = dadosQuestSel()
    if not d then return end
    local chave = tostring(d.nome) .. "/" .. tostring(d.idx)
    if chave ~= self.chave then
        iniciarQuest(d.nome, d.idx, true)
        self.chave = chave
    elseif not questAtiva() then
        iniciarQuest(d.nome, d.idx, false)
    end
end

function F.iniciarQuestSelecionadaAgora()
    task.spawn(function()
        local d = dadosQuestSel()
        if not d then notificar("Missões", "Escolha uma missão primeiro.") return end
        iniciarQuest(d.nome, d.idx, true)
        notificar("Missões", "Missão iniciada: " .. tostring(d.mob) .. " (Lv " .. tostring(d.nivel) .. ")")
    end)
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
    { nome = "Boss (todos do sea)", chaves = { "AutoBossesAll" }, raio = 5000, pastas = soEnemies,
      filtro = function(e) return (BOSS_SET[seaEfetivo()] or {})[norm(e.Name)] == true end },
    { nome = "Boss (selecionado)", chaves = { "AutoBossSel" }, raio = 5000, pastas = soEnemies,
      filtro = function(e) return norm(e.Name) == norm(Cfg:Get("BossSelecionado")) end },
    { nome = "Elite", chaves = { "AutoElite" }, raio = 5000, pastas = soEnemies,
      filtro = function(e) return ELITE_SET[norm(e.Name)] == true end },
    { nome = "Sea Event", chaves = { "AutoSeaEvent" }, raio = 5000,
      pastas = function() return listaPastas(Workspace:FindFirstChild("SeaBeasts"), pastaEnemies()) end,
      filtro = function(e) return (e.Parent and e.Parent.Name == "SeaBeasts") or SEA_INIMIGOS[e.Name] == true end },
    { nome = "Raid", chaves = { "AutoRaid" }, filtro = qualquer, raio = 1500, pastas = soEnemies,
      fallback = proximaIlhaRaid },
    { nome = "Mastery", chaves = { "AutoMastery", "AutoMasteryFruit" }, filtro = qualquer, raio = 2000,
      pastas = soEnemies, mastery = true },
    { nome = "Bones", chaves = { "AutoBones" }, filtro = nomeEm(BONES_MOBS), raio = 3000, pastas = soEnemies,
      fallback = function() return spawnMaisProximo(BONES_MOBS) end },
    { nome = "Missão selecionada", chaves = { "AutoQuestSel" }, raio = 3000, pastas = soEnemies,
      preparar = function() QuestSel:Garantir() end,
      filtro = function(e) local d = dadosQuestSel() return d ~= nil and e.Name == d.mob end,
      fallback = function()
          local d = dadosQuestSel()
          return d and spawnMaisProximo({ [d.mob] = true }) or nil
      end },
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
        CombatManager:Atacar(char, myHum, backpack, tooltip, alvo)
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

-- Chama um remote do CommF_ em segundo plano e avisa a resposta
function F.invocar(modulo, ...)
    local args = table.pack(...)
    task.spawn(function()
        local ok, r = pcall(function() return obterCommF():InvokeServer(table.unpack(args, 1, args.n)) end)
        if not ok then
            registrarErro(modulo, r)
            notificar(modulo, "Erro: " .. tostring(r))
        else
            registrarLog(modulo, "Resposta do jogo: " .. tostring(r))
            notificar(modulo, "Resposta do jogo: " .. tostring(r))
        end
    end)
end

-- =========================================================================
-- WEBHOOK DO DISCORD + SISTEMA DE AVISOS
-- =========================================================================
local function obterRequisicao()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end

local function urlWebhookValida(url)
    return type(url) == "string"
        and string.find(url, "^https://") ~= nil
        and string.find(url, "discord", 1, true) ~= nil
        and string.find(url, "/api/webhooks/", 1, true) ~= nil
end

-- Devolve true/false + (status ou motivo do erro)
function F.postarWebhook(titulo, texto, cor)
    local url = trim(Cfg:Get("WebhookUrl"))
    if url == "" then return false, "nenhuma URL de webhook foi informada" end
    if not urlWebhookValida(url) then
        return false, "URL inválida (use a URL completa: https://discord.com/api/webhooks/...)"
    end
    local req = obterRequisicao()
    if not req then return false, "o executor não tem função de requisição HTTP (request / http_request)" end

    local payload = {
        username = "Automata Hub",
        embeds = { {
            title = tostring(titulo),
            description = tostring(texto),
            color = cor or 7226332,
            fields = {
                { name = "Jogador", value = LocalPlayer.Name, inline = true },
                { name = "Jogadores no servidor", value = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers), inline = true },
                { name = "JobId do servidor", value = "`" .. tostring(game.JobId) .. "`", inline = false },
            },
            footer = { text = "Automata Hub v" .. VERSAO },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }
    local ok, res = pcall(req, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload),
    })
    if not ok then return false, tostring(res) end
    if type(res) ~= "table" then return false, "resposta inesperada do executor" end
    local status = tonumber(res.StatusCode or res.Status)
    if status and status >= 200 and status < 300 then return true, status end
    return false, string.format("status %s %s", tostring(status), tostring(res.StatusMessage or res.Body or ""))
end

-- Notificação na tela + (se ativado) mensagem no Discord
function F.avisar(titulo, texto, cor)
    notificar(titulo, texto)
    registrarLog("Aviso", tostring(titulo) .. " - " .. tostring(texto))
    if Cfg:Get("WebhookAtivo") then
        task.spawn(function()
            local ok, info = F.postarWebhook(titulo, texto, cor)
            if not ok then registrarErro("Webhook", info) end
        end)
    end
end

function F.testarWebhook()
    task.spawn(function()
        local ok, info = F.postarWebhook("Teste do Webhook", "Se você está vendo esta mensagem, o webhook está funcionando!", 5763719)
        if ok then
            notificar("Webhook OK", "Mensagem de teste enviada (status " .. tostring(info) .. ").")
        else
            notificar("Webhook - FALHOU", tostring(info))
        end
    end)
end

-- =========================================================================
-- FRUTAS
-- =========================================================================
function F.parteDe(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    local h = obj:FindFirstChild("Handle")
    if h and h:IsA("BasePart") then return h end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    return obj:FindFirstChildWhichIsA("BasePart", true)
end

function F.frutasNoMapa()
    local l = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if (obj:IsA("Tool") or obj:IsA("Model")) and string.find(string.lower(obj.Name), "fruit", 1, true)
            and obj:FindFirstChild("Handle") then
            table.insert(l, obj)
        end
    end
    return l
end

-- Nome "limpo" da fruta para mostrar no ESP / avisos
function F.nomeFruta(obj)
    local n = tostring(obj:GetAttribute("OriginalName") or obj.Name)
    n = string.gsub(n, "%s*[Ff][Rr][Uu][Ii][Tt]%s*", " ")
    n = trim(n)
    if n == "" then n = tostring(obj.Name) end
    return n
end

function F.raridade(nome)
    local l = string.lower(tostring(nome))
    for _, r in ipairs(RARIDADES) do
        for _, k in ipairs(r.chaves) do
            if string.find(l, k, 1, true) then return r end
        end
    end
    return nil
end

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

loopToggle("AutoTweenFruit", "TweenFruta", function()
    local root = meuRoot()
    if not root then return 1 end
    local melhor, menor, melhorParte = nil, math.huge, nil
    for _, f in ipairs(F.frutasNoMapa()) do
        local p = F.parteDe(f)
        if p then
            local d = (p.Position - root.Position).Magnitude
            if d < menor then menor, melhor, melhorParte = d, f, p end
        end
    end
    if melhor then
        MovementService:Interpola(melhorParte.CFrame, 150, function() return Cfg:Get("AutoTweenFruit") and melhor.Parent ~= nil end)
    end
    return 1
end)

function F.trazerTodasFrutas()
    local root = meuRoot()
    if not root then return end
    for _, f in ipairs(F.frutasNoMapa()) do
        pcall(function()
            local p = F.parteDe(f)
            if not p then return end
            if firetouchinterest then
                firetouchinterest(root, p, 0)
                firetouchinterest(root, p, 1)
            else
                p.CFrame = root.CFrame
            end
        end)
    end
end

-- Fruit Sniper ---------------------------------------------------------------
function F.temFrutaNoInventario(nome)
    local ok, inv = pcall(function() return obterCommF():InvokeServer("getInventoryFruits") end)
    if not ok or type(inv) ~= "table" then return nil end
    local alvo = string.lower(tostring(nome))
    for _, item in pairs(inv) do
        local n = item
        if type(item) == "table" then n = item.Name or item.name end
        if type(n) == "string" and string.lower(n) == alvo then return true end
    end
    return false
end

function F.comprarSniper(nome, preco)
    local ok, r = pcall(function() return obterCommF():InvokeServer("PurchaseRawFruit", nome) end)
    if not ok then
        F.avisar("Fruit Sniper - ERRO", "Falha ao tentar comprar " .. nome .. ": " .. tostring(r), 15158332)
        return
    end
    task.wait(1.5)
    local conf = F.temFrutaNoInventario(nome)
    local extra = preco and (" (preço: " .. tostring(preco) .. ")") or ""
    if conf == true then
        F.avisar("Fruit Sniper - COMPRADA!", nome .. " foi comprada e está no seu inventário." .. extra, 5763719)
    elseif conf == false then
        F.avisar("Fruit Sniper - não confirmada",
            "Tentei comprar " .. nome .. ", mas ela não apareceu no inventário. Resposta do jogo: " .. tostring(r) .. extra, 15105570)
    else
        F.avisar("Fruit Sniper - compra enviada",
            "Pedido de compra de " .. nome .. " enviado (sem confirmação). Resposta do jogo: " .. tostring(r) .. extra, 16776960)
    end
end

do
    local ultimaCompra = {}
    loopToggle("FruitSniper", "Sniper", function()
        local alvos = {}
        for pedaco in string.gmatch(string.lower(tostring(Cfg:Get("FrutaAlvo") or "")), "[^,]+") do
            local t = trim(pedaco)
            if t ~= "" then table.insert(alvos, t) end
        end
        if #alvos == 0 then return 5 end

        local lista = obterCommF():InvokeServer("GetFruits")
        if type(lista) ~= "table" then return 5 end
        for _, f in pairs(lista) do
            if type(f) == "table" and f.OnSale then
                local nome = tostring(f.Name)
                local minusculo = string.lower(nome)
                for _, alvo in ipairs(alvos) do
                    if string.find(minusculo, alvo, 1, true) and os.clock() - (ultimaCompra[nome] or -999) > 60 then
                        ultimaCompra[nome] = os.clock()
                        F.avisar("Fruit Sniper", nome .. " está no estoque! Tentando comprar...", 3447003)
                        task.spawn(F.comprarSniper, nome, f.Price)
                        break
                    end
                end
            end
        end
        return 5
    end)
end

-- Aviso de fruta que spawnou no mapa
do
    local vistos = setmetatable({}, { __mode = "k" })
    loopToggle("FruitNotifier", "Notifier", function()
        for _, f in ipairs(F.frutasNoMapa()) do
            if not vistos[f] then
                vistos[f] = true
                local nome = F.nomeFruta(f)
                local r = F.raridade(nome)
                F.avisar("Fruta spawnou no mapa!", nome .. (r and (" [" .. r.nome .. "]") or ""), 15844367)
            end
        end
        return 3
    end)
end

-- Aviso de boss que spawnou (só do sea escolhido)
do
    local vistos = setmetatable({}, { __mode = "k" })
    loopToggle("BossNotifier", "BossNotifier", function()
        local pasta = pastaEnemies()
        if not pasta then return 5 end
        local conjunto = BOSS_SET[seaEfetivo()] or {}
        for _, e in ipairs(pasta:GetChildren()) do
            local k = norm(e.Name)
            if (conjunto[k] or ELITE_SET[k]) and not vistos[e] then
                local h = e:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    vistos[e] = true
                    F.avisar("Boss spawnou!", e.Name .. " apareceu neste servidor.", 15158332)
                end
            end
        end
        return 5
    end)
end

-- =========================================================================
-- STATS / RAIDS / HAKI
-- =========================================================================
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

loopToggle("AutoBuso", "Buso", function()
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("HasBuso") then obterCommF():InvokeServer("Buso") end
    return 2
end)

-- =========================================================================
-- BARCO / CÓDIGOS / SERVIDOR / SEA / LOJA
-- =========================================================================
function F.comprarBarco()
    task.spawn(function()
        local ok, r = pcall(function() return obterCommF():InvokeServer("BuyBoat", Cfg:Get("Barco")) end)
        if not ok then registrarErro("Barco", r) else registrarLog("Barco", "Resposta do jogo: " .. tostring(r)) end
    end)
end

function F.resgatarCodigos()
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

function F.serverHop()
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

function F.reentrar()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

function F.copiarJobId()
    local id = tostring(game.JobId)
    if setclipboard then
        pcall(setclipboard, id)
        notificar("JobId", "Copiado para a área de transferência.")
    else
        notificar("JobId", id)
    end
end

function F.entrarNoServidor()
    local id = trim(Cfg:Get("JobIdAlvo"))
    if id == "" then notificar("Servidor", "Cole um JobId primeiro.") return end
    local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer) end)
    if not ok then notificar("Servidor", "Falhou: " .. tostring(err)) end
end

function F.irParaSea()
    local alvo = seaEfetivo()
    if alvo == seaAtual() then notificar("Sea", "Você já está no Sea " .. tostring(alvo) .. ".") return end
    notificar("Sea", "Tentando viajar para o Sea " .. tostring(alvo) .. "...")
    F.invocar("Sea", TRAVEL_REMOTES[alvo])
end

function F.comprarEstilo()
    local remote = ESTILOS[Cfg:Get("EstiloSelecionado")]
    if not remote then notificar("Loja", "Escolha um estilo primeiro.") return end
    F.invocar("Loja", remote)
end

function F.listaEstilos()
    local l = {}
    for nome in pairs(ESTILOS) do table.insert(l, nome) end
    table.sort(l)
    return l
end

-- =========================================================================
-- TELEPORTES
-- =========================================================================
function F.acharIlhaEvento(ev)
    local mapa = Workspace:FindFirstChild("Map")
    local locs = locations()
    for _, pasta in ipairs(listaPastas(mapa, locs)) do
        for _, c in ipairs(pasta:GetChildren()) do
            if not c:IsA("Tool") then
                local n = string.lower(c.Name)
                for _, palavra in ipairs(ev.palavras) do
                    if string.find(n, palavra, 1, true) then return c end
                end
            end
        end
    end
    return nil
end

function F.irParaIlhaEvento(ev)
    local ilha = F.acharIlhaEvento(ev)
    local cf = pivotDe(ilha)
    if not cf then notificar("Evento", ev.titulo .. " não está no servidor agora.") return end
    teleportar(cf + Vector3.new(0, 120, 0))
end

function F.listarIlhas()
    local l, locs = {}, locations()
    if locs then for _, c in ipairs(locs:GetChildren()) do table.insert(l, c.Name) end end
    table.sort(l)
    return #l > 0 and l or { "(nenhuma)" }
end

function F.listarNPCs()
    local l, pasta = {}, Workspace:FindFirstChild("NPCs")
    if pasta then for _, c in ipairs(pasta:GetChildren()) do table.insert(l, c.Name) end end
    table.sort(l)
    return #l > 0 and l or { "(nenhum)" }
end

function F.irParaIlhaSelecionada()
    local locs, nome = locations(), Cfg:Get("IlhaSelecionada")
    local ilha = locs and nome and locs:FindFirstChild(nome)
    if ilha then teleportar(ilha:GetPivot() + Vector3.new(0, 50, 0)) else notificar("Teleport", "Escolha uma ilha primeiro.") end
end

function F.irParaNpcSelecionado()
    local pasta, nome = Workspace:FindFirstChild("NPCs"), Cfg:Get("NpcSelecionado")
    local npc = pasta and nome and pasta:FindFirstChild(nome)
    if npc then teleportar(npc:GetPivot() + Vector3.new(0, 4, 0)) else notificar("Teleport", "Escolha um NPC primeiro.") end
end

function F.irParaFrutaMaisProxima()
    local root = meuRoot()
    if not root then return end
    local melhor, menor = nil, math.huge
    for _, f in ipairs(F.frutasNoMapa()) do
        local p = F.parteDe(f)
        if p then
            local d = (p.Position - root.Position).Magnitude
            if d < menor then menor, melhor = d, p end
        end
    end
    if melhor then teleportar(melhor.CFrame + Vector3.new(0, 4, 0)) else notificar("Frutas", "Nenhuma fruta no mapa agora.") end
end

-- =========================================================================
-- HELPERS DE GUI
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

-- =========================================================================
-- VISUAIS
-- =========================================================================
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

-- FPS Boost (sombras, efeitos pós-processamento e qualidade gráfica)
do
    local guardado = nil
    function F.aplicarFpsBoost(ligado)
        pcall(function()
            if ligado then
                if guardado then return end
                guardado = { sombra = Lighting.GlobalShadows, efeitos = {} }
                Lighting.GlobalShadows = false
                for _, e in ipairs(Lighting:GetChildren()) do
                    if e:IsA("PostEffect") then
                        guardado.efeitos[e] = e.Enabled
                        e.Enabled = false
                    end
                end
                pcall(function()
                    guardado.qualidade = settings().Rendering.QualityLevel
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                end)
            elseif guardado then
                Lighting.GlobalShadows = guardado.sombra
                for e, v in pairs(guardado.efeitos) do
                    if e.Parent then e.Enabled = v end
                end
                if guardado.qualidade then
                    pcall(function() settings().Rendering.QualityLevel = guardado.qualidade end)
                end
                guardado = nil
            end
        end)
    end
    ScriptJanitor:Adicionar({ Destroy = function() F.aplicarFpsBoost(false) end }, "Destroy")
end

-- =========================================================================
-- RECURSOS DO JOGADOR (speed, pulo infinito, energia, full bright, água)
-- =========================================================================
do
    local original = nil
    task.spawn(function()
        while Estado.rodando do
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                if Cfg:Get("WalkSpeedOn") then
                    if not original then original = hum.WalkSpeed end
                    hum.WalkSpeed = tonumber(Cfg:Get("WalkSpeed")) or 60
                elseif original then
                    hum.WalkSpeed = original
                    original = nil
                end
            end)
            task.wait(0.3)
        end
    end)
    ScriptJanitor:Adicionar({ Destroy = function()
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and original then hum.WalkSpeed = original end
        end)
    end }, "Destroy")
end

ScriptJanitor:Adicionar(UserInputService.JumpRequest:Connect(function()
    if Cfg:Get("InfJump") then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end
end))

do
    local avisouSemMax = false
    loopToggle("InfEnergy", "Energia", function()
        local char = LocalPlayer.Character
        local e = char and char:FindFirstChild("Energy")
        if not e then return 1 end
        local mx = e:FindFirstChild("MaxValue")
        mx = (mx and mx.Value) or e:GetAttribute("MaxValue") or e:GetAttribute("Max")
        if type(mx) == "number" then
            e.Value = mx
        elseif not avisouSemMax then
            avisouSemMax = true
            registrarLog("Energia", "Não achei o valor máximo da energia; Infinite Energy pode não funcionar nesta versão.")
        end
        return 0.2
    end)
end

do
    local orig = nil
    task.spawn(function()
        while Estado.rodando do
            pcall(function()
                if Cfg:Get("FullBright") then
                    if not orig then orig = { Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient } end
                    Lighting.Brightness = 2
                    Lighting.Ambient = Color3.fromRGB(190, 190, 190)
                    Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
                elseif orig then
                    Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient = orig[1], orig[2], orig[3]
                    orig = nil
                end
            end)
            task.wait(1)
        end
    end)
    ScriptJanitor:Adicionar({ Destroy = function()
        if orig then
            pcall(function() Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient = orig[1], orig[2], orig[3] end)
        end
    end }, "Destroy")
end

do
    local orig = nil
    local function restaurar()
        if orig then
            pcall(function()
                if orig[1].Parent then orig[1].Size, orig[1].CanCollide = orig[2], orig[3] end
            end)
            orig = nil
        end
    end
    task.spawn(function()
        while Estado.rodando do
            pcall(function()
                local mapa = Workspace:FindFirstChild("Map")
                local plano = mapa and mapa:FindFirstChild("WaterBase-Plane")
                if Cfg:Get("WalkWater") then
                    if not plano then return end
                    if not orig then orig = { plano, plano.Size, plano.CanCollide } end
                    plano.Size = Vector3.new(1000, 113, 1000)
                    plano.CanCollide = true
                else
                    restaurar()
                end
            end)
            task.wait(1)
        end
    end)
    ScriptJanitor:Adicionar({ Destroy = restaurar }, "Destroy")
end

-- =========================================================================
-- ESP (BillboardGui com texto por cima de cada alvo)
-- =========================================================================
do
    local pasta = Instance.new("Folder")
    pasta.Name = "AutomataEsp"
    montarGui(pasta)
    ScriptJanitor:Adicionar(pasta, "Destroy")

    local itens = {}   -- itens[obj] = { gui, label, parte }

    local function criarEtiqueta(parte)
        local gui = Instance.new("BillboardGui")
        gui.Name = "AutomataEspItem"
        gui.Adornee = parte
        gui.AlwaysOnTop = true
        gui.Size = UDim2.new(0, 200, 0, 44)
        gui.ResetOnSpawn = false
        pcall(function() gui.MaxDistance = math.huge end)

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextWrapped = true
        label.TextStrokeTransparency = 0.35
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = ""
        label.Parent = gui

        gui.Parent = pasta
        return { gui = gui, label = label, parte = parte }
    end

    local function nomeBau(nome)
        if string.find(nome, "3", 1, true) then return "Baú (Ouro)", Color3.fromRGB(255, 215, 0) end
        if string.find(nome, "2", 1, true) then return "Baú (Prata)", Color3.fromRGB(200, 200, 215) end
        return "Baú (Bronze)", Color3.fromRGB(205, 127, 50)
    end

    local cacheBaus, tBaus = {}, -999
    local cacheItensEvento, tItens = {}, -999

    local CATEGORIAS = {
        { chave = "FruitESP", coletar = function(emitir)
            for _, f in ipairs(F.frutasNoMapa()) do
                local nome = F.nomeFruta(f)
                local r = F.raridade(nome)
                emitir(f, F.parteDe(f), nome .. (r and (" [" .. r.nome .. "]") or ""),
                    r and r.cor or Color3.fromRGB(0, 255, 128))
            end
        end },

        { chave = "EspIlha", coletar = function(emitir)
            local locs = locations()
            if not locs then return end
            for _, c in ipairs(locs:GetChildren()) do
                local cf = pivotDe(c)
                local p = F.parteDe(c)
                if cf and p then emitir(c, p, c.Name, Color3.fromRGB(255, 215, 90), cf.Position, 40) end
            end
        end },

        { chave = "EspEvento", coletar = function(emitir)
            local ilhas = {}
            for _, ev in ipairs(EVENTOS_ILHA) do
                local ilha = F.acharIlhaEvento(ev)
                if ilha then
                    table.insert(ilhas, ilha)
                    local cf = pivotDe(ilha)
                    local p = F.parteDe(ilha)
                    if cf and p then
                        emitir(ilha, p, "[EVENTO] " .. ev.titulo, Color3.fromRGB(255, 110, 255), cf.Position, 80)
                    end
                end
            end
            -- itens dentro das ilhas de evento (melhor esforço, atualiza a cada 3s)
            if os.clock() - tItens > 3 then
                tItens = os.clock()
                cacheItensEvento = {}
                for _, ilha in ipairs(ilhas) do
                    for _, d in ipairs(ilha:GetDescendants()) do
                        if #cacheItensEvento >= 30 then break end
                        if d:IsA("BasePart") or d:IsA("Model") then
                            local l = string.lower(d.Name)
                            for _, it in ipairs(ITENS_EVENTO) do
                                if string.find(l, it[1], 1, true) then
                                    table.insert(cacheItensEvento, { d, it[2] })
                                    break
                                end
                            end
                        end
                    end
                end
            end
            for _, par in ipairs(cacheItensEvento) do
                if par[1].Parent then
                    local p = F.parteDe(par[1])
                    if p then emitir(par[1], p, par[2], Color3.fromRGB(120, 255, 255)) end
                end
            end
        end },

        { chave = "EspPlayer", coletar = function(emitir)
            for _, pl in ipairs(Players:GetPlayers()) do
                local char = pl ~= LocalPlayer and pl.Character
                local r = char and char:FindFirstChild("HumanoidRootPart")
                if r then
                    local h = char:FindFirstChildOfClass("Humanoid")
                    local vida = h and (" | " .. math.floor(h.Health / math.max(h.MaxHealth, 1) * 100) .. "%") or ""
                    emitir(char, r, pl.DisplayName .. vida, Color3.fromRGB(255, 90, 90))
                end
            end
        end },

        { chave = "EspBoss", coletar = function(emitir)
            local pasta2 = pastaEnemies()
            if not pasta2 then return end
            local conjunto = BOSS_SET[seaEfetivo()] or {}
            for _, e in ipairs(pasta2:GetChildren()) do
                local k = norm(e.Name)
                if conjunto[k] or ELITE_SET[k] then
                    local r = e:FindFirstChild("HumanoidRootPart")
                    local h = e:FindFirstChildOfClass("Humanoid")
                    if r and h and h.Health > 0 then
                        emitir(e, r, "[BOSS] " .. e.Name .. " | " .. math.floor(h.Health / math.max(h.MaxHealth, 1) * 100) .. "%",
                            Color3.fromRGB(255, 140, 40))
                    end
                end
            end
        end },

        { chave = "EspBau", coletar = function(emitir)
            if os.clock() - tBaus > 5 then
                tBaus = os.clock()
                cacheBaus = {}
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and string.find(obj.Name, "Chest", 1, true)
                        and not (obj.Parent and obj.Parent:FindFirstChildOfClass("Humanoid")) then
                        table.insert(cacheBaus, obj)
                    end
                end
            end
            local root = meuRoot()
            local lista = {}
            for _, b in ipairs(cacheBaus) do
                if b.Parent then table.insert(lista, b) end
            end
            if root then
                table.sort(lista, function(a, b)
                    return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
                end)
            end
            for i = 1, math.min(#lista, 60) do
                local texto, cor = nomeBau(lista[i].Name)
                emitir(lista[i], lista[i], texto, cor)
            end
        end },

        { chave = "EspFlor", coletar = function(emitir)
            local def = {
                { "Flower1", "Flor Azul (Flower1)", Color3.fromRGB(90, 150, 255) },
                { "Flower2", "Flor Vermelha (Flower2)", Color3.fromRGB(255, 80, 80) },
                { "Flower3", "Flor Amarela (Flower3)", Color3.fromRGB(255, 230, 80) },
            }
            for _, d in ipairs(def) do
                local f = Workspace:FindFirstChild(d[1])
                local p = f and F.parteDe(f)
                if p then emitir(f, p, d[2], d[3]) end
            end
        end },

        { chave = "EspNpc", coletar = function(emitir)
            local pasta2 = Workspace:FindFirstChild("NPCs")
            if not pasta2 then return end
            for _, n in ipairs(pasta2:GetChildren()) do
                local p = F.parteDe(n)
                if p then emitir(n, p, n.Name, Color3.fromRGB(150, 230, 255)) end
            end
        end },

        { chave = "EspBarco", coletar = function(emitir)
            local pasta2 = Workspace:FindFirstChild("Boats")
            if not pasta2 then return end
            for _, b in ipairs(pasta2:GetChildren()) do
                local p = F.parteDe(b)
                if p then emitir(b, p, "Barco: " .. b.Name, Color3.fromRGB(110, 190, 255)) end
            end
        end },

        { chave = "EspSeaBeast", coletar = function(emitir)
            local pasta2 = Workspace:FindFirstChild("SeaBeasts")
            if not pasta2 then return end
            for _, b in ipairs(pasta2:GetChildren()) do
                local p = F.parteDe(b)
                if p then emitir(b, p, "[SEA] " .. b.Name, Color3.fromRGB(255, 70, 170)) end
            end
        end },
    }

    local function limparTudo()
        for obj, item in pairs(itens) do
            pcall(function() item.gui:Destroy() end)
            itens[obj] = nil
        end
    end
    ScriptJanitor:Adicionar({ Destroy = limparTudo }, "Destroy")

    local function ciclo()
        local vivos = {}
        local function emitir(obj, parte, texto, cor, posicao, altura)
            if not obj or not parte or not parte.Parent then return end
            vivos[obj] = { parte = parte, texto = texto, cor = cor, posicao = posicao, altura = altura or 3 }
        end

        for _, cat in ipairs(CATEGORIAS) do
            if Cfg:Get(cat.chave) then
                local ok, err = pcall(cat.coletar, emitir)
                if not ok then registrarErro("ESP", err) end
            end
        end

        for obj, item in pairs(itens) do
            if not vivos[obj] or not obj.Parent then
                pcall(function() item.gui:Destroy() end)
                itens[obj] = nil
            end
        end

        local root = meuRoot()
        local maxd = tonumber(Cfg:Get("EspMaxDist")) or 15000
        local tam = tonumber(Cfg:Get("EspTamanho")) or 14
        local mostrarDist = Cfg:Get("EspDistancia") == true

        for obj, d in pairs(vivos) do
            local item = itens[obj]
            if item and item.parte ~= d.parte then
                pcall(function() item.gui:Destroy() end)
                itens[obj] = nil
                item = nil
            end
            if not item then
                item = criarEtiqueta(d.parte)
                itens[obj] = item
            end

            local alvoPos = d.posicao or d.parte.Position
            item.gui.StudsOffsetWorldSpace = (alvoPos - d.parte.Position) + Vector3.new(0, d.altura, 0)

            local dist = root and (alvoPos - root.Position).Magnitude or 0
            item.gui.Enabled = dist <= maxd
            item.label.TextColor3 = d.cor
            item.label.TextSize = tam
            item.label.Text = d.texto .. (mostrarDist and ("\n[" .. math.floor(dist) .. "m]") or "")
        end
    end

    task.spawn(function()
        while Estado.rodando do
            local algum = false
            for _, cat in ipairs(CATEGORIAS) do
                if Cfg:Get(cat.chave) then algum = true break end
            end
            if algum then
                local ok, err = pcall(ciclo)
                if not ok then registrarErro("ESP", err) end
            elseif next(itens) then
                limparTudo()
            end
            task.wait(0.4)
        end
    end)
end

-- =========================================================================
-- AVISOS: LUA CHEIA E ILHAS DE EVENTO (Mirage / Kitsune / Pré-Histórica)
-- =========================================================================
function F.mostrarIdLua()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    local id = sky and string.match(tostring(sky.MoonTextureId), "%d+")
    notificar("ID da Lua", "MoonTextureId atual: " .. tostring(id) .. (id and LUA_CHEIA_IDS[id] and " (LUA CHEIA)" or ""))
    registrarLog("Lua", "MoonTextureId atual: " .. tostring(id))
end

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
                if cheia and not estavaCheia then F.avisar("LUA CHEIA ATIVA!", "A Lua Cheia está no céu agora.", 16777215)
                elseif estavaCheia and not cheia then F.avisar("Lua Cheia terminou", "A lua mudou de fase.", 8421504) end
                estavaCheia = cheia
            end)
            if not ok then registrarErro("Lua", err) end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    local presente = {}
    while Estado.rodando do
        for _, ev in ipairs(EVENTOS_ILHA) do
            if Cfg:Get(ev.chave) then
                local ok, err = pcall(function()
                    local existe = F.acharIlhaEvento(ev) ~= nil
                    if existe and not presente[ev.chave] then
                        F.avisar(ev.titulo .. " apareceu!", "A " .. ev.titulo .. " está ativa neste servidor.", 15277667)
                    elseif not existe and presente[ev.chave] then
                        F.avisar(ev.titulo .. " sumiu", "A " .. ev.titulo .. " não está mais neste servidor.", 8421504)
                    end
                    presente[ev.chave] = existe
                end)
                if not ok then registrarErro("Evento", err) end
            else
                presente[ev.chave] = nil
            end
        end
        task.wait(8)
    end
end)

-- =========================================================================
-- NOCLIP (durante movimento automático ou quando ativado manualmente)
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

    local function frame(char, zerarVelocidade)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if char ~= personagemAtual then
            table.clear(originais)
            personagemAtual = char
            atualizarPartes(char)
        elseif os.clock() - ultimoRefresh > 2 then
            atualizarPartes(char)
        end
        if zerarVelocidade then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        for i = 1, #partes do
            if partes[i].Parent then partes[i].CanCollide = false end
        end
    end

    ScriptJanitor:Adicionar({ Destroy = restaurar }, "Destroy")

    while Estado.rodando do
        local char = LocalPlayer.Character
        local auto = Cfg:Get("EmMovimento")
        if (auto or Cfg:Get("NoClipManual")) and char then
            pcall(frame, char, auto)
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
            elseif res == 0 and Cfg:Get("ChestHopServer") then F.serverHop() task.wait(15) end
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
-- CONTROLES (usados pela UI)
-- tipos: secao | info | toggle | slider | dropdown | botao | input
-- =========================================================================
local atualizarVisuais = function() end   -- substituída quando a UI é montada

local function aoMudarSea()
    local sea = seaEfetivo()
    Cfg:Set("BossSelecionado", listaBossesDoSea(sea)[1])
    Cfg:Set("QuestSelecionada", QuestDB:Lista(sea)[1])
end

local function infoSea()
    local lv = "?"
    pcall(function() lv = LocalPlayer.Data.Level.Value end)
    return string.format("Sea atual: %d   |   Sea selecionado: %d   |   Seu level: %s",
        seaAtual(), seaEfetivo(), tostring(lv))
end

local function infoBosses()
    local sea = seaEfetivo()
    local vivos = {}
    local pasta = pastaEnemies()
    if pasta then
        local conjunto = BOSS_SET[sea] or {}
        for _, e in ipairs(pasta:GetChildren()) do
            local k = norm(e.Name)
            if conjunto[k] or ELITE_SET[k] then table.insert(vivos, e.Name) end
        end
    end
    return string.format("Bosses do Sea %d: %d na lista.\nSpawnados agora: %s",
        sea, #listaBossesDoSea(sea), #vivos > 0 and table.concat(vivos, ", ") or "nenhum")
end

local function listaBossesSelecionados() return listaBossesDoSea(seaEfetivo()) end
local function listaMissoesSelecionadas() return QuestDB:Lista(seaEfetivo()) end

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
    { aba = "Main", tipo = "toggle", nome = "Auto Buso (Haki)", chave = "AutoBuso" },

    -- MASTERY
    { aba = "Mastery", tipo = "toggle", nome = "Auto Mastery Weapon", chave = "AutoMastery" },
    { aba = "Mastery", tipo = "dropdown", nome = "Select Mastery Weapon", chave = "MasteryWeapon", opcoes = ARMAS_MAESTRIA },
    { aba = "Mastery", tipo = "toggle", nome = "Auto Mastery Fruit", chave = "AutoMasteryFruit" },
    { aba = "Mastery", tipo = "slider", nome = "Mastery Health %", chave = "MasteryHealth", min = 5, max = 60, passo = 5 },

    -- MISSÕES / SEA
    { aba = "Missões", tipo = "info", texto = infoSea },
    { aba = "Missões", tipo = "dropdown", nome = "Sea selecionado", chave = "SeaSelecionado", opcoes = OPCOES_SEA, aoMudar = aoMudarSea },
    { aba = "Missões", tipo = "botao", nome = "Viajar para o Sea selecionado", acao = F.irParaSea },
    { aba = "Missões", tipo = "secao", nome = "Missão escolhida por você" },
    { aba = "Missões", tipo = "dropdown", nome = "Missão", chave = "QuestSelecionada", opcoes = listaMissoesSelecionadas },
    { aba = "Missões", tipo = "toggle", nome = "Auto Farm da missão selecionada", chave = "AutoQuestSel" },
    { aba = "Missões", tipo = "botao", nome = "Iniciar missão selecionada (1x)", acao = F.iniciarQuestSelecionadaAgora },
    { aba = "Missões", tipo = "info", texto = "A lista mostra as missões do sea selecionado, ordenadas por level. O \"Auto Farm Level\" da aba Main continua escolhendo a missão sozinho." },

    -- BOSSES (separados por sea)
    { aba = "Bosses", tipo = "info", texto = infoBosses },
    { aba = "Bosses", tipo = "dropdown", nome = "Sea dos bosses", chave = "SeaSelecionado", opcoes = OPCOES_SEA, aoMudar = aoMudarSea },
    { aba = "Bosses", tipo = "toggle", nome = "Auto Farm All Bosses (do sea)", chave = "AutoBossesAll" },
    { aba = "Bosses", tipo = "dropdown", nome = "Select Boss", chave = "BossSelecionado", opcoes = listaBossesSelecionados },
    { aba = "Bosses", tipo = "toggle", nome = "Auto Farm Selected Boss", chave = "AutoBossSel" },
    { aba = "Bosses", tipo = "toggle", nome = "Auto Elite Hunter (Sea 3)", chave = "AutoElite" },
    { aba = "Bosses", tipo = "toggle", nome = "Avisar quando um boss spawnar", chave = "BossNotifier" },
    { aba = "Bosses", tipo = "toggle", nome = "ESP de Bosses", chave = "EspBoss" },

    -- SEA EVENTS
    { aba = "Sea Events", tipo = "dropdown", nome = "Select Boat", chave = "Barco", opcoes = BARCOS },
    { aba = "Sea Events", tipo = "botao", nome = "Comprar Barco", acao = F.comprarBarco },
    { aba = "Sea Events", tipo = "toggle", nome = "Auto Attack Sea Events", chave = "AutoSeaEvent" },
    { aba = "Sea Events", tipo = "toggle", nome = "ESP de Sea Beasts", chave = "EspSeaBeast" },
    { aba = "Sea Events", tipo = "toggle", nome = "ESP de Barcos", chave = "EspBarco" },
    { aba = "Sea Events", tipo = "toggle", nome = "Remover Névoa (Zona 6)", chave = "SemNevoa", aoMudar = aplicarSemNevoa },
    { aba = "Sea Events", tipo = "toggle", nome = "Andar na Água", chave = "WalkWater" },

    -- RAIDS
    { aba = "Raids", tipo = "dropdown", nome = "Select Raid", chave = "RaidSelecionada", opcoes = RAIDS },
    { aba = "Raids", tipo = "toggle", nome = "Auto Buy Chip", chave = "AutoBuyChip" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Start Raid", chave = "AutoStartRaid" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Kill Aura (Raid)", chave = "AutoRaid" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Next Island", chave = "AutoNextIsland" },
    { aba = "Raids", tipo = "toggle", nome = "Auto Awake Fruit", chave = "AutoAwake" },

    -- FRUTAS
    { aba = "Frutas", tipo = "toggle", nome = "Fruit ESP (nome em cima da fruta)", chave = "FruitESP" },
    { aba = "Frutas", tipo = "toggle", nome = "Avisar quando uma fruta spawnar", chave = "FruitNotifier" },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Tween Fruit", chave = "AutoTweenFruit" },
    { aba = "Frutas", tipo = "botao", nome = "Teleportar p/ fruta mais próxima", acao = F.irParaFrutaMaisProxima },
    { aba = "Frutas", tipo = "botao", nome = "Bring All Fruits", acao = F.trazerTodasFrutas },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Store Fruit", chave = "AutoStoreFruit" },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Random Fruit", chave = "AutoRandomFruit" },
    { aba = "Frutas", tipo = "slider", nome = "Intervalo Random Fruit (s)", chave = "IntervaloFruta", min = 30, max = 7200, passo = 30 },
    { aba = "Frutas", tipo = "secao", nome = "Fruit Sniper" },
    { aba = "Frutas", tipo = "input", nome = "Frutas alvo (separe por vírgula)", chave = "FrutaAlvo", placeholder = "ex: dragon, leopard, kitsune" },
    { aba = "Frutas", tipo = "toggle", nome = "Auto Buy Fruit (Sniper)", chave = "FruitSniper" },
    { aba = "Frutas", tipo = "info", texto = "O resultado de cada compra do Sniper aparece como notificação (e no Discord, se o webhook estiver ativo na aba Avisos)." },

    -- ESP
    { aba = "ESP", tipo = "toggle", nome = "ESP Frutas", chave = "FruitESP" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Ilhas", chave = "EspIlha" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Eventos (Mirage/Kitsune/Pré-História)", chave = "EspEvento" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Players", chave = "EspPlayer" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Bosses (do sea selecionado)", chave = "EspBoss" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Baús", chave = "EspBau" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Flores", chave = "EspFlor" },
    { aba = "ESP", tipo = "toggle", nome = "ESP NPCs", chave = "EspNpc" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Barcos", chave = "EspBarco" },
    { aba = "ESP", tipo = "toggle", nome = "ESP Sea Beasts", chave = "EspSeaBeast" },
    { aba = "ESP", tipo = "secao", nome = "Opções do ESP" },
    { aba = "ESP", tipo = "toggle", nome = "Mostrar distância", chave = "EspDistancia" },
    { aba = "ESP", tipo = "slider", nome = "Distância máxima", chave = "EspMaxDist", min = 500, max = 50000, passo = 500 },
    { aba = "ESP", tipo = "slider", nome = "Tamanho do texto", chave = "EspTamanho", min = 10, max = 24, passo = 1 },

    -- EVENTOS
    { aba = "Eventos", tipo = "botao", nome = "Teleportar: Mirage Island", acao = function() F.irParaIlhaEvento(EVENTOS_ILHA[1]) end },
    { aba = "Eventos", tipo = "botao", nome = "Teleportar: Kitsune Island", acao = function() F.irParaIlhaEvento(EVENTOS_ILHA[2]) end },
    { aba = "Eventos", tipo = "botao", nome = "Teleportar: Prehistoric Island", acao = function() F.irParaIlhaEvento(EVENTOS_ILHA[3]) end },
    { aba = "Eventos", tipo = "toggle", nome = "ESP Eventos", chave = "EspEvento" },
    { aba = "Eventos", tipo = "botao", nome = "Mostrar ID da lua atual", acao = F.mostrarIdLua },
    { aba = "Eventos", tipo = "toggle", nome = "Chest Hop (Coletar Baús)", chave = "ChestHop" },
    { aba = "Eventos", tipo = "toggle", nome = "Chest Hop: trocar de servidor ao acabar", chave = "ChestHopServer" },
    { aba = "Eventos", tipo = "info", texto = "Os avisos de Mirage, Kitsune, Pré-História, Lua Cheia, Boss e Fruta ficam na aba Avisos." },

    -- AVISOS
    { aba = "Avisos", tipo = "secao", nome = "Discord Webhook" },
    { aba = "Avisos", tipo = "input", nome = "URL do Webhook", chave = "WebhookUrl", placeholder = "https://discord.com/api/webhooks/..." },
    { aba = "Avisos", tipo = "botao", nome = "Testar Webhook", acao = F.testarWebhook },
    { aba = "Avisos", tipo = "toggle", nome = "Enviar avisos para o Discord", chave = "WebhookAtivo" },
    { aba = "Avisos", tipo = "secao", nome = "O que avisar" },
    { aba = "Avisos", tipo = "toggle", nome = "Mirage Island", chave = "MirageNotifier" },
    { aba = "Avisos", tipo = "toggle", nome = "Kitsune Island", chave = "KitsuneNotifier" },
    { aba = "Avisos", tipo = "toggle", nome = "Prehistoric Island", chave = "PrehistoricNotifier" },
    { aba = "Avisos", tipo = "toggle", nome = "Lua Cheia", chave = "FullMoonNotifier" },
    { aba = "Avisos", tipo = "toggle", nome = "Fruta spawnou no mapa", chave = "FruitNotifier" },
    { aba = "Avisos", tipo = "toggle", nome = "Boss spawnou", chave = "BossNotifier" },
    { aba = "Avisos", tipo = "info", texto = "O resultado do Fruit Sniper sempre é avisado na tela. Com \"Enviar avisos para o Discord\" ligado, todos os avisos também vão para o webhook (com o JobId do servidor)." },

    -- STATS
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Melee", chave = "AutoStatMelee" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Defense", chave = "AutoStatDefense" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Sword", chave = "AutoStatSword" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Gun", chave = "AutoStatGun" },
    { aba = "Stats", tipo = "toggle", nome = "Auto Put Stats Blox Fruit", chave = "AutoStatFruit" },
    { aba = "Stats", tipo = "slider", nome = "Point Amount", chave = "QuantidadePontos", min = 1, max = 10, passo = 1 },

    -- TELEPORT
    { aba = "Teleport", tipo = "dropdown", nome = "Select Island", chave = "IlhaSelecionada", opcoes = F.listarIlhas },
    { aba = "Teleport", tipo = "botao", nome = "Teleport to Island", acao = F.irParaIlhaSelecionada },
    { aba = "Teleport", tipo = "dropdown", nome = "Select NPC", chave = "NpcSelecionado", opcoes = F.listarNPCs },
    { aba = "Teleport", tipo = "botao", nome = "Teleport to NPC", acao = F.irParaNpcSelecionado },
    { aba = "Teleport", tipo = "dropdown", nome = "Sea de destino", chave = "SeaSelecionado", opcoes = OPCOES_SEA, aoMudar = aoMudarSea },
    { aba = "Teleport", tipo = "botao", nome = "Viajar para o Sea selecionado", acao = F.irParaSea },
    { aba = "Teleport", tipo = "botao", nome = "Definir ponto de spawn aqui", acao = function() F.invocar("Spawn", "SetSpawnPoint") end },

    -- LOJA
    { aba = "Loja", tipo = "dropdown", nome = "Estilo de luta", chave = "EstiloSelecionado", opcoes = F.listaEstilos },
    { aba = "Loja", tipo = "botao", nome = "Comprar estilo selecionado", acao = F.comprarEstilo },
    { aba = "Loja", tipo = "secao", nome = "Haki / Habilidades" },
    { aba = "Loja", tipo = "botao", nome = "Comprar Geppo", acao = function() F.invocar("Loja", "BuyHaki", "Geppo") end },
    { aba = "Loja", tipo = "botao", nome = "Comprar Buso Haki", acao = function() F.invocar("Loja", "BuyHaki", "Buso") end },
    { aba = "Loja", tipo = "botao", nome = "Comprar Soru", acao = function() F.invocar("Loja", "BuyHaki", "Soru") end },
    { aba = "Loja", tipo = "secao", nome = "Time" },
    { aba = "Loja", tipo = "botao", nome = "Entrar nos Pirates", acao = function() F.invocar("Time", "SetTeam", "Pirates") end },
    { aba = "Loja", tipo = "botao", nome = "Entrar nos Marines", acao = function() F.invocar("Time", "SetTeam", "Marines") end },

    -- JOGADOR
    { aba = "Jogador", tipo = "toggle", nome = "Velocidade customizada", chave = "WalkSpeedOn" },
    { aba = "Jogador", tipo = "slider", nome = "Velocidade", chave = "WalkSpeed", min = 16, max = 300, passo = 2 },
    { aba = "Jogador", tipo = "toggle", nome = "Pulo infinito", chave = "InfJump" },
    { aba = "Jogador", tipo = "toggle", nome = "Noclip", chave = "NoClipManual" },
    { aba = "Jogador", tipo = "toggle", nome = "Energia infinita (melhor esforço)", chave = "InfEnergy" },
    { aba = "Jogador", tipo = "toggle", nome = "Full Bright", chave = "FullBright" },
    { aba = "Jogador", tipo = "toggle", nome = "Andar na Água", chave = "WalkWater" },
    { aba = "Jogador", tipo = "toggle", nome = "Remover Névoa", chave = "SemNevoa", aoMudar = aplicarSemNevoa },
    { aba = "Jogador", tipo = "toggle", nome = "FPS Boost", chave = "FpsBoost", aoMudar = F.aplicarFpsBoost },

    -- SISTEMA
    { aba = "Sistema", tipo = "toggle", nome = "White Screen (CPU/Bateria)", chave = "WhiteScreen", aoMudar = aplicarWhiteScreen },
    { aba = "Sistema", tipo = "toggle", nome = "Debug Screen", chave = "Debug" },
    { aba = "Sistema", tipo = "toggle", nome = "Anti-AFK", chave = "AntiAFK" },
    { aba = "Sistema", tipo = "toggle", nome = "Auto Rejoin (queda de conexão)", chave = "AutoRejoin" },
    { aba = "Sistema", tipo = "botao", nome = "Server Hop", acao = F.serverHop },
    { aba = "Sistema", tipo = "botao", nome = "Reentrar no jogo (Rejoin)", acao = F.reentrar },
    { aba = "Sistema", tipo = "botao", nome = "Copiar JobId deste servidor", acao = F.copiarJobId },
    { aba = "Sistema", tipo = "input", nome = "JobId para entrar", chave = "JobIdAlvo", placeholder = "cole o JobId aqui" },
    { aba = "Sistema", tipo = "botao", nome = "Entrar no servidor do JobId", acao = F.entrarNoServidor },
    { aba = "Sistema", tipo = "botao", nome = "Auto Redeem All Codes", acao = F.resgatarCodigos },
    { aba = "Sistema", tipo = "botao", nome = "Descarregar Hub (desligar tudo)", acao = function() ScriptJanitor:LimparTudo() end },
}

local function definir(c, valor, leve)
    Cfg:Set(c.chave, valor)
    if c.aoMudar then pcall(c.aoMudar, valor) end
    if not leve then atualizarVisuais() end
end

local function opcoesDe(c)
    local o = c.opcoes
    if type(o) == "function" then o = o() end
    return o
end

-- valores iniciais dos dropdowns dinâmicos (ilha/NPC/boss/missão)
for _, c in ipairs(CONTROLES) do
    if c.tipo == "dropdown" and Cfg:Get(c.chave) == nil then
        Cfg:Set(c.chave, opcoesDe(c)[1])
    end
end

-- =========================================================================
-- HUD DE DEBUG + BOTÃO FLUTUANTE
-- =========================================================================
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
    label.Size = UDim2.new(0, 210, 0, 90)
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
                label.Text = string.format(" Sessão: %s\n Modo: %s\n Sea: %d (sel. %d)\n Level: %s\n Beli: %s | Frag: %s",
                    formatarTempo(os.clock() - Estado.inicio), Estado.modo, seaAtual(), seaEfetivo(),
                    tostring(lv), tostring(beli), tostring(frag))
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
-- UI PRÓPRIA: ABAS NA ESQUERDA
-- =========================================================================
local UI = { frame = nil }

local Tema = {
    fundo = Color3.fromRGB(16, 16, 24),
    painel = Color3.fromRGB(24, 24, 36),
    item = Color3.fromRGB(34, 34, 50),
    acento = Color3.fromRGB(110, 70, 220),
    texto = Color3.fromRGB(235, 235, 245),
    sub = Color3.fromRGB(165, 165, 190),
    on = Color3.fromRGB(46, 160, 100),
    off = Color3.fromRGB(80, 80, 104),
    botao = Color3.fromRGB(70, 60, 150),
}

local LARGURA, ALTURA, LARGURA_ABAS, ALTURA_TOPO = 620, 380, 128, 34

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
            local pai = frame.Parent
            local tela = pai and pai.AbsoluteSize or Vector2.new(1280, 720)
            local tam = frame.AbsoluteSize
            local nx = math.clamp(startPos.X.Offset + d.X, 0, math.max(0, tela.X - 80))
            local ny = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, tela.Y - 40))
            frame.Position = UDim2.fromOffset(nx, ny)
        end
    end))
end

local function novoTexto(pai, texto, tam, cor, fonte)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = texto
    l.TextSize = tam or 13
    l.TextColor3 = cor or Tema.texto
    l.Font = fonte or Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = pai
    return l
end

local function construirUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutomataUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    montarGui(gui)
    ScriptJanitor:Adicionar(gui, "Destroy")

    local atualizadores = {}
    atualizarVisuais = function()
        for _, fn in ipairs(atualizadores) do pcall(fn) end
    end
    local function registrar(fn) table.insert(atualizadores, fn) end

    -- janela principal
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.fromOffset(LARGURA, ALTURA)
    Main.AnchorPoint = Vector2.new(0, 0)
    Main.Position = UDim2.fromOffset(40, 40) -- ajustado logo abaixo, depois do UIScale
    Main.BackgroundColor3 = Tema.fundo
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.ClipsDescendants = true
    Main.Parent = gui
    arredondar(Main, 8)
    UI.frame = Main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Tema.acento
    stroke.Transparency = 0.4
    stroke.Thickness = 1.5
    stroke.Parent = Main

    -- escala automática (celular / tela pequena)
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local escala = Instance.new("UIScale")
    escala.Scale = math.clamp(math.min(vp.X * 0.9 / LARGURA, vp.Y * 0.85 / ALTURA), 0.5, 1)
    escala.Parent = Main
    -- centraliza UMA vez; o topo fica fixo ao minimizar/abrir
    Main.Position = UDim2.fromOffset(
        math.max(0, (vp.X - LARGURA * escala.Scale) / 2),
        math.max(0, (vp.Y - ALTURA * escala.Scale) / 2))

    -- topo
    local Topo = Instance.new("Frame")
    Topo.Size = UDim2.new(1, 0, 0, ALTURA_TOPO)
    Topo.BackgroundColor3 = Tema.acento
    Topo.BorderSizePixel = 0
    Topo.Parent = Main
    arredondar(Topo, 8)

    local titulo = novoTexto(Topo, "AUTOMATA HUB v" .. VERSAO .. "  -  Blox Fruits", 14, Color3.new(1, 1, 1), Enum.Font.GothamBold)
    titulo.Size = UDim2.new(1, -90, 1, 0)
    titulo.Position = UDim2.new(0, 12, 0, 0)
    tornarArrastavel(Main, Topo)

    local function botaoTopo(texto, deslocamento)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 28, 0, 24)
        b.Position = UDim2.new(1, deslocamento, 0.5, -12)
        b.BackgroundColor3 = Color3.fromRGB(80, 50, 170)
        b.Text = texto
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.Parent = Topo
        arredondar(b, 6)
        return b
    end
    local btnMin = botaoTopo("-", -66)
    local btnFechar = botaoTopo("X", -34)

    -- corpo (barra de abas à ESQUERDA + conteúdo)
    local Corpo = Instance.new("Frame")
    Corpo.Size = UDim2.new(1, 0, 1, -ALTURA_TOPO)
    Corpo.Position = UDim2.new(0, 0, 0, ALTURA_TOPO)
    Corpo.BackgroundTransparency = 1
    Corpo.Parent = Main

    local BarraAbas = Instance.new("ScrollingFrame")
    BarraAbas.Size = UDim2.new(0, LARGURA_ABAS, 1, -8)
    BarraAbas.Position = UDim2.new(0, 4, 0, 4)
    BarraAbas.BackgroundColor3 = Tema.painel
    BarraAbas.BorderSizePixel = 0
    BarraAbas.ScrollBarThickness = 3
    BarraAbas.CanvasSize = UDim2.new(0, 0, 0, 0)
    BarraAbas.AutomaticCanvasSize = Enum.AutomaticSize.Y
    BarraAbas.Parent = Corpo
    arredondar(BarraAbas, 6)
    local layAbas = Instance.new("UIListLayout")
    layAbas.Padding = UDim.new(0, 4)
    layAbas.SortOrder = Enum.SortOrder.LayoutOrder
    layAbas.Parent = BarraAbas
    local padAbas = Instance.new("UIPadding")
    padAbas.PaddingTop = UDim.new(0, 4)
    padAbas.PaddingLeft = UDim.new(0, 4)
    padAbas.PaddingRight = UDim.new(0, 4)
    padAbas.PaddingBottom = UDim.new(0, 4)
    padAbas.Parent = BarraAbas

    local Conteudo = Instance.new("Frame")
    Conteudo.Size = UDim2.new(1, -(LARGURA_ABAS + 12), 1, -8)
    Conteudo.Position = UDim2.new(0, LARGURA_ABAS + 8, 0, 4)
    Conteudo.BackgroundColor3 = Tema.painel
    Conteudo.BorderSizePixel = 0
    Conteudo.ClipsDescendants = true
    Conteudo.Parent = Corpo
    arredondar(Conteudo, 6)

    local minimizado = false
    ScriptJanitor:Adicionar(btnMin.MouseButton1Click:Connect(function()
        minimizado = not minimizado
        Corpo.Visible = not minimizado
        Main.Size = UDim2.fromOffset(LARGURA, minimizado and ALTURA_TOPO or ALTURA)
    end))
    ScriptJanitor:Adicionar(btnFechar.MouseButton1Click:Connect(function() Main.Visible = false end))

    -- páginas ------------------------------------------------------------
    local paginas, botoesAba, ordemAba, ordemItens = {}, {}, 0, {}

    local function proximaOrdem(pagina)
        ordemItens[pagina] = (ordemItens[pagina] or 0) + 1
        return ordemItens[pagina]
    end

    local function mostrar(nome)
        for n, p in pairs(paginas) do p.Visible = (n == nome) end
        for n, b in pairs(botoesAba) do
            b.BackgroundColor3 = (n == nome) and Tema.acento or Tema.item
            b.TextColor3 = (n == nome) and Color3.new(1, 1, 1) or Tema.sub
        end
    end

    local function pagina(nome)
        if paginas[nome] then return paginas[nome] end

        ordemAba = ordemAba + 1
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.LayoutOrder = ordemAba
        btn.Text = nome
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = Tema.sub
        btn.BackgroundColor3 = Tema.item
        btn.AutoButtonColor = true
        btn.Parent = BarraAbas
        arredondar(btn, 6)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.Parent = btn
        botoesAba[nome] = btn
        ScriptJanitor:Adicionar(btn.MouseButton1Click:Connect(function() mostrar(nome) end))

        local p = Instance.new("ScrollingFrame")
        p.Name = "Pagina_" .. nome
        p.Size = UDim2.new(1, -8, 1, -8)
        p.Position = UDim2.new(0, 4, 0, 4)
        p.BackgroundTransparency = 1
        p.BorderSizePixel = 0
        p.ScrollBarThickness = 4
        p.CanvasSize = UDim2.new(0, 0, 0, 0)
        p.AutomaticCanvasSize = Enum.AutomaticSize.Y
        p.Visible = false
        p.Parent = Conteudo
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 6)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = p
        local padP = Instance.new("UIPadding")
        padP.PaddingRight = UDim.new(0, 6)
        padP.PaddingBottom = UDim.new(0, 6)
        padP.Parent = p
        paginas[nome] = p
        return p
    end

    local function novaLinha(p, altura)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, altura)
        f.BackgroundColor3 = Tema.item
        f.BorderSizePixel = 0
        f.LayoutOrder = proximaOrdem(p)
        f.Parent = p
        arredondar(f, 6)
        return f
    end

    -- controles ----------------------------------------------------------
    local function criarSecao(p, c)
        local l = novoTexto(p, string.upper(c.nome), 12, Tema.acento, Enum.Font.GothamBold)
        l.Size = UDim2.new(1, 0, 0, 22)
        l.LayoutOrder = proximaOrdem(p)
    end

    local function criarInfo(p, c)
        local linha = novaLinha(p, 0)
        linha.AutomaticSize = Enum.AutomaticSize.Y
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = linha
        local rot = novoTexto(linha, "", 12, Tema.sub)
        rot.Size = UDim2.new(1, 0, 0, 0)
        rot.AutomaticSize = Enum.AutomaticSize.Y
        rot.TextWrapped = true
        rot.TextYAlignment = Enum.TextYAlignment.Top
        local function visual()
            rot.Text = type(c.texto) == "function" and tostring(c.texto()) or tostring(c.texto)
        end
        visual()
        registrar(visual)
    end

    local function criarToggle(p, c)
        local linha = novaLinha(p, 36)
        local rot = novoTexto(linha, c.nome, 12)
        rot.Size = UDim2.new(1, -66, 1, 0)
        rot.Position = UDim2.new(0, 10, 0, 0)
        rot.TextWrapped = true

        local trilho = Instance.new("Frame")
        trilho.Size = UDim2.new(0, 40, 0, 20)
        trilho.Position = UDim2.new(1, -50, 0.5, -10)
        trilho.BorderSizePixel = 0
        trilho.Parent = linha
        arredondar(trilho, 10)
        local bola = Instance.new("Frame")
        bola.Size = UDim2.new(0, 16, 0, 16)
        bola.BackgroundColor3 = Color3.new(1, 1, 1)
        bola.BorderSizePixel = 0
        bola.Parent = trilho
        arredondar(bola, 8)

        local botao = Instance.new("TextButton")
        botao.Size = UDim2.new(1, 0, 1, 0)
        botao.BackgroundTransparency = 1
        botao.Text = ""
        botao.Parent = linha

        local function visual()
            local on = Cfg:Get(c.chave) == true
            trilho.BackgroundColor3 = on and Tema.on or Tema.off
            bola.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end
        visual()
        registrar(visual)
        ScriptJanitor:Adicionar(botao.MouseButton1Click:Connect(function()
            definir(c, not (Cfg:Get(c.chave) == true))
        end))
    end

    local function criarSlider(p, c)
        local linha = novaLinha(p, 50)
        local rot = novoTexto(linha, c.nome, 12)
        rot.Size = UDim2.new(1, -100, 0, 24)
        rot.Position = UDim2.new(0, 10, 0, 2)
        local valor = novoTexto(linha, "", 12, Tema.acento, Enum.Font.GothamBold)
        valor.Size = UDim2.new(0, 84, 0, 24)
        valor.Position = UDim2.new(1, -94, 0, 2)
        valor.TextXAlignment = Enum.TextXAlignment.Right

        local barra = Instance.new("Frame")
        barra.Size = UDim2.new(1, -24, 0, 8)
        barra.Position = UDim2.new(0, 12, 0, 34)
        barra.BackgroundColor3 = Tema.off
        barra.BorderSizePixel = 0
        barra.Parent = linha
        arredondar(barra, 4)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Tema.acento
        fill.BorderSizePixel = 0
        fill.Parent = barra
        arredondar(fill, 4)

        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 0, 26)
        hit.Position = UDim2.new(0, 0, 0, 24)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.Parent = linha

        local function visual()
            local v = tonumber(Cfg:Get(c.chave)) or c.min
            local a = (v - c.min) / math.max(c.max - c.min, 1)
            fill.Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0)
            valor.Text = tostring(v)
        end
        visual()
        registrar(visual)

        local arrastando = false
        local function aPartirDe(x)
            local larg = barra.AbsoluteSize.X
            if larg <= 0 then return end
            local a = math.clamp((x - barra.AbsolutePosition.X) / larg, 0, 1)
            local v = c.min + a * (c.max - c.min)
            v = c.min + math.floor((v - c.min) / c.passo + 0.5) * c.passo
            v = math.clamp(v, c.min, c.max)
            if v ~= Cfg:Get(c.chave) then
                definir(c, v, true)
                visual()
            end
        end
        ScriptJanitor:Adicionar(hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                arrastando = true
                p.ScrollingEnabled = false
                aPartirDe(input.Position.X)
            end
        end))
        ScriptJanitor:Adicionar(UserInputService.InputChanged:Connect(function(input)
            if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                aPartirDe(input.Position.X)
            end
        end))
        ScriptJanitor:Adicionar(UserInputService.InputEnded:Connect(function(input)
            if arrastando and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                arrastando = false
                p.ScrollingEnabled = true
                atualizarVisuais()
            end
        end))
    end

    local function criarDropdown(p, c)
        local cont = Instance.new("Frame")
        cont.Size = UDim2.new(1, 0, 0, 36)
        cont.AutomaticSize = Enum.AutomaticSize.Y
        cont.BackgroundColor3 = Tema.item
        cont.BorderSizePixel = 0
        cont.LayoutOrder = proximaOrdem(p)
        cont.Parent = p
        arredondar(cont, 6)
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 4)
        lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        lay.Parent = cont

        local cab = Instance.new("TextButton")
        cab.Size = UDim2.new(1, 0, 0, 36)
        cab.BackgroundTransparency = 1
        cab.Text = ""
        cab.LayoutOrder = 1
        cab.Parent = cont
        local rot = novoTexto(cab, c.nome, 12, Tema.sub)
        rot.Size = UDim2.new(0.42, -10, 1, 0)
        rot.Position = UDim2.new(0, 10, 0, 0)
        rot.TextWrapped = true
        local val = novoTexto(cab, "", 12)
        val.Size = UDim2.new(0.58, -34, 1, 0)
        val.Position = UDim2.new(0.42, 0, 0, 0)
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.TextTruncate = Enum.TextTruncate.AtEnd
        local seta = novoTexto(cab, "v", 12, Tema.acento, Enum.Font.GothamBold)
        seta.Size = UDim2.new(0, 20, 1, 0)
        seta.Position = UDim2.new(1, -24, 0, 0)
        seta.TextXAlignment = Enum.TextXAlignment.Center

        local lista = Instance.new("ScrollingFrame")
        lista.Size = UDim2.new(1, -12, 0, 0)
        lista.BackgroundColor3 = Tema.painel
        lista.BorderSizePixel = 0
        lista.ScrollBarThickness = 3
        lista.CanvasSize = UDim2.new(0, 0, 0, 0)
        lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
        lista.Visible = false
        lista.LayoutOrder = 2
        lista.Parent = cont
        arredondar(lista, 6)
        local layLista = Instance.new("UIListLayout")
        layLista.Padding = UDim.new(0, 2)
        layLista.SortOrder = Enum.SortOrder.LayoutOrder
        layLista.Parent = lista
        local padLista = Instance.new("UIPadding")
        padLista.PaddingTop = UDim.new(0, 2)
        padLista.PaddingBottom = UDim.new(0, 2)
        padLista.PaddingLeft = UDim.new(0, 2)
        padLista.PaddingRight = UDim.new(0, 2)
        padLista.Parent = lista

        local function visual()
            val.Text = tostring(Cfg:Get(c.chave) or "-")
        end
        visual()
        registrar(visual)

        local aberto = false
        local function fechar()
            aberto = false
            lista.Visible = false
            lista.Size = UDim2.new(1, -12, 0, 0)
            seta.Text = "v"
        end
        local function abrir()
            for _, ch in ipairs(lista:GetChildren()) do
                if ch:IsA("TextButton") then ch:Destroy() end
            end
            local opcoes = opcoesDe(c) or {}
            local atual = Cfg:Get(c.chave)
            for i, op in ipairs(opcoes) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -4, 0, 26)
                b.LayoutOrder = i
                b.Text = tostring(op)
                b.Font = Enum.Font.Gotham
                b.TextSize = 12
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.TextTruncate = Enum.TextTruncate.AtEnd
                b.TextColor3 = Tema.texto
                b.BackgroundColor3 = (op == atual) and Tema.acento or Tema.item
                b.Parent = lista
                arredondar(b, 4)
                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 8)
                pad.PaddingRight = UDim.new(0, 8)
                pad.Parent = b
                b.MouseButton1Click:Connect(function()
                    definir(c, op)
                    fechar()
                end)
            end
            lista.Size = UDim2.new(1, -12, 0, math.min(#opcoes * 28 + 6, 150))
            lista.Visible = true
            aberto = true
            seta.Text = "^"
        end
        ScriptJanitor:Adicionar(cab.MouseButton1Click:Connect(function()
            if aberto then fechar() else abrir() end
        end))
    end

    local function criarBotao(p, c)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 34)
        b.BackgroundColor3 = Tema.botao
        b.Text = c.nome
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.LayoutOrder = proximaOrdem(p)
        b.Parent = p
        arredondar(b, 6)
        ScriptJanitor:Adicionar(b.MouseButton1Click:Connect(function()
            task.spawn(function()
                local ok, err = pcall(c.acao)
                if not ok then registrarErro("Botao", err) end
            end)
        end))
    end

    local function criarInput(p, c)
        local linha = novaLinha(p, 58)
        local rot = novoTexto(linha, c.nome, 12, Tema.sub)
        rot.Size = UDim2.new(1, -20, 0, 22)
        rot.Position = UDim2.new(0, 10, 0, 3)
        local caixa = Instance.new("TextBox")
        caixa.Size = UDim2.new(1, -20, 0, 26)
        caixa.Position = UDim2.new(0, 10, 0, 27)
        caixa.Text = tostring(Cfg:Get(c.chave) or "")
        caixa.PlaceholderText = c.placeholder or "digite aqui"
        caixa.PlaceholderColor3 = Tema.off
        caixa.ClearTextOnFocus = false
        caixa.ClipsDescendants = true
        caixa.TextColor3 = Tema.texto
        caixa.BackgroundColor3 = Color3.fromRGB(46, 46, 66)
        caixa.Font = Enum.Font.Gotham
        caixa.TextSize = 12
        caixa.TextXAlignment = Enum.TextXAlignment.Left
        caixa.Parent = linha
        arredondar(caixa, 5)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = caixa
        ScriptJanitor:Adicionar(caixa.FocusLost:Connect(function()
            local t = trim(caixa.Text)
            caixa.Text = t
            definir(c, t)
        end))
    end

    local criadores = {
        secao = criarSecao, info = criarInfo, toggle = criarToggle, slider = criarSlider,
        dropdown = criarDropdown, botao = criarBotao, input = criarInput,
    }

    local primeira = nil
    for _, c in ipairs(CONTROLES) do
        local p = pagina(c.aba)
        primeira = primeira or c.aba
        local criar = criadores[c.tipo]
        if criar then
            local ok, err = pcall(criar, p, c)
            if not ok then registrarLog("UI", "Falha ao criar controle '" .. tostring(c.nome or c.tipo) .. "'", err) end
        end
    end
    if primeira then mostrar(primeira) end

    -- mantém textos informativos / valores atualizados
    task.spawn(function()
        while Estado.rodando do
            if Main.Visible and not minimizado then atualizarVisuais() end
            task.wait(2)
        end
    end)
end

-- =========================================================================
-- INICIALIZAÇÃO
-- =========================================================================
criarDebugHud()

task.spawn(function()
    local ok, err = pcall(construirUI)
    if ok then
        criarBotaoFlutuante(function()
            if UI.frame then UI.frame.Visible = not UI.frame.Visible end
        end)
    else
        registrarLog("UI", "Falha ao montar a interface", err)
        notificar("AUTOMATA", "Falha ao montar a interface: " .. tostring(err))
    end
end)

task.delay(1, function()
    notificar("AUTOMATA v" .. VERSAO, "Script carregado. Sea atual: " .. tostring(seaAtual()))
end)