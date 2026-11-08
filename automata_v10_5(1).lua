-- =========================================================================
--   AUTOMATA HUB v14.3 - BLOX FRUITS
-- =========================================================================
local VERSAO = "14.3"

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
local GuiService = Services.GuiService

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

-- Presets de eventos temporários (palavras-chave separadas por vírgula; o espaço e
-- os símbolos são ignorados: "jack o lantern" casa com "Jack O' Lantern").
-- ATENÇÃO: estas palavras vêm de guias do evento Halloween 2026 (Candy Corn,
-- Harvest Moon, Hellrider, Unbound Werewolf, Great Pumpkin, Zioles, Witch). Os
-- nomes INTERNOS dos objetos no jogo não foram verificados: use o "Escanear evento".
local PRESET_HALLOWEEN = "Halloween 2026 (nomes dos guias)"
local PRESETS_EVENTO = {
    [PRESET_HALLOWEEN] = {
        mobs = "jack o lantern, werewolf, hellrider, hell rider, great pumpkin, pumpkin snowman, pumpkin head",
        coletaveis = "pumpkin",
        portas = "door",
        npcs = "zioles, witch",
        quebrar = "pumpkin, jack o lantern",   -- segundo os guias, abóboras são quebradas atacando
        excluir = "gray, grey",                -- variante cinza é descrita como perigosa (spawna inimigos)
    },
}
local OPCOES_PRESET_EVENTO = { PRESET_HALLOWEEN, "Personalizado" }

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

local Estado = { rodando = true, modo = "ocioso", inicio = os.clock(), pausa = false, pausas = 0 }

-- Pausa por contador: várias ações podem pausar ao mesmo tempo, e o farm só
-- volta quando TODAS terminarem (antes, a primeira a terminar religava tudo).
local function pausar()
    Estado.pausas = Estado.pausas + 1
    Estado.pausa = true
end
local function retomar()
    Estado.pausas = math.max(0, Estado.pausas - 1)
    Estado.pausa = Estado.pausas > 0
end

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
        IntervaloNormalMs = 120, IntervaloFastMs = 30,
        VelTeleport = 250, VelFarm = 75, VelColeta = 150,
        -- Mastery
        AutoMastery = false, AutoMasteryFruit = false, MasteryWeapon = "Sword", MasteryHealth = 20,
        -- Sea / Missões
        SeaSelecionado = SEA_AUTO, QuestSelecionada = nil, AutoQuestSel = false,
        QuestTravar = true,
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
        -- Loja / Progressão
        EstiloSelecionado = "Superhuman", AutoComprarEstilos = false, VoltarDepoisCompra = true,
        UsarEstiloFarm = false, EstiloFarm = nil, VendedorNotifier = true, NpcBusca = "", NpcManual = "",
        -- Avisos / Eventos
        FullMoonNotifier = true, BossNotifier = false,
        MirageNotifier = true, KitsuneNotifier = true, PrehistoricNotifier = true,
        ChestHop = false, ChestHopServer = false,
        -- Eventos temporários
        EventoPreset = PRESET_HALLOWEEN,
        EventoMobs = PRESETS_EVENTO[PRESET_HALLOWEEN].mobs,
        EventoColetaveis = PRESETS_EVENTO[PRESET_HALLOWEEN].coletaveis,
        EventoPortas = PRESETS_EVENTO[PRESET_HALLOWEEN].portas,
        EventoNpcs = PRESETS_EVENTO[PRESET_HALLOWEEN].npcs,
        EventoNpcSel = nil,
        EventoFarmMobs = false, EventoColetar = false, EventoPortasOn = false,
        EventoQuebrarOn = false,
        EventoQuebrar = PRESETS_EVENTO[PRESET_HALLOWEEN].quebrar,
        EventoQuebrarExcluir = PRESETS_EVENTO[PRESET_HALLOWEEN].excluir,
        EventoSoHarvest = true, EventoToque = false, EventoRaio = 1500,
        EventoAvisoHarvest = false, EventoMonitor = false,
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

-- CFrame do spawn mais próximo cujo nome contém algum nome do conjunto.
-- Se o conjunto tem UM só nome (caso das missões), tenta primeiro o nome EXATO:
-- "Bandit" não deve levar você ao spawn de "Desert Bandit".
local function spawnMaisProximo(conjunto)
    local spawns, root = spawnsPasta(), meuRoot()
    if not spawns or not root then return nil end

    local total = 0
    for _ in pairs(conjunto) do total = total + 1 end

    local function procurar(exato)
        local melhor, menor = nil, math.huge
        for _, s in ipairs(spawns:GetChildren()) do
            for nome in pairs(conjunto) do
                local casou
                if exato then
                    casou = (s.Name == nome)
                else
                    casou = string.find(s.Name, nome, 1, true) ~= nil
                end
                if casou then
                    local cf = pivotDe(s)
                    if cf then
                        local d = (cf.Position - root.Position).Magnitude
                        if d < menor then menor, melhor = d, cf end
                    end
                end
            end
        end
        return melhor
    end

    if total == 1 then
        local exato = procurar(true)
        if exato then return exato end
    end
    return procurar(false)
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
    -- treino de maestria: com a arma "Melee", usa o estilo escolhido na aba Progressão
    if tooltip == "Melee" and Cfg:Get("UsarEstiloFarm") and type(Cfg:Get("EstiloFarm")) == "string" then
        for _, container in ipairs({ char, backpack }) do
            local t = container:FindFirstChild(Cfg:Get("EstiloFarm"))
            if t and t:IsA("Tool") then return t end
        end
    end
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
local AtaqueNet = { atk = nil, hit = nil, ultimo = 0, avisou = false }
-- golpes = vezes que o script enviou RegisterAttack+RegisterHit; dano = vida
-- perdida pelo alvo enquanto o script o atacava (inclui dano de outras fontes)
local Metricas = { golpes = 0, falhas = 0, dano = 0 }

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
    if not atk or not hit then
        Metricas.falhas = Metricas.falhas + 1
        if not AtaqueNet.avisou then
            AtaqueNet.avisou = true
            registrarLog("Combate", "RE/RegisterAttack / RE/RegisterHit NÃO encontrados em ReplicatedStorage.Modules.Net: o dano depende só de Tool:Activate(). Rode o Diagnóstico de ataque (aba Main).")
            notificar("Combate", "Remotes de ataque não encontrados: o Fast Attack não tem efeito. Veja o F9.")
        end
        return false
    end
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
    Metricas.golpes = Metricas.golpes + 1
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
    local ms = Cfg:Get("FastAttack") and (tonumber(Cfg:Get("IntervaloFastMs")) or 30)
        or (tonumber(Cfg:Get("IntervaloNormalMs")) or 120)
    local intervalo = math.max(ms, 0) / 1000
    if os.clock() - AtaqueNet.ultimo < intervalo then return end
    AtaqueNet.ultimo = os.clock()

    CombatManager:Golpear(alvo)
    -- animação / fallback. NÃO usamos mais VirtualUser:Button1Down(0,0):
    -- isso clicava no canto superior esquerdo da tela e apertava os botões da UI.
    pcall(function() ferramenta:Activate() end)
end

-- Só equipa a arma/estilo e clica (Tool:Activate), no mesmo ritmo do ataque normal.
-- Usado para quebrar objetos que não são mobs (ex.: abóboras do evento).
function CombatManager:Clicar(char, hum, backpack, tooltip)
    local ferramenta = escolherFerramenta(char, backpack, tooltip)
    if ferramenta and ferramenta.Parent ~= char then
        hum:EquipTool(ferramenta)
        task.wait(0.05)
    end
    if not (ferramenta and ferramenta.Parent == char) then return false end
    local ms = Cfg:Get("FastAttack") and (tonumber(Cfg:Get("IntervaloFastMs")) or 30)
        or (tonumber(Cfg:Get("IntervaloNormalMs")) or 120)
    if os.clock() - AtaqueNet.ultimo < math.max(ms, 0) / 1000 then return true end
    AtaqueNet.ultimo = os.clock()
    pcall(function() ferramenta:Activate() end)
    return true
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

function F.diagnosticoCombate()
    task.spawn(function()
        local linhas = {}
        local function out(t)
            table.insert(linhas, t)
            registrarLog("Combate", t)
        end
        out("=== Diagnóstico de ataque - Automata Hub v" .. VERSAO .. " ===")
        local mods = ReplicatedStorage:FindFirstChild("Modules")
        local net = mods and mods:FindFirstChild("Net")
        out("ReplicatedStorage.Modules: " .. (mods and "existe" or "NÃO existe"))
        out("ReplicatedStorage.Modules.Net: " .. (net and ("existe [" .. net.ClassName .. "]") or "NÃO existe"))
        local atk = net and net:FindFirstChild("RE/RegisterAttack")
        local hit = net and net:FindFirstChild("RE/RegisterHit")
        out("RE/RegisterAttack: " .. (atk and atk.ClassName or "NÃO encontrado"))
        out("RE/RegisterHit: " .. (hit and hit.ClassName or "NÃO encontrado"))
        if net then
            local nomes = {}
            for _, c in ipairs(net:GetChildren()) do
                local l = string.lower(c.Name)
                if string.find(l, "regist", 1, true) or string.find(l, "attack", 1, true)
                    or string.find(l, "hit", 1, true) or string.find(l, "damage", 1, true) then
                    table.insert(nomes, "[" .. c.ClassName .. "] " .. c.Name)
                end
            end
            table.sort(nomes)
            out("Total de filhos de Net: " .. #net:GetChildren() .. " | com 'regist/attack/hit/damage' no nome: " .. #nomes)
            for _, n in ipairs(nomes) do out("   " .. n) end
        end
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        out("Ferramenta equipada: " .. (tool and (tool.Name .. " | ToolTip=" .. tostring(tool.ToolTip)) or "nenhuma"))
        out(string.format("Config: FastAttack=%s | intervalo normal=%sms | intervalo Fast=%sms | arma=%s",
            tostring(Cfg:Get("FastAttack")), tostring(Cfg:Get("IntervaloNormalMs")),
            tostring(Cfg:Get("IntervaloFastMs")), tostring(Cfg:Get("Weapon"))))
        out(string.format("Desde que o script carregou: golpes enviados=%d | falhas (remotes ausentes)=%d | dano observado=%.0f",
            Metricas.golpes, Metricas.falhas, Metricas.dano))
        out("=== fim do diagnóstico ===")
        local texto = table.concat(linhas, "\n")
        local copiado, salvo = false, false
        if setclipboard then copiado = pcall(setclipboard, texto) end
        if writefile then salvo = pcall(writefile, "automata_diagnostico_ataque.txt", texto) end
        notificar("Diagnóstico de ataque", string.format("Pronto. Área de transferência: %s | Arquivo: %s | F9: sim.",
            copiado and "copiado" or "indisponível", salvo and "salvo" or "indisponível"))
    end)
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
-- Detecta se o HumanoidRootPart está enfiado em chão/parede (só peças que
-- colidem; ignora mobs e outros jogadores). A caixa é um pouco menor que o
-- corpo para que ficar em pé no chão NÃO conte como "preso".
local ParamsColisao = OverlapParams.new()
ParamsColisao.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() ParamsColisao.RespectCanCollide = true end)

local function personagemPreso(char)
    local ok, res = pcall(function()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        -- sentado (barco, assento): o corpo fica dentro do assento de propósito
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then return false end
        local excluir = { char }
        local e = Workspace:FindFirstChild("Enemies")
        if e then table.insert(excluir, e) end
        local c = Workspace:FindFirstChild("Characters")
        if c then table.insert(excluir, c) end
        ParamsColisao.FilterDescendantsInstances = excluir
        local partes = Workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(2.2, 5, 1.4), ParamsColisao)
        for _, p in ipairs(partes) do
            -- só conta peça SÓLIDA de verdade: zonas/marcadores (CanCollide=false),
            -- terreno/água e o plano do mar não prendem ninguém
            if p.CanCollide and not p:IsA("Terrain") and p.Name ~= "WaterBase-Plane" then
                return true
            end
        end
        return false
    end)
    return ok and res == true
end

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
            and (root.Position - destino.Position).Magnitude > 1.5 do
            task.wait(0.1)
            gasto = gasto + 0.1
            if gasto > tempo + 3 then break end
        end
    end)

    if tween then pcall(function() tween:Cancel() tween:Destroy() end) end
    pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
    self._ocupado = false
    Cfg:Set("EmMovimento", false)

    if not ok then error(erro, 0) end
    return root.Parent ~= nil and (root.Position - destino.Position).Magnitude <= 8
end

-- Velocidade (studs/s) lida da configuração; "padrao" vale se a chave estiver vazia
local function velCfg(chave, padrao)
    return math.max(10, tonumber(Cfg:Get(chave)) or padrao)
end

-- Viagem em 3 fases (BLOQUEANTE): sobe -> atravessa no alto -> desce.
-- Devolve true se chegou ao destino.
local function viajar(cf, velocidade)
    local v = velocidade or velCfg("VelTeleport", 250)
    -- espera outro movimento terminar (até 20s)
    local t0 = os.clock()
    while MovementService._ocupado and os.clock() - t0 < 20 do task.wait(0.2) end
    local root = meuRoot()
    if not root then return false end
    local ini, alvo = root.Position, cf.Position
    local horizontal = Vector3.new(ini.X - alvo.X, 0, ini.Z - alvo.Z).Magnitude
    if horizontal > 120 then
        local alt = math.max(ini.Y, alvo.Y) + 150
        if not MovementService:Interpola(CFrame.new(ini.X, alt, ini.Z), v) then return false end
        if not MovementService:Interpola(CFrame.new(alvo.X, alt, alvo.Z), v) then return false end
    end
    return MovementService:Interpola(cf, v)
end
F.viajar = viajar

local function teleportar(cf, velocidade)
    task.spawn(function()
        local ok, res = pcall(viajar, cf, velocidade)
        if not ok then
            registrarErro("Teleport", res)
        elseif not res then
            local root = meuRoot()
            local d = root and (root.Position - cf.Position).Magnitude
            registrarLog("Teleport", string.format("Parou a %s studs do destino (Y atual=%s, Y destino=%.0f)",
                d and string.format("%.0f", d) or "?", root and string.format("%.0f", root.Position.Y) or "?", cf.Position.Y))
            notificar("Teleport", "Não chegou ao destino" .. (d and string.format(" (parou a %.0f studs)", d) or "")
                .. ". Veja o F9 para detalhes.")
        end
    end)
end

-- =========================================================================
-- MISSÕES
-- =========================================================================
-- true / false = estado lido da GUI de missão; nil = não foi possível ler
local function estadoQuestGui()
    local ok, v = pcall(function() return LocalPlayer.PlayerGui.Main.Quest.Visible end)
    if ok and type(v) == "boolean" then return v end
    return nil
end

local function questAtiva()
    return estadoQuestGui() == true
end

local function iniciarQuest(nome, idx, abandonarAntes)
    if abandonarAntes and questAtiva() then
        pcall(function() obterCommF():InvokeServer("AbandonQuest") end)
    end
    local ok, err = pcall(function() obterCommF():InvokeServer("StartQuest", nome, idx) end)
    if not ok then registrarErro("Quest", err) end
end

-- Escolhe a missão pelo level (mesma regra de antes) e devolve também a quantidade
-- de alvos exigida: nome, índice, mob, quantidade
local function escolherQuestPorLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local lv = data and data:FindFirstChild("Level")
    local mod = ReplicatedStorage:FindFirstChild("Quests")
    if not lv or not mod then return nil end
    local okReq, tabela = pcall(require, mod)
    if not okReq or type(tabela) ~= "table" then return nil end

    local function melhorQuest(exigirSpawn)
        local nomeQ, idxQ, mobQ, qtdQ, reqQ = nil, nil, nil, nil, -1
        for nome, lista in pairs(tabela) do
            if type(lista) == "table" then
                for idx, q in pairs(lista) do
                    if type(q) == "table" and type(q.Task) == "table" and type(q.LevelReq) == "number"
                        and q.LevelReq <= lv.Value and q.LevelReq > reqQ then
                        local mob, qtd = next(q.Task)
                        -- tarefas com 1 alvo costumam ser bosses: ignora
                        if mob and type(qtd) == "number" and qtd > 1 and not ALL_BOSS_SET[norm(mob)]
                            and (not exigirSpawn or existeSpawn(mob)) then
                            nomeQ, idxQ, mobQ, qtdQ, reqQ = nome, idx, mob, qtd, q.LevelReq
                        end
                    end
                end
            end
        end
        return nomeQ, idxQ, mobQ, qtdQ
    end

    local n, i, m, c = melhorQuest(true)
    if not n then n, i, m, c = melhorQuest(false) end
    return n, i, m, c
end

-- Gerenciador de missão. Regras:
--  * a missão é identificada por NOME + ÍNDICE (antes só pelo nome);
--  * com "travar" ligado, a missão atual NÃO é trocada por subir de level: só depois de concluída;
--  * "concluída" = a GUI da missão estava visível e deixou de estar; se a GUI não puder ser
--    lida, vale a contagem de mortes do alvo (>= quantidade exigida);
--  * o StartQuest só é reenviado se a missão nunca apareceu como ativa em 10 s.
local function novaGerenciadoraQuest(rotulo, escolher, travar)
    local q = { nome = nil, indice = nil, mob = nil, qtd = nil, chave = nil,
                ultimo = 0, ultimoStart = 0, viuAtiva = false, mortes = 0 }

    local function chaveDe(n, i) return tostring(n) .. "#" .. tostring(i) end

    function q:Liberar(motivo)
        registrarLog("Quest", string.format("[%s] liberando a missão %s (%s)", rotulo, tostring(self.chave), motivo))
        self.nome, self.indice, self.mob, self.qtd, self.chave = nil, nil, nil, nil, nil
        self.viuAtiva, self.mortes = false, 0
    end

    function q:Matou(alvo)
        if self.chave and self.mob and alvo and alvo.Name == self.mob then
            self.mortes = self.mortes + 1
            registrarLog("Quest", string.format("[%s] %s morto (%d/%s)",
                rotulo, tostring(self.mob), self.mortes, tostring(self.qtd or "?")))
        end
    end

    function q:Garantir()
        local agora = os.clock()
        if agora - self.ultimo < 2 then return end
        self.ultimo = agora
        local estado = estadoQuestGui()
        local abandonarAntes = false

        if self.chave then
            if estado == true then self.viuAtiva = true end

            local terminou = false
            if estado == false and self.viuAtiva then
                terminou = true
            elseif estado == nil and self.qtd and self.mortes >= self.qtd then
                terminou = true
            end

            if terminou then
                self:Liberar("concluída")
            elseif not travar() then
                local n, i = escolher()
                if n and chaveDe(n, i) ~= self.chave then
                    self:Liberar("a escolha mudou")
                    abandonarAntes = (estado == true)
                end
            end

            if self.chave then
                -- continua na mesma missão; só reenvia o StartQuest se ele não "pegou"
                if estado == false and not self.viuAtiva and agora - self.ultimoStart > 10 then
                    self.ultimoStart = agora
                    registrarLog("Quest", string.format("[%s] a missão %s não apareceu como ativa em 10s: reenviando StartQuest",
                        rotulo, self.chave))
                    iniciarQuest(self.nome, self.indice, false)
                end
                return
            end
        end

        local n, i, m, qtd = escolher()
        if not n then return end
        self.nome, self.indice, self.mob, self.qtd = n, i, m, qtd
        self.chave = chaveDe(n, i)
        self.viuAtiva, self.mortes, self.ultimoStart = false, 0, agora
        registrarLog("Quest", string.format("[%s] iniciando a missão %s (alvo: %s x%s)",
            rotulo, self.chave, tostring(m), tostring(qtd or "?")))
        iniciarQuest(n, i, abandonarAntes)
    end

    return q
end

-- Auto Farm Level: missão escolhida pelo level, travada até concluir (opção "QuestTravar")
local Quest = novaGerenciadoraQuest("Level", escolherQuestPorLevel,
    function() return Cfg:Get("QuestTravar") ~= false end)

-- Missão escolhida pelo usuário na aba "Missões": se ele trocar a escolha, troca na hora
local function dadosQuestSel()
    return QuestDB:Dados(Cfg:Get("QuestSelecionada"))
end

local QuestSel = novaGerenciadoraQuest("Selecionada", function()
    local d = dadosQuestSel()
    if d then return d.nome, d.idx, d.mob, d.qtd end
    return nil
end, function() return false end)

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
-- ---- Palavras-chave de eventos --------------------------------------------
local function normKw(s)
    return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

local kwCache = {}
local function kwDe(chave)
    local raw = tostring(Cfg:Get(chave) or "")
    local c = kwCache[chave]
    if c and c.raw == raw then return c.lista end
    local lista = {}
    for pedaco in string.gmatch(raw, "[^,;\n]+") do
        local k = normKw(pedaco)
        if k ~= "" then table.insert(lista, k) end
    end
    kwCache[chave] = { raw = raw, lista = lista }
    return lista
end

-- devolve a palavra da lista contida no nome, ou nil
local function casaKw(nome, lista)
    local n = normKw(nome)
    for _, k in ipairs(lista) do
        if string.find(n, k, 1, true) then return k end
    end
    return nil
end

-- Relógio do servidor (UTC). Harvest Moon = primeiros 10 min de cada hora (segundo os guias)
function F.agoraUtc()
    local ok, t = pcall(function() return Workspace:GetServerTimeNow() end)
    if ok and type(t) == "number" then return t end
    return os.time()
end
function F.harvestAtiva()
    return F.agoraUtc() % 3600 < 600
end

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
    { nome = "Evento (mobs)", chaves = { "EventoFarmMobs" }, raio = 5000, pastas = soEnemies,
      filtro = function(e) return casaKw(e.Name, kwDe("EventoMobs")) ~= nil end },
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
      aoMatar = function(alvo) QuestSel:Matou(alvo) end,
      filtro = function(e) local d = dadosQuestSel() return d ~= nil and e.Name == d.mob end,
      fallback = function()
          local d = dadosQuestSel()
          return d and spawnMaisProximo({ [d.mob] = true }) or nil
      end },
    { nome = "Level", chaves = { "AutoFarm" }, raio = 3000, pastas = soEnemies,
      preparar = function() Quest:Garantir() end,
      aoMatar = function(alvo) Quest:Matou(alvo) end,
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
    local ativo = function() return modoAtivo(modo) and not Estado.pausa end

    local dist = tonumber(Cfg:Get("AttackDistance")) or 6.5
    local destino = rootAlvo.CFrame * CFrame.new(0, dist, 0)
    if (myRoot.Position - destino.Position).Magnitude > 12 then
        if not MovementService:Interpola(destino, velCfg("VelFarm", 75), ativo) then return end
    end

    Cfg:Set("EmMovimento", true)
    local inicio = os.clock()
    local vidaAnterior = humAlvo.Health
    while Estado.rodando and ativo() and os.clock() - inicio < 5 do
        local vidaAgora = humAlvo.Health
        if vidaAgora < vidaAnterior then Metricas.dano = Metricas.dano + (vidaAnterior - vidaAgora) end
        vidaAnterior = vidaAgora
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

    -- contabiliza a morte do alvo (usado pelo controle de missão)
    if modo.aoMatar then
        local ok, morto = pcall(function() return humAlvo.Health <= 0 end)
        if ok and morto then pcall(modo.aoMatar, alvo) end
    end
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
                    MovementService:Interpola(cf + Vector3.new(0, 20, 0), velCfg("VelFarm", 75) * 1.2, function() return modoAtivo(modo) end)
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
        if algumModoAtivo() and not Estado.pausa then
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

-- Auto Random Fruit: espera "interrompível" (o toggle responde na hora) e
-- tentativa nova em 5 min se a compra não for confirmada.
do
    local function esperarAtivo(chave, segundos)
        local t0 = os.clock()
        while Estado.rodando and Cfg:Get(chave) and os.clock() - t0 < segundos do
            task.wait(1)
        end
    end

    local function contarFrutas()
        local inv = nil
        local ok, r = pcall(function() return obterCommF():InvokeServer("getInventoryFruits") end)
        if ok and type(r) == "table" then
            inv = 0
            for _ in pairs(r) do inv = inv + 1 end
        end
        local mochila = 0
        for _, pasta in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
            if pasta then
                for _, t in ipairs(pasta:GetChildren()) do
                    if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then mochila = mochila + 1 end
                end
            end
        end
        return inv, mochila
    end

    task.spawn(function()
        while Estado.rodando do
            if Cfg:Get("AutoRandomFruit") then
                local ok, err = pcall(function()
                    local invAntes, mochAntes = contarFrutas()
                    -- a compra só funciona perto do NPC do gacha: vai até ele, compra e volta
                    local feito, r, achou = F.comNpc({ "cousin", "gacha" }, function()
                        return obterCommF():InvokeServer("Cousin", "Buy")
                    end)
                    if not achou then
                        registrarLog("Fruta", "NPC do gacha não encontrado no mapa; tentei comprar mesmo assim")
                    end
                    task.wait(2)
                    local invDepois, mochDepois = contarFrutas()
                    local ganhou = (invAntes and invDepois and invDepois > invAntes) or mochDepois > mochAntes
                    registrarLog("Fruta", "Resposta do jogo: " .. tostring(r))
                    if ganhou then
                        notificar("Random Fruit", "Fruta comprada! Próxima tentativa conforme o intervalo.")
                        esperarAtivo("AutoRandomFruit", tonumber(Cfg:Get("IntervaloFruta")) or 7200)
                    else
                        notificar("Random Fruit", "Não comprou (resposta: " .. tostring(r) .. ")" .. (achou and "" or " [NPC do gacha não encontrado]") .. ". Nova tentativa em 5 min.")
                        esperarAtivo("AutoRandomFruit", 300)
                    end
                end)
                if not ok then registrarErro("Fruta", err) esperarAtivo("AutoRandomFruit", 30) end
            end
            task.wait(1)
        end
    end)
end

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

do
    local avisouSkip = false
    loopToggle("AutoStoreFruit", "Guardar", function()
        -- não guarda a fruta se você a usa para farmar
        if Cfg:Get("AutoMasteryFruit") or Cfg:Get("Weapon") == "Blox Fruit" then
            if not avisouSkip then
                avisouSkip = true
                notificar("Guardar fruta", "Pausado: a arma selecionada é a Blox Fruit (troque para Melee/Sword/Gun).")
            end
            return 3
        end
        avisouSkip = false

        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        for _, container in ipairs({ backpack, char }) do
            if container then
                for _, t in ipairs(container:GetChildren()) do
                    if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then
                        -- fruta equipada não pode ser guardada: desequipa antes
                        if t.Parent == char and hum then pcall(function() hum:UnequipTools() end) task.wait(0.15) end

                        local nomes, vistos = {}, {}
                        local function add(n)
                            if type(n) == "string" and n ~= "" and not vistos[n] then vistos[n] = true table.insert(nomes, n) end
                        end
                        add(t:GetAttribute("OriginalName"))
                        add(t.Name)
                        add(trim((string.gsub(t.Name, "%s*[Ff][Rr][Uu][Ii][Tt]%s*", " "))))

                        for _, nome in ipairs(nomes) do
                            local ok, r = pcall(function() return obterCommF():InvokeServer("StoreFruit", nome, t) end)
                            registrarLog("Guardar", string.format("%s -> %s", nome, ok and tostring(r) or ("erro: " .. tostring(r))))
                            task.wait(0.4)
                            if not t.Parent or (t.Parent ~= backpack and t.Parent ~= char) then break end
                        end
                    end
                end
            end
        end
        return 3
    end)
end

loopToggle("AutoTweenFruit", "TweenFruta", function()
    if Estado.pausa then return 0.5 end
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
        -- a Tool pode só mudar de pai ao ser coletada: "no mapa" = filha do Workspace
        local ativo = function() return Cfg:Get("AutoTweenFruit") and melhor.Parent == Workspace and not Estado.pausa end
        local chegou = MovementService:Interpola(melhorParte.CFrame + Vector3.new(0, 3, 0), velCfg("VelColeta", 150), ativo)
        -- só encosta se o tween realmente chegou (evita teleporte direto de longe)
        if chegou and ativo() then
            local pegou = F.pegarFruta(melhor, melhorParte)
            registrarLog("TweenFruta", (pegou and "Coletou: " or "Não conseguiu coletar: ") .. tostring(melhor.Name))
        end
    end
    return 0.5
end)

-- O Interpola para a ~1.5 studs do alvo e cancela o tween; o pickup do jogo
-- é por toque no Handle, então aqui encostamos de fato: posiciona em cima do
-- Handle e dispara o toque.
function F.pegarFruta(fruta, parte)
    local root = meuRoot()
    if not root or not fruta or not parte then return false end
    local antes = Cfg:Get("EmMovimento")
    Cfg:Set("EmMovimento", true) -- mantém o noclip enquanto encosta
    for _ = 1, 8 do
        if fruta.Parent ~= Workspace or not parte.Parent then break end
        -- +3 studs: os pés ficam na altura do Handle, sem enterrar o corpo no chão
        pcall(function() root.CFrame = parte.CFrame + Vector3.new(0, 3, 0) end)
        if firetouchinterest then
            pcall(function()
                firetouchinterest(root, parte, 0)
                firetouchinterest(root, parte, 1)
            end)
        end
        task.wait(0.15)
    end
    Cfg:Set("EmMovimento", antes)
    return fruta.Parent ~= Workspace
end

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

-- Erro 773 = "teleporte para local restrito": o servidor escolhido (ou o modo
-- de teleporte) foi recusado. Em vez de tentar uma vez só, agora o script
-- escuta TeleportInitFailed, marca o servidor como ruim e tenta outro.
local Hop = { ocupado = false, falhos = {}, ultimaFalha = -999 }

-- Listener permanente: registra TODA falha de teleporte (o log mostra o motivo
-- real) e guarda o instante, usado pelo Auto Rejoin para não reagir ao popup
-- de falha de teleporte.
ScriptJanitor:Adicionar(TeleportService.TeleportInitFailed:Connect(function(pl, resultado, msg)
    if pl == LocalPlayer then
        Hop.ultimaFalha = os.clock()
        registrarLog("Teleport", "TeleportInitFailed: " .. tostring(resultado) .. " - " .. tostring(msg))
    end
end))

local function requisicaoHttp(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and res ~= "" then return res end
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(r) == "table" and type(r.Body) == "string" then return r.Body end
    end
    return nil
end

local function listarServidores()
    local lista, cursor = {}, nil
    for _ = 1, 3 do
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        if cursor then url = url .. "&cursor=" .. cursor end
        local corpo = requisicaoHttp(url)
        if not corpo then break end
        local ok, dados = pcall(function() return HttpService:JSONDecode(corpo) end)
        if not ok or type(dados) ~= "table" then break end
        for _, sv in ipairs(dados.data or {}) do
            if sv.id ~= game.JobId and not Hop.falhos[sv.id]
                and sv.playing and sv.maxPlayers and sv.playing > 0 and sv.playing < sv.maxPlayers - 2 then
                table.insert(lista, sv.id)
            end
        end
        cursor = dados.nextPageCursor
        if type(cursor) ~= "string" then break end
    end
    return lista
end

-- Executa um teleporte e espera ~10s para ver se o Roblox recusou.
-- Devolve true se aparentemente está em andamento, false + motivo se falhou.
local function teleportarComRetorno(fn)
    local falhou = nil
    local con = TeleportService.TeleportInitFailed:Connect(function(pl, resultado, msg)
        if pl == LocalPlayer then falhou = tostring(resultado) .. " - " .. tostring(msg) end
    end)
    local ok, err = pcall(fn)
    if not ok then con:Disconnect() return false, tostring(err) end
    local t0 = os.clock()
    while os.clock() - t0 < 10 and not falhou do task.wait(0.25) end
    con:Disconnect()
    if falhou then return false, falhou end
    return true
end

function F.serverHop()
    if Hop.ocupado then notificar("Server Hop", "Já existe uma troca de servidor em andamento.") return end
    Hop.ocupado = true
    task.spawn(function()
        local ok, err = pcall(function()
            local candidatos = listarServidores()
            local tentativas = 0
            local recusados = 0
            while #candidatos > 0 and tentativas < 6 do
                tentativas = tentativas + 1
                local i = math.random(#candidatos)
                local id = table.remove(candidatos, i)
                local feito, motivo = teleportarComRetorno(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
                end)
                if feito then return end
                Hop.falhos[id] = true
                if string.find(tostring(motivo), "Unauthorized", 1, true) then
                    recusados = recusados + 1
                    if recusados >= 2 then
                        error("o Roblox recusou o teleporte 2x seguidas (" .. tostring(motivo)
                            .. "); parei de tentar outros servidores", 0)
                    end
                else
                    recusados = 0
                end
                registrarLog("ServerHop", "Falhou (" .. tostring(motivo) .. "), tentando outro servidor...")
                task.wait(1.5)
            end
            -- último recurso: deixa o Roblox escolher um servidor
            notificar("Server Hop", "Tentando entrar em qualquer servidor disponível...")
            local feito, motivo = teleportarComRetorno(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            if not feito then error(motivo, 0) end
        end)
        Hop.ocupado = false
        if not ok then registrarErro("ServerHop", err) notificar("Server Hop", "Falhou: " .. tostring(err)) end
    end)
end

function F.reentrar()
    if Hop.ocupado then return end
    Hop.ocupado = true
    task.spawn(function()
        local estrategias = {
            function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end, -- mesmo servidor
            function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end,                           -- qualquer servidor
        }
        local deuCerto = false
        local motivos = {}
        for _, fn in ipairs(estrategias) do
            local feito, motivo = teleportarComRetorno(fn)
            if feito then deuCerto = true break end
            table.insert(motivos, tostring(motivo))
            registrarLog("Rejoin", "Falhou: " .. tostring(motivo))
            notificar("Rejoin", "Falhou (" .. tostring(motivo) .. "). Tentando outro método...")
            task.wait(3)
        end
        if not deuCerto then
            F.avisar("Rejoin - FALHOU", "Nenhum método de reentrada funcionou: "
                .. table.concat(motivos, " || ") .. ". Reentre manualmente.", 15158332)
        end
        Hop.ocupado = false
    end)
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
    task.spawn(function()
        local feito, motivo = teleportarComRetorno(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer) end)
        if not feito then notificar("Servidor", "Falhou: " .. tostring(motivo)) end
    end)
end

function F.irParaSea()
    local alvo = seaEfetivo()
    if alvo == seaAtual() then notificar("Sea", "Você já está no Sea " .. tostring(alvo) .. ".") return end
    notificar("Sea", "Tentando viajar para o Sea " .. tostring(alvo) .. "...")
    F.invocar("Sea", TRAVEL_REMOTES[alvo])
end

-- =========================================================================
-- PROGRESSÃO: ESTILOS DE LUTA, ESPADAS LENDÁRIAS E VENDEDORES RAROS
-- =========================================================================
do
    -- Estilos de luta. req = { {estilo, maestria mínima} }. Valores APROXIMADOS:
    -- confira no jogo (o servidor é quem decide se a compra vale).
    -- "extra" = quest/itens que o script NÃO consegue fazer sozinho.
    local TODOS400 = { { "Superhuman", 400 }, { "Death Step", 400 }, { "Sharkman Karate", 400 },
                       { "Electric Claw", 400 }, { "Dragon Talon", 400 } }
    local ESTILOS_LISTA = {
        { nome = "Black Leg", remote = "BuyBlackLeg", beli = 150000, npc = { "dark step", "black leg" } },
        { nome = "Electro", remote = "BuyElectro", beli = 500000, npc = { "scientist", "electro" } },
        { nome = "Fishman Karate", remote = "BuyFishmanKarate", beli = 750000, npc = { "kung", "fishman karate" } },
        { nome = "Dragon Claw", remote = "BuyDragonClaw", frag = 1500, npc = { "dragon claw" } },
        { nome = "Superhuman", remote = "BuySuperhuman", beli = 3000000,
          req = { { "Black Leg", 300 }, { "Electro", 300 }, { "Fishman Karate", 300 }, { "Dragon Claw", 300 } },
          npc = { "martial", "superhuman" } },
        { nome = "Death Step", remote = "BuyDeathStep", beli = 2500000, frag = 5000,
          req = { { "Black Leg", 400 } }, extra = "Library Key (Awakened Ice Admiral)", npc = { "death step" } },
        { nome = "Sharkman Karate", remote = "BuySharkmanKarate", beli = 2500000, frag = 5000,
          req = { { "Fishman Karate", 400 } }, extra = "Water Key (Tide Keeper)", npc = { "sharkman" } },
        { nome = "Electric Claw", remote = "BuyElectricClaw", beli = 3000000, frag = 5000,
          req = { { "Electro", 400 } }, extra = "Sea 3", npc = { "previous hero", "electric claw" } },
        { nome = "Dragon Talon", remote = "BuyDragonTalon", beli = 3000000, frag = 5000,
          req = { { "Dragon Claw", 400 } }, extra = "Fire Essence", npc = { "dragon talon", "uzoth" } },
        { nome = "Godhuman", remote = "BuyGodhuman", beli = 5000000, frag = 5000,
          req = TODOS400, extra = "materiais (Fish Tail, Magma Ore, Dragon Scale, Mystic Droplet)", npc = { "godhuman" } },
        { nome = "Sanguine Art", remote = "BuySanguineArt", req = TODOS400,
          extra = "materiais do Sea 3 (veja no jogo)", npc = { "sanguine" } },
    }

    local ESPADAS_LENDARIAS = {   -- a ordem 1/2/3 pode variar: confira a resposta do jogo
        { nome = "Shisui", id = "1" }, { nome = "Saddi", id = "2" }, { nome = "Wando", id = "3" },
    }

    -- raro = true: não fica sempre disponível (aviso quando spawnar)
    local VENDEDORES = {
        { chave = "LegendarySword", nome = "Legendary Sword Dealer", npc = { "legendary sword" }, raro = true },
        { chave = "HakiColor", nome = "Haki Color Dealer", npc = { "haki color", "color dealer" }, raro = true },
        { chave = "AdvancedFruit", nome = "Advanced Fruit Dealer (Mirage)", npc = { "advanced fruit" }, raro = true },
        { chave = "BloxFruit", nome = "Blox Fruit Dealer", npc = { "blox fruit dealer", "fruit dealer" }, raro = false },
    }

    local function fmtNum(n)
        local s = tostring(math.floor(tonumber(n) or 0))
        s = string.reverse(s)
        s = string.gsub(s, "(%d%d%d)", "%1.")
        s = string.reverse(s)
        s = string.gsub(s, "^%.", "")
        return s
    end

    local function dadosJogador()
        local d = LocalPlayer:FindFirstChild("Data")
        local b = d and d:FindFirstChild("Beli")
        local f = d and d:FindFirstChild("Fragments")
        return b and tonumber(b.Value) or 0, f and tonumber(f.Value) or 0
    end

    -- inventário (cache atualizado em segundo plano, no máx. a cada 20s)
    local invCache, invT = {}, -999
    local function atualizarInventarioAsync()
        if os.clock() - invT < 20 then return end
        invT = os.clock()
        task.spawn(function()
            local ok, inv = pcall(function() return obterCommF():InvokeServer("getInventory") end)
            if ok and type(inv) == "table" then
                local nomes = {}
                for _, item in pairs(inv) do
                    local n = item
                    if type(item) == "table" then n = item.Name or item.name end
                    if type(n) == "string" then nomes[n] = true end
                end
                invCache = nomes
            end
        end)
    end

    -- ---- Busca de NPCs ------------------------------------------------------
    -- Normaliza: minúsculas e sem espaços/símbolos ("Dark-Step Teacher" -> "darkstepteacher")
    local function normNome(s)
        s = string.lower(tostring(s or ""))
        s = string.gsub(s, "[^%w]", "")
        return s
    end

    -- Todos os pedaços da palavra-chave precisam aparecer no nome:
    -- "blox fruit dealer" casa com "Blox Fruits Dealer"; "dark step" com "DarkStepTeacher"
    local function casa(nomeNorm, palavra)
        local algum = false
        for pedaco in string.gmatch(palavra, "%S+") do
            local p = normNome(pedaco)
            if p ~= "" then
                algum = true
                if not string.find(nomeNorm, p, 1, true) then return false end
            end
        end
        return algum
    end

    -- Versão com os pedaços já normalizados (usada na varredura grande)
    local function tokensDe(palavra)
        local l = {}
        for pedaco in string.gmatch(palavra, "%S+") do
            local p = normNome(pedaco)
            if p ~= "" then table.insert(l, p) end
        end
        return l
    end
    local function casaTokens(nomeNorm, tokens)
        if #tokens == 0 then return false end
        for _, p in ipairs(tokens) do
            if not string.find(nomeNorm, p, 1, true) then return false end
        end
        return true
    end

    -- nome do modelo E o DisplayName do Humanoid
    local function nomesDe(c)
        local l = { normNome(c.Name) }
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.DisplayName ~= "" then table.insert(l, normNome(h.DisplayName)) end
        return l
    end

    -- Índice de modelos que contêm um Humanoid: UMA varredura inicial e depois
    -- mantido por eventos. (Antes, cada busca "profunda" refazia
    -- Workspace:GetDescendants() a cada 15s, o que trava em mapas grandes.)
    local indiceHum = {}      -- indiceHum[modelo] = true
    local indiceMontado = false
    local function registrarHumanoid(h)
        local m = h.Parent
        if m and m:IsA("Model") then indiceHum[m] = true end
    end
    local function montarIndice()
        if indiceMontado then return end
        indiceMontado = true
        ScriptJanitor:Adicionar(Workspace.DescendantAdded:Connect(function(d)
            if d:IsA("Humanoid") then registrarHumanoid(d) end
        end))
        ScriptJanitor:Adicionar(Workspace.DescendantRemoving:Connect(function(d)
            if indiceHum[d] then indiceHum[d] = nil end
        end))
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Humanoid") then registrarHumanoid(d) end
        end
    end
    task.defer(function() pcall(montarIndice) end)

    -- Candidatos: Workspace.NPCs + modelos soltos com Humanoid + (profundo) QUALQUER
    -- modelo com Humanoid em qualquer lugar do Workspace (via índice acima).
    -- O 2º parâmetro (forcar) foi mantido só por compatibilidade e é ignorado.
    local function candidatosNpc(profundo, forcar)
        local lista, vistos = {}, {}
        local function add(c)
            if not vistos[c] then
                vistos[c] = true
                table.insert(lista, c)
            end
        end
        local pasta = Workspace:FindFirstChild("NPCs")
        if pasta then for _, c in ipairs(pasta:GetChildren()) do add(c) end end
        for _, c in ipairs(Workspace:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(c) then
                add(c)
            end
        end
        if profundo then
            pcall(montarIndice)
            local enemies = Workspace:FindFirstChild("Enemies")
            local chars = Workspace:FindFirstChild("Characters")
            local boats = Workspace:FindFirstChild("Boats")
            for m in pairs(indiceHum) do
                if m.Parent and not vistos[m] and not Players:GetPlayerFromCharacter(m)
                    and not (enemies and m:IsDescendantOf(enemies))
                    and not (chars and m:IsDescendantOf(chars))
                    and not (boats and m:IsDescendantOf(boats)) then
                    add(m)
                end
            end
        end
        return lista
    end

    -- Procura o NPC já carregado no cliente. Devolve (npc, distância) ou nil.
    function F.acharNpc(palavras, profundo, forcar)
        if profundo == nil then profundo = true end
        local root = meuRoot()
        local cands = candidatosNpc(profundo, forcar)
        for _, exato in ipairs({ true, false }) do
            local melhor, menor = nil, math.huge
            for _, c in ipairs(cands) do
                if not c:IsA("Tool") then
                    local nomes = nomesDe(c)
                    local bate = false
                    for _, p in ipairs(palavras) do
                        local pn = normNome(p)
                        for _, n in ipairs(nomes) do
                            if (exato and n == pn) or (not exato and casa(n, p)) then bate = true break end
                        end
                        if bate then break end
                    end
                    if bate then
                        local cf = pivotDe(c)
                        if cf then
                            local d = root and (cf.Position - root.Position).Magnitude or 0
                            if d < menor then menor, melhor = d, c end
                        end
                    end
                end
            end
            if melhor then return melhor, menor end
        end
        return nil, nil
    end

    -- Nomes de NPCs "parecidos" com o que foi procurado (para você ver o nome real)
    function F.nomesParecidos(palavras)
        local tokens = {}
        for _, p in ipairs(palavras) do
            for pedaco in string.gmatch(p, "%S+") do
                local t = normNome(pedaco)
                if #t >= 3 then tokens[t] = true end
            end
        end
        local achados, vistos = {}, {}
        for _, c in ipairs(candidatosNpc(true)) do
            for _, n in ipairs(nomesDe(c)) do
                for t in pairs(tokens) do
                    if string.find(n, t, 1, true) and not vistos[c.Name] then
                        vistos[c.Name] = true
                        table.insert(achados, c.Name)
                    end
                end
            end
            if #achados >= 12 then break end
        end
        return achados
    end

    local function logNaoAchado(palavras)
        local pasta = Workspace:FindFirstChild("NPCs")
        local parecidos = F.nomesParecidos(palavras)
        registrarLog("NPC", string.format("'%s' não encontrado | StreamingEnabled=%s | Workspace.NPCs=%s | nomes parecidos: %s",
            table.concat(palavras, " / "), tostring(Workspace.StreamingEnabled),
            pasta and (tostring(#pasta:GetChildren()) .. " itens") or "inexistente",
            #parecidos > 0 and table.concat(parecidos, ", ") or "nenhum"))
    end

    -- Procura QUALQUER Model/Folder/BasePart (não só os que têm Humanoid) cujo
    -- nome contenha os termos, no Workspace e no ReplicatedStorage. Percorre em
    -- lotes para não travar o jogo. Yield! Devolve (tabela termo -> instâncias, total examinado).
    function F.buscarPorNome(termos, limitePorTermo)
        local alvos = {}
        for _, t in ipairs(termos) do
            alvos[t] = { tokens = tokensDe(t), achados = {} }
        end
        local contador = 0
        for _, raiz in ipairs({ Workspace, ReplicatedStorage }) do
            for _, d in ipairs(raiz:GetDescendants()) do
                contador = contador + 1
                if contador % 3000 == 0 then task.wait() end
                if d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart") then
                    local n = normNome(d.Name)
                    if n ~= "" then
                        for _, t in ipairs(termos) do
                            local a = alvos[t]
                            if #a.achados < limitePorTermo and casaTokens(n, a.tokens) then
                                table.insert(a.achados, d)
                            end
                        end
                    end
                end
            end
        end
        local resultado = {}
        for _, t in ipairs(termos) do resultado[t] = alvos[t].achados end
        return resultado, contador
    end

    -- Se o mapa usa streaming, NPCs longe não existem no cliente: força o carregamento
    local NpcPos = {}   -- posições já vistas nesta sessão
    local function carregarAoRedor(pos, timeout)
        pcall(function() LocalPlayer:RequestStreamAroundAsync(pos, timeout or 4) end)
    end

    -- Procura o NPC (pode demorar: faz varredura pelas ilhas se necessário). Yield!
    function F.localizarNpc(palavras)
        local chave = normNome(palavras[1] or "")
        local npc, d = F.acharNpc(palavras, true)
        if npc then
            local cf = pivotDe(npc)
            if cf then NpcPos[chave] = cf.Position end
            return npc, d
        end
        if not Workspace.StreamingEnabled then return nil, nil end

        local conhecido = NpcPos[chave]
        if conhecido then
            carregarAoRedor(conhecido, 4)
            task.wait(0.3)
            npc, d = F.acharNpc(palavras, true, true)
            if npc then return npc, d end
        end

        notificar("NPC", "Procurando '" .. tostring(palavras[1]) .. "' pelo mapa (pode levar até 1 min)...")
        local locs = locations()
        if not locs then return nil, nil end
        local root = meuRoot()
        local pontos = {}
        for _, c in ipairs(locs:GetChildren()) do
            local cf = pivotDe(c)
            if cf then table.insert(pontos, cf.Position) end
        end
        if root then
            table.sort(pontos, function(a, b)
                return (a - root.Position).Magnitude < (b - root.Position).Magnitude
            end)
        end
        local t0 = os.clock()
        for _, pos in ipairs(pontos) do
            if os.clock() - t0 > 60 or not Estado.rodando then break end
            carregarAoRedor(pos, 3)
            task.wait(0.2)
            npc, d = F.acharNpc(palavras, true, true)
            if npc then
                local cf = pivotDe(npc)
                if cf then NpcPos[chave] = cf.Position end
                return npc, d
            end
        end
        return nil, nil
    end

    -- Vai até o NPC (se achar), pausa as automações, executa acao() e volta.
    -- Devolve: ok, resultado_ou_erro, achouNpc
    function F.comNpc(palavras, acao)
        local root = meuRoot()
        if not root then return false, "sem personagem", false end
        local origem = root.CFrame
        local resultado, achou = nil, false
        pausar()
        local ok, err = pcall(function()
            local npc = F.localizarNpc(palavras)
            achou = npc ~= nil
            if npc then
                local cf = pivotDe(npc)
                if cf and not viajar(cf + Vector3.new(0, 4, 0)) then
                    error("não consegui chegar até o NPC", 0)
                end
            else
                logNaoAchado(palavras)
            end
            task.wait(0.5)
            resultado = acao()
            task.wait(0.3)
            if achou and Cfg:Get("VoltarDepoisCompra") then viajar(origem) end
        end)
        retomar()
        if not ok then return false, tostring(err), achou end
        return true, resultado, achou
    end

    -- Diagnóstico: relatório completo (F9 + área de transferência + arquivo)
    function F.diagnosticoNpcs()
        task.spawn(function()
            local linhas = {}
            local function out(s)
                table.insert(linhas, s)
                registrarLog("NPC", s)
            end

            out("=== Diagnóstico de NPCs - Automata Hub v" .. VERSAO .. " ===")
            out("PlaceId=" .. tostring(game.PlaceId) .. " | StreamingEnabled=" .. tostring(Workspace.StreamingEnabled))
            pcall(function()
                out("StreamingMinRadius=" .. tostring(Workspace.StreamingMinRadius)
                    .. " | StreamingTargetRadius=" .. tostring(Workspace.StreamingTargetRadius))
            end)

            local function listarPasta(titulo, pasta)
                if not pasta then out(titulo .. ": NÃO existe") return end
                local nomes = {}
                for _, c in ipairs(pasta:GetChildren()) do
                    table.insert(nomes, c.Name .. " [" .. c.ClassName .. "]")
                end
                table.sort(nomes)
                out(string.format("%s: %d itens", titulo, #nomes))
                local limite = math.min(#nomes, 300)
                for i = 1, limite, 15 do
                    out("   " .. table.concat(nomes, ", ", i, math.min(i + 14, limite)))
                end
            end
            listarPasta("Workspace.NPCs", Workspace:FindFirstChild("NPCs"))
            listarPasta("ReplicatedStorage.NPCs", ReplicatedStorage:FindFirstChild("NPCs"))

            local modelos = candidatosNpc(true)
            local caminhos = {}
            for _, m in ipairs(modelos) do table.insert(caminhos, m:GetFullName()) end
            table.sort(caminhos)
            out("Modelos carregados agora (Workspace.NPCs + modelos com Humanoid, sem Enemies/Characters/Boats/jogadores): " .. #caminhos)
            for i = 1, math.min(#caminhos, 200) do out("   " .. caminhos[i]) end
            if #caminhos > 200 then out("   ... (+" .. (#caminhos - 200) .. " omitidos)") end

            -- termos: o que você digitou em "Procurar NPC por nome" OU todas as
            -- palavras-chave que o script usa hoje (estilos, vendedores, gacha)
            local termos, vistosTermo = {}, {}
            local function addTermo(t)
                t = trim(t)
                if t ~= "" and not vistosTermo[t] then
                    vistosTermo[t] = true
                    table.insert(termos, t)
                end
            end
            local digitado = trim(Cfg:Get("NpcBusca"))
            if digitado ~= "" then
                addTermo(digitado)
            else
                for _, e in ipairs(ESTILOS_LISTA) do for _, p in ipairs(e.npc) do addTermo(p) end end
                for _, v in ipairs(VENDEDORES) do for _, p in ipairs(v.npc) do addTermo(p) end end
                addTermo("cousin")
                addTermo("gacha")
            end

            out("Buscando por nome em Workspace e ReplicatedStorage (pode levar alguns segundos)...")
            local ok, achados, total = pcall(F.buscarPorNome, termos, 15)
            if not ok then
                out("ERRO na busca por nome: " .. tostring(achados))
            else
                out("Instâncias examinadas: " .. tostring(total))
                for _, t in ipairs(termos) do
                    local l = achados[t] or {}
                    if #l == 0 then
                        out(string.format("termo '%s': nenhuma instância com esse nome", t))
                    else
                        out(string.format("termo '%s': %d resultado(s)", t, #l))
                        for _, d in ipairs(l) do
                            out("   [" .. d.ClassName .. "] " .. d:GetFullName())
                        end
                    end
                end
            end
            out("=== fim do diagnóstico ===")

            local texto = table.concat(linhas, "\n")
            local copiado, salvo = false, false
            if setclipboard then copiado = pcall(setclipboard, texto) end
            if writefile then salvo = pcall(writefile, "automata_diagnostico.txt", texto) end
            notificar("Diagnóstico de NPCs", string.format("Pronto (%d linhas). Área de transferência: %s | Arquivo automata_diagnostico.txt: %s | F9: sim.",
                #linhas, copiado and "copiado" or "indisponível", salvo and "salvo" or "indisponível"))
        end)
    end

    -- Procurar um NPC pelo nome digitado e ir até ele
    function F.procurarNpcPorNome()
        task.spawn(function()
            local texto = trim(Cfg:Get("NpcBusca"))
            if texto == "" then notificar("NPC", "Digite o nome (ou parte do nome) do NPC primeiro.") return end
            pausar()
            local ok, npc = pcall(F.localizarNpc, { texto })
            local cf = ok and npc and pivotDe(npc)
            local nomeDestino = npc and npc.Name or nil
            if not cf then
                -- plano B: qualquer Model/Folder/BasePart com esse nome (mostra o caminho real)
                local ok2, achados = pcall(F.buscarPorNome, { texto }, 10)
                if ok2 and type(achados) == "table" then
                    local lista = achados[texto] or {}
                    local escolhido = nil
                    for _, d in ipairs(lista) do
                        if d:IsA("Model") then escolhido = d break end
                    end
                    escolhido = escolhido or lista[1]
                    if escolhido then
                        cf = pivotDe(escolhido)
                        nomeDestino = "[" .. escolhido.ClassName .. "] " .. escolhido:GetFullName()
                    end
                end
            end
            retomar()
            if cf then
                notificar("NPC", "Indo até " .. tostring(nomeDestino))
                teleportar(cf + Vector3.new(0, 4, 0))
            else
                logNaoAchado({ texto })
                notificar("NPC", "Não achei '" .. texto .. "'. Rode o Diagnóstico de NPCs: o relatório vai para o F9 e para a área de transferência.")
            end
        end)
    end

    -- Tudo que você possui: Tools (estilos/espadas) + inventário. Devolve (set, maestria)
    function F.possuidos()
        atualizarInventarioAsync()
        local set, mast = {}, {}
        for nome in pairs(invCache) do set[nome] = true end
        for _, pasta in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
            if pasta then
                for _, t in ipairs(pasta:GetChildren()) do
                    if t:IsA("Tool") then
                        set[t.Name] = true
                        local lv = t:FindFirstChild("Level")
                        if lv and type(lv.Value) == "number" then mast[t.Name] = lv.Value end
                    end
                end
            end
        end
        return set, mast
    end

    local function estiloPorNome(nome)
        for _, e in ipairs(ESTILOS_LISTA) do
            if e.nome == nome then return e end
        end
        return nil
    end

    function F.textoEstilos()
        local tenho, mast = F.possuidos()
        local beli, frag = dadosJogador()
        local linhas = {}
        for _, e in ipairs(ESTILOS_LISTA) do
            if tenho[e.nome] then
                table.insert(linhas, string.format("[TENHO] %s (maestria %s)", e.nome, mast[e.nome] and tostring(mast[e.nome]) or "?"))
            else
                local falta = {}
                for _, rq in ipairs(e.req or {}) do
                    local m = mast[rq[1]]
                    if (m or 0) < rq[2] then
                        table.insert(falta, string.format("%s %s/%d", rq[1], m and tostring(m) or "?", rq[2]))
                    end
                end
                if e.beli and beli < e.beli then table.insert(falta, "Beli " .. fmtNum(beli) .. "/" .. fmtNum(e.beli)) end
                if e.frag and frag < e.frag then table.insert(falta, "Frag " .. fmtNum(frag) .. "/" .. fmtNum(e.frag)) end
                if e.extra then table.insert(falta, "quest/itens: " .. e.extra) end
                local estado = (#falta == 0) and "PRONTO PARA COMPRAR" or ("falta: " .. table.concat(falta, ", "))
                table.insert(linhas, string.format("[FALTA] %s - %s", e.nome, estado))
            end
        end
        return table.concat(linhas, "\n") .. "\n(valores aproximados; quem decide é o jogo)"
    end

    function F.listaEstilosFaltando()
        local tenho = F.possuidos()
        local l = {}
        for _, e in ipairs(ESTILOS_LISTA) do
            if not tenho[e.nome] then table.insert(l, e.nome) end
        end
        if #l == 0 then return { "(você já tem todos)" } end
        return l
    end

    function F.listaEstilosTenho()
        local tenho = F.possuidos()
        local l = { "Combat" }
        for _, e in ipairs(ESTILOS_LISTA) do
            if tenho[e.nome] then table.insert(l, e.nome) end
        end
        return l
    end

    -- Compra (BLOQUEANTE): vai até o NPC ensinador, compra e confere nas Tools
    function F.comprarEstiloPorNome(nome)
        local e = estiloPorNome(nome)
        if not e then notificar("Estilos", "Escolha um estilo que falta primeiro.") return false end
        if F.possuidos()[e.nome] then notificar("Estilos", "Você já tem o " .. e.nome .. ".") return true end
        local palavras = e.npc
        local manual = trim(Cfg:Get("NpcManual"))
        if manual ~= "" then palavras = { manual } end   -- nome do NPC digitado por você
        local feito, r, achou = F.comNpc(palavras, function() return obterCommF():InvokeServer(e.remote) end)
        task.wait(1.5)
        if F.possuidos()[e.nome] then
            F.avisar("Estilo comprado!", e.nome .. " foi liberado no seu personagem.", 5763719)
            return true
        end
        local msg = "Não consegui comprar " .. e.nome .. ". Resposta do jogo: " .. tostring(r)
        if not achou then msg = msg .. ". NPC ensinador não encontrado: vá até ele e tente de novo" end
        notificar("Estilos", msg)
        registrarLog("Estilos", msg)
        return false
    end

    function F.comprarEstilo()
        local nome = Cfg:Get("EstiloSelecionado")
        task.spawn(F.comprarEstiloPorNome, nome)
    end

    -- Auto compra: só estilos sem quest "extra" cujos requisitos (maestria/Beli/Frag) já bateram
    do
        local ultima = {}
        loopToggle("AutoComprarEstilos", "Estilos", function()
            local tenho, mast = F.possuidos()
            local beli, frag = dadosJogador()
            for _, e in ipairs(ESTILOS_LISTA) do
                if not tenho[e.nome] and not e.extra and os.clock() - (ultima[e.nome] or -9999) > 600 then
                    local pronto = true
                    for _, rq in ipairs(e.req or {}) do
                        if (mast[rq[1]] or 0) < rq[2] then pronto = false end
                    end
                    if e.beli and beli < e.beli then pronto = false end
                    if e.frag and frag < e.frag then pronto = false end
                    if pronto then
                        ultima[e.nome] = os.clock()
                        F.comprarEstiloPorNome(e.nome)
                        return 5
                    end
                end
            end
            return 30
        end)
    end

    -- Espadas lendárias ------------------------------------------------------
    function F.textoEspadas()
        local tenho = F.possuidos()
        local linhas = {}
        for _, e in ipairs(ESPADAS_LENDARIAS) do
            table.insert(linhas, (tenho[e.nome] and "[TENHO] " or "[FALTA] ") .. e.nome)
        end
        return table.concat(linhas, "\n") .. "\nO Legendary Sword Dealer só vende quando está spawnado."
    end

    function F.comprarEspada(i)
        task.spawn(function()
            local e = ESPADAS_LENDARIAS[i]
            if not e then return end
            if F.possuidos()[e.nome] then notificar("Espadas", "Você já tem a " .. e.nome .. ".") return end
            if not F.acharNpc({ "legendary sword" }) then
                notificar("Espadas", "O Legendary Sword Dealer não está spawnado agora.")
                return
            end
            local feito, r = F.comNpc({ "legendary sword" }, function()
                return obterCommF():InvokeServer("LegendarySwordDealer", e.id)
            end)
            task.wait(1.5)
            if F.possuidos()[e.nome] then
                F.avisar("Espada comprada!", e.nome .. " foi comprada no Legendary Sword Dealer.", 5763719)
            else
                notificar("Espadas", "Não comprou a " .. e.nome .. ". Resposta do jogo: " .. tostring(r))
            end
        end)
    end

    -- Vendedores raros ---------------------------------------------------------
    function F.textoVendedores()
        local l = {}
        for _, v in ipairs(VENDEDORES) do
            local npc, dist = F.acharNpc(v.npc)
            if npc then
                table.insert(l, string.format("%s: SPAWNADO (a %.0f studs)", v.nome, dist or 0))
            else
                table.insert(l, v.nome .. ": não encontrado" .. (v.raro and " (não spawnou)" or ""))
            end
        end
        if Workspace.StreamingEnabled then
            table.insert(l, "(este mapa usa streaming: NPCs longe podem não estar carregados — use \"Ir até\" para procurar)")
        end
        return table.concat(l, "\n")
    end

    function F.irParaVendedor(chave)
        task.spawn(function()
            for _, v in ipairs(VENDEDORES) do
                if v.chave == chave then
                    pausar()
                    local ok, npc = pcall(F.localizarNpc, v.npc)
                    retomar()
                    local cf = ok and npc and pivotDe(npc)
                    if cf then
                        teleportar(cf + Vector3.new(0, 4, 0))
                    else
                        logNaoAchado(v.npc)
                        notificar("Vendedores", v.nome .. " não está spawnado (ou não foi encontrado). Veja o F9.")
                    end
                    return
                end
            end
        end)
    end

    task.spawn(function()
        local presente = {}
        while Estado.rodando do
            if Cfg:Get("VendedorNotifier") then
                for _, v in ipairs(VENDEDORES) do
                    if v.raro then
                        local ok, err = pcall(function()
                            local npc, dist = F.acharNpc(v.npc)
                            local existe = npc ~= nil
                            if existe and not presente[v.chave] then
                                F.avisar(v.nome .. " spawnou!", string.format("%s está no mapa (a %.0f studs de você).", v.nome, dist or 0), 3066993)
                                presente[v.chave] = true
                            elseif not existe and presente[v.chave] then
                                -- Com streaming, "não está carregado no cliente" NÃO significa
                                -- "sumiu do jogo" (acontece só de você se afastar). Só avisa
                                -- "sumiu" quando o mapa não usa streaming.
                                if not Workspace.StreamingEnabled then
                                    F.avisar(v.nome .. " sumiu", v.nome .. " não está mais no mapa.", 8421504)
                                    presente[v.chave] = false
                                end
                            end
                        end)
                        if not ok then registrarErro("Vendedor", err) end
                    end
                end
            else
                table.clear(presente)
            end
            task.wait(10)
        end
    end)
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

-- Descobre onde pousar: lança um raio de cima para baixo na posição (X, Z) do
-- destino e devolve um ponto 6 studs acima do 1º chão OU DA ÁGUA encontrado.
-- (Antes o raio ignorava a água e acertava o fundo do mar.)
function F.pontoSeguroAcima(pos, permitirSubmerso)
    local mapa = Workspace:FindFirstChild("Map")
    local plano = mapa and mapa:FindFirstChild("WaterBase-Plane")
    local nivelAgua = plano and (plano.Position.Y + plano.Size.Y / 2) or nil
    local root = meuRoot()

    local excluir = {}
    if LocalPlayer.Character then table.insert(excluir, LocalPlayer.Character) end
    local e = Workspace:FindFirstChild("Enemies")
    if e then table.insert(excluir, e) end
    local c = Workspace:FindFirstChild("Characters")
    if c then table.insert(excluir, c) end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = false            -- a superfície da água conta como "chão"
    pcall(function() params.RespectCanCollide = false end)

    -- começa bem acima de tudo: do marcador, do nível do mar e de onde você está
    local topo = math.max(pos.Y, nivelAgua or pos.Y, root and root.Position.Y or pos.Y) + 300
    local origem = Vector3.new(pos.X, topo, pos.Z)
    for _ = 1, 12 do
        params.FilterDescendantsInstances = excluir
        local r = Workspace:Raycast(origem, Vector3.new(0, -(topo + 3000), 0), params)
        if not r then break end
        local inst = r.Instance
        local ehAgua = inst:IsA("Terrain") and r.Material == Enum.Material.Water
        -- ignora zonas/barreiras invisíveis (a água do mapa não conta como invisível)
        if not ehAgua and inst.Transparency >= 0.95 and inst.Name ~= "WaterBase-Plane" then
            table.insert(excluir, inst)
        else
            local y = r.Position.Y
            -- ainda assim acertou o fundo (água não consultável): fica na superfície
            if nivelAgua and y < nivelAgua - 2 and not permitirSubmerso then y = nivelAgua end
            return CFrame.new(pos.X, y + 6, pos.Z)
        end
    end
    return nil
end

function F.irParaIlhaEvento(ev)
    local ilha = F.acharIlhaEvento(ev)
    local cf = pivotDe(ilha)
    if not cf then notificar("Evento", ev.titulo .. " não está no servidor agora.") return end
    local destino = F.pontoSeguroAcima(cf.Position, false) or (cf + Vector3.new(0, 120, 0))
    registrarLog("Teleport", string.format("%s: marcador Y=%.0f -> destino Y=%.0f", ev.titulo, cf.Position.Y, destino.Position.Y))
    teleportar(destino)
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
    local cf = pivotDe(ilha)
    if not cf then notificar("Teleport", "Escolha uma ilha primeiro.") return end
    local submerso = string.find(string.lower(tostring(nome)), "underwater", 1, true) ~= nil
    local destino = F.pontoSeguroAcima(cf.Position, submerso) or (cf + Vector3.new(0, 50, 0))
    registrarLog("Teleport", string.format("%s: marcador Y=%.0f -> destino Y=%.0f", tostring(nome), cf.Position.Y, destino.Position.Y))
    teleportar(destino)
end

function F.irParaNpcSelecionado()
    local pasta, nome = Workspace:FindFirstChild("NPCs"), Cfg:Get("NpcSelecionado")
    local npc = pasta and nome and pasta:FindFirstChild(nome)
    local cf = pivotDe(npc)
    if cf then teleportar(cf + Vector3.new(0, 4, 0)) else notificar("Teleport", "Escolha um NPC primeiro.") end
end

function F.irParaFrutaMaisProxima()
    local root = meuRoot()
    if not root then return end
    local melhor, menor, melhorFruta = nil, math.huge, nil
    for _, f in ipairs(F.frutasNoMapa()) do
        local p = F.parteDe(f)
        if p then
            local d = (p.Position - root.Position).Magnitude
            if d < menor then menor, melhor, melhorFruta = d, p, f end
        end
    end
    if melhor then
        task.spawn(function()
            local ok, err = pcall(function()
                -- só encosta se o tween chegou (evita teleporte direto de longe)
                local chegou = MovementService:Interpola(melhor.CFrame + Vector3.new(0, 3, 0), velCfg("VelTeleport", 250))
                if chegou then F.pegarFruta(melhorFruta, melhor) end
            end)
            if not ok then registrarErro("Teleport", err) end
        end)
    else notificar("Frutas", "Nenhuma fruta no mapa agora.") end
end

-- =========================================================================
-- EVENTOS TEMPORÁRIOS (Halloween e semelhantes): motor por palavras-chave
-- Os NOMES internos dos objetos do jogo NÃO são conhecidos: tudo aqui trabalha
-- com palavras-chave editáveis e com um escaneador que mostra o que existe.
-- =========================================================================
do
    -- Índice de objetos "interagíveis" (ProximityPrompt / ClickDetector / TouchInterest):
    -- uma varredura inicial (só quando algum recurso do evento é usado) + eventos.
    local indice = {}
    local montado = false
    local function interagivel(d)
        return d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d.ClassName == "TouchInterest"
    end
    local function montarIndice()
        if montado then return end
        montado = true
        ScriptJanitor:Adicionar(Workspace.DescendantAdded:Connect(function(d)
            if interagivel(d) then indice[d] = true end
        end))
        ScriptJanitor:Adicionar(Workspace.DescendantRemoving:Connect(function(d)
            if indice[d] then indice[d] = nil end
        end))
        for _, d in ipairs(Workspace:GetDescendants()) do
            if interagivel(d) then indice[d] = true end
        end
    end

    local function parteDoInteragivel(inst)
        local pai = inst.Parent
        if not pai then return nil end
        if pai:IsA("BasePart") then return pai end
        if pai:IsA("Attachment") and pai.Parent and pai.Parent:IsA("BasePart") then return pai.Parent end
        return F.parteDe(pai)
    end

    local function temHumanoid(parte)
        local m = parte:FindFirstAncestorOfClass("Model")
        return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
    end

    -- Nome do próprio objeto + até 3 ancestrais (+ textos do prompt) para casar com as palavras
    local function textosDe(inst)
        local l, n = {}, inst
        for _ = 1, 4 do
            if not n or n == Workspace or n == game then break end
            table.insert(l, normKw(n.Name))
            n = n.Parent
        end
        if inst:IsA("ProximityPrompt") then
            table.insert(l, normKw(inst.ActionText))
            table.insert(l, normKw(inst.ObjectText))
        end
        return l
    end

    local cacheCasa = {}
    local function casaInter(inst, chaveKw)
        local lista = kwDe(chaveKw)
        local sig = table.concat(lista, ",")
        cacheCasa[chaveKw] = cacheCasa[chaveKw] or setmetatable({}, { __mode = "k" })
        local c = cacheCasa[chaveKw][inst]
        if c and c.sig == sig then return c.kw or nil end
        local kw = nil
        for _, t in ipairs(textosDe(inst)) do
            for _, k in ipairs(lista) do
                if string.find(t, k, 1, true) then kw = k break end
            end
            if kw then break end
        end
        cacheCasa[chaveKw][inst] = { sig = sig, kw = kw or false }
        return kw
    end

    -- Interagíveis cujo nome (ou de um ancestral próximo) contém alguma palavra da lista
    local function candidatos(chaveKw, raio, centro)
        montarIndice()
        local root = meuRoot()
        local ref = centro or (root and root.Position)
        if not ref then return {} end
        local lista = {}
        for inst in pairs(indice) do
            if inst.Parent and not (inst:IsA("ProximityPrompt") and not inst.Enabled) then
                local kw = casaInter(inst, chaveKw)
                if kw and (inst.ClassName ~= "TouchInterest" or Cfg:Get("EventoToque")) then
                    local parte = parteDoInteragivel(inst)
                    if parte and not temHumanoid(parte) then
                        local d = (parte.Position - ref).Magnitude
                        if d <= raio then
                            table.insert(lista, { inst = inst, parte = parte, dist = d, kw = kw })
                        end
                    end
                end
            end
        end
        table.sort(lista, function(a, b) return a.dist < b.dist end)
        return lista
    end

    local function interagir(c)
        local inst, parte = c.inst, c.parte
        if inst:IsA("ProximityPrompt") then
            if not fireproximityprompt then return false, "fireproximityprompt indisponível neste executor" end
            fireproximityprompt(inst)
        elseif inst:IsA("ClickDetector") then
            if not fireclickdetector then return false, "fireclickdetector indisponível neste executor" end
            fireclickdetector(inst)
        else
            local root = meuRoot()
            if not (firetouchinterest and root) then return false, "firetouchinterest indisponível neste executor" end
            firetouchinterest(root, parte, 0)
            firetouchinterest(root, parte, 1)
        end
        return true
    end

    local visitados = setmetatable({}, { __mode = "k" })
    -- Vai até o interagível mais próximo ainda não visitado (dentro do raio) e interage.
    -- Devolve o tempo de espera até a próxima volta.
    local function ciclo(chaveKw, cooldown, ativoFn)
        local raio = tonumber(Cfg:Get("EventoRaio")) or 1500
        local lista = candidatos(chaveKw, raio)
        local agora = os.clock()
        for _, c in ipairs(lista) do
            if not ativoFn() then return 1 end
            local usado = visitados[c.inst]
            if not usado or agora - usado > cooldown then
                local chegou = MovementService:Interpola(c.parte.CFrame + Vector3.new(0, 3, 0),
                    velCfg("VelColeta", 150), ativoFn)
                if chegou and ativoFn() then
                    local ok, res, motivo = pcall(interagir, c)
                    visitados[c.inst] = os.clock()
                    if ok and res then
                        registrarLog("Evento", string.format("Interagiu: [%s] %s (palavra '%s')",
                            c.inst.ClassName, c.inst:GetFullName(), c.kw))
                    else
                        registrarLog("Evento", "Falha ao interagir com " .. c.inst:GetFullName()
                            .. ": " .. tostring(ok and motivo or res))
                    end
                else
                    -- não chegou (ou outro movimento estava em curso): tenta de novo em ~5s
                    visitados[c.inst] = os.clock() - cooldown + 5
                end
                return 0.3
            end
        end
        return 1.5
    end

    loopToggle("EventoColetar", "EventoColeta", function()
        local function ativo() return Cfg:Get("EventoColetar") and not Estado.pausa end
        if not ativo() then return 1 end
        return ciclo("EventoColetaveis", 20, ativo)
    end)

    loopToggle("EventoPortasOn", "EventoPortas", function()
        local function ativo()
            return Cfg:Get("EventoPortasOn") and not Estado.pausa
                and (not Cfg:Get("EventoSoHarvest") or F.harvestAtiva())
        end
        if not ativo() then return 2 end
        return ciclo("EventoPortas", 120, ativo)
    end)

    -- ---- Quebrar objetos (abóboras): vai até o objeto e ATACA com a arma/estilo ----
    -- Segundo os guias, as abóboras são quebradas atacando (não por prompt/clique).
    -- Aqui NÃO se sabe como elas são representadas no jogo: o script procura
    -- Model/BasePart cujo nome contém as palavras, fora de Enemies/Characters e sem Humanoid.
    local quebrar = { indice = {}, sig = nil, montando = false, ouvinte = nil, total = 0 }

    local function ehExcluido(inst)
        local e = Workspace:FindFirstChild("Enemies")
        local c = Workspace:FindFirstChild("Characters")
        if (e and inst:IsDescendantOf(e)) or (c and inst:IsDescendantOf(c)) then return true end
        local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
        return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
    end

    local function casaQuebrar(inst)
        if not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
        local inc = kwDe("EventoQuebrar")
        if not casaKw(inst.Name, inc) then return false end
        local exc = kwDe("EventoQuebrarExcluir")
        if #exc > 0 and casaKw(inst.Name, exc) then return false end
        -- peça solta dentro de um Model que já casa: só o Model conta
        if inst:IsA("BasePart") then
            local pai = inst.Parent
            if pai and pai ~= Workspace and pai:IsA("Model") and casaKw(pai.Name, inc) then return false end
        end
        return not ehExcluido(inst)
    end

    -- Varredura completa só quando as palavras mudam (em lotes) + eventos para o que nascer depois
    local function reindexar()
        local sig = table.concat(kwDe("EventoQuebrar"), ",") .. "|" .. table.concat(kwDe("EventoQuebrarExcluir"), ",")
        if quebrar.sig == sig or quebrar.montando then return end
        quebrar.montando = true
        quebrar.sig = sig
        quebrar.indice = {}
        if not quebrar.ouvinte then
            quebrar.ouvinte = ScriptJanitor:Adicionar(Workspace.DescendantAdded:Connect(function(d)
                if Cfg:Get("EventoQuebrarOn") and casaQuebrar(d) then quebrar.indice[d] = true end
            end))
        end
        local n = 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            n = n + 1
            if n % 3000 == 0 then task.wait() end
            if casaQuebrar(d) then quebrar.indice[d] = true end
        end
        quebrar.montando = false
    end

    local quebradosEm = setmetatable({}, { __mode = "k" })   -- cooldown por objeto

    local function cicloQuebrar()
        if Estado.pausa then return 1 end
        reindexar()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not (root and hum and hum.Health > 0 and backpack) then return 1 end

        local raio = tonumber(Cfg:Get("EventoRaio")) or 1500
        local melhor, menor, melhorCf = nil, raio, nil
        for inst in pairs(quebrar.indice) do
            if not inst.Parent then
                quebrar.indice[inst] = nil
            else
                local usado = quebradosEm[inst]
                if not usado or os.clock() - usado > 0 then
                    local cf = pivotDe(inst)
                    if cf then
                        local d = (cf.Position - root.Position).Magnitude
                        if d < menor then menor, melhor, melhorCf = d, inst, cf end
                    end
                end
            end
        end
        if not melhor then return 1.5 end

        local ativo = function() return Cfg:Get("EventoQuebrarOn") and not Estado.pausa end
        local alvoPos = melhorCf.Position
        local caminho = melhor:GetFullName()
        -- ponto de ataque: 4 studs ao lado do objeto (do lado em que você já está), olhando para ele
        local horiz = Vector3.new(root.Position.X - alvoPos.X, 0, root.Position.Z - alvoPos.Z)
        local dir = horiz.Magnitude > 0.1 and horiz.Unit or Vector3.new(0, 0, 1)
        local ponto = alvoPos + dir * 4 + Vector3.new(0, 2, 0)
        local olhar = Vector3.new(alvoPos.X, ponto.Y, alvoPos.Z)

        local chegou = MovementService:Interpola(CFrame.lookAt(ponto, olhar), velCfg("VelColeta", 150), ativo)
        if not (chegou and ativo()) then
            quebradosEm[melhor] = os.clock() + 5      -- tenta de novo em ~5s
            return 0.5
        end

        Cfg:Set("EmMovimento", true)
        local inicio, quebrou = os.clock(), false
        while Estado.rodando and ativo() and os.clock() - inicio < 6 do
            if hum.Health <= 0 or not root.Parent then break end
            if not melhor.Parent then quebrou = true break end
            root.CFrame = CFrame.lookAt(ponto, olhar)
            root.AssemblyLinearVelocity = Vector3.zero
            CombatManager:Clicar(char, hum, backpack, Cfg:Get("Weapon"))
            task.wait()
        end
        Cfg:Set("EmMovimento", false)
        if not melhor.Parent then quebrou = true end
        if quebrou then
            quebrar.total = quebrar.total + 1
            registrarLog("Evento", string.format("Quebrou (#%d): %s", quebrar.total, caminho))
        else
            -- não saiu do mapa em 6s: não insiste por 10 min (pode ser enfeite, e não alvo)
            quebradosEm[melhor] = os.clock() + 600
            registrarLog("Evento", "NÃO quebrou em 6s (ignorando por 10 min): " .. caminho)
        end
        return 0.2
    end

    loopToggle("EventoQuebrarOn", "EventoQuebrar", cicloQuebrar)

    -- Aviso de início da Harvest Moon (primeiros 10 min de cada hora, relógio do servidor)
    task.spawn(function()
        local ativaAntes = nil
        while Estado.rodando do
            if Cfg:Get("EventoAvisoHarvest") then
                local ativa = F.harvestAtiva()
                if ativaAntes == false and ativa then
                    F.avisar("Harvest Moon!", "Começou a Harvest Moon (primeiros 10 min da hora, UTC). Segundo os guias, é quando as portas funcionam.", 16753920)
                end
                ativaAntes = ativa
            else
                ativaAntes = nil
            end
            task.wait(2)
        end
    end)

    -- Monitor de spawns: registra no F9 (e avisa, para mobs) tudo o que aparecer com nome da lista
    local conMonitor, contLog, ultimoAviso = nil, 0, {}
    function F.eventoMonitor(ligado)
        if conMonitor then conMonitor:Disconnect() conMonitor = nil end
        if not ligado then return end
        conMonitor = Workspace.DescendantAdded:Connect(function(d)
            if not (d:IsA("Model") or d:IsA("BasePart") or d:IsA("Tool") or d:IsA("Folder")) then return end
            if contLog >= 300 then return end
            local cat, kw = "mob", casaKw(d.Name, kwDe("EventoMobs"))
            if not kw then cat, kw = "item", casaKw(d.Name, kwDe("EventoColetaveis")) end
            if not kw then cat, kw = "porta", casaKw(d.Name, kwDe("EventoPortas")) end
            if not kw then cat, kw = "npc", casaKw(d.Name, kwDe("EventoNpcs")) end
            if not kw then return end
            contLog = contLog + 1
            registrarLog("Evento", string.format("[spawn %s] [%s] %s", cat, d.ClassName, d:GetFullName()))
            if cat == "mob" and d:IsA("Model") and os.clock() - (ultimoAviso[d.Name] or -999) > 30 then
                ultimoAviso[d.Name] = os.clock()
                F.avisar("Evento: " .. d.Name .. " apareceu", "[" .. d.ClassName .. "] " .. d:GetFullName(), 15844367)
            end
        end)
    end
    ScriptJanitor:Adicionar({ Destroy = function()
        if conMonitor then conMonitor:Disconnect() conMonitor = nil end
    end }, "Destroy")

    function F.aplicarPresetEvento(nome)
        local p = PRESETS_EVENTO[nome]
        if not p then return end   -- "Personalizado": mantém o que você digitou
        Cfg:Set("EventoMobs", p.mobs)
        Cfg:Set("EventoColetaveis", p.coletaveis)
        Cfg:Set("EventoPortas", p.portas)
        Cfg:Set("EventoNpcs", p.npcs)
        Cfg:Set("EventoQuebrar", p.quebrar)
        Cfg:Set("EventoQuebrarExcluir", p.excluir)
    end

    -- NPCs do evento (texto original digitado, para mostrar na lista)
    function F.eventoNpcsLista()
        local l = {}
        for pedaco in string.gmatch(tostring(Cfg:Get("EventoNpcs") or ""), "[^,;\n]+") do
            local t = trim(pedaco)
            if t ~= "" then table.insert(l, t) end
        end
        return #l > 0 and l or { "(nenhum)" }
    end

    function F.irParaNpcEvento()
        task.spawn(function()
            local nome = trim(Cfg:Get("EventoNpcSel"))
            if nome == "" or nome == "(nenhum)" then notificar("Evento", "Informe os NPCs do evento primeiro.") return end
            pausar()
            local ok, npc = pcall(F.localizarNpc, { nome })
            retomar()
            local cf = ok and npc and pivotDe(npc)
            if cf then
                notificar("Evento", "Indo até " .. npc.Name)
                teleportar(cf + Vector3.new(0, 4, 0))
            else
                notificar("Evento", "Não achei '" .. nome .. "'. Rode o \"Escanear evento\" (resultado no F9).")
            end
        end)
    end

    -- Relatório completo: o que existe no jogo com os nomes das suas palavras-chave
    -- e quais interagíveis existem perto de você. Yield (varredura em lotes).
    function F.escanearEvento()
        task.spawn(function()
            local linhas = {}
            local function out(s)
                table.insert(linhas, s)
                registrarLog("Evento", s)
            end
            out("=== Escaneamento de evento - Automata Hub v" .. VERSAO .. " ===")
            out(string.format("Horário do servidor (UTC): %s | Harvest Moon (min 0-10): %s",
                os.date("!%Y-%m-%d %H:%M:%S", math.floor(F.agoraUtc())), tostring(F.harvestAtiva())))
            out("PlaceId=" .. tostring(game.PlaceId) .. " | StreamingEnabled=" .. tostring(Workspace.StreamingEnabled))
            local root = meuRoot()
            if root then
                out(string.format("Sua posição: %.0f, %.0f, %.0f", root.Position.X, root.Position.Y, root.Position.Z))
            end

            local grupos = {
                { "mobs", "EventoMobs" }, { "itens", "EventoColetaveis" },
                { "portas", "EventoPortas" }, { "npcs", "EventoNpcs" },
                { "quebrar", "EventoQuebrar" },
            }
            local achados, listas = {}, {}
            for _, g in ipairs(grupos) do
                achados[g[1]] = {}
                listas[g[1]] = kwDe(g[2])
                out(string.format("Palavras (%s): %s", g[1], #listas[g[1]] > 0 and table.concat(listas[g[1]], ", ") or "(nenhuma)"))
            end

            local contador = 0
            for _, raiz in ipairs({ Workspace, ReplicatedStorage }) do
                for _, d in ipairs(raiz:GetDescendants()) do
                    contador = contador + 1
                    if contador % 3000 == 0 then task.wait() end
                    if d:IsA("Model") or d:IsA("BasePart") or d:IsA("Folder") or d:IsA("Tool")
                        or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
                        local n = normKw(d.Name)
                        if n ~= "" then
                            for _, g in ipairs(grupos) do
                                local l = achados[g[1]]
                                if #l < 30 then
                                    for _, k in ipairs(listas[g[1]]) do
                                        if string.find(n, k, 1, true) then table.insert(l, { d, k }) break end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            out("Instâncias examinadas (Workspace + ReplicatedStorage): " .. contador)

            for _, g in ipairs(grupos) do
                local l = achados[g[1]]
                if #l == 0 then
                    out(string.format("[%s] nenhuma instância com essas palavras no nome", g[1]))
                else
                    out(string.format("[%s] %d resultado(s)%s", g[1], #l, #l >= 30 and " (limitado a 30)" or ""))
                    for _, par in ipairs(l) do
                        local d, k = par[1], par[2]
                        local extra = {}
                        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then table.insert(extra, "Humanoid") end
                        pcall(function()
                            if d:FindFirstChildWhichIsA("ProximityPrompt", true) then table.insert(extra, "tem ProximityPrompt") end
                            if d:FindFirstChildWhichIsA("ClickDetector", true) then table.insert(extra, "tem ClickDetector") end
                        end)
                        local cf = pivotDe(d)
                        out(string.format("   [%s] %s | '%s' | %s%s", d.ClassName, d:GetFullName(), k,
                            cf and string.format("pos %.0f,%.0f,%.0f", cf.Position.X, cf.Position.Y, cf.Position.Z) or "sem posição",
                            #extra > 0 and (" | " .. table.concat(extra, ", ")) or ""))
                    end
                end
            end

            -- o que o farm usaria agora (interagíveis que casam com as palavras)
            for _, par in ipairs({ { "itens", "EventoColetaveis" }, { "portas", "EventoPortas" } }) do
                local c = candidatos(par[2], 1e9)
                out(string.format("Interagíveis que o auto-coletar usaria (%s): %d", par[1], #c))
                for i = 1, math.min(#c, 15) do
                    out(string.format("   %.0f studs | [%s] %s | '%s'", c[i].dist, c[i].inst.ClassName, c[i].inst:GetFullName(), c[i].kw))
                end
            end

            -- tudo que é interagível num raio de 120 studs de você (sem filtro de palavras):
            -- fique ao lado de uma porta / abóbora e rode o escaneamento para descobrir o nome real
            if root then
                montarIndice()
                local perto = {}
                for inst in pairs(indice) do
                    if inst.Parent then
                        local parte = parteDoInteragivel(inst)
                        if parte then
                            local d = (parte.Position - root.Position).Magnitude
                            if d <= 120 then table.insert(perto, { inst, d }) end
                        end
                    end
                end
                table.sort(perto, function(a, b) return a[2] < b[2] end)
                out("Interagíveis (ProximityPrompt/ClickDetector/TouchInterest) a até 120 studs de você: " .. #perto)
                for i = 1, math.min(#perto, 40) do
                    local inst = perto[i][1]
                    local texto = ""
                    if inst:IsA("ProximityPrompt") then
                        texto = string.format(" | ActionText='%s' ObjectText='%s' Enabled=%s",
                            inst.ActionText, inst.ObjectText, tostring(inst.Enabled))
                    end
                    out(string.format("   %.0f studs | [%s] %s%s", perto[i][2], inst.ClassName, inst:GetFullName(), texto))
                end
            end

            out("=== fim do escaneamento ===")
            local texto = table.concat(linhas, "\n")
            local copiado, salvo = false, false
            if setclipboard then copiado = pcall(setclipboard, texto) end
            if writefile then salvo = pcall(writefile, "automata_diagnostico_evento.txt", texto) end
            notificar("Escaneamento de evento", string.format("Pronto (%d linhas). Área de transferência: %s | Arquivo: %s | F9: sim.",
                #linhas, copiado and "copiado" or "indisponível", salvo and "salvo" or "indisponível"))
        end)
    end
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
                        presente[ev.chave] = true
                    elseif not existe and presente[ev.chave] then
                        -- com streaming, "não carregada no cliente" != "sumiu do servidor"
                        if not Workspace.StreamingEnabled then
                            F.avisar(ev.titulo .. " sumiu", "A " .. ev.titulo .. " não está mais neste servidor.", 8421504)
                            presente[ev.chave] = false
                        end
                    end
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

    local ultimaSegura, tSegura, fimMov = nil, 0, 0

    -- Sobe aos poucos até sair de dentro do cenário; se não achar saída,
    -- volta para o último ponto em que o personagem estava livre.
    local function liberar(char)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _ = 1, 25 do
            if not personagemPreso(char) then return end
            root.CFrame = root.CFrame + Vector3.new(0, 3, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            RunService.Stepped:Wait()
            pcall(frame, char, true)
        end
        -- só volta ao último ponto livre se ele for PERTO (antes puxava de volta
        -- para onde você estava antes de um teleporte longo)
        if ultimaSegura and (ultimaSegura.Position - root.Position).Magnitude < 150 then
            root.CFrame = ultimaSegura
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end

    while Estado.rodando do
        local char = LocalPlayer.Character
        local auto = Cfg:Get("EmMovimento")
        if auto then fimMov = os.clock() end
        if (auto or Cfg:Get("NoClipManual")) and char then
            pcall(frame, char, auto)
        elseif next(originais) then
            if char and os.clock() - fimMov < 0.3 then
                pcall(frame, char, true)            -- folga de 0.3s após o movimento
            else
                if char then pcall(liberar, char) end
                restaurar()
            end
        elseif char and os.clock() - tSegura > 0.5 then
            tSegura = os.clock()
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and not personagemPreso(char) then ultimaSegura = root.CFrame end
        end
        RunService.Stepped:Wait()
    end
end)

-- =========================================================================
-- CHEST HOP
-- =========================================================================
local visitados = setmetatable({}, { __mode = "k" })
local function chestAtivo() return Cfg:Get("ChestHop") and not Estado.pausa end

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
            local chegou = MovementService:Interpola(obj.CFrame + Vector3.new(0, 3, 0), velCfg("VelColeta", 150), chestAtivo)
            if chegou then visitados[obj] = os.clock() end
            task.wait(0.2)
        end
    end
    return #lista
end

task.spawn(function()
    local hopsSemEfeito = 0
    while Estado.rodando do
        if chestAtivo() then
            local ok, res = pcall(cicloBaus)
            if not ok then registrarErro("ChestHop", res)
            elseif res == 0 and Cfg:Get("ChestHopServer") then
                F.serverHop()
                task.wait(30)
                -- se o teleporte tivesse funcionado, o jogo já teria trocado de servidor
                hopsSemEfeito = hopsSemEfeito + 1
                if hopsSemEfeito >= 2 then
                    hopsSemEfeito = 0
                    Cfg:Set("ChestHopServer", false)
                    notificar("Chest Hop", "Desliguei a troca automática de servidor: 2 tentativas seguidas sem trocar de servidor. Veja o F9.")
                end
            end
        end
        task.wait(1)
    end
end)

-- =========================================================================
-- ANTI-AFK E REJOIN AUTOMÁTICO
-- =========================================================================
local AntiAfk = { idled = 0, ultimoIdled = nil, backup = 0, ultimoBackup = nil }

local function cutucarAfk()
    if not VirtualUser then error("VirtualUser indisponível neste executor", 0) end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end

if not VirtualUser then
    registrarLog("AntiAFK", "VirtualUser indisponível: o Anti-AFK não vai funcionar neste executor")
end

-- Camada 1: reage ao evento Idled do jogador
ScriptJanitor:Adicionar(LocalPlayer.Idled:Connect(function()
    AntiAfk.idled = AntiAfk.idled + 1
    AntiAfk.ultimoIdled = os.clock()
    registrarLog("AntiAFK", "Evento Idled recebido (#" .. tostring(AntiAfk.idled) .. ")")
    if Cfg:Get("AntiAFK") then
        local ok, err = pcall(cutucarAfk)
        if not ok then registrarErro("AntiAFK", err) end
    end
end))

-- Camada 2: não depende do evento Idled; repete o mesmo toque a cada 50s.
task.spawn(function()
    while Estado.rodando do
        task.wait(50)
        if Cfg:Get("AntiAFK") then
            local ok, err = pcall(cutucarAfk)
            if ok then
                AntiAfk.backup = AntiAfk.backup + 1
                AntiAfk.ultimoBackup = os.clock()
            else
                registrarErro("AntiAFK", err)
            end
        end
    end
end)

-- Texto de todos os TextLabel do prompt (para o log: mostra a mensagem real)
local function textoDoPrompt(prompt)
    local partes = {}
    pcall(function()
        for _, d in ipairs(prompt:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then table.insert(partes, d.Text) end
        end
    end)
    return table.concat(partes, " | ")
end

-- Código do erro mostrado pelo Roblox (Enum.ConnectionError). Devolve (valor numérico, nome)
local function codigoDeErro()
    if not GuiService then return nil, nil end
    local ok, cod = pcall(function() return GuiService:GetErrorCode() end)
    if not ok or cod == nil then return nil, nil end
    local valor = nil
    pcall(function() valor = cod.Value end)
    return valor, tostring(cod)
end

local RejoinAuto = { tentativas = {} }   -- os.clock() de cada tentativa automática

task.spawn(function()
    local ok = pcall(function()
        local gui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = gui and gui:WaitForChild("promptOverlay", 10)
        if not overlay then return end
        ScriptJanitor:Adicionar(overlay.ChildAdded:Connect(function(c)
            if c.Name ~= "ErrorPrompt" then return end
            task.wait(1)   -- dá tempo para o texto e o código de erro ficarem prontos
            local valor, nomeCod = codigoDeErro()
            local textoPrompt = textoDoPrompt(c)
            registrarLog("Rejoin", string.format("ErrorPrompt: código=%s (%s) | texto: %s",
                tostring(valor), tostring(nomeCod), textoPrompt))
            local eTeleporte = (valor ~= nil and valor >= 768 and valor <= 775)
                or (os.clock() - Hop.ultimaFalha < 8)
            -- avisa SEMPRE (tela + Discord, se o webhook estiver ativo)
            F.avisar(eTeleporte and "Falha de teleporte" or "Desconectado do jogo",
                string.format("Código %s (%s). %s", tostring(valor), tostring(nomeCod), textoPrompt), 15158332)
            if not Cfg:Get("AutoRejoin") then return end

            -- Falha de teleporte (768-775) ou teleporte recusado há poucos segundos:
            -- você continua no jogo; "reentrar" repetiria o teleporte que acabou de falhar.
            if eTeleporte then
                registrarLog("Rejoin", "Prompt de falha de teleporte: Auto Rejoin NÃO acionado.")
                return
            end

            -- no máximo 3 tentativas automáticas em 10 minutos
            local agora, recentes = os.clock(), {}
            for _, t in ipairs(RejoinAuto.tentativas) do
                if agora - t < 600 then table.insert(recentes, t) end
            end
            RejoinAuto.tentativas = recentes
            if #recentes >= 3 then
                registrarLog("Rejoin", "Limite de 3 tentativas em 10 min atingido: não vou tentar de novo.")
                notificar("Auto Rejoin", "3 tentativas em 10 min sem sucesso: parei de tentar. Veja o F9.")
                return
            end
            table.insert(RejoinAuto.tentativas, agora)
            F.reentrar() -- já ignora se houver teleporte em andamento
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

-- Fim da listagem oficial do evento Halloween 2026 na Roblox: 15/11/2026 01:00 UTC
-- (duas fontes de guias concordam; o jogo não mostra data própria)
local FIM_HALLOWEEN_UTC = 1794704400
local function infoEvento()
    local agora = F.agoraUtc()
    local resto = FIM_HALLOWEEN_UTC - agora
    local fim
    if resto > 0 then
        fim = string.format("Listagem oficial do Halloween 2026 termina em %dd %02dh %02dmin",
            math.floor(resto / 86400), math.floor((resto % 86400) / 3600), math.floor((resto % 3600) / 60))
    else
        fim = "A listagem oficial do Halloween 2026 (15/11/2026 01:00 UTC) já terminou"
    end
    local seg = agora % 3600
    local lua = seg < 600
        and string.format("Harvest Moon ATIVA (mais %d min)", math.ceil((600 - seg) / 60))
        or string.format("Próxima Harvest Moon em %d min", math.ceil((3600 - seg) / 60))
    return fim .. "\n" .. lua .. "\nDatas e mecânicas vêm de guias de terceiros (checados em 01/11/2026); o jogo não as confirma."
end

local CONTROLES = {
    -- MAIN
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Level", chave = "AutoFarm" },
    { aba = "Main", tipo = "toggle", nome = "Travar a missão até concluir (Auto Farm Level)", chave = "QuestTravar" },
    { aba = "Main", tipo = "dropdown", nome = "Select Weapon", chave = "Weapon", opcoes = ARMAS },
    { aba = "Main", tipo = "toggle", nome = "Auto Farm Nearest", chave = "AutoFarmNearest" },
    { aba = "Main", tipo = "toggle", nome = "Fast Attack", chave = "FastAttack" },
    { aba = "Main", tipo = "slider", nome = "Intervalo entre golpes (ms) - normal", chave = "IntervaloNormalMs", min = 0, max = 500, passo = 10 },
    { aba = "Main", tipo = "slider", nome = "Intervalo entre golpes (ms) - Fast Attack", chave = "IntervaloFastMs", min = 0, max = 300, passo = 5 },
    { aba = "Main", tipo = "botao", nome = "Diagnóstico de ataque (F9 + área de transferência)", acao = F.diagnosticoCombate },
    { aba = "Main", tipo = "info", texto = "Cada golpe só pode sair uma vez por quadro do jogo, então intervalos menores que ~1 quadro (cerca de 17 ms a 60 FPS) não aceleram mais nada. Ligue o Debug Screen (aba Sistema) para ver Golpes/s enviados e Dano/s observado no alvo." },
    { aba = "Main", tipo = "secao", nome = "Velocidade do tween (studs/s)" },
    { aba = "Main", tipo = "slider", nome = "Teleporte / viagens", chave = "VelTeleport", min = 50, max = 1000, passo = 25 },
    { aba = "Main", tipo = "slider", nome = "Farm (aproximar do alvo / ir ao spawn)", chave = "VelFarm", min = 30, max = 400, passo = 5 },
    { aba = "Main", tipo = "slider", nome = "Coleta (frutas / baús)", chave = "VelColeta", min = 50, max = 600, passo = 10 },
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
    { aba = "Eventos", tipo = "secao", nome = "Halloween e eventos temporários" },
    { aba = "Eventos", tipo = "info", texto = infoEvento },
    { aba = "Eventos", tipo = "dropdown", nome = "Preset de palavras", chave = "EventoPreset", opcoes = OPCOES_PRESET_EVENTO, aoMudar = F.aplicarPresetEvento },
    { aba = "Eventos", tipo = "input", nome = "Mobs / bosses do evento (palavras, separe por vírgula)", chave = "EventoMobs", placeholder = "ex: werewolf, hellrider" },
    { aba = "Eventos", tipo = "input", nome = "Itens para coletar (palavras)", chave = "EventoColetaveis", placeholder = "ex: pumpkin" },
    { aba = "Eventos", tipo = "input", nome = "Portas / interações da Harvest Moon (palavras)", chave = "EventoPortas", placeholder = "ex: door" },
    { aba = "Eventos", tipo = "input", nome = "NPCs do evento (palavras)", chave = "EventoNpcs", placeholder = "ex: zioles, witch" },
    { aba = "Eventos", tipo = "toggle", nome = "Auto Farm mobs / bosses do evento", chave = "EventoFarmMobs" },
    { aba = "Eventos", tipo = "toggle", nome = "Auto coletar itens do evento", chave = "EventoColetar" },
    { aba = "Eventos", tipo = "toggle", nome = "Auto interagir com portas", chave = "EventoPortasOn" },
    { aba = "Eventos", tipo = "input", nome = "Objetos para QUEBRAR atacando - abóboras (palavras)", chave = "EventoQuebrar", placeholder = "ex: pumpkin, jack o lantern" },
    { aba = "Eventos", tipo = "input", nome = "NÃO quebrar (palavras)", chave = "EventoQuebrarExcluir", placeholder = "ex: gray, grey" },
    { aba = "Eventos", tipo = "toggle", nome = "Auto quebrar abóboras (ataca com a arma selecionada)", chave = "EventoQuebrarOn" },
    { aba = "Eventos", tipo = "info", texto = "Quebrar: vai até cada objeto com esse nome (Model/Peça fora de Enemies, sem Humanoid), olha para ele e ataca por até 6 s com a arma da aba Main. O F9 registra \"Quebrou\" ou \"NÃO quebrou\"; o que não quebra é ignorado por 10 min (pode ser enfeite). Os objetos de cada palavra aparecem no Escanear evento." },
    { aba = "Eventos", tipo = "toggle", nome = "Portas só na Harvest Moon (min 0-10 de cada hora, UTC)", chave = "EventoSoHarvest" },
    { aba = "Eventos", tipo = "toggle", nome = "Incluir itens por toque (sem prompt/clique)", chave = "EventoToque" },
    { aba = "Eventos", tipo = "slider", nome = "Raio de busca (studs)", chave = "EventoRaio", min = 100, max = 6000, passo = 100 },
    { aba = "Eventos", tipo = "toggle", nome = "Avisar quando a Harvest Moon começar", chave = "EventoAvisoHarvest" },
    { aba = "Eventos", tipo = "toggle", nome = "Monitorar spawns do evento (F9 + aviso para mobs)", chave = "EventoMonitor", aoMudar = F.eventoMonitor },
    { aba = "Eventos", tipo = "dropdown", nome = "NPC do evento", chave = "EventoNpcSel", opcoes = F.eventoNpcsLista },
    { aba = "Eventos", tipo = "botao", nome = "Ir até o NPC do evento", acao = F.irParaNpcEvento },
    { aba = "Eventos", tipo = "botao", nome = "Escanear evento (F9 + área de transferência)", acao = F.escanearEvento },
    { aba = "Eventos", tipo = "info", texto = "Como usar: os nomes padrão vêm de guias e NÃO foram verificados no jogo. Fique ao lado de uma porta ou abóbora do evento e rode \"Escanear evento\": ele lista o nome real e os interagíveis a 120 studs de você. Ajuste as palavras acima. O farm de mobs só enxerga o que estiver em Workspace.Enemies. As ações de movimento são uma por vez: evite ligar o coletar e o Auto Farm ao mesmo tempo." },
    { aba = "Eventos", tipo = "secao", nome = "Ilhas de evento, lua e baús" },
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

    -- PROGRESSÃO
    { aba = "Progressão", tipo = "secao", nome = "Estilos de luta" },
    { aba = "Progressão", tipo = "info", texto = F.textoEstilos },
    { aba = "Progressão", tipo = "dropdown", nome = "Estilo que falta", chave = "EstiloSelecionado", opcoes = F.listaEstilosFaltando },
    { aba = "Progressão", tipo = "botao", nome = "Comprar estilo selecionado (vai até o NPC)", acao = F.comprarEstilo },
    { aba = "Progressão", tipo = "toggle", nome = "Comprar sozinho os estilos já liberados", chave = "AutoComprarEstilos" },
    { aba = "Progressão", tipo = "toggle", nome = "Voltar ao ponto de origem depois de comprar", chave = "VoltarDepoisCompra" },
    { aba = "Progressão", tipo = "secao", nome = "Treinar maestria" },
    { aba = "Progressão", tipo = "dropdown", nome = "Estilo para treinar", chave = "EstiloFarm", opcoes = F.listaEstilosTenho },
    { aba = "Progressão", tipo = "toggle", nome = "Usar este estilo nos farms (arma Melee)", chave = "UsarEstiloFarm" },
    { aba = "Progressão", tipo = "info", texto = "Com a arma \"Melee\" selecionada na aba Main, ligue Auto Farm Level / Nearest: o farm vai usar o estilo escolhido aqui e subir a maestria dele. As quests com chave/itens (Library Key, Water Key, Fire Essence...) você ainda faz manualmente." },
    { aba = "Progressão", tipo = "secao", nome = "Espadas lendárias" },
    { aba = "Progressão", tipo = "info", texto = F.textoEspadas },
    { aba = "Progressão", tipo = "botao", nome = "Comprar Shisui", acao = function() F.comprarEspada(1) end },
    { aba = "Progressão", tipo = "botao", nome = "Comprar Saddi", acao = function() F.comprarEspada(2) end },
    { aba = "Progressão", tipo = "botao", nome = "Comprar Wando", acao = function() F.comprarEspada(3) end },
    { aba = "Progressão", tipo = "secao", nome = "Vendedores (spawn)" },
    { aba = "Progressão", tipo = "info", texto = F.textoVendedores },
    { aba = "Progressão", tipo = "botao", nome = "Ir até o Legendary Sword Dealer", acao = function() F.irParaVendedor("LegendarySword") end },
    { aba = "Progressão", tipo = "botao", nome = "Ir até o Haki Color Dealer", acao = function() F.irParaVendedor("HakiColor") end },
    { aba = "Progressão", tipo = "botao", nome = "Ir até o Advanced Fruit Dealer", acao = function() F.irParaVendedor("AdvancedFruit") end },
    { aba = "Progressão", tipo = "toggle", nome = "Avisar quando um vendedor raro spawnar", chave = "VendedorNotifier" },
    { aba = "Progressão", tipo = "secao", nome = "NPCs (busca e diagnóstico)" },
    { aba = "Progressão", tipo = "botao", nome = "Diagnóstico de NPCs (F9 + área de transferência)", acao = F.diagnosticoNpcs },
    { aba = "Progressão", tipo = "input", nome = "Procurar NPC por nome", chave = "NpcBusca", placeholder = "ex: dealer, scientist, teacher" },
    { aba = "Progressão", tipo = "botao", nome = "Ir até o NPC pesquisado", acao = F.procurarNpcPorNome },
    { aba = "Progressão", tipo = "input", nome = "NPC ensinador manual (usado ao comprar estilos)", chave = "NpcManual", placeholder = "deixe vazio para usar o automático" },

    -- LOJA
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
    { aba = "Sistema", tipo = "info", texto = "Server Hop, Rejoin e \"Entrar no servidor do JobId\" usam TeleportService iniciado pelo cliente. Se o jogo responder Unauthorized (erro 773), o script não consegue contornar: a falha é avisada e as tentativas automáticas param." },
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
    label.Size = UDim2.new(0, 230, 0, 122)
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
        local amostras = {}   -- { tempo, golpes, dano } dos últimos ~6s
        while Estado.rodando do
            label.Visible = Cfg:Get("Debug") == true
            if label.Visible then
                local lv, beli, frag = "?", "?", "?"
                pcall(function()
                    local d = LocalPlayer.Data
                    lv, beli, frag = d.Level.Value, d.Beli.Value, d.Fragments.Value
                end)
                local agora = os.clock()
                table.insert(amostras, { agora, Metricas.golpes, Metricas.dano })
                while #amostras > 1 and agora - amostras[1][1] > 6 do table.remove(amostras, 1) end
                local primeiro, ultimo = amostras[1], amostras[#amostras]
                local dt = ultimo[1] - primeiro[1]
                local golpesPorSeg = dt > 0 and (ultimo[2] - primeiro[2]) / dt or 0
                local danoPorSeg = dt > 0 and (ultimo[3] - primeiro[3]) / dt or 0
                label.Text = string.format(" Sessão: %s\n Modo: %s\n Sea: %d (sel. %d)\n Level: %s\n Beli: %s | Frag: %s\n AntiAFK: Idled=%d | backup=%d\n Golpes/s: %.1f | Dano/s: %.0f",
                    formatarTempo(os.clock() - Estado.inicio), Estado.modo, seaAtual(), seaEfetivo(),
                    tostring(lv), tostring(beli), tostring(frag), AntiAfk.idled, AntiAfk.backup,
                    golpesPorSeg, danoPorSeg)
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
            -- o UIScale também multiplica o offset da Position: compensa a escala
            local esc = frame:FindFirstChildOfClass("UIScale")
            local s = esc and esc.Scale or 1
            local nx = math.clamp(startPos.X.Offset + d.X / s, 0, math.max(0, tela.X / s - 80))
            local ny = math.clamp(startPos.Y.Offset + d.Y / s, 0, math.max(0, tela.Y / s - 40))
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
    -- centraliza UMA vez (compensando a escala); o topo fica fixo ao minimizar/abrir
    local s0 = escala.Scale
    Main.Position = UDim2.fromOffset(
        math.max(0, (vp.X - LARGURA * s0) / 2) / s0,
        math.max(0, (vp.Y - ALTURA * s0) / 2) / s0)

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
        -- os textos informativos só são calculados para a aba visível:
        -- atualiza assim que a aba muda
        task.defer(function() atualizarVisuais() end)
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
        -- texto fixo: mostra já. Texto calculado: só quando a aba estiver visível
        -- (alguns fazem buscas de NPC / consultas ao inventário).
        if type(c.texto) ~= "function" then visual() else rot.Text = "..." end
        registrar(function()
            if p.Visible then visual() end
        end)
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
        -- se o valor mudar por fora (ex.: preset de evento), reflete na caixa
        registrar(function()
            if not caixa:IsFocused() then
                local v = tostring(Cfg:Get(c.chave) or "")
                if caixa.Text ~= v then caixa.Text = v end
            end
        end)
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