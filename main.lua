-- =================================================================
-- NANA'S HUB v2 - MONOLITHIC BUILD (CONSOLIDATED)
-- Target: Blox Fruits (Sea 1, Sea 2, Sea 3)
-- Single-file: nenhum HttpGet de submodulo. Cole e execute.
-- Registry guard: reexecucao na mesma sessao e segura.
-- =================================================================

-- ============================================================
-- GUARD DE AMBIENTE - roda antes de qualquer coisa tocar o executor
-- ============================================================
-- getgenv pode faltar em alguns builds de executor mobile. Tentamos, em
-- ordem: getgenv nativo, _G, e por fim uma tabela propria. Sem isso, um
-- executor sem getgenv derrubava o script antes da primeira linha util.
local function resolver_global()
    local ok, g = pcall(function() return getgenv and getgenv() end)
    if ok and type(g) == "table" then return g end

    ok, g = pcall(function() return _G end)
    if ok and type(g) == "table" then return g end

    ok, g = pcall(function() return getfenv and getfenv(0) end)
    if ok and type(g) == "table" then return g end

    return {}
end

local GLOBAL = resolver_global()
local getgenv = function() return GLOBAL end
local getfenv = function() return GLOBAL end

-- ============================================================
-- REGISTRY + require interno + guard de reexecucao
-- ============================================================
local REGISTRY = getgenv().LuaCore_Registry or {}
getgenv().LuaCore_Registry = REGISTRY

-- Se uma execucao anterior deixou modulos vivos, derruba tudo antes de repovoar.
-- Sem isso, rodar o script duas vezes cria loops paralelos e conexoes orfas.
if getgenv().LuaCore and getgenv().LuaCore.reg == REGISTRY then
    for _, nome in ipairs({
        "d1", "d2", "d5",
        "d4", "e2", "e3",
        "e1", "f3", "b3",
    }) do
        local m = REGISTRY[nome]
        if m and type(m.stop) == "function" then pcall(m.stop) end
    end
    pcall(function()
        local g = REGISTRY["b2"]
        if g and g.low_end_off then g.low_end_off() end
    end)
    pcall(function()
        local b = REGISTRY["b1"]
        if b and b.disable then b.disable() end
    end)
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer
            :FindFirstChild("PlayerGui")
        if pg then
            local f = pg:FindFirstChild("LCFloat")
            if f then f:Destroy() end
        end
    end)
    for k in pairs(REGISTRY) do REGISTRY[k] = nil end
end

local function require_mod(nome)
    local mod = REGISTRY[nome]
    if mod == nil then
        error(("[LC] modulo nao carregado: %s"):format(tostring(nome)), 2)
    end
    return mod
end

-- ============================================================
-- a4
-- ============================================================

REGISTRY["a4"] = (function()
    local Services = {}

    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local Workspace         = game:GetService("Workspace")
    local Lighting          = game:GetService("Lighting")
    local TweenService      = game:GetService("TweenService")
    local UserInputService  = game:GetService("UserInputService")
    local VirtualUser       = game:GetService("VirtualUser")
    local VirtualInputMgr   = game:GetService("VirtualInputManager")
    local HttpService       = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterGui        = game:GetService("StarterGui")
    local Stats             = game:GetService("Stats")
    local CollectionService = game:GetService("CollectionService")

    Services.Players           = Players
    Services.RunService        = RunService
    Services.Workspace         = Workspace
    Services.Lighting          = Lighting
    Services.TweenService      = TweenService
    Services.UserInputService  = UserInputService
    Services.VirtualUser       = VirtualUser
    Services.VirtualInputMgr   = VirtualInputMgr
    Services.HttpService       = HttpService
    Services.ReplicatedStorage = ReplicatedStorage
    Services.StarterGui        = StarterGui
    Services.Stats             = Stats
    Services.CollectionService = CollectionService

    Services.LocalPlayer = Players.LocalPlayer
    Services.Character   = nil
    Services.Humanoid    = nil
    Services.Root        = nil
    Services.Remotes     = {}

    local function bind_character(char)
        Services.Character = char
        Services.Humanoid  = char:WaitForChild("Humanoid", 10)
        Services.Root      = char:WaitForChild("HumanoidRootPart", 10)
    end

    if Services.LocalPlayer.Character then
        bind_character(Services.LocalPlayer.Character)
    end
    Services.LocalPlayer.CharacterAdded:Connect(bind_character)

    function Services.refresh()
        local lp = Services.LocalPlayer
        Services.Character = lp.Character
        Services.Humanoid  = Services.Character
            and Services.Character:FindFirstChildOfClass("Humanoid")
        Services.Root      = Services.Character
            and Services.Character:FindFirstChild("HumanoidRootPart")
    end

    return Services
end)()

-- ============================================================
-- a6
-- ============================================================

-- ============================================================
-- a3  -  camada unica de protecao para chamadas de executor
-- Todo acesso a funcao nao-padrao (setfpscap, firetouchinterest,
-- getgenv, isfile...) passa por aqui. Se o executor mobile nao expoe
-- a funcao, o script segue rodando em vez de morrer.
-- ============================================================
REGISTRY["a3"] = (function()
    local Env = {}

    Env.mobile = (function()
        local ok, t = pcall(function()
            return game:GetService("UserInputService").TouchEnabled
        end)
        return ok and t == true
    end)()

    Env.executor = (function()
        for _, f in ipairs({ "identifyexecutor", "getexecutorname" }) do
            local fn = rawget(getfenv and getfenv() or _G, f)
            if type(fn) == "function" then
                local ok, nome = pcall(fn)
                if ok and type(nome) == "string" then return nome end
            end
        end
        return "desconhecido"
    end)()

    -- Cache de resultados para nao repetir pcall caro a cada frame.
    local cache_fps = { valor = nil, quando = 0 }

    -- ---------------------------------------------------------
    -- FPS cap: pcall duplo (a funcao pode nem existir, ou existir e
    -- recusar valores fora de faixa no mobile).
    -- ---------------------------------------------------------
    function Env.set_fps(n)
        n = tonumber(n) or 120
        n = math.clamp(math.floor(n), 30, 240)
        local agora = os.clock()
        if cache_fps.valor == n and (agora - cache_fps.quando) < 1 then
            return true
        end

        local fn
        pcall(function()
            fn = rawget(getfenv and getfenv() or _G, "setfpscap")
        end)
        if type(fn) ~= "function" then return false end

        local ok = pcall(fn, n)
        if not ok then
            -- Alguns executores so aceitam 30/60/120/240.
            for _, alt in ipairs({ 60, 120, 240, 30 }) do
                if pcall(fn, alt) then
                    cache_fps.valor, cache_fps.quando = alt, agora
                    return true
                end
            end
            return false
        end
        cache_fps.valor, cache_fps.quando = n, agora
        return true
    end

    -- ---------------------------------------------------------
    -- Interacao fisica: cada uma existe em alguns executores e nao
    -- em outros. Nunca deixa propagar erro.
    -- ---------------------------------------------------------
    function Env.touch(parte, alvo, estado_touch)
        local fn
        pcall(function()
            fn = rawget(getfenv and getfenv() or _G, "firetouchinterest")
        end)
        if type(fn) ~= "function" then return false end
        if not (parte and alvo) then return false end
        return pcall(fn, parte, alvo, estado_touch or 0)
    end

    function Env.click(detector)
        local fn
        pcall(function()
            fn = rawget(getfenv and getfenv() or _G, "fireclickdetector")
        end)
        if type(fn) ~= "function" or not detector then return false end
        return pcall(fn, detector)
    end

    function Env.prompt(prompt)
        if not prompt then return false end
        local fn
        pcall(function()
            fn = rawget(getfenv and getfenv() or _G, "fireproximityprompt")
        end)
        if type(fn) == "function" then
            if pcall(fn, prompt) then return true end
        end
        -- Fallback nativo (nao precisa de executor).
        return pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.min(prompt.HoldDuration or 0.4, 2))
            prompt:InputHoldEnd()
        end)
    end

    function Env.identify()
        return Env.executor, Env.mobile
    end

    -- ---------------------------------------------------------
    -- Medidor de saude do ambiente: usado no boot para reportar
    -- o que o executor entrega e o que falta.
    -- ---------------------------------------------------------
    function Env.diagnostico()
        local g = getfenv and getfenv() or _G
        local itens = {
            "setfpscap", "firetouchinterest", "fireclickdetector",
            "fireproximityprompt", "getgenv", "isfile", "readfile",
            "writefile", "identifyexecutor", "gcinfo", "setclipboard",
        }
        local tem, falta = {}, {}
        for _, nome in ipairs(itens) do
            local fn
            pcall(function() fn = rawget(g, nome) end)
            if type(fn) == "function" then
                table.insert(tem, nome)
            else
                table.insert(falta, nome)
            end
        end
        return tem, falta
    end

    return Env
end)()

REGISTRY["a6"] = (function()
    local Util = {}

    function Util.wait(t) return task.wait(t) end

    function Util.dyn_wait(base)
        base = base or 0.1
        local ok, carga = pcall(function()
            return game:GetService("Stats").Heartbeat:GetValue()
        end)
        carga = (ok and carga) or (1 / 60)
        local fator = math.clamp(carga * 30, 1, 3)
        return task.wait(base * fator)
    end

    function Util.safe(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[LC] " .. tostring(err)) end
        return ok, err
    end

    function Util.dist(a, b) return (a - b).Magnitude end

    function Util.nearest(lista, from)
        local melhor, melhord = nil, math.huge
        for _, v in ipairs(lista) do
            local p = v.Position or (v.PrimaryPart and v.PrimaryPart.Position)
            if p then
                local d = (p - from).Magnitude
                if d < melhord then melhor, melhord = v, d end
            end
        end
        return melhor, melhord
    end

    function Util.gc()
        if collectgarbage then pcall(collectgarbage, "collect") end
    end

    function Util.notify(titulo, texto, dur)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = titulo, Text = texto, Duration = dur or 3,
            })
        end)
    end

    function Util.bind(signal, fn)
        local conn
        conn = signal:Connect(function(...)
            if not fn(...) then conn:Disconnect() end
        end)
        return conn
    end

    function Util.clonar(t)
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        return out
    end

    return Util
end)()

-- ============================================================
-- a2
-- ============================================================

REGISTRY["a2"] = (function()
    local Services = require_mod("a4")
    local Dump     = {}

    -- =========================================================
    -- MODELO REAL DO JOGO
    -- Todo o jogo passa por UM RemoteFunction chamado CommF_.
    -- O comando vai como PRIMEIRO ARGUMENTO:
    --     CommF_:InvokeServer("StartQuest", "Bandit", 1)
    --     CommF_:InvokeServer("AddPoint", "Melee", 1)
    -- Nao existem remotes separados por acao. A tabela abaixo mapeia o
    -- nome logico usado pelo hub para o comando real do jogo.
    -- =========================================================
    local COMANDOS = {
        StartQuest    = "StartQuest",
        CompleteQuest = "CompleteQuest",
        AddPoint      = "AddPoint",
        BuySkill      = "BuySkill",
        EquipTool     = "EquipTool",
        StoreFruit    = "StoreFruit",
        PickupFruit   = "PickupFruit",
        BuyItem       = "BuyItem",
        Cousin        = "Cousin",
        RaidsNpc      = "RaidsNpc",
        RaceV4        = "RaceV4",
        Dialogue      = "Dialogue",
        Quest         = "Quest",
        CheckQuest    = "CheckQuest",
        Attack        = "Attack",
        -- Comandos de leitura usados pelo diagnostico
        getLevel      = "getLevel",
        getBeli       = "getBeli",
        getPoints     = "getPoints",
        getFragments  = "getFragments",
        getInventory  = "getInventory",
    }

    -- Candidatos a remote principal, em ordem de preferencia.
    local NOMES_COMM = { "CommF_", "CommF", "CommE", "Comm" }

    -- Assinaturas mantidas apenas para o dump informativo (Dump.cru).
    local ASSINATURAS = COMANDOS

    local RUIDO = {
        "analytics", "telemetry", "report", "metric", "trace", "beacon",
    }

    local function eh_ruido(nome)
        local n = nome:lower()
        for _, r in ipairs(RUIDO) do
            if n:find(r, 1, true) then return true end
        end
        return false
    end

    local function casa(nome, padroes)
        local n = nome:lower()
        for _, p in ipairs(padroes) do
            if not n:find(p, 1, true) then return false end
        end
        return true
    end

    local function varrer()
        local out = {}
        for _, obj in ipairs(Services.ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
               or obj:IsA("UnreliableRemoteEvent") then
                table.insert(out, { obj = obj, nome = obj.Name })
            end
        end
        return out
    end

    -- Localiza o remote principal do jogo. Tenta nomes exatos primeiro,
    -- depois busca por prefixo. Guarda a classe para saber se e Function
    -- (InvokeServer) ou Event (FireServer).
    local function achar_comm()
        local lista = varrer()
        -- 1) nome exato
        for _, candidato in ipairs(NOMES_COMM) do
            for _, r in ipairs(lista) do
                if r.nome == candidato then return r end
            end
        end
        -- 2) case-insensitive
        for _, candidato in ipairs(NOMES_COMM) do
            for _, r in ipairs(lista) do
                if r.nome:lower() == candidato:lower() then return r end
            end
        end
        -- 3) prefixo "comm"
        for _, r in ipairs(lista) do
            if r.nome:lower():sub(1, 4) == "comm" and not eh_ruido(r.nome) then
                return r
            end
        end
        return nil
    end

    function Dump.run(silencioso)
        local lista = varrer()
        Services.Remotes = Services.Remotes or {}

        local comm = achar_comm()
        Services.CommF = comm

        local faltando = {}
        if comm then
            -- Todos os comandos logicos passam pelo mesmo remote.
            for logico in pairs(COMANDOS) do
                Services.Remotes[logico] = comm
                Services.Remotes[logico .. "_classe"] = comm.obj.ClassName
            end
        else
            for logico in pairs(COMANDOS) do
                table.insert(faltando, logico)
            end
        end

        if not silencioso then
            print(("[LC/Dump] %d remotes encontrados"):format(#lista))
            if comm then
                local n_cmd = 0
                for _ in pairs(COMANDOS) do
                    n_cmd = n_cmd + 1
                end
                print(("  principal -> %s (%s)"):format(
                    comm.obj:GetFullName(), comm.obj.ClassName))
                print(("  %d comandos mapeados via esse remote"):format(n_cmd))
            else
                warn("[LC/Dump] NAO ACHEI o remote principal (CommF_)!")
                warn("[LC/Dump] rode 'Listar Remotes' na aba Home e me mande a lista")
            end
        end

        local total_res = comm and 1 or 0
        return { total = #lista, resolvidos = comm and { CommF = comm.obj } or {},
                 faltando = faltando, comm = comm }
    end

    function Dump.cru()
        print("[LC/Dump] === REMOTES ===")
        for _, obj in ipairs(Services.ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
               or obj:IsA("UnreliableRemoteEvent") then
                print(("  %-20s %s"):format(obj.ClassName, obj:GetFullName()))
            end
        end
        print("[LC/Dump] === FIM ===")
    end

    -- =========================================================
    -- A CHAMADA CENTRAL. Todo comando do hub passa por aqui.
    -- O primeiro argumento e SEMPRE a string do comando do jogo:
    --     Dump.invoke("StartQuest", "Bandit", 1)
    --       -> CommF_:InvokeServer("StartQuest", "Bandit", 1)
    --
    -- RETORNO: o Blox Fruits devolve nil na maioria dos comandos de acao
    -- mesmo quando deu certo. Por isso devolvemos DOIS valores:
    --     ok   -> true se a chamada foi enviada sem erro
    --     res  -> o que o jogo respondeu (geralmente nil)
    -- Call sites antigos que testam "~= nil" recebem Dump.OK (sentinela
    -- verdadeiro) quando a chamada passou e o jogo nao retornou nada.
    -- =========================================================
    local avisou_comm = false
    Dump.OK = setmetatable({}, { __tostring = function() return "LC/OK" end })

    function Dump.invoke(logico, ...)
        local comm = Services.CommF
        if not comm or not comm.obj then
            if not avisou_comm then
                avisou_comm = true
                warn("[LC/Dump] remote principal ausente - nada vai funcionar")
            end
            return nil, false, "CommF_ ausente"
        end

        local cmd = COMANDOS[logico] or logico
        local obj = comm.obj

        -- '...' nao atravessa closure: capturar antes.
        local args = table.pack(...)

        local ok, res = pcall(function()
            if obj:IsA("RemoteFunction") then
                return obj:InvokeServer(cmd, table.unpack(args, 1, args.n))
            else
                return obj:FireServer(cmd, table.unpack(args, 1, args.n))
            end
        end)

        if not ok then
            -- ok aqui e o erro da pcall
            return nil, false, res
        end

        -- Chamada enviada. Se o jogo nao respondeu nada, devolvemos o
        -- sentinela para os call sites antigos que testam ~= nil.
        return (res == nil and Dump.OK or res), true, res
    end

    -- Chamada crua, sem mapeamento: Dump.raw("Comando", arg1, arg2)
    function Dump.raw(cmd, ...)
        local comm = Services.CommF
        if not comm or not comm.obj then return nil, false, "CommF_ ausente" end
        local args = table.pack(...)
        local ok, res = pcall(function()
            if comm.obj:IsA("RemoteFunction") then
                return comm.obj:InvokeServer(cmd, table.unpack(args, 1, args.n))
            else
                return comm.obj:FireServer(cmd, table.unpack(args, 1, args.n))
            end
        end)
        if not ok then return nil, false, res end
        return (res == nil and Dump.OK or res), true, res
    end

    -- True se o remote principal foi localizado.
    function Dump.pronto()
        return Services.CommF ~= nil and Services.CommF.obj ~= nil
    end

    -- Lista os comandos que o hub conhece (para o painel de diagnostico).
    function Dump.comandos()
        local out = {}
        for logico, cmd in pairs(COMANDOS) do
            out[#out + 1] = logico .. " -> \"" .. cmd .. "\""
        end
        table.sort(out)
        return out
    end

    function Dump.nome(logico)
        local comm = Services.CommF
        if not comm then return "(ausente)" end
        return comm.obj:GetFullName() .. '("' .. (COMANDOS[logico] or logico) .. '")'
    end

    return Dump
end)()

-- ============================================================
-- a5
-- ============================================================

REGISTRY["a5"] = (function()
    local Thread = {}
    local tarefas, rodando = {}, false

    function Thread.spawn(nome, fn, intervalo)
        for _, t in ipairs(tarefas) do
            if t.nome == nome then
                t.fn, t.intervalo = fn, intervalo or t.intervalo
                return
            end
        end
        table.insert(tarefas, {
            nome = nome, fn = fn, intervalo = intervalo or 0.5,
            ultimo = os.clock(),
        })
        Thread.start()
    end

    function Thread.kill(nome)
        for i, t in ipairs(tarefas) do
            if t.nome == nome then table.remove(tarefas, i) return end
        end
    end

    function Thread.has(nome)
        for _, t in ipairs(tarefas) do
            if t.nome == nome then return true end
        end
        return false
    end

    function Thread.start()
        if rodando then return end
        rodando = true
        task.spawn(function()
            while rodando do
                local agora = os.clock()
                for _, t in ipairs(tarefas) do
                    if agora - t.ultimo >= t.intervalo then
                        t.ultimo = agora
                        task.spawn(function() pcall(t.fn) end)
                    end
                end
                task.wait(0.05)
            end
        end)
    end

    function Thread.stop_all()
        for i = #tarefas, 1, -1 do tarefas[i] = nil end
    end

    return Thread
end)()

-- ============================================================
-- a1
-- ============================================================

REGISTRY["a1"] = (function()
    local Services = require_mod("a4")
    local AntiAFK = {}
    local ativo, conns = false, {}

    function AntiAFK.start()
        if ativo then return end
        ativo = true
        table.insert(conns, Services.VirtualUser.Idled:Connect(function()
            Services.VirtualUser:CaptureController()
            Services.VirtualUser:ClickButton2(Vector2.new())
        end))
        table.insert(conns, Services.LocalPlayer.OnTeleport:Connect(function()
            AntiAFK.restart()
        end))
    end

    function AntiAFK.stop()
        ativo = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for i = #conns, 1, -1 do conns[i] = nil end
    end

    function AntiAFK.restart()
        AntiAFK.stop()
        task.wait(1)
        AntiAFK.start()
    end

    return AntiAFK
end)()

-- ============================================================
-- b3
-- ============================================================

-- ============================================================
-- b3  -  versao blindada para mobile
-- Teto de conexoes adaptativo, pausa entre lotes, tudo em pcall.
-- Android tem limite duro de conexoes/threads: estourar = crash.
-- ============================================================
REGISTRY["b3"] = (function()
    local Services = require_mod("a4")
    local KillsHook = {}

    -- Perfil conservador por padrao. Detectado no start().
    local MOBILE  = (function()
        local ok, tipo = pcall(function()
            return Services.UserInputService.TouchEnabled
        end)
        return ok and tipo == true
    end)()

    local estado = {
        ativo = false, kills = 0, janela = 300,
        -- Android aguenta muito menos conexoes simultaneas que desktop.
        max_conexoes = MOBILE and 90 or 250,
        lote = MOBILE and 12 or 40,      -- conexoes por varredura
        pausa_lote = MOBILE and 1.2 or 0.4,
        filtro = nil, inicio = 0,
    }

    local conexoes = setmetatable({}, { __mode = "k" })
    local amostras, conns_global = {}, {}
    local varrendo = false

    local ALIADOS = {
        "Citizen", "Villager", "Shop", "Dealer", "Blacksmith", "Quest Giver",
        "Sword Dealer", "Bartilo", "Zioles", "Cousin", "Military Detective",
        "King Red Head", "Cake Queen", "Death King", "Shanks",
    }

    local function eh_aliado(nome)
        for _, a in ipairs(ALIADOS) do
            if nome:find(a, 1, true) then return true end
        end
        return false
    end

    local function hostil(model)
        if model == Services.Character then return false end
        local ok = pcall(function() return model:IsA("Model") end)
        if not (ok and model:IsA("Model")) then return false end
        local h = model:FindFirstChildOfClass("Humanoid")
        if not h then return false end
        if not model:FindFirstChild("HumanoidRootPart") then return false end
        if eh_aliado(model.Name) then return false end
        if Services.Players:GetPlayerFromCharacter(model) then return false end
        if estado.filtro and not estado.filtro(model) then return false end
        return true
    end

    local function registrar()
        estado.kills += 1
        table.insert(amostras, { t = os.clock() })
        local corte = os.clock() - estado.janela
        local i = 1
        while i <= #amostras and amostras[i].t < corte do i += 1 end
        if i > 1 then
            for j = i, #amostras do amostras[j - (i - 1)] = amostras[j] end
            for j = #amostras, #amostras - (i - 2), -1 do amostras[j] = nil end
        end
    end

    local function hookar(model)
        if conexoes[model] then return false end
        local h = model:FindFirstChildOfClass("Humanoid")
        if not h then return false end

        local vida_anterior = h.Health
        local conn
        -- pcall na conexao: se o executor/engine recusar, nao derruba nada.
        local ok = pcall(function()
            conn = h.HealthChanged:Connect(function(nova)
                if vida_anterior > 0 and nova <= 0 then
                    registrar()
                    if conn then pcall(function() conn:Disconnect() end) end
                    conexoes[model] = nil
                end
                vida_anterior = nova
            end)
        end)
        if not (ok and conn) then return false end
        conexoes[model] = conn
        return true
    end

    local function contar_conns()
        local n = 0
        for _ in pairs(conexoes) do n += 1 end
        return n
    end

    -- Varredura em lotes: nunca cria centenas de conexoes de uma vez.
    local function varrer()
        if varrendo then return contar_conns() end
        varrendo = true
        local n = contar_conns()
        local criadas = 0
        local ok = pcall(function()
            for _, v in ipairs(Services.Workspace:GetChildren()) do
                if n >= estado.max_conexoes then break end
                if criadas >= estado.lote then break end
                if hostil(v) then
                    if hookar(v) then
                        n += 1
                        criadas += 1
                    end
                end
            end
        end)
        varrendo = false
        if not ok then
            -- Se a varredura estourou, reduz o teto e segue vivo.
            estado.max_conexoes = math.max(30, math.floor(estado.max_conexoes * 0.7))
            warn("[LC/KillsHook] varredura falhou, teto reduzido para "
                .. estado.max_conexoes)
        end
        return n
    end

    function KillsHook.kpm()
        local agora = os.clock()
        local n = 0
        for _, a in ipairs(amostras) do
            if agora - a.t <= 60 then n += 1 end
        end
        local janela_efetiva = math.min(60, agora - (estado.inicio or agora))
        if janela_efetiva < 5 then return 0 end
        return (n / janela_efetiva) * 60
    end

    function KillsHook.total() return estado.kills end

    function KillsHook.reset()
        estado.kills = 0
        amostras = {}
        estado.inicio = os.clock()
    end

    function KillsHook.start(opcoes)
        if estado.ativo then return end
        estado.ativo = true
        estado.inicio = os.clock()
        estado.kills = 0
        amostras = {}
        for k, v in pairs(opcoes or {}) do estado[k] = v end

        varrer()

        -- DescendantAdded tambem protegido: em mobile, conexoes soltas matam.
        pcall(function()
            table.insert(conns_global,
                Services.Workspace.DescendantAdded:Connect(function(obj)
                    if not estado.ativo then return end
                    local ok = pcall(function()
                        if obj:IsA("Humanoid") then
                            local model = obj.Parent
                            if model and hostil(model) then
                                if contar_conns() < estado.max_conexoes then
                                    hookar(model)
                                end
                            end
                        end
                    end)
                    if not ok then
                        warn("[LC/KillsHook] hook de spawn falhou (ignorado)")
                    end
                end))
        end)

        -- Manutencao periodica: limpa mortos e re-varre em lotes.
        task.spawn(function()
            while estado.ativo do
                task.wait(MOBILE and 45 or 30)
                pcall(function()
                    for model, conn in pairs(conexoes) do
                        if not model.Parent then
                            pcall(function() conn:Disconnect() end)
                            conexoes[model] = nil
                        end
                    end
                    varrer()
                end)
            end
        end)
    end

    function KillsHook.stop()
        estado.ativo = false
        for model, conn in pairs(conexoes) do
            pcall(function() conn:Disconnect() end)
            conexoes[model] = nil
        end
        for _, c in ipairs(conns_global) do
            pcall(function() c:Disconnect() end)
        end
        for i = #conns_global, 1, -1 do conns_global[i] = nil end
    end

    function KillsHook.estado() return estado end
    function KillsHook.contagem_conexoes() return contar_conns() end
    function KillsHook.mobile() return MOBILE end

    return KillsHook
end)()

REGISTRY["b2"] = (function()
    local Services = require_mod("a4")
    local Env      = require_mod("a3")
    local Graphics = {}

    local estado = { ativo = false, snapshot = nil }
    local MaterialOriginal, conns = {}, {}

    local function snapshot()
        local s = {
            GlobalShadows = Services.Lighting.GlobalShadows,
            FogEnd        = Services.Lighting.FogEnd,
            Brightness    = Services.Lighting.Brightness,
            Ambient       = Services.Lighting.Ambient,
            efeitos       = {},
        }
        for _, e in ipairs(Services.Lighting:GetChildren()) do
            if e:IsA("PostEffect") or e:IsA("Atmosphere")
               or e:IsA("Sky") or e:IsA("BloomEffect") or e:IsA("BlurEffect") then
                table.insert(s.efeitos, { obj = e, enabled = e.Enabled })
            end
        end
        return s
    end

    local function aplicar_lighting()
        local L = Services.Lighting
        L.GlobalShadows = false
        L.FogEnd        = 100000
        L.Brightness    = 2
        L.Ambient       = Color3.fromRGB(180, 180, 180)
        for _, e in ipairs(L:GetChildren()) do
            if e:IsA("PostEffect") or e:IsA("Atmosphere") then
                e.Enabled = false
            elseif e:IsA("Sky") then
                e.Parent = nil
            end
        end
    end

    local function achatar(part)
        if not part:IsA("BasePart") then return end
        if MaterialOriginal[part] == nil then
            MaterialOriginal[part] = { mat = part.Material, color = part.Color }
        end
        part.Material    = Enum.Material.SmoothPlastic
        part.Color       = Color3.fromRGB(140, 140, 140)
        part.Reflectance = 0
        part.CastShadow  = false
    end

    local function varrer_mundo()
        for _, obj in ipairs(Services.Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                achatar(obj)
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail")
                or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("Terrain") then
                obj.WaterWaveSize     = 0
                obj.WaterWaveSpeed    = 0
                obj.WaterReflectance  = 0
                obj.WaterTransparency = 1
            end
        end
    end

    function Graphics.low_end_on()
        if estado.ativo then return end
        estado.ativo = true
        estado.snapshot = snapshot()
        aplicar_lighting()
        varrer_mundo()
        table.insert(conns, Services.Workspace.DescendantAdded:Connect(
            function(obj)
                if not estado.ativo then return end
                if obj:IsA("BasePart") then
                    achatar(obj)
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    obj.Enabled = false
                end
            end))
    end

    function Graphics.low_end_off()
        estado.ativo = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for i = #conns, 1, -1 do conns[i] = nil end

        local s = estado.snapshot
        if s then
            local L = Services.Lighting
            L.GlobalShadows = s.GlobalShadows
            L.FogEnd        = s.FogEnd
            L.Brightness    = s.Brightness
            L.Ambient       = s.Ambient
            for _, e in ipairs(s.efeitos) do
                pcall(function() e.obj.Enabled = e.enabled end)
            end
        end
        for part, orig in pairs(MaterialOriginal) do
            pcall(function()
                part.Material = orig.mat
                part.Color    = orig.color
            end)
        end
        MaterialOriginal = {}
    end

    function Graphics.set_fps_cap(n)
        -- Blindado: setfpscap e opcional no executor mobile.
        return Env.set_fps(n)
    end

    -- Exposto para a UI ler o estado real (flags persistentes).
    function Graphics.estado() return estado end

    return Graphics
end)()

-- ============================================================
-- b1
-- ============================================================

REGISTRY["b1"] = (function()
    local Services  = require_mod("a4")
    local Env       = require_mod("a3")
    local KillsHook = require_mod("b3")
    local BlackScreen = {}

    local estado = {
        ativo = false, inicio = 0,
        mostrar_grafico = true, usar_killshook = false,
    }

    local gui, labels, conn_render = nil, {}, nil
    local grafico

    local telemetria = {
        amostras_beli = {}, amostras_kills = {},
        kills_total = 0, ultimo_n_mobs = nil, janela = 300,
        kills_por_min = 0, beli_por_hora = 0,
        historico_kpm = {}, historico_bph = {},
        nivel_inicial = 0, nivel_por_hora = nil, fonte_kills = "proxy",
    }

    local function ler_beli()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local b = d and d:FindFirstChild("Beli")
        return b and b.Value or 0
    end

    local function ler_nivel()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local l = d and d:FindFirstChild("Level")
        return l and l.Value or 0
    end

    local function ler_frag()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local f = d and d:FindFirstChild("Fragments")
        return f and f.Value or 0
    end

    local function ler_quest()
        local pg = Services.LocalPlayer:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        if q and q:FindFirstChild("Title") then return q.Title.Text end
        return "--"
    end

    local function contar_mobs()
        local n = 0
        for _, v in ipairs(Services.Workspace:GetChildren()) do
            if v:IsA("Model") and v ~= Services.Character then
                local h = v:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then n += 1 end
            end
        end
        return n
    end

    local function podar(lista, agora)
        local corte = agora - telemetria.janela
        local i = 1
        while i <= #lista and lista[i].t < corte do i += 1 end
        if i > 1 then
            for j = i, #lista do lista[j - (i - 1)] = lista[j] end
            for j = #lista, #lista - (i - 2), -1 do lista[j] = nil end
        end
    end

    function BlackScreen.set_hook(ligado)
        estado.usar_killshook = ligado
        if ligado then
            KillsHook.start()
            telemetria.fonte_kills = "hook"
            if telemetria.kills_total > 0 then
                KillsHook.estado().kills = telemetria.kills_total
            end
        else
            KillsHook.stop()
            telemetria.fonte_kills = "proxy"
            telemetria.kills_total = KillsHook.total()
        end
    end

    function BlackScreen.amostrar()
        local agora = os.clock()

        local beli = ler_beli()
        table.insert(telemetria.amostras_beli, { t = agora, v = beli })
        podar(telemetria.amostras_beli, agora)
        local ab = telemetria.amostras_beli
        if #ab >= 2 then
            local dt = agora - ab[1].t
            if dt > 5 then
                telemetria.beli_por_hora = ((beli - ab[1].v) / dt) * 3600
            end
        end

        if estado.usar_killshook then
            telemetria.kills_total   = KillsHook.total()
            telemetria.kills_por_min = KillsHook.kpm()
            telemetria.fonte_kills   = "hook"
        else
            local n_mobs = contar_mobs()
            if telemetria.ultimo_n_mobs then
                local delta = telemetria.ultimo_n_mobs - n_mobs
                if delta > 0 then telemetria.kills_total += delta end
            end
            telemetria.ultimo_n_mobs = n_mobs

            table.insert(telemetria.amostras_kills, { t = agora, v = n_mobs })
            podar(telemetria.amostras_kills, agora)

            local ak = telemetria.amostras_kills
            if #ak >= 2 then
                local ref = ak[1]
                for _, a in ipairs(ak) do
                    if agora - a.t <= 60 then ref = a break end
                end
                local dt = agora - ref.t
                if dt > 5 then
                    telemetria.kills_por_min =
                        math.max(0, ((ref.v - n_mobs) / dt) * 60)
                end
            end
            telemetria.fonte_kills = "proxy"
        end

        table.insert(telemetria.historico_kpm, telemetria.kills_por_min)
        table.insert(telemetria.historico_bph, telemetria.beli_por_hora)
        if #telemetria.historico_kpm > 60 then
            table.remove(telemetria.historico_kpm, 1)
        end
        if #telemetria.historico_bph > 60 then
            table.remove(telemetria.historico_bph, 1)
        end

        local dt_total = agora - estado.inicio
        if dt_total > 30 then
            telemetria.nivel_por_hora =
                ((ler_nivel() - telemetria.nivel_inicial) / dt_total) * 3600
        end
    end

    local function fmt_num(n)
        n = math.floor(n or 0)
        local s = tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse()
        return (s:gsub("^%.", ""))
    end

    local function fmt_hora(n)
        n = n or 0
        if n >= 1e9 then return ("%.2fB"):format(n / 1e9) end
        if n >= 1e6 then return ("%.2fM"):format(n / 1e6) end
        if n >= 1e3 then return ("%.1fK"):format(n / 1e3) end
        return tostring(math.floor(n))
    end

    local function fmt_tempo(seg)
        return string.format("%02d:%02d:%02d",
            math.floor(seg / 3600),
            math.floor((seg % 3600) / 60),
            math.floor(seg % 60))
    end

    local function criar_hud()
        local pg = Services.LocalPlayer:WaitForChild("PlayerGui", 10)
        gui = Instance.new("ScreenGui")
        gui.Name = "LCHUD"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 500
        gui.Parent = pg

        local fundo = Instance.new("Frame")
        fundo.Size = UDim2.new(1, 0, 1, 0)
        fundo.BackgroundColor3 = Color3.new(0, 0, 0)
        fundo.BorderSizePixel = 0
        fundo.ZIndex = 0
        fundo.Parent = gui

        local painel = Instance.new("Frame")
        painel.Name = "Painel"
        painel.Size = UDim2.new(0, 300, 0, 336)
        painel.Position = UDim2.new(0, 16, 0, 16)
        painel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
        painel.BackgroundTransparency = 0.15
        painel.BorderSizePixel = 0
        painel.ZIndex = 5
        painel.Parent = gui

        local cantos = Instance.new("UICorner")
        cantos.CornerRadius = UDim.new(0, 10)
        cantos.Parent = painel

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(60, 220, 140)
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        stroke.Parent = painel

        local titulo = Instance.new("TextLabel")
        titulo.Size = UDim2.new(1, -20, 0, 22)
        titulo.Position = UDim2.new(0, 10, 0, 8)
        titulo.BackgroundTransparency = 1
        titulo.Font = Enum.Font.GothamBold
        titulo.TextSize = 15
        titulo.TextColor3 = Color3.fromRGB(60, 220, 140)
        titulo.TextXAlignment = Enum.TextXAlignment.Left
        titulo.Text = "NANA'S HUB  -  AFK"
        titulo.ZIndex = 6
        titulo.Parent = painel

        local campos = {
            { id = "fps",   label = "FPS",        x = 0, y = 0 },
            { id = "nivel", label = "Nivel",      x = 1, y = 0 },
            { id = "beli",  label = "Beli",       x = 0, y = 1 },
            { id = "frag",  label = "Fragmentos", x = 1, y = 1 },
            { id = "quest", label = "Quest",      x = 0, y = 2, largo = true },
            { id = "afk",   label = "Tempo AFK",  x = 0, y = 3 },
            { id = "kpm",   label = "Kills/min",  x = 1, y = 3 },
            { id = "bph",   label = "Beli/h",     x = 0, y = 4 },
            { id = "ktot",  label = "Kills tot",  x = 1, y = 4 },
            { id = "lvlh",  label = "Nivel/h",    x = 0, y = 5, largo = true },
        }

        for _, c in ipairs(campos) do
            local largura = c.largo and UDim2.new(1, -20, 0, 30)
                or UDim2.new(0.5, -15, 0, 30)
            local x_off = c.largo and 10 or (10 + c.x * 145)

            local card = Instance.new("Frame")
            card.Size = largura
            card.Position = UDim2.new(0, x_off, 0, 36 + c.y * 36)
            card.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            card.BackgroundTransparency = 0.3
            card.BorderSizePixel = 0
            card.ZIndex = 6
            card.Parent = painel

            local cc = Instance.new("UICorner")
            cc.CornerRadius = UDim.new(0, 6)
            cc.Parent = card

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -8, 0, 12)
            lbl.Position = UDim2.new(0, 4, 0, 2)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 10
            lbl.TextColor3 = Color3.fromRGB(130, 130, 140)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = c.label
            lbl.ZIndex = 7
            lbl.Parent = card

            local val = Instance.new("TextLabel")
            val.Name = "Val"
            val.Size = UDim2.new(1, -8, 0, 16)
            val.Position = UDim2.new(0, 4, 0, 12)
            val.BackgroundTransparency = 1
            val.Font = Enum.Font.Code
            val.TextSize = 13
            val.TextColor3 = Color3.fromRGB(225, 225, 232)
            val.TextXAlignment = Enum.TextXAlignment.Left
            val.Text = "--"
            val.ZIndex = 7
            val.Parent = card

            labels[c.id] = val
        end

        local fonte = Instance.new("TextLabel")
        fonte.Name = "Fonte"
        fonte.Size = UDim2.new(0, 90, 0, 14)
        fonte.Position = UDim2.new(1, -100, 0, 8)
        fonte.BackgroundTransparency = 1
        fonte.Font = Enum.Font.Code
        fonte.TextSize = 10
        fonte.TextColor3 = Color3.fromRGB(110, 110, 120)
        fonte.TextXAlignment = Enum.TextXAlignment.Right
        fonte.Text = "[proxy]"
        fonte.ZIndex = 7
        fonte.Parent = painel
        labels.fonte = fonte

        if estado.mostrar_grafico then
            grafico = Instance.new("Frame")
            grafico.Name = "Grafico"
            grafico.Size = UDim2.new(1, -20, 0, 44)
            grafico.Position = UDim2.new(0, 10, 0, 36 + 6 * 36)
            grafico.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            grafico.BackgroundTransparency = 0.3
            grafico.BorderSizePixel = 0
            grafico.ZIndex = 6
            grafico.Parent = painel

            local gc = Instance.new("UICorner")
            gc.CornerRadius = UDim.new(0, 6)
            gc.Parent = grafico
        end
    end

    local function atualizar()
        local fps = 0
        pcall(function()
            local ft = Services.Stats.FrameTime
            if ft > 0 then fps = math.floor(1 / ft + 0.5) end
        end)

        local seg = os.clock() - estado.inicio

        labels.fps.Text   = tostring(fps)
        labels.nivel.Text = tostring(ler_nivel())
        labels.beli.Text  = fmt_hora(ler_beli())
        labels.frag.Text  = fmt_hora(ler_frag())
        labels.quest.Text = ler_quest()
        labels.afk.Text   = fmt_tempo(seg)
        labels.kpm.Text   = ("%.1f"):format(telemetria.kills_por_min)
        labels.bph.Text   = fmt_hora(telemetria.beli_por_hora)
        labels.ktot.Text  = fmt_num(telemetria.kills_total)
        labels.lvlh.Text  = telemetria.nivel_por_hora
            and ("%.2f nv/h"):format(telemetria.nivel_por_hora) or "--"

        local hook = telemetria.fonte_kills == "hook"
        labels.fonte.Text = hook and "[hook]" or "[proxy]"
        labels.fonte.TextColor3 = hook
            and Color3.fromRGB(60, 220, 140)
            or Color3.fromRGB(110, 110, 120)

        if grafico and estado.mostrar_grafico then
            for _, ch in ipairs(grafico:GetChildren()) do
                if ch:IsA("Frame") and ch.Name == "Bar" then ch:Destroy() end
            end
            local hist = telemetria.historico_kpm
            local maxv = 1
            for _, v in ipairs(hist) do if v > maxv then maxv = v end end
            local n = #hist
            local largura = grafico.AbsoluteSize.X
            if largura <= 0 then largura = 280 end
            local passo = largura / math.max(n, 1)
            for i, v in ipairs(hist) do
                local h = math.clamp((v / maxv) * 36, 1, 36)
                local bar = Instance.new("Frame")
                bar.Name = "Bar"
                bar.Size = UDim2.new(0, math.max(passo - 1, 1), 0, h)
                bar.Position = UDim2.new(0, (i - 1) * passo, 1, -h - 4)
                bar.BackgroundColor3 = Color3.fromRGB(60, 220, 140)
                bar.BackgroundTransparency = 0.15
                bar.BorderSizePixel = 0
                bar.ZIndex = 7
                bar.Parent = grafico
            end
        end
    end

    function BlackScreen.enable(hook)
        if estado.ativo then return end
        estado.ativo = true
        estado.inicio = os.clock()

        telemetria.kills_total = 0
        telemetria.ultimo_n_mobs = nil
        telemetria.beli_por_hora = 0
        telemetria.kills_por_min = 0
        telemetria.amostras_beli = {}
        telemetria.amostras_kills = {}
        telemetria.historico_kpm = {}
        telemetria.historico_bph = {}
        telemetria.nivel_inicial = ler_nivel()
        telemetria.nivel_por_hora = nil

        if hook then
            estado.usar_killshook = true
            KillsHook.start()
            telemetria.fonte_kills = "hook"
        end

        criar_hud()

        -- 10 fps trava o compositor no Android; 30 e o piso seguro.
        Env.set_fps(30)
        pcall(function()
            local cam = Services.Workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(0, 100000, 0)
        end)

        task.spawn(function()
            while estado.ativo do
                pcall(BlackScreen.amostrar)
                task.wait(1)
            end
        end)

        -- O Heartbeat pode nao existir / nao aceitar conexao no executor.
        -- Se falhar, cai para um loop de atualizacao do HUD, para nao deixar
        -- o BlackScreen num estado pela metade.
        local ok_hb = pcall(function()
            conn_render = Services.RunService.Heartbeat:Connect(function()
                if not estado.ativo then return end
                if os.clock() % 0.5 < 0.02 then pcall(atualizar) end
            end)
        end)
        if not (ok_hb and conn_render) then
            warn("[LC/BlackScreen] Heartbeat indisponivel, usando loop de fallback")
            task.spawn(function()
                while estado.ativo do
                    pcall(atualizar)
                    task.wait(0.5)
                end
            end)
        end
    end

    function BlackScreen.disable()
        if not estado.ativo then return end
        estado.ativo = false
        if estado.usar_killshook then KillsHook.stop() end
        if conn_render then conn_render:Disconnect() conn_render = nil end
        if gui then gui:Destroy() gui = nil end
        labels = {}
        Env.set_fps(120)
        pcall(function()
            local cam = Services.Workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
        end)
    end

    function BlackScreen.telemetria() return telemetria end
    function BlackScreen.ativo() return estado.ativo end
    function BlackScreen.estado() return estado end

    return BlackScreen
end)()

-- ============================================================
-- b4
-- ============================================================

REGISTRY["b4"] = (function()
    local Util = require_mod("a6")
    local MemSaver = {}
    local conn, rodando = nil, false
    local INTERVALO_GC = 300

    function MemSaver.start()
        if rodando then return end
        rodando = true
        task.spawn(function()
            while rodando do
                task.wait(INTERVALO_GC)
                Util.gc()
                pcall(function()
                    local mem = gcinfo and gcinfo() or 0
                    if mem / 1024 > 1500 then
                        Util.gc()
                        Util.notify("LuaCore", "Memoria alta - GC forcado", 2)
                    end
                end)
            end
        end)
        conn = game:GetService("Players").LocalPlayer.CharacterAdded:Connect(
            function()
                task.wait(2)
                Util.gc()
            end)
    end

    function MemSaver.stop()
        rodando = false
        if conn then conn:Disconnect() end
    end

    -- Exposto para a UI ler o estado real (flags persistentes).
    function MemSaver.estado() return { ativo = rodando } end

    return MemSaver
end)()

-- ============================================================
-- c2
-- ============================================================

REGISTRY["c2"] = (function()
    local Services = require_mod("a4")
    local Tween = {}
    local VELOCIDADE_PADRAO = 320
    local colisoes_salvas = {}

    local function desligar_colisao(char)
        colisoes_salvas = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                colisoes_salvas[p] = true
                p.CanCollide = false
            end
        end
    end

    local function restaurar_colisao()
        for p in pairs(colisoes_salvas) do
            pcall(function() p.CanCollide = true end)
        end
        colisoes_salvas = {}
    end

    function Tween.to(posicao, velocidade, timeout)
        local char = Services.Character
        local root = Services.Root
        if not (char and root) then return false end

        velocidade = velocidade or VELOCIDADE_PADRAO
        timeout    = timeout or 30

        local origem  = root.Position
        local dist    = (posicao - origem).Magnitude
        if dist < 1 then return true end

        desligar_colisao(char)

        local t = Services.TweenService:Create(
            root,
            TweenInfo.new(dist / velocidade, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(posicao) }
        )

        local terminou, conn = false, nil
        conn = t.Completed:Connect(function() terminou = true end)
        t:Play()

        local t0 = os.clock()
        while not terminou and (os.clock() - t0) < timeout do
            if not Services.Humanoid or Services.Humanoid.Health <= 0 then
                t:Cancel() break
            end
            task.wait(0.1)
        end
        conn:Disconnect()
        if not terminou then t:Cancel() end

        restaurar_colisao()
        return terminou
    end

    function Tween.hop(posicao, passos, velocidade)
        passos = passos or 3
        local root = Services.Root
        if not root then return false end
        local origem = root.Position
        for i = 1, passos do
            local alvo = origem:Lerp(posicao, i / passos)
            if not Tween.to(alvo, velocidade, 10) then return false end
        end
        return true
    end

    function Tween.set_velocidade(v)
        VELOCIDADE_PADRAO = math.clamp(v, 100, 600)
    end

    return Tween
end)()

-- ============================================================
-- c1
-- ============================================================

REGISTRY["c1"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Env      = require_mod("a3")
    local Tween    = require_mod("c2")
    local Hitbox   = {}
    local RAIO_PADRAO = 60
    local avisou_remote = false

    -- Mobs ficam dentro de pastas (Enemies, Mobs) no Blox Fruits.
    -- Varrer so a Workspace direta nao acha nada em muitas ilhas.
    local function containers_mobs()
        local ws = Services.Workspace
        return {
            ws:FindFirstChild("Enemies"),
            ws:FindFirstChild("Mobs"),
            ws:FindFirstChild("NPCs"),
            ws,
        }
    end

    -- Varre um container (e um nivel de subpastas) procurando mobs vivos.
    local function mobs_proximos(raio, limite)
        local out = {}
        local root = Services.Root
        if not root then return out end
        raio = raio or RAIO_PADRAO
        local eu = Services.Character

        local function examinar(c)
            if not c then return end
            for _, v in ipairs(c:GetChildren()) do
                if v:IsA("Model") and v ~= eu then
                    local h  = v:FindFirstChildOfClass("Humanoid")
                    local mp = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                    if h and mp and h.Health > 0 then
                        local ok, pos = pcall(function() return mp.Position end)
                        if ok and pos then
                            local d = (pos - root.Position).Magnitude
                            if d <= raio then
                                table.insert(out, { mob = v, dist = d })
                            end
                        end
                    end
                elseif v:IsA("Folder") then
                    -- desce um nivel (ilhas costumam ter subpastas)
                    examinar(v)
                end
            end
        end

        for _, c in ipairs(containers_mobs()) do examinar(c) end
        table.sort(out, function(a, b) return a.dist < b.dist end)

        local lista = {}
        for i = 1, math.min(#out, limite or 20) do
            lista[i] = out[i].mob
        end
        return lista
    end
    Hitbox.mobs_proximos = mobs_proximos

    function Hitbox.bring_mobs(raio, altura)
        raio   = raio or RAIO_PADRAO
        altura = altura or 12
        local root = Services.Root
        if not root then return 0 end

        local mobs = mobs_proximos(raio, 12)
        local alvo = root.Position + Vector3.new(0, altura, 0)
        local n = 0
        local tocados = {}

        for _, mob in ipairs(mobs) do
            local mp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
            if mp then
                local ok = pcall(function()
                    mp.CFrame   = CFrame.new(alvo)
                    mp.Velocity = Vector3.zero
                    -- Anchored so por um instante: prender mob permanentemente
                    -- faz o servidor corrigir a posicao e o mob volta.
                    mp.Anchored = true
                end)
                if ok then
                    n += 1
                    tocados[#tocados + 1] = mp
                end
            end
        end
        task.wait(0.1)
        for _, mp in ipairs(tocados) do
            pcall(function() mp.Anchored = false end)
        end
        return n
    end

    function Hitbox.fast_attack(modo, alvo)
        modo = modo or "seguro"

        -- Atacar pelo caminho oficial: CommF_:InvokeServer("Attack", true).
        -- NAO usamos Services.Remotes direto: aquilo e o wrapper do Dump
        -- ({obj=, nome=}), nao o remote, e o pcall engolia o erro.
        local Dump = require_mod("a2")
        if not Dump.pronto() then
            if not avisou_remote then
                avisou_remote = true
                warn("[LC/Hitbox] sem remote de ataque - veja a aba Home")
            end
            return false
        end

        local repeticoes = (modo == "blatant") and 8 or 4
        local pausa      = (modo == "blatant") and 0.03 or 0.08
        local enviados   = 0

        for _ = 1, repeticoes do
            local _, ok = Dump.invoke("Attack")
            if ok then enviados += 1 end
            Util.dyn_wait(pausa)
        end

        -- Se temos um alvo, cutucamos o Humanoid diretamente. Isso faz o
        -- servidor registrar o dano mesmo quando o touch do executor falha.
        if alvo and alvo.Parent then
            local h = alvo:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                pcall(function()
                    -- O TakeDamage e uma via local; o servidor valida pelo
                    -- InvokeServer acima. Serve para destravar mobs parados.
                    if h.Health > 0 then h:TakeDamage(0) end
                end)
            end
        end

        -- Cancelar animacao de ataque travada (comum em mobile com lag).
        local char = Services.Character
        if char then
            pcall(function()
                local anim = char:FindFirstChildOfClass("Animator")
                if anim then
                    for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
                        if t.Animation and t.Animation.Name:find("Attack") then
                            t:Stop(0)
                        end
                    end
                end
            end)
        end

        return enviados > 0
    end

    -- Loop de combate. Nao depende de tween nem de touch: usa o InvokeServer
    -- de ataque e verifica o HP do alvo para saber se esta funcionando.
    function Hitbox.combat_loop(alvo_fn, opcoes, vivo_fn)
        opcoes = opcoes or {}
        local raio     = opcoes.raio or RAIO_PADRAO
        local modo     = opcoes.modo or "seguro"
        local dist     = opcoes.distancia or 20
        -- Se vivo_fn nao for passado, assume "sempre vivo": antes o loop
        -- simplesmente nao rodava quando o chamador omitia o terceiro arg.
        if not vivo_fn then vivo_fn = function() return true end end

        local sem_alvo = 0
        local hp_antes = nil

        while vivo_fn() do
            local alvo = alvo_fn()
            if not alvo or not alvo.Parent then
                sem_alvo += 1
                -- Mobs em respawn: espera sem desistir.
                Util.dyn_wait(sem_alvo > 20 and 1.0 or 0.25)
            else
                sem_alvo = 0
                local root = Services.Root
                local mp = alvo:FindFirstChild("HumanoidRootPart") or alvo.PrimaryPart
                local hum = alvo:FindFirstChildOfClass("Humanoid")

                if not (root and mp) then
                    Util.dyn_wait(0.2)
                else
                    local hp = hum and hum.Health or 0
                    hp_antes = hp

                    -- Aproximar. Se o Tween falhar, o ataque ainda sai:
                    -- o servidor aceita Attack a distancia no Blox Fruits.
                    local ok_pos, pos = pcall(function() return mp.Position end)
                    if ok_pos and pos then
                        local d = (pos - root.Position).Magnitude
                        if d > dist then
                            pcall(function()
                                Tween.to(pos + (root.Position - pos).Unit * dist)
                            end)
                        end
                    end

                    -- Atacar. fast_attack devolve true se o comando saiu.
                    Hitbox.fast_attack(modo, alvo)

                    -- Se o HP nao caiu em varios ciclos, tentamos trazer os
                    -- mobs para perto (fallback), mas so de vez em quando.
                    Util.dyn_wait(0.12)
                    if hum and hum.Health >= hp_antes and hp > 0 then
                        _G.__nana_sem_dano = (_G.__nana_sem_dano or 0) + 1
                        if _G.__nana_sem_dano % 30 == 0 then
                            pcall(function() Hitbox.bring_mobs(raio, 10) end)
                        end
                    else
                        _G.__nana_sem_dano = 0
                    end
                end
            end
        end
    end

    return Hitbox
end)()

-- ============================================================
-- d3
-- ============================================================

REGISTRY["d3"] = (function()
    local Quests = {}

    Quests.sea1 = {
        [1]   = { npc = "Quest Giver", mob = "Bandit",         ilha = "Starter Island",   level = 1   },
        [10]  = { npc = "Quest Giver", mob = "Monkey",         ilha = "Jungle",           level = 10  },
        [20]  = { npc = "Quest Giver", mob = "Pirate",         ilha = "Pirate Village",   level = 20  },
        [30]  = { npc = "Quest Giver", mob = "Brute",          ilha = "Marine Fortress",  level = 30  },
        [40]  = { npc = "Quest Giver", mob = "Desert Bandit",  ilha = "Desert",           level = 40  },
        [60]  = { npc = "Quest Giver", mob = "Desert Officer", ilha = "Desert",           level = 60  },
        [75]  = { npc = "Quest Giver", mob = "Snow Bandit",    ilha = "Snow Island",      level = 75  },
        [90]  = { npc = "Quest Giver", mob = "Snowman",        ilha = "Snow Island",      level = 90  },
        [100] = { npc = "Quest Giver", mob = "Frost Bandit",   ilha = "Frost Island",     level = 100 },
        [120] = { npc = "Quest Giver", mob = "Frost Officer",  ilha = "Frost Island",     level = 120 },
        [150] = { npc = "Quest Giver", mob = "Sky Bandit",     ilha = "Skylands",         level = 150 },
        [175] = { npc = "Quest Giver", mob = "Dark Master",    ilha = "Skylands",         level = 175 },
        [200] = { npc = "Quest Giver", mob = "Fountain Guard", ilha = "Upper Skylands",   level = 200 },
        [250] = { npc = "Quest Giver", mob = "Galley Pirate",  ilha = "Colosseum",        level = 250 },
        [300] = { npc = "Quest Giver", mob = "Galley Captain", ilha = "Colosseum",        level = 300 },
        [375] = { npc = "Quest Giver", mob = "Raider",         ilha = "Magma Village",    level = 375 },
        [450] = { npc = "Quest Giver", mob = "Mercenary",      ilha = "Magma Village",    level = 450 },
        [500] = { npc = "Quest Giver", mob = "Cyborg",         ilha = "Underwater City",  level = 500 },
        [625] = { npc = "Quest Giver", mob = "Diamond Pirate", ilha = "Underwater City",  level = 625 },
        [700] = { npc = "Quest Giver", mob = "Fajita",         ilha = "Fishman Island",   level = 700 },
    }

    Quests.sea2 = {
        [700]  = { npc = "Quest Giver", mob = "Raider",           ilha = "Kingdom of Rose", level = 700  },
        [775]  = { npc = "Quest Giver", mob = "Mercenary",        ilha = "Kingdom of Rose", level = 775  },
        [850]  = { npc = "Quest Giver", mob = "Swan Pirate",      ilha = "Kingdom of Rose", level = 850  },
        [925]  = { npc = "Quest Giver", mob = "Factory Staff",    ilha = "Kingdom of Rose", level = 925  },
        [1000] = { npc = "Quest Giver", mob = "Military Soldier", ilha = "Green Zone",      level = 1000 },
        [1050] = { npc = "Quest Giver", mob = "Military Spy",     ilha = "Green Zone",      level = 1050 },
        [1100] = { npc = "Quest Giver", mob = "Fajita",           ilha = "Graveyard",       level = 1100 },
        [1200] = { npc = "Quest Giver", mob = "Reborn Skeleton",  ilha = "Graveyard",       level = 1200 },
        [1250] = { npc = "Quest Giver", mob = "Living Zombie",    ilha = "Graveyard",       level = 1250 },
        [1350] = { npc = "Quest Giver", mob = "Demonic Soul",     ilha = "Graveyard",       level = 1350 },
        [1425] = { npc = "Quest Giver", mob = "Snow Trooper",     ilha = "Snow Mountain",   level = 1425 },
        [1500] = { npc = "Quest Giver", mob = "Winter Warrior",   ilha = "Snow Mountain",   level = 1500 },
        [1625] = { npc = "Quest Giver", mob = "Lab Subordinate",  ilha = "Hot and Cold",    level = 1625 },
        [1750] = { npc = "Quest Giver", mob = "Horned Warrior",   ilha = "Hot and Cold",    level = 1750 },
        [1850] = { npc = "Quest Giver", mob = "Magma Ninja",      ilha = "Cursed Ship",     level = 1850 },
        [2000] = { npc = "Quest Giver", mob = "Lava Pirate",      ilha = "Cursed Ship",     level = 2000 },
        [2100] = { npc = "Quest Giver", mob = "Ship Deckhand",    ilha = "Cursed Ship",     level = 2100 },
        [2200] = { npc = "Quest Giver", mob = "Ship Engineer",    ilha = "Cursed Ship",     level = 2200 },
        [2300] = { npc = "Quest Giver", mob = "Ship Steward",     ilha = "Cursed Ship",     level = 2300 },
        [2400] = { npc = "Quest Giver", mob = "Ship Officer",     ilha = "Cursed Ship",     level = 2400 },
        [2500] = { npc = "Quest Giver", mob = "Arctic Warrior",   ilha = "Ice Castle",      level = 2500 },
        [2600] = { npc = "Quest Giver", mob = "Snow Lurker",      ilha = "Ice Castle",      level = 2600 },
        [2700] = { npc = "Quest Giver", mob = "Frozen Monster",   ilha = "Ice Castle",      level = 2700 },
        [2800] = { npc = "Quest Giver", mob = "Snow Queen Guard", ilha = "Ice Castle",      level = 2800 },
    }

    Quests.sea3 = {
        [1500] = { npc = "Quest Giver", mob = "Pirate Millionaire",  ilha = "Port Town",         level = 1500 },
        [1625] = { npc = "Quest Giver", mob = "Pistol Billionaire",  ilha = "Port Town",         level = 1625 },
        [1750] = { npc = "Quest Giver", mob = "Dragon Crew Warrior", ilha = "Hydra Island",      level = 1750 },
        [1850] = { npc = "Quest Giver", mob = "Dragon Crew Archer",  ilha = "Hydra Island",      level = 1850 },
        [2000] = { npc = "Quest Giver", mob = "Female Islander",     ilha = "Great Tree",        level = 2000 },
        [2100] = { npc = "Quest Giver", mob = "Giant Islander",      ilha = "Great Tree",        level = 2100 },
        [2250] = { npc = "Quest Giver", mob = "Marine Commando",     ilha = "Floating Turtle",   level = 2250 },
        [2400] = { npc = "Quest Giver", mob = "Marine Captain",      ilha = "Floating Turtle",   level = 2400 },
        [2550] = { npc = "Quest Giver", mob = "Forest Pirate",       ilha = "Haunted Castle",    level = 2550 },
        [2700] = { npc = "Quest Giver", mob = "Mythological Pirate", ilha = "Haunted Castle",    level = 2700 },
        [2850] = { npc = "Quest Giver", mob = "Jungle Pirate",       ilha = "Castle on the Sea", level = 2850 },
        [3000] = { npc = "Quest Giver", mob = "Musketeer Pirate",    ilha = "Castle on the Sea", level = 3000 },
        [3150] = { npc = "Quest Giver", mob = "Reborn Skeleton",     ilha = "Haunted Castle",    level = 3150 },
        [3300] = { npc = "Quest Giver", mob = "Living Zombie",       ilha = "Haunted Castle",    level = 3300 },
        [3500] = { npc = "Quest Giver", mob = "Demonic Soul",        ilha = "Haunted Castle",    level = 3500 },
        [3750] = { npc = "Quest Giver", mob = "Possessed Mummy",     ilha = "Haunted Castle",    level = 3750 },
        [4000] = { npc = "Quest Giver", mob = "Cursed Skeleton",     ilha = "Haunted Castle",    level = 4000 },
        [4200] = { npc = "Quest Giver", mob = "Cursed Zombie",       ilha = "Haunted Castle",    level = 4200 },
        [4400] = { npc = "Quest Giver", mob = "Ghost",               ilha = "Haunted Castle",    level = 4400 },
        [4600] = { npc = "Quest Giver", mob = "Ghost Captain",       ilha = "Haunted Castle",    level = 4600 },
        [5000] = { npc = "Quest Giver", mob = "Terrorshark",         ilha = "Great Tree",        level = 5000 },
        [5250] = { npc = "Quest Giver", mob = "Shark",               ilha = "Great Tree",        level = 5250 },
        [5500] = { npc = "Quest Giver", mob = "Fishman Raider",      ilha = "Great Tree",        level = 5500 },
        [5750] = { npc = "Quest Giver", mob = "Fishman Captain",     ilha = "Great Tree",        level = 5750 },
        [6000] = { npc = "Quest Giver", mob = "Forest Pirate",       ilha = "Haunted Castle",    level = 6000 },
    }

    function Quests.for_level(sea, level)
        local tabela = Quests["sea" .. sea] or Quests.sea1
        local melhor, melhor_lv = nil, 0
        for lv, q in pairs(tabela) do
            if lv <= level and lv > melhor_lv then
                melhor, melhor_lv = q, lv
            end
        end
        if not melhor then
            local menor = math.huge
            for lv, q in pairs(tabela) do
                if lv < menor then melhor, menor = q, lv end
            end
        end
        return melhor, melhor_lv
    end

    function Quests.contagem()
        return { sea1 = #Quests.sea1, sea2 = #Quests.sea2, sea3 = #Quests.sea3 }
    end

    function Quests.detect_sea()
        local lp = game:GetService("Players").LocalPlayer
        local ok, mar = pcall(function() return lp:GetAttribute("Sea") end)
        if ok and type(mar) == "number" then return mar end
        local d = lp:FindFirstChild("Data")
        local lv = d and d:FindFirstChild("Level")
        local nivel = lv and lv.Value or 1
        if nivel >= 1500 then return 3 end
        if nivel >= 700 then return 2 end
        return 1
    end

    return Quests
end)()

-- ============================================================
-- d1
-- ============================================================

REGISTRY["d1"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local Quests   = require_mod("d3")
    local Level    = {}

    local estado = {
        ativo = false, stats_alvo = "Melee", metodo = "Tween",
        modo = "seguro", auto_quest = true, ciclos = 0,
    }

    local MAPA_STATS = {
        Melee = "Melee", Defense = "Defense", Sword = "Sword",
        Gun = "Gun", ["Blox Fruit"] = "Demon Fruit",
    }

    local function valor(campo)
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local v = d and d:FindFirstChild(campo)
        return v and v.Value or 0
    end

    local function nivel_atual()   return valor("Level")  end
    local function pontos_livres() return valor("Points") end

    local function alocar_stats()
        local pontos = pontos_livres()
        if pontos <= 0 then return 0 end
        local stat = MAPA_STATS[estado.stats_alvo]
        if not stat then
            local lv = nivel_atual()
            if lv < 1000 then stat = "Melee" else stat = "Melee" end
        end
        local alocados = 0
        -- Blox Fruits devolve nil mesmo em sucesso, entao usamos o
        -- segundo valor (ok) para saber se a chamada foi enviada.
        for _ = 1, math.min(pontos, 50) do
            local _, ok = Dump.invoke("AddPoint", stat, 1)
            if not ok then break end
            alocados += 1
            Util.dyn_wait(0.08)
        end
        return alocados
    end

    local function achar_mob(nomes)
        local root = Services.Root
        if not root then return nil end
        if type(nomes) == "string" then nomes = { nomes } end

        -- Containers onde o Blox Fruits guarda mobs. GetChildren() direto
        -- na Workspace perde tudo que esta dentro de pasta (Enemies etc).
        local containers = {
            Services.Workspace:FindFirstChild("Enemies"),
            Services.Workspace:FindFirstChild("Mobs"),
            Services.Workspace:FindFirstChild("NPCs"),
        }

        local melhor, melhord = nil, math.huge

        local function examinar(container)
            if not container then return end
            for _, v in ipairs(container:GetChildren()) do
                if v:IsA("Model") then
                    local bate = false
                    for _, n in ipairs(nomes) do
                        if v.Name:lower():find(n:lower(), 1, true) then
                            bate = true break
                        end
                    end
                    if bate then
                        local h  = v:FindFirstChildOfClass("Humanoid")
                        local mp = v:FindFirstChild("HumanoidRootPart")
                            or v.PrimaryPart
                        if h and mp and h.Health > 0 then
                            local ok, pos = pcall(function() return mp.Position end)
                            if ok and pos then
                                local d = (pos - root.Position).Magnitude
                                if d < melhord then melhor, melhord = v, d end
                            end
                        end
                    end
                end
            end
        end

        -- 1) containers conhecidos
        for _, c in ipairs(containers) do examinar(c) end
        -- 2) fallback: varre a Workspace inteira (custo maior, so se preciso)
        if not melhor then examinar(Services.Workspace) end

        return melhor, melhord
    end

    local function ir_para_ilha(nome)
        local ilha = Services.Workspace:FindFirstChild(nome, true)
        if not ilha then return false end
        local ponto = ilha:FindFirstChild("SpawnPoint")
            or ilha:FindFirstChild("Spawn")
            or ilha:FindFirstChildWhichIsA("BasePart")
        if not ponto then return false end
        local root = Services.Root
        if root and (ponto.Position - root.Position).Magnitude < 80 then
            return true
        end
        return Tween.to(ponto.Position, 340, 30)
    end

    -- Assinatura real do Blox Fruits: ("StartQuest", npc, level)
    -- Nao tentamos variacoes: isso spamma o servidor e arrisca kick.
    --
    -- O nome do NPC na tabela pode estar desatualizado (o jogo muda os
    -- nomes nos patches). Se falhar, procuramos um NPC de quest por perto
    -- e tentamos com o nome real encontrado no jogo.
    local npc_cache = {}

    local function achar_npc_quest(ilha)
        local ws = Services.Workspace
        local raiz = ilha and ws:FindFirstChild(ilha, true) or ws
        if not raiz then return nil end
        local root = Services.Root
        local melhor, melhord = nil, math.huge
        for _, v in ipairs(raiz:GetDescendants()) do
            if v:IsA("Model") or v:IsA("BasePart") then
                local n = v.Name:lower()
                if n:find("quest") or n:find("giver") or n:find("dealer")
                   or n:find("owner") or n:find("blacksmith") then
                    local p = v:FindFirstChild("HumanoidRootPart")
                        or (v:IsA("BasePart") and v)
                    if p and root then
                        local ok, pos = pcall(function() return p.Position end)
                        if ok and pos then
                            local d = (pos - root.Position).Magnitude
                            if d < melhord then melhor, melhord = v.Name, d end
                        end
                    end
                end
            end
        end
        return melhor
    end

    local function aceitar_quest(q)
        -- 1) tenta o nome da tabela
        local r, ok = Dump.invoke("StartQuest", q.npc, q.level)
        if ok and r ~= nil then return true end

        -- 2) tenta o nome real do NPC no jogo (com cache por ilha)
        local chave = q.ilha or "?"
        local real = npc_cache[chave]
        if real == nil then
            real = achar_npc_quest(q.ilha) or false
            npc_cache[chave] = real
        end
        if real then
            r, ok = Dump.invoke("StartQuest", real, q.level)
            if ok and r ~= nil then
                if q.npc ~= real then
                    warn(("[LC/Quest] NPC '%s' nao existe; usando '%s'")
                        :format(q.npc, real))
                end
                return true
            end
        end
        return false
    end

    -- ("CompleteQuest") sem argumentos. Tambem aceita ("CompleteQuest", npc)
    -- em versoes antigas; tentamos a forma canonica primeiro.
    local function completar_quest(q)
        local r, ok = Dump.invoke("CompleteQuest")
        if ok then return true end
        r, ok = Dump.invoke("CompleteQuest", q.npc)
        return ok == true
    end

    local function loop()
        while estado.ativo do
            estado.ciclos += 1
            if estado.ciclos % 50 == 0 then Dump.run(true) end

            local lv  = nivel_atual()
            local sea = Quests.detect_sea()
            local q   = Quests.for_level(sea, lv)

            if q and estado.auto_quest then
                ir_para_ilha(q.ilha)
                aceitar_quest(q)

                local t0 = os.clock()
                while estado.ativo and (os.clock() - t0) < 120 do
                    local mob = achar_mob(q.mob)
                    if mob then
                        Hitbox.combat_loop(
                            function() return (achar_mob(q.mob)) end,
                            { raio = 70, modo = estado.modo, distancia = 28 },
                            function() return estado.ativo end)
                    else
                        -- Mob ainda nao spawnou. Espera em vez de desistir -
                        -- o respawn leva alguns segundos.
                        Util.dyn_wait(0.5)
                    end
                end
                completar_quest(q)
            end

            -- Alocar pontos com teto e espera: sem isso, se o servidor
            -- demorar a atualizar Points, isto vira loop infinito.
            local voltas = 0
            while estado.ativo and pontos_livres() > 0 and voltas < 20 do
                voltas += 1
                local n = alocar_stats()
                if n == 0 then break end
            end

            Util.dyn_wait(0.5)
        end
    end

    function Level.start(opcoes)
        if estado.ativo then return end
        estado.ativo = true
        for k, v in pairs(opcoes or {}) do estado[k] = v end
        task.spawn(function() Util.safe(loop) end)
    end

    function Level.stop() estado.ativo = false end
    function Level.config(o) for k, v in pairs(o or {}) do estado[k] = v end end
    function Level.estado() return estado end

    return Level
end)()

-- ============================================================
-- d2
-- ============================================================

REGISTRY["d2"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local Mastery  = {}

    local estado = {
        ativo = false, alvo_nivel = 300, lista = {},
        indice = 1, raio = 60, modo = "seguro",
    }

    local function nivel_arma(nome)
        local d = Services.LocalPlayer:FindFirstChild("Data")
        if not d then return 0 end
        local inv   = d:FindFirstChild("Inventory")
        local tools = inv and inv:FindFirstChild("Tools")
        local t     = tools and tools:FindFirstChild(nome)
        if t then
            local lv = t:FindFirstChild("Level") or t:FindFirstChild("Mastery")
            if lv then return lv.Value end
        end
        local frutas = d:FindFirstChild("Fruits")
            or (inv and inv:FindFirstChild("Fruits"))
        local f = frutas and frutas:FindFirstChild(nome)
        if f then
            local lv = f:FindFirstChild("Mastery") or f:FindFirstChild("Level")
            if lv then return lv.Value end
        end
        local styles = inv and inv:FindFirstChild("Styles")
        local s = styles and styles:FindFirstChild(nome)
        if s then
            local lv = s:FindFirstChild("Level") or s:FindFirstChild("Mastery")
            if lv then return lv.Value end
        end
        return 0
    end

    local function possui(nome)
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local inv = d and d:FindFirstChild("Inventory")
        if not inv then return false end
        for _, cont in ipairs({ "Tools", "Fruits", "Styles" }) do
            local c = inv:FindFirstChild(cont)
            if c and c:FindFirstChild(nome) then return true end
        end
        return false
    end

    local function equipar(nome)
        Dump.invoke("EquipTool", nome)
        Util.dyn_wait(0.4)
    end

    local function proxima()
        for i = estado.indice, #estado.lista do
            local nome = estado.lista[i]
            if possui(nome) and nivel_arma(nome) < estado.alvo_nivel then
                estado.indice = i
                return nome
            end
        end
        return nil
    end

    local function mob_proximo()
        local root = Services.Root
        if not root then return nil end
        local melhor, melhord = nil, estado.raio
        for _, v in ipairs(Services.Workspace:GetChildren()) do
            if v:IsA("Model") and v ~= Services.Character then
                local h  = v:FindFirstChildOfClass("Humanoid")
                local mp = v:FindFirstChild("HumanoidRootPart")
                if h and mp and h.Health > 0 then
                    local d = (mp.Position - root.Position).Magnitude
                    if d < melhord then melhor, melhord = v, d end
                end
            end
        end
        return melhor
    end

    local function loop()
        if #estado.lista == 0 then
            Util.notify("LuaCore", "Mastery: lista vazia", 4)
            estado.ativo = false
            return
        end
        while estado.ativo do
            local arma = proxima()
            if not arma then
                Util.notify("LuaCore", "Mastery maxima", 4)
                estado.ativo = false
                break
            end
            equipar(arma)
            Util.notify("LuaCore",
                ("Mastery: %s (nv %d)"):format(arma, nivel_arma(arma)), 2)

            local t0 = os.clock()
            while estado.ativo and nivel_arma(arma) < estado.alvo_nivel
                  and (os.clock() - t0) < 1800 do
                local mob = mob_proximo()
                if mob then
                    local mp   = mob:FindFirstChild("HumanoidRootPart")
                    local root = Services.Root
                    if mp and root
                       and (mp.Position - root.Position).Magnitude > 40 then
                        Tween.to(mp.Position, 340, 15)
                    end
                    Hitbox.bring_mobs(estado.raio, 10)
                    Hitbox.fast_attack(estado.modo)
                end
                Util.dyn_wait(0.15)
            end
            estado.indice += 1
        end
    end

    function Mastery.start(lista, alvo_nivel, modo)
        if estado.ativo then return end
        estado.ativo = true
        if type(lista) == "table" and #lista > 0 then
            estado.lista = lista
        elseif type(lista) == "string" then
            local l = {}
            for w in lista:gmatch("[^,]+") do
                table.insert(l, (w:gsub("^%s+", ""):gsub("%s+$", "")))
            end
            estado.lista = l
        end
        estado.alvo_nivel = alvo_nivel or estado.alvo_nivel
        estado.modo = modo or estado.modo
        estado.indice = 1
        task.spawn(function() Util.safe(loop) end)
    end

    function Mastery.stop() estado.ativo = false end
    function Mastery.estado() return estado end

    return Mastery
end)()

-- ============================================================
-- d5
-- ============================================================

REGISTRY["d5"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local SeaEvents = {}

    local estado = { ativo = false, eventos = {}, raio = 600, modo = "seguro" }

    local ALVOS = {
        ship = { nomes = { "Pirate Grand Ship", "Pirate Ship",
                           "Marine Ship", "Ship" },
                 tags = { "Ship", "ShipEvent", "PirateShip" } },
        terror = { nomes = { "Terror Shark", "TerrorShark", "Terrorshark" },
                   tags = { "TerrorShark", "SeaEvent" } },
        leviathan = { nomes = { "Leviathan" },
                      tags = { "Leviathan", "SeaEvent" } },
        seabeast = { nomes = { "Sea Beast", "SeaBeast", "Seabeast" },
                     tags = { "SeaBeast", "SeaEvent" } },
    }

    local function bate_nome(nome, lista)
        for _, n in ipairs(lista) do
            if nome:find(n, 1, true) then return true end
        end
        return false
    end

    local function vivo(model)
        local h = model:FindFirstChildOfClass("Humanoid")
        if not h then
            local hp = model:GetAttribute("Health")
            return hp == nil or hp > 0
        end
        return h.Health > 0
    end

    local function tem_tag(model, tags)
        for _, t in ipairs(tags) do
            if Services.CollectionService:HasTag(model, t) then return true end
        end
        return false
    end

    local function achar(tipo)
        local cfg = ALVOS[tipo]
        if not cfg then return nil end
        local root = Services.Root
        if not root then return nil end

        local melhor, melhord = nil, estado.raio

        local function considerar(model)
            if not model:IsA("Model") then return end
            if model == Services.Character then return end
            if not (bate_nome(model.Name, cfg.nomes)
                    or tem_tag(model, cfg.tags)) then return end
            if not vivo(model) then return end
            local mp = model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart")
            if not mp then return end
            local d = (mp.Position - root.Position).Magnitude
            if d < melhord then melhor, melhord = model, d end
        end

        for _, v in ipairs(Services.Workspace:GetChildren()) do considerar(v) end
        for _, t in ipairs(cfg.tags) do
            for _, m in ipairs(Services.CollectionService:GetTagged(t)) do
                considerar(m)
            end
        end
        return melhor, melhord
    end

    local function atacar(alvo, timeout)
        local root = Services.Root
        if not (root and alvo and alvo.Parent) then return end
        local mp = alvo:FindFirstChild("HumanoidRootPart")
            or alvo:FindFirstChildWhichIsA("BasePart")
        if not mp then return end

        local t0 = os.clock()
        while estado.ativo and alvo.Parent and vivo(alvo)
              and (os.clock() - t0) < (timeout or 120) do
            if (mp.Position - root.Position).Magnitude > 40 then
                Tween.to(mp.Position, 380, 20)
            end
            Hitbox.bring_mobs(50, 8)
            Hitbox.fast_attack(estado.modo)
            Util.dyn_wait(0.2)
        end
    end

    local function loop()
        while estado.ativo do
            local algum = false
            for tipo, ligado in pairs(estado.eventos) do
                if ligado and estado.ativo then
                    local alvo = achar(tipo)
                    if alvo then
                        algum = true
                        Util.notify("LuaCore", "Evento: " .. tipo, 3)
                        atacar(alvo)
                    end
                end
            end
            Util.dyn_wait(algum and 0.5 or 1.5)
        end
    end

    function SeaEvents.start(ligados)
        if estado.ativo then return end
        estado.ativo = true
        estado.eventos = ligados or { terror = true, seabeast = true }
        task.spawn(function() Util.safe(loop) end)
    end

    function SeaEvents.stop() estado.ativo = false end
    function SeaEvents.toggle(tipo, ligado) estado.eventos[tipo] = ligado end
    function SeaEvents.estado() return estado end

    return SeaEvents
end)()

-- ============================================================
-- d4
-- ============================================================

REGISTRY["d4"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Env      = require_mod("a3")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local Raids    = {}

    local estado = {
        ativo = false, fruta = "Dough", auto_awaken = true,
        chip_extra = false, modo = "seguro",
    }

    local function beli()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local b = d and d:FindFirstChild("Beli")
        return b and b.Value or 0
    end

    local function tem_chip()
        local lp = Services.LocalPlayer
        local ok, v = pcall(function() return lp:GetAttribute("RaidChip") end)
        if ok and v then return true end
        local d = lp:FindFirstChild("Data")
        local inv = d and d:FindFirstChild("Inventory")
        local c = inv and inv:FindFirstChild("RaidChip")
        return c ~= nil
    end

    local function comprar_chip()
        if tem_chip() and not estado.chip_extra then return true end
        if beli() < 100000 then return false end
        -- Forma canonica: ("RaidsNpc", "Select", fruta) compra o chip.
        local _, ok = Dump.invoke("RaidsNpc", "Select", estado.fruta)
        if ok then
            Util.dyn_wait(0.8)
            return true
        end
        return false
    end

    local function achar_portal()
        for _, nome in ipairs({ "Raids", "RaidPortal", "Raid", "Portal" }) do
            local p = Services.Workspace:FindFirstChild(nome, true)
            if p then
                local parte = p:IsA("BasePart") and p
                    or p:FindFirstChildWhichIsA("BasePart")
                if parte then return parte end
            end
        end
        return nil
    end

    local function entrar_portal()
        local portal = achar_portal()
        if portal then
            local root = Services.Root
            if root and (portal.Position - root.Position).Magnitude > 20 then
                Tween.to(portal.Position, 340, 20)
            end
            Env.touch(Services.Root, portal, 0)
            Env.touch(Services.Root, portal, 1)
        end
        -- Forma canonica: ("RaidsNpc", "Teleport")
        local _, ok = Dump.invoke("RaidsNpc", "Teleport")
        return ok == true
    end

    local function achar_ilha(i)
        return Services.Workspace:FindFirstChild("Island " .. i, true)
            or Services.Workspace:FindFirstChild("Island" .. i, true)
    end

    local function dentro_da_raid()
        for i = 1, 5 do
            if achar_ilha(i) then return true end
        end
        return false
    end

    local function limpar_ilha(ilha)
        local root = Services.Root
        if not root then return false end
        local t0 = os.clock()
        while estado.ativo and (os.clock() - t0) < 90 do
            local mob, mp = nil, nil
            for _, v in ipairs(ilha:GetDescendants()) do
                if v:IsA("Model") then
                    local h = v:FindFirstChildOfClass("Humanoid")
                    local p = v:FindFirstChild("HumanoidRootPart")
                    if h and p and h.Health > 0 then mob, mp = v, p break end
                end
            end
            if not mob then return true end
            if (mp.Position - root.Position).Magnitude > 35 then
                Tween.to(mp.Position, 360, 20)
            end
            Hitbox.bring_mobs(50, 8)
            Hitbox.fast_attack(estado.modo)
            Util.dyn_wait(0.2)
        end
        return false
    end

    local function limpar_todas()
        for i = 1, 5 do
            if not estado.ativo then return false end
            local ilha = achar_ilha(i)
            if ilha then
                Util.notify("LuaCore", "Raid: " .. ilha.Name, 2)
                limpar_ilha(ilha)
            end
        end
        return true
    end

    local function awaken()
        if not estado.auto_awaken then return true end
        for skill = 1, 8 do
            Dump.invoke("BuySkill", skill)
            Util.dyn_wait(0.4)
        end
        pcall(function()
            local pg = Services.LocalPlayer:FindFirstChild("PlayerGui")
            local main = pg and (pg:FindFirstChild("Main")
                or pg:FindFirstChild("MainGui"))
            local menu = main and main:FindFirstChild("Awaken", true)
            if menu then
                for _, b in ipairs(menu:GetDescendants()) do
                    if b:IsA("TextButton") or b:IsA("ImageButton") then
                        local ok = pcall(function() b:Activate() end)
                        if not ok then
                            Env.click(b)
                        end
                    end
                end
            end
        end)
        return true
    end

    local function loop()
        while estado.ativo do
            if dentro_da_raid() then
                limpar_todas()
                awaken()
                Util.dyn_wait(2)
            else
                if comprar_chip() then
                    entrar_portal()
                    Util.dyn_wait(3)
                    if dentro_da_raid() then
                        limpar_todas()
                        awaken()
                        Util.dyn_wait(2)
                    else
                        Util.dyn_wait(1)
                    end
                else
                    Util.notify("LuaCore", "Raid: sem Beli para o chip", 3)
                    Util.dyn_wait(5)
                end
            end
        end
    end

    function Raids.start(fruta, opcoes)
        if estado.ativo then return end
        estado.ativo = true
        estado.fruta = fruta or estado.fruta
        for k, v in pairs(opcoes or {}) do estado[k] = v end
        task.spawn(function() Util.safe(loop) end)
    end

    function Raids.stop() estado.ativo = false end
    function Raids.estado() return estado end

    return Raids
end)()

-- ============================================================
-- e2
-- ============================================================

REGISTRY["e2"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Env      = require_mod("a3")
    local Tween    = require_mod("c2")
    local Sniper   = {}

    local estado = {
        ativo = false, esp = true, auto_coletar = false,
        -- Sem teto de distancia: a fruta pode nascer em qualquer ilha.
        -- math.huge significa "sem limite". Os sliders da UI ajustam estes
        -- valores; o padrao global garante cobertura de todo o mapa.
        raio_esp = math.huge, raio_coleta = math.huge,
    }

    local marcados, conns = {}, {}

    local NOMES_FRUTA = {
        "Fruit", "Blox Fruit", "FruitSpawner", "FruitDealer", "RandomFruit",
    }

    local function eh_fruta(obj)
        if obj:IsA("Tool") then
            if obj:GetAttribute("Fruit") then return true end
            if obj:GetAttribute("IsFruit") then return true end
            for _, n in ipairs(NOMES_FRUTA) do
                if obj.Name:find(n, 1, true) then return true end
            end
        end
        -- Alguns spawns vem como Model com Handle e atributo de fruta.
        if obj:IsA("Model") then
            if obj:GetAttribute("Fruit") or obj:GetAttribute("IsFruit") then
                return true
            end
            if obj.Name:find("Fruit", 1, true) then return true end
        end
        return false
    end

    -- Verdadeiro se a fruta esta dentro do raio configurado.
    -- raio nil ou <= 0 ou math.huge => sem limite (mapa inteiro).
    local function dentro_do_raio(dist, raio)
        if raio == nil or raio <= 0 or raio == math.huge then return true end
        return dist <= raio
    end

    local function handle_de(obj)
        return obj:FindFirstChild("Handle")
            or obj:FindFirstChildWhichIsA("BasePart")
    end

    local function marcar(fruta)
        if marcados[fruta] then return end
        local h = handle_de(fruta)
        if not h then return end

        local bg = Instance.new("BillboardGui")
        bg.Name = "LCESP"
        bg.Size = UDim2.new(0, 200, 0, 52)
        bg.AlwaysOnTop = true
        bg.StudsOffset = Vector3.new(0, 3.5, 0)
        bg.Adornee = h
        bg.Parent = h

        local fundo = Instance.new("Frame")
        fundo.Size = UDim2.new(1, 0, 1, 0)
        fundo.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
        fundo.BackgroundTransparency = 0.25
        fundo.BorderSizePixel = 0
        fundo.Parent = bg

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = fundo

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 90, 120)
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.Parent = fundo

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 1)
        layout.Parent = fundo

        local nome_lbl = Instance.new("TextLabel")
        nome_lbl.Size = UDim2.new(1, -8, 0, 20)
        nome_lbl.BackgroundTransparency = 1
        nome_lbl.TextColor3 = Color3.fromRGB(255, 110, 140)
        nome_lbl.Font = Enum.Font.GothamBold
        nome_lbl.TextSize = 14
        nome_lbl.Text = fruta.Name
        nome_lbl.LayoutOrder = 1
        nome_lbl.Parent = fundo

        local dist_lbl = Instance.new("TextLabel")
        dist_lbl.Size = UDim2.new(1, -8, 0, 16)
        dist_lbl.BackgroundTransparency = 1
        dist_lbl.TextColor3 = Color3.fromRGB(210, 210, 218)
        dist_lbl.Font = Enum.Font.Code
        dist_lbl.TextSize = 12
        dist_lbl.Text = "--"
        dist_lbl.LayoutOrder = 2
        dist_lbl.Parent = fundo

        local conn = fruta.AncestryChanged:Connect(function()
            if not fruta.Parent then
                pcall(function() bg:Destroy() end)
                marcados[fruta] = nil
            end
        end)
        marcados[fruta] = { gui = bg, conn = conn, dist = dist_lbl }
    end

    local function atualizar_distancias()
        local root = Services.Root
        if not root then return end
        for fruta, d in pairs(marcados) do
            local h = handle_de(fruta)
            if h then
                d.dist.Text = ("%.0f studs"):format(
                    (h.Position - root.Position).Magnitude)
            end
        end
    end

    local function coletar(fruta)
        local root = Services.Root
        local h = handle_de(fruta)
        if not (root and h) then return false end

        local okp, pos = pcall(function() return h.Position end)
        if not okp or not pos then return false end

        local dist = (pos - root.Position).Magnitude

        -- Fruta LONGEE: tween nao chega (e trava se o mapa nao estiver
        -- carregado). Teleportamos direto para o lado dela.
        if dist > 200 then
            pcall(function()
                root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            end)
            task.wait(0.35)
        elseif dist > 10 then
            pcall(function() Tween.to(pos, 400, 25) end)
        end

        -- Tentar pegar: touch + comando, algumas vezes.
        for _ = 1, 3 do
            Env.touch(root, h, 0)
            task.wait(0.05)
            Env.touch(root, h, 1)
            Dump.invoke("PickupFruit", fruta)
            task.wait(0.2)
            if not fruta.Parent
               or not fruta:IsDescendantOf(Services.Workspace) then
                return true
            end
        end
        return false
    end

    -- Coleta GLOBAL: percorre a Workspace inteira (incluindo pastas e
    -- ilhas distantes) procurando frutas no chao.
    local function varrer_existentes()
        local root = Services.Root
        local achados = {}

        -- 1) Workspace direta (spawn mais comum)
        for _, obj in ipairs(Services.Workspace:GetChildren()) do
            if eh_fruta(obj) then achados[#achados + 1] = obj end
        end

        -- 2) Descendentes: cobre frutas dentro de pastas/ilhas
        local ok, desc = pcall(function()
            return Services.Workspace:GetDescendants()
        end)
        if ok and desc then
            for _, obj in ipairs(desc) do
                if eh_fruta(obj) then achados[#achados + 1] = obj end
            end
        end

        for _, obj in ipairs(achados) do
            local d = math.huge
            local h = handle_de(obj)
            if h and root then
                local okp, pos = pcall(function() return h.Position end)
                if okp and pos then d = (pos - root.Position).Magnitude end
            end

            if estado.esp and dentro_do_raio(d, estado.raio_esp) then
                marcar(obj)
            end
            if estado.auto_coletar and dentro_do_raio(d, estado.raio_coleta) then
                coletar(obj)
            end
        end
    end

    local function loop()
        -- Observar spawns em QUALQUER nivel da arvore, nao so na raiz.
        table.insert(conns, Services.Workspace.DescendantAdded:Connect(function(obj)
            if not estado.ativo then return end
            if eh_fruta(obj) then
                if estado.esp then marcar(obj) end
                if estado.auto_coletar then
                    task.spawn(function() Util.safe(function() coletar(obj) end) end)
                end
            end
        end))
        while estado.ativo do
            pcall(varrer_existentes)
            pcall(atualizar_distancias)
            Util.dyn_wait(0.6)
        end
    end

    function Sniper.start()
        if estado.ativo then return end
        estado.ativo = true
        task.spawn(function() Util.safe(loop) end)
    end

    function Sniper.stop()
        estado.ativo = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for i = #conns, 1, -1 do conns[i] = nil end
        for fruta, d in pairs(marcados) do
            pcall(function() d.gui:Destroy() d.conn:Disconnect() end)
            marcados[fruta] = nil
        end
    end

    function Sniper.config(o) for k, v in pairs(o or {}) do estado[k] = v end end
    function Sniper.estado() return estado end

    return Sniper
end)()

-- ============================================================
-- e3
-- ============================================================

REGISTRY["e3"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Store    = {}

    local estado = { ativo = false, incluir_frutas = true, incluir_tools = false }

    local function eh_fruta(t)
        if not t:IsA("Tool") then return false end
        if t:GetAttribute("Fruit") or t:GetAttribute("IsFruit") then
            return true
        end
        local nome = t.Name:lower()
        local palavras = { "fruit", "dough", "leopard", "dragon", "kitsune",
                           "venom", "shadow", "control", "spirit", "buddha",
                           "portal", "rumble", "blizzard", "pain", "gas" }
        for _, p in ipairs(palavras) do
            if nome:find(p, 1, true) then return true end
        end
        return false
    end

    local function containers()
        local lp  = Services.LocalPlayer
        local out = {}
        local bag = lp:FindFirstChild("Backpack")
        if bag then table.insert(out, bag) end
        if lp.Character then table.insert(out, lp.Character) end
        return out
    end

    -- Re-varredura completa a cada chamada: o inventario muda enquanto
    -- guardamos, e uma lista velha tentaria guardar tools que ja sairam.
    local function listar()
        local out, vistos = {}, {}
        for _, cont in ipairs(containers()) do
            local ok, filhos = pcall(function() return cont:GetChildren() end)
            if ok and filhos then
                for _, t in ipairs(filhos) do
                    if t:IsA("Tool") and not vistos[t] then
                        if (estado.incluir_frutas and eh_fruta(t))
                           or (estado.incluir_tools and not eh_fruta(t)) then
                            vistos[t] = true
                            table.insert(out, t)
                        end
                    end
                end
            end
        end
        return out
    end

    -- True se a tool realmente saiu do jogador.
    local function saiu(tool)
        if not tool or not tool.Parent then return true end
        local ok, dentro = pcall(function()
            return tool:IsDescendantOf(Services.LocalPlayer)
        end)
        return not (ok and dentro)
    end

    -- Guardar com CONFIRMACAO. O Blox Fruits devolve nil mesmo em sucesso e
    -- as vezes leva um instante para remover a tool. Tentamos varias vezes
    -- ate a remocao ser confirmada de fato.
    local TENTATIVAS = 6

    local function guardar(tool)
        if not tool or not tool.Parent then return true end
        local nome = tool.Name

        for tentativa = 1, TENTATIVAS do
            if saiu(tool) then return true end

            -- Forma canonica: ("StoreFruit", nome).
            Dump.invoke("StoreFruit", nome)
            -- Variante usada em alguns patches quando a fruta esta equipada.
            if tentativa >= 3 and tentativa <= 4 then
                Dump.invoke("StoreFruit", nome, true)
            end

            -- Espera crescente: 0.25, 0.5, 0.75...
            local espera = 0.25 * tentativa
            local t0 = os.clock()
            while (os.clock() - t0) < espera do
                if saiu(tool) then return true end
                Util.dyn_wait(0.05)
            end
        end

        return saiu(tool)
    end

    local function loop()
        local falhas_seguidas = 0
        while estado.ativo do
            local tools = listar()
            local guardados = 0

            for _, t in ipairs(tools) do
                if not estado.ativo then break end
                local nome = t.Name
                if guardar(t) then
                    guardados += 1
                    falhas_seguidas = 0
                    Util.notify("LuaCore", "Guardado: " .. nome, 2)
                else
                    falhas_seguidas += 1
                    -- Se nao consegue guardar nada, provavelmente falta
                    -- espaco ou o comando mudou. Avisa uma vez e espera mais.
                    if falhas_seguidas == 3 then
                        warn("[LC/Store] nao consegui guardar '" .. nome ..
                             "'. Inventario cheio ou comando mudou.")
                    end
                end
                Util.dyn_wait(0.4)
            end

            -- Se guardamos algo, volta imediatamente: pode ter mais.
            if guardados == 0 then
                Util.dyn_wait(falhas_seguidas >= 3 and 5.0 or 1.5)
            end
        end
    end

    function Store.start(opcoes)
        if estado.ativo then return end
        estado.ativo = true
        for k, v in pairs(opcoes or {}) do estado[k] = v end
        task.spawn(function() Util.safe(loop) end)
    end

    function Store.stop() estado.ativo = false end
    function Store.estado() return estado end
    function Store.listar() return listar() end
    function Store.guardar_agora(tool) return guardar(tool or listar()[1]) end

    return Store
end)()

-- ============================================================
-- e1
-- ============================================================

REGISTRY["e1"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Gacha    = {}

    local estado = {
        ativo = false, preco_max = 100000, intervalo = 60,
        max_beli_guardar = 500000,
    }

    local ultima_compra = 0
    local COOLDOWN = 60 * 60

    local function beli()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local b = d and d:FindFirstChild("Beli")
        return b and b.Value or 0
    end

    local function cooldown_restante()
        local lp = Services.LocalPlayer
        local ok, v = pcall(function()
            return lp:GetAttribute("RandomFruitCooldown")
        end)
        if ok and type(v) == "number" then return v end
        return math.max(0, COOLDOWN - (os.clock() - ultima_compra))
    end

    local function tem_espaco()
        local d = Services.LocalPlayer:FindFirstChild("Data")
        local inv = d and d:FindFirstChild("Inventory")
        local fruits = inv and inv:FindFirstChild("Fruits")
        if not fruits then return true end
        return #fruits:GetChildren() < 20
    end

    local function comprar()
        -- Forma canonica do Blox Fruits para a fruta aleatoria do Cousin.
        -- NAO tentamos varias variantes: cada tentativa e um comando real
        -- enviado ao servidor, e spam de comando arrisca kick.
        local _, ok = Dump.invoke("Cousin", "Buy")
        if ok then
            ultima_compra = os.clock()
            Util.notify("LuaCore", "Gacha: fruta comprada", 3)
            return true
        end
        -- Fallback: alguns patches usam o hub de dialogo em vez do Cousin.
        _, ok = Dump.invoke("Cousin")
        if ok then
            ultima_compra = os.clock()
            Util.notify("LuaCore", "Gacha: fruta comprada", 3)
            return true
        end
        return false
    end

    local function loop()
        while estado.ativo do
            local cd = cooldown_restante()
            if cd > 0 then
                Util.dyn_wait(math.min(cd, estado.intervalo))
            elseif beli() < estado.preco_max + estado.max_beli_guardar then
                Util.dyn_wait(estado.intervalo)
            elseif not tem_espaco() then
                Util.notify("LuaCore", "Gacha: inventario cheio", 3)
                Util.dyn_wait(60)
            else
                comprar()
                Util.dyn_wait(estado.intervalo)
            end
        end
    end

    function Gacha.start(opcoes)
        if estado.ativo then return end
        estado.ativo = true
        for k, v in pairs(opcoes or {}) do estado[k] = v end
        task.spawn(function() Util.safe(loop) end)
    end

    function Gacha.stop() estado.ativo = false end
    function Gacha.estado() return estado end

    return Gacha
end)()

-- ============================================================
-- f2
-- ============================================================

REGISTRY["f2"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Env      = require_mod("a3")
    local Tween    = require_mod("c2")
    local Calibrador = {}

    local function normaliza(v, s)
        local r = v % s
        if r < 0 then r += s end
        return r
    end

    local function listar_gears(container)
        local gears = {}
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("Model") and v.Name:find("Gear", 1, true) then
                table.insert(gears, v)
            end
        end
        if #gears == 0 then
            for _, tag in ipairs({ "Gear", "MirageGear" }) do
                for _, g in ipairs(Services.CollectionService:GetTagged(tag)) do
                    table.insert(gears, g)
                end
            end
        end
        table.sort(gears, function(a, b) return a.Name < b.Name end)
        return gears
    end

    local function ler_estado(gear, s)
        local ok, v = pcall(function() return gear:GetAttribute("State") end)
        if ok and type(v) == "number" then return normaliza(v, s) end
        ok, v = pcall(function() return gear:GetAttribute("Rotation") end)
        if ok and type(v) == "number" then return normaliza(v, s) end
        ok, v = pcall(function() return gear:GetAttribute("Index") end)
        if ok and type(v) == "number" then return normaliza(v, s) end
        local p = gear:FindFirstChildWhichIsA("BasePart") or gear.PrimaryPart
        if p then
            local _, y = p.CFrame:ToOrientation()
            return math.floor(((math.deg(y) % 360) / (360 / s)) + 0.5) % s
        end
        return 0
    end

    local function clicar(gear)
        local root = Services.Root
        local p = gear:FindFirstChildWhichIsA("BasePart") or gear.PrimaryPart
        if p and root then
            if (p.Position - root.Position).Magnitude > 12 then
                Tween.to(p.Position, 320, 12)
            end
        end

        local prompt = gear:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            -- Env.prompt cai para InputHold nativo se o executor nao tiver
            -- fireproximityprompt (comum no Delta mobile).
            Env.prompt(prompt)
            return true
        end

        local cd = gear:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then
            Env.click(cd)
            return true
        end

        if p and root then
            Env.touch(root, p, 0)
            task.wait(0.05)
            Env.touch(root, p, 1)
            return true
        end
        return false
    end

    function Calibrador.calibrar(container, opcoes)
        opcoes = opcoes or {}
        local S     = opcoes.n_estados or 3
        local pausa = opcoes.pausa or 0.45
        local conf  = opcoes.confirmacoes or 2

        local gears = listar_gears(container)
        local n = #gears
        if n == 0 then return nil, "sem gears" end

        Util.notify("LuaCore",
            ("Calibrando %d gears (S=%d)..."):format(n, S), 3)

        local acoplamento = {}
        local observacoes = {}

        for i = 1, n do
            local pre = {}
            for j, g in ipairs(gears) do pre[j] = ler_estado(g, S) end

            clicar(gears[i])
            task.wait(pausa)

            local leituras = {}
            for _ = 1, conf do
                local leitura = {}
                for j, g in ipairs(gears) do leitura[j] = ler_estado(g, S) end
                table.insert(leituras, leitura)
                task.wait(0.12)
            end

            local pos_final = {}
            for j = 1, n do
                local vals = {}
                for _, l in ipairs(leituras) do table.insert(vals, l[j]) end
                table.sort(vals)
                pos_final[j] = vals[math.ceil(#vals / 2)]
            end

            observacoes[i] = {}
            for j = 1, n do
                observacoes[i][j] = normaliza(pos_final[j] - pre[j], S)
            end

            if i % 3 == 0 then
                Util.notify("LuaCore",
                    ("Calibracao: %d/%d"):format(i, n), 1.5)
            end
        end

        for i = 1, n do
            acoplamento[i] = {}
            for j = 1, n do acoplamento[i][j] = observacoes[i][j] end
        end

        local suspeitos = {}
        for i = 1, n do
            if acoplamento[i][i] ~= 1 then
                table.insert(suspeitos,
                    ("gear %d avanca %d (esperado 1)")
                    :format(i, acoplamento[i][i]))
            end
        end

        Util.notify("LuaCore",
            ("Calibracao concluida. %d avisos."):format(#suspeitos), 3)
        for _, s in ipairs(suspeitos) do warn("[LC/Gear] " .. s) end

        return {
            acoplamento = acoplamento, n_estados = S, n_gears = n,
            observacoes = observacoes, suspeitos = suspeitos,
        }
    end

    function Calibrador.validar(container, modelo, opcoes)
        opcoes = opcoes or {}
        local S = modelo.n_estados
        local pausa = opcoes.pausa or 0.45
        local gears = listar_gears(container)
        local erros = 0

        for i = 1, #gears do
            local pre = {}
            for j, g in ipairs(gears) do pre[j] = ler_estado(g, S) end
            clicar(gears[i])
            task.wait(pausa)
            for j, g in ipairs(gears) do
                local d_obs = normaliza(ler_estado(g, S) - pre[j], S)
                local d_esp = modelo.acoplamento[i][j]
                if d_obs ~= d_esp then
                    erros += 1
                    warn(("[LC/Gear] diverg. clique %d gear %d: %d vs %d")
                        :format(i, j, d_obs, d_esp))
                end
            end
        end
        return erros == 0, erros
    end

    function Calibrador.para_solver(modelo)
        local ac = {}
        for i, linha in pairs(modelo.acoplamento) do
            ac[i] = {}
            for j, delta in pairs(linha) do
                if j ~= i and delta ~= 0 then ac[i][j] = delta end
            end
        end
        return { acoplamento = ac, n_estados = modelo.n_estados,
                 n_gears = modelo.n_gears }
    end

    function Calibrador.listar_gears(container) return listar_gears(container) end
    Calibrador.normaliza  = normaliza
    Calibrador.ler_estado = ler_estado
    Calibrador.clicar     = clicar

    return Calibrador
end)()

-- ============================================================
-- f3
-- ============================================================

REGISTRY["f3"] = (function()
    local Services   = require_mod("a4")
    local Util       = require_mod("a6")
    local Dump       = require_mod("a2")
    local Tween      = require_mod("c2")
    local Calibrador = require_mod("f2")
    local RaceV4     = {}

    local estado = {
        ativo = false, auto_mirage = true, auto_gear = true,
        auto_trial = true, ultima_mirage = 0, modelo_gear = nil, n_estados = 3,
    }

    local Solver = {}

    local function normaliza(v, s)
        local r = v % s
        if r < 0 then r += s end
        return r
    end

    local function chave(vetor) return table.concat(vetor, ",") end

    function Solver.resolver(p)
        local inicial = {}
        for i = 1, p.n do
            inicial[i] = normaliza(p.estado_inicial[i] or 0, p.s)
        end

        local igual = true
        for i = 1, p.n do
            if inicial[i] ~= normaliza(p.alvo[i], p.s) then
                igual = false break
            end
        end
        if igual then return {} end

        local fila = { { estado = inicial, caminho = {} } }
        p.visitados = { [chave(inicial)] = true }
        local cabeca = 1

        while cabeca <= #fila do
            local no = fila[cabeca]
            cabeca += 1
            if cabeca > 200000 then return nil, "espaco grande demais" end

            for clique = 1, p.n do
                local prox = {}
                for k, v in ipairs(no.estado) do prox[k] = v end
                prox[clique] = normaliza(prox[clique] + 1, p.s)

                if p.acoplamento then
                    for j, delta in pairs(p.acoplamento[clique] or {}) do
                        prox[j] = normaliza(prox[j] + delta, p.s)
                    end
                end

                local k = chave(prox)
                if not p.visitados[k] then
                    p.visitados[k] = true
                    local caminho = {}
                    for ci, cv in ipairs(no.caminho) do caminho[ci] = cv end
                    table.insert(caminho, clique)

                    local ok = true
                    for i = 1, p.n do
                        if prox[i] ~= normaliza(p.alvo[i], p.s) then
                            ok = false break
                        end
                    end
                    if ok then return caminho end

                    table.insert(fila, { estado = prox, caminho = caminho })
                end
            end
        end
        return nil, "sem solucao"
    end

    local function achar_mirage()
        for _, nome in ipairs({ "Mirage", "MirageIsland", "Sphinx",
                                "SphinxIsland" }) do
            local m = Services.Workspace:FindFirstChild(nome, true)
            if m then return m end
        end
        for _, tag in ipairs({ "Mirage", "MirageIsland", "Sphinx" }) do
            local t = Services.CollectionService:GetTagged(tag)
            if #t > 0 then return t[1] end
        end
        return nil
    end

    local function lua_cheia()
        local ct = Services.Lighting.ClockTime
        local noite = (ct >= 18) or (ct < 6)
        local ok, force = pcall(function()
            return Services.Workspace:GetAttribute("FullMoon")
                or Services.LocalPlayer:GetAttribute("FullMoon")
        end)
        return noite or (ok and force == true)
    end

    local function ler_estado(gear, s)
        return Calibrador.ler_estado(gear, s)
    end

    local function ler_alvo(gear, s)
        local ok, v = pcall(function() return gear:GetAttribute("Target") end)
        if ok and type(v) == "number" then return normaliza(v, s) end
        ok, v = pcall(function() return gear:GetAttribute("Solution") end)
        if ok and type(v) == "number" then return normaliza(v, s) end
        return 0
    end

    local function resolver_gear(mirage)
        local gears = Calibrador.listar_gears(mirage)
        if #gears == 0 then return false, "sem gears" end

        local n, S = #gears, estado.n_estados
        local inicial, alvo = {}, {}
        for i, g in ipairs(gears) do
            inicial[i] = ler_estado(g, S)
            alvo[i]    = ler_alvo(g, S)
        end

        local p = { n = n, s = S, alvo = alvo, estado_inicial = inicial }
        if estado.modelo_gear then
            p.acoplamento =
                Calibrador.para_solver(estado.modelo_gear).acoplamento
        end

        local caminho, err = Solver.resolver(p)
        if not caminho then
            Util.notify("LuaCore", "Gear: " .. tostring(err), 3)
            return false, err
        end

        Util.notify("LuaCore",
            ("Gear: %d cliques%s"):format(#caminho,
                estado.modelo_gear and " (calibrado)" or ""), 3)

        for _, idx in ipairs(caminho) do
            if not estado.ativo then return false, "cancelado" end
            local g = gears[idx]
            if g then
                Calibrador.clicar(g)
                Util.dyn_wait(0.45)
            end
        end
        return true
    end

    local function trial()
        Dump.invoke("RaceV4", "StartTrial")
        Util.dyn_wait(2)
        Dump.invoke("Dialogue", "Race", "Trial")
    end

    local function loop()
        while estado.ativo do
            local mirage = achar_mirage()
            if mirage then
                local agora = os.clock()
                if agora - estado.ultima_mirage > 20 then
                    Util.notify("LuaCore", "Mirage Island detectada", 4)
                    estado.ultima_mirage = agora
                end

                if estado.auto_mirage then
                    local p = mirage:FindFirstChildWhichIsA("BasePart")
                        or mirage.PrimaryPart
                    if p then
                        local root = Services.Root
                        if root
                           and (p.Position - root.Position).Magnitude > 30 then
                            Tween.to(p.Position, 400, 40)
                        end
                    end
                end

                if estado.auto_gear then resolver_gear(mirage) end
                if estado.auto_trial and lua_cheia() then trial() end
            end
            Util.dyn_wait(2.5)
        end
    end

    function RaceV4.start(opcoes)
        if estado.ativo then return end
        estado.ativo = true
        for k, v in pairs(opcoes or {}) do estado[k] = v end
        task.spawn(function() Util.safe(loop) end)
    end

    function RaceV4.stop() estado.ativo = false end
    function RaceV4.estado() return estado end

    function RaceV4.calibrar(opcoes)
        local mirage = achar_mirage()
        if not mirage then
            Util.notify("LuaCore", "Calibracao: Mirage ausente", 3)
            return false, "sem mirage"
        end
        local modelo, err = Calibrador.calibrar(mirage, opcoes)
        if not modelo then
            Util.notify("LuaCore", "Calibracao falhou: " .. tostring(err), 3)
            return false, err
        end
        estado.modelo_gear = modelo
        estado.n_estados   = modelo.n_estados
        Util.notify("LuaCore", "Modelo de gear ativo", 4)
        return true, modelo
    end

    function RaceV4.modelo() return estado.modelo_gear end
    function RaceV4.limpar_modelo() estado.modelo_gear = nil end

    RaceV4.Solver = Solver
    return RaceV4
end)()

-- ============================================================
-- f4
-- ============================================================

REGISTRY["f4"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Env      = require_mod("a3")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local Weapons  = {}

    Weapons.receitas = {
        Superhuman = { nivel = 300, beli = 3000000, passos = {
            { tipo = "ir", local_nome = "Black Leg" },
            { tipo = "comprar", npc = "Black Leg", item = "Black Leg" },
            { tipo = "coletar", mob = "Bandit", n = 300, raio = 80 },
            { tipo = "comprar", npc = "Martial Arts", item = "Superhuman" },
        }},
        DeathStep = { nivel = 1000, beli = 2500000, passos = {
            { tipo = "coletar", mob = "Reborn Skeleton", n = 500, raio = 80 },
            { tipo = "coletar", item = "Dark Fragment", n = 10 },
            { tipo = "comprar", npc = "Death Step Master",
              item = "Death Step" },
        }},
        SharkmanKarate = { nivel = 1000, beli = 2500000, passos = {
            { tipo = "ir", local_nome = "Underwater City" },
            { tipo = "coletar", mob = "Sharkman", n = 1, raio = 200 },
            { tipo = "coletar", item = "Water Key", n = 1 },
            { tipo = "comprar", npc = "Sharkman Karate Master",
              item = "Sharkman Karate" },
        }},
        ElectricClaw = { nivel = 1500, beli = 3000000, passos = {
            { tipo = "ir", local_nome = "Floating Turtle" },
            { tipo = "coletar", mob = "Marine Commando", n = 500, raio = 90 },
            { tipo = "coletar", item = "Electric Claw", n = 20 },
            { tipo = "comprar", npc = "Electric Claw Master",
              item = "Electric Claw" },
        }},
        DragonTalon = { nivel = 2000, beli = 5000000, passos = {
            { tipo = "coletar", mob = "Dragon Crew", n = 500, raio = 90 },
            { tipo = "coletar", item = "Dragon Talon", n = 1 },
            { tipo = "comprar", npc = "Dragon Talon Master",
              item = "Dragon Talon" },
        }},
        Godhuman = { nivel = 2500, beli = 5000000, passos = {
            { tipo = "coletar", mob = "Pirate Millionaire", n = 500, raio = 90 },
            { tipo = "coletar", item = "Godhuman Fragment", n = 50 },
            { tipo = "ir", local_nome = "Great Tree" },
            { tipo = "comprar", npc = "Godhuman Master", item = "Godhuman" },
        }},
        TTK = { nivel = 1000, beli = 1000000, passos = {
            { tipo = "coletar", item = "Shusui", n = 1 },
            { tipo = "coletar", item = "Saddi",  n = 1 },
            { tipo = "coletar", item = "Wando",  n = 1 },
            { tipo = "comprar", npc = "Legendary Sword Dealer",
              item = "True Triple Katana" },
        }},
        CDK = { nivel = 1500, beli = 2000000, passos = {
            { tipo = "coletar", item = "Cursed Dual Katana", n = 1 },
            { tipo = "ir", local_nome = "Haunted Castle" },
            { tipo = "comprar", npc = "Cursed Dual Katana Master",
              item = "Cursed Dual Katana" },
        }},
        HallowScythe = { nivel = 2000, beli = 2000000, passos = {
            { tipo = "coletar", mob = "Soul Reaper", n = 1, raio = 200 },
            { tipo = "coletar", item = "Hallow Essence", n = 30 },
            { tipo = "comprar", npc = "Hallow Scythe Master",
              item = "Hallow Scythe" },
        }},
        SoulGuitar = { nivel = 2000, beli = 2000000, passos = {
            { tipo = "coletar", mob = "Living Zombie", n = 300, raio = 80 },
            { tipo = "coletar", item = "Soul Fragment", n = 3 },
            { tipo = "comprar", npc = "Soul Guitar Master",
              item = "Soul Guitar" },
        }},
        Canvander = { nivel = 1500, beli = 1500000, passos = {
            { tipo = "ir", local_nome = "Haunted Castle" },
            { tipo = "coletar", item = "Canvander", n = 1 },
            { tipo = "comprar", npc = "Canvander Master", item = "Canvander" },
        }},
    }

    local function achar_local(nome)
        return Services.Workspace:FindFirstChild(nome, true)
    end

    local function ir(local_nome)
        local obj = achar_local(local_nome)
        if not obj then
            Util.notify("LuaCore", "Local ausente: " .. local_nome, 3)
            return false
        end
        local p = obj:IsA("BasePart") and obj
            or obj:FindFirstChildWhichIsA("BasePart")
        if not p then return false end
        local root = Services.Root
        if root and (p.Position - root.Position).Magnitude < 30 then
            return true
        end
        return Tween.to(p.Position, 340, 30)
    end

    local function coletar(mob_nome, n, raio)
        raio = raio or 80
        local mortos, t0 = 0, os.clock()
        while mortos < n and (os.clock() - t0) < 1800 do
            local root = Services.Root
            if not root then
                Util.dyn_wait(0.5)
            else
                local melhor, melhord = nil, raio
                for _, v in ipairs(Services.Workspace:GetChildren()) do
                    if v:IsA("Model") and v.Name:find(mob_nome, 1, true) then
                        local h = v:FindFirstChildOfClass("Humanoid")
                        local p = v:FindFirstChild("HumanoidRootPart")
                        if h and p and h.Health > 0 then
                            local d = (p.Position - root.Position).Magnitude
                            if d < melhord then melhor, melhord = v, d end
                        end
                    end
                end
                if not melhor then
                    Util.dyn_wait(0.8)
                    if mortos > 0 then break end
                else
                    Hitbox.bring_mobs(raio, 10)
                    Hitbox.fast_attack("seguro")
                    mortos += 1
                    if mortos % 25 == 0 then
                        Util.notify("LuaCore",
                            ("%s: %d/%d"):format(mob_nome, mortos, n), 2)
                    end
                end
            end
            Util.dyn_wait(0.2)
        end
        return mortos >= n
    end

    local function contar_item(nome)
        local total = 0
        local function contar(cont)
            if not cont then return end
            for _, v in ipairs(cont:GetDescendants()) do
                if v.Name:find(nome, 1, true) then total += 1 end
            end
        end
        local lp = Services.LocalPlayer
        contar(lp:FindFirstChild("Backpack"))
        contar(lp.Character)
        contar(lp:FindFirstChild("Data"))
        return total
    end

    local function coletar(item, n)
        local t0 = os.clock()
        while contar_item(item) < n and (os.clock() - t0) < 1800 do
            local achou = false
            for _, v in ipairs(Services.Workspace:GetChildren()) do
                if (v:IsA("Model") or v:IsA("Tool"))
                   and v.Name:find(item, 1, true) then
                    local p    = v:FindFirstChildWhichIsA("BasePart")
                    local root = Services.Root
                    if p and root then
                        Tween.to(p.Position, 400, 20)
                        Env.touch(root, p, 0)
                        task.wait(0.05)
                        Env.touch(root, p, 1)
                        achou = true
                    end
                end
            end
            if not achou then
                Util.dyn_wait(1.0)
                Hitbox.fast_attack("seguro")
            end
            Util.dyn_wait(0.3)
        end
        return contar_item(item) >= n
    end

    local function comprar(npc, item)
        -- Forma canonica: ("BuyItem", item).
        -- Confiamos na CONTAGEM real do item, nao no retorno do remote:
        -- o Blox Fruits devolve nil mesmo quando a compra deu certo.
        local antes = contar_item(item)
        local _, ok = Dump.invoke("BuyItem", item)
        if not ok then return false end
        Util.dyn_wait(0.8)
        if contar_item(item) > antes then
            Util.notify("LuaCore", "Comprado: " .. item, 3)
            return true
        end
        return false
    end

    local function executar_passo(passo)
        if passo.tipo == "ir" then
            return ir(passo.local_nome)
        elseif passo.tipo == "coletar" then
            return coletar(passo.mob, passo.n, passo.raio)
        elseif passo.tipo == "coletar" then
            return coletar(passo.item, passo.n)
        elseif passo.tipo == "comprar" then
            return comprar(passo.npc, passo.item)
        elseif passo.tipo == "esperar" then
            Util.dyn_wait(passo.s or 1)
            return true
        end
        return false
    end

    function Weapons.resolver(nome)
        local r = Weapons.receitas[nome]
        if not r then
            Util.notify("LuaCore", "Receita desconhecida: " .. nome, 3)
            return false
        end
        local d  = Services.LocalPlayer:FindFirstChild("Data")
        local lv = d and d:FindFirstChild("Level")
        if r.nivel and lv and lv.Value < r.nivel then
            Util.notify("LuaCore",
                ("Nivel insuf.: %d/%d"):format(lv.Value, r.nivel), 4)
            return false
        end
        Util.notify("LuaCore", "Solver: " .. nome, 3)
        for i, passo in ipairs(r.passos) do
            local ok, err = pcall(executar_passo, passo)
            if not ok then
                warn(("[LC/Weapons] passo %d falhou: %s")
                    :format(i, tostring(err)))
            end
        end
        return true
    end

    local loops = {}
    function Weapons.auto(nome)
        if loops[nome] then return end
        loops[nome] = true
        task.spawn(function()
            while loops[nome] do
                Weapons.resolver(nome)
                Util.dyn_wait(5)
            end
        end)
    end
    function Weapons.parar(nome) loops[nome] = nil end

    return Weapons
end)()

-- ============================================================
-- f1
-- ============================================================

REGISTRY["f1"] = (function()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Tween    = require_mod("c2")
    local Hitbox   = require_mod("c1")
    local Bosses   = {}

    Bosses.defs = {
        saber = { nome = "Saber Expert",
            nomes_alt = { "Saber Expert", "SaberExpert", "Saber" },
            ilha = "Jungle", quest = { npc = "Shanks", level = 1 },
            recompensa = "Saber", nivel_min = 1 },
        ice_admiral = { nome = "Ice Admiral",
            nomes_alt = { "Ice Admiral", "IceAdmiral" },
            ilha = "Marine Fortress",
            quest = { npc = "Military Detective", level = 100 },
            recompensa = "Sea 2 unlock", nivel_min = 100 },
        don_swan = { nome = "Don Swan",
            nomes_alt = { "Don Swan", "DonSwan" },
            ilha = "Kingdom of Rose",
            quest = { npc = "King Red Head", level = 900 },
            recompensa = "Sea 3 unlock", nivel_min = 900 },
        cake_prince = { nome = "Cake Prince",
            nomes_alt = { "Cake Prince", "CakePrince" },
            ilha = "Cake Island",
            quest = { npc = "Cake Queen", level = 2300 },
            requisito_mobs = 500, recompensa = "Drop Cake Prince",
            nivel_min = 2300 },
        dough_king = { nome = "Dough King",
            nomes_alt = { "Dough King", "DoughKing" },
            ilha = "Cake Island",
            quest = { npc = "Dough King Summon", level = 2500 },
            recompensa = "Dough Awaken", nivel_min = 2500 },
        bartilo = { nome = "Bartilo", nomes_alt = { "Bartilo" },
            ilha = "Kingdom of Rose",
            quest = { npc = "Bartilo", level = 850 },
            recompensa = "Flower Quest", nivel_min = 850 },
    }

    local estado_auto_kill = false

    local function nivel()
        local d  = Services.LocalPlayer:FindFirstChild("Data")
        local lv = d and d:FindFirstChild("Level")
        return lv and lv.Value or 1
    end

    local function achar_boss(def)
        for _, v in ipairs(Services.Workspace:GetChildren()) do
            if v:IsA("Model") then
                for _, nome in ipairs(def.nomes_alt) do
                    if v.Name:find(nome, 1, true) then
                        local h = v:FindFirstChildOfClass("Humanoid")
                        if h and h.Health > 0 then return v end
                    end
                end
            end
        end
        return nil
    end

    local function ir_para(nome_local)
        local obj = Services.Workspace:FindFirstChild(nome_local, true)
        if not obj then return false end
        local p = obj:IsA("BasePart") and obj
            or obj:FindFirstChildWhichIsA("BasePart")
        if not p then return false end
        local root = Services.Root
        if root and (p.Position - root.Position).Magnitude < 40 then
            return true
        end
        return Tween.to(p.Position, 340, 30)
    end

    local function iniciar_quest(def)
        if not def.quest then return end
        Dump.invoke("StartQuest", def.quest.npc, def.quest.level)
    end

    local function contar_mobs(n, filtro)
        local mortos, t0 = 0, os.clock()
        while mortos < n and (os.clock() - t0) < 3600 do
            local root = Services.Root
            if not root then
                Util.dyn_wait(0.5)
            else
                local melhor, melhord = nil, 120
                for _, v in ipairs(Services.Workspace:GetChildren()) do
                    if v:IsA("Model") and v ~= Services.Character then
                        local h = v:FindFirstChildOfClass("Humanoid")
                        local p = v:FindFirstChild("HumanoidRootPart")
                        if h and p and h.Health > 0 then
                            local bate = true
                            if filtro then
                                bate = v.Name:find(filtro, 1, true) ~= nil
                            end
                            if bate then
                                local d = (p.Position - root.Position).Magnitude
                                if d < melhord then
                                    melhor, melhord = v, d
                                end
                            end
                        end
                    end
                end
                if melhor then
                    Hitbox.bring_mobs(100, 10)
                    Hitbox.fast_attack("seguro")
                    mortos += 1
                    if mortos % 50 == 0 then
                        Util.notify("LuaCore",
                            ("Mobs: %d/%d"):format(mortos, n), 2)
                    end
                else
                    Util.dyn_wait(0.8)
                end
            end
            Util.dyn_wait(0.15)
        end
        return mortos
    end

    local function matar(boss, timeout)
        local mp = boss:FindFirstChild("HumanoidRootPart")
            or boss:FindFirstChildWhichIsA("BasePart")
        if not mp then return false end
        local t0 = os.clock()
        while boss.Parent and (os.clock() - t0) < (timeout or 300) do
            local h = boss:FindFirstChildOfClass("Humanoid")
            if h and h.Health <= 0 then return true end
            local root = Services.Root
            if root and (mp.Position - root.Position).Magnitude > 35 then
                Tween.to(mp.Position, 360, 20)
            end
            Hitbox.bring_mobs(60, 10)
            Hitbox.fast_attack("seguro")
            Util.dyn_wait(0.2)
        end
        return false
    end

    function Bosses.run(chave, opcoes)
        local def = Bosses.defs[chave]
        if not def then
            Util.notify("LuaCore", "Boss desconhecido: " .. tostring(chave), 3)
            return false
        end
        opcoes = opcoes or {}
        task.spawn(function()
            Util.safe(function()
                if nivel() < (def.nivel_min or 1) then
                    Util.notify("LuaCore",
                        ("Nivel minimo: %d"):format(def.nivel_min), 4)
                    return
                end
                iniciar_quest(def)
                ir_para(def.ilha)

                if def.requisito_mobs and not opcoes.pular_contagem then
                    Util.notify("LuaCore",
                        ("Contando %d mobs"):format(def.requisito_mobs), 3)
                    contar_mobs(def.requisito_mobs, opcoes.filtro_mob)
                end

                Util.notify("LuaCore", "Aguardando: " .. def.nome, 3)
                local boss, t0 = nil, os.clock()
                while not boss and (os.clock() - t0) < 300 do
                    boss = achar_boss(def)
                    if not boss then Util.dyn_wait(1.5) end
                end
                if not boss then
                    Util.notify("LuaCore", "Spawn nao detectado", 3)
                    return
                end
                Util.notify("LuaCore", "Matando: " .. def.nome, 3)
                matar(boss)
                Util.notify("LuaCore",
                    ("%s concluido (%s)"):format(def.nome, def.recompensa), 4)
            end)
        end)
        return true
    end

    local conns = {}
    function Bosses.monitorar(ligado)
        if not ligado then
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            for i = #conns, 1, -1 do conns[i] = nil end
            return
        end
        table.insert(conns, Services.Workspace.ChildAdded:Connect(function(obj)
            if not obj:IsA("Model") then return end
            for chave, def in pairs(Bosses.defs) do
                for _, nome in ipairs(def.nomes_alt) do
                    if obj.Name:find(nome, 1, true) then
                        Util.notify("LuaCore",
                            ("Spawn: %s (%s)"):format(def.nome, chave), 4)
                        if estado_auto_kill then matar(obj) end
                        return
                    end
                end
            end
        end))
    end

    function Bosses.auto_kill(ligado) estado_auto_kill = ligado end

    return Bosses
end)()

-- ============================================================
-- UI/Loader.lua
-- ============================================================

-- ============================================================
-- g3  -  paleta + helpers de construcao nativa
-- Substitui completamente o antigo UI/Loader.lua.
-- Zero HttpGet. Zero dependencia externa. Offline total.
-- ============================================================
REGISTRY["g3"] = (function()
    local Services = require_mod("a4")
    local Theme = {}

    Theme.cor = {
        fundo        = Color3.fromRGB(16, 16, 20),
        fundo_alt    = Color3.fromRGB(22, 22, 28),
        painel       = Color3.fromRGB(20, 20, 26),
        card         = Color3.fromRGB(26, 26, 33),
        card_hover   = Color3.fromRGB(34, 34, 43),
        borda        = Color3.fromRGB(45, 45, 56),
        acento       = Color3.fromRGB(60, 220, 140),
        acento_esc   = Color3.fromRGB(38, 150, 96),
        texto        = Color3.fromRGB(228, 228, 236),
        texto_dim    = Color3.fromRGB(140, 140, 155),
        perigo       = Color3.fromRGB(230, 80, 90),
        aviso        = Color3.fromRGB(240, 180, 70),
        off          = Color3.fromRGB(48, 48, 58),
    }

    Theme.fonte      = Enum.Font.Gotham
    Theme.fonte_bold = Enum.Font.GothamBold
    Theme.fonte_mono = Enum.Font.Code

    -- Arredondamento padrao
    function Theme.cantos(obj, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = obj
        return c
    end

    function Theme.contorno(obj, cor, esp, transp)
        local s = Instance.new("UIStroke")
        s.Color = cor or Theme.cor.borda
        s.Thickness = esp or 1
        s.Transparency = transp or 0
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = obj
        return s
    end

    function Theme.padding(obj, px)
        local p = Instance.new("UIPadding")
        p.PaddingLeft   = UDim.new(0, px)
        p.PaddingRight  = UDim.new(0, px)
        p.PaddingTop    = UDim.new(0, px)
        p.PaddingBottom = UDim.new(0, px)
        p.Parent = obj
        return p
    end

    -- Protecao de executor: qualquer propriedade que o mobile nao aceite
    -- nao derruba o script.
    function Theme.prop(obj, props)
        for k, v in pairs(props or {}) do
            pcall(function() obj[k] = v end)
        end
        return obj
    end

    function Theme.label(pai, props)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = Theme.fonte
        l.TextSize = 13
        l.TextColor3 = Theme.cor.texto
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.RichText = false
        Theme.prop(l, props)
        l.Parent = pai
        return l
    end

    function Theme.botao(pai, props)
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = Theme.cor.card
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = Theme.fonte
        b.TextSize = 13
        b.TextColor3 = Theme.cor.texto
        Theme.prop(b, props)
        Theme.cantos(b, 6)
        b.Parent = pai
        return b
    end

    function Theme.frame(pai, props)
        local f = Instance.new("Frame")
        f.BackgroundColor3 = Theme.cor.card
        f.BorderSizePixel = 0
        Theme.prop(f, props)
        f.Parent = pai
        return f
    end

    -- Efeito de hover simples e barato
    function Theme.hover(botao, cor_normal, cor_hover)
        cor_normal = cor_normal or Theme.cor.card
        cor_hover  = cor_hover  or Theme.cor.card_hover
        botao.MouseEnter:Connect(function()
            pcall(function() botao.BackgroundColor3 = cor_hover end)
        end)
        botao.MouseLeave:Connect(function()
            pcall(function() botao.BackgroundColor3 = cor_normal end)
        end)
    end

    return Theme
end)()

-- ============================================================
-- g1  -  interface 100% nativa (sem Rayfield/Orion)
-- Construida apenas com ScreenGui, Frame, TextButton, TextBox.
-- ============================================================
REGISTRY["g1"] = (function()
    local Services   = require_mod("a4")
    local Util       = require_mod("a6")
    local Dump       = require_mod("a2")
    local Theme      = require_mod("g3")
    local Graphics   = require_mod("b2")
    local Black      = require_mod("b1")
    local MemSaver   = require_mod("b4")
    local KillsHook  = require_mod("b3")
    local Tween      = require_mod("c2")
    local Level      = require_mod("d1")
    local Mastery    = require_mod("d2")
    local SeaEvents  = require_mod("d5")
    local Raids      = require_mod("d4")
    local Sniper     = require_mod("e2")
    local Store      = require_mod("e3")
    local Gacha      = require_mod("e1")
    local RaceV4     = require_mod("f3")
    local Calibrador = require_mod("f2")
    local Weapons    = require_mod("f4")
    local Bosses     = require_mod("f1")

    local Panel = {}
    local C = Theme.cor

    -- Estado global da UI
    local UI = {
        gui = nil, janela = nil, scroll = nil, corpo = nil,
        abas = {}, aba_atual = nil, aberto = true,
        widgets = {}, escala = 1,
        -- ============================================================
        -- FONTE DE VERDADE DOS WIDGETS.
        -- Cada toggle/slider/dropdown/input grava seu valor aqui, chaveado
        -- pelo rotulo. Ao trocar de aba, limpar_corpo() destroi os frames
        -- mas as flags sobrevivem - os widgets renascem refletindo o estado
        -- real dos modulos em vez de voltarem ao valor padrao.
        -- ============================================================
        Flags = {},
    }
    Panel.UI = UI

    -- ---------------------------------------------------------
    -- API de flags: o unico lugar que escreve no estado da UI.
    -- ---------------------------------------------------------
    local function flag_set(chave, valor)
        UI.Flags[chave] = valor
        return valor
    end

    local function flag_get(chave, padrao)
        local v = UI.Flags[chave]
        if v == nil then return padrao end
        return v
    end

    -- Le o estado REAL do modulo, para o toggle nascer refletindo a verdade
    -- e nao o que o widget lembra. 'vivo' e uma funcao opcional que consulta
    -- o modulo (ex: function() return Level.estado().ativo end).
    local function flag_viva(chave, padrao, vivo)
        if vivo then
            local ok, v = pcall(vivo)
            if ok and v ~= nil then
                UI.Flags[chave] = v
                return v
            end
        end
        return flag_get(chave, padrao)
    end

    local ABAS_DEF = {
        { nome = "Home" },
        { nome = "Perf" },
        { nome = "Farm" },
        { nome = "Frutas" },
        { nome = "Prog" },
        { nome = "Config" },
    }

    -- ---------------------------------------------------------
    -- Helpers reutilizaveis
    -- ---------------------------------------------------------
    local function limpar_corpo()
        if not UI.corpo then return end
        -- Snapshot primeiro: destruir enquanto itera GetChildren() pula itens
        -- e deixa widgets orfaos empilhados - vazamento que trava no mobile.
        -- Iteramos de tras para frente e so destruimos GuiObject, para
        -- preservar o UIListLayout e o UIPadding do scroller.
        local filhos = UI.corpo:GetChildren()
        for i = #filhos, 1, -1 do
            local ch = filhos[i]
            if ch and ch:IsA("GuiObject") then
                pcall(function() ch:Destroy() end)
                pcall(function() ch.Parent = nil end)
            end
        end
        -- Segunda passada: garante que nada escapou do snapshot.
        for _, ch in ipairs(UI.corpo:GetChildren()) do
            if ch:IsA("GuiObject") then
                pcall(function() ch:Destroy() end)
            end
        end
    end

    local function secao(titulo)
        local holder = Theme.frame(UI.corpo, {
            Name = "Secao", Size = UDim2.new(1, -16, 0, 26),
            BackgroundTransparency = 1,
        })
        local l = Theme.label(holder, {
            Size = UDim2.new(1, 0, 1, 0),
            Text = titulo:upper(),
            Font = Theme.fonte_bold,
            TextSize = 11,
            TextColor3 = C.acento,
        })
        local ln = Theme.frame(holder, {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -3),
            BackgroundColor3 = C.borda, BackgroundTransparency = 0.4,
        })
        return holder
    end

    -- ---------------------------------------------------------
    -- Widgets
    -- ---------------------------------------------------------

    -- Botao simples
    -- =========================================================
    -- WIDGETS PERSISTENTES
    -- Contrato comum: o valor vive em UI.Flags[chave], nao na closure.
    -- Ao trocar de aba o widget e destruido, mas a flag permanece e o
    -- widget novo nasce com o valor real.
    --   chave -> string unica; se omitida, usa o proprio rotulo
    --   vivo  -> funcao opcional que le o estado real do modulo
    -- =========================================================

    function Panel.botao(texto, callback)
        local b = Theme.botao(UI.corpo, {
            Name = "Btn", Size = UDim2.new(1, -16, 0, 34), Text = texto,
        })
        Theme.hover(b)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(callback)
            if not ok then
                warn("[LC/UI] " .. tostring(err))
                Util.notify("LuaCore", "Erro: " .. tostring(err), 4)
            end
        end)
        return b
    end

    -- Toggle com flag persistente
    function Panel.toggle(texto, valor_inicial, callback, chave, vivo)
        chave = chave or texto
        local inicial = flag_viva(chave, valor_inicial, vivo)

        local holder = Theme.frame(UI.corpo, {
            Name = "Toggle", Size = UDim2.new(1, -16, 0, 30),
        })
        Theme.cantos(holder, 6)

        local lbl = Theme.label(holder, {
            Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 10, 0, 0),
            Text = texto,
        })

        local trilha = Theme.frame(holder, {
            Name = "Trilha", Size = UDim2.new(0, 44, 0, 22),
            Position = UDim2.new(1, -54, 0.5, -11),
            BackgroundColor3 = inicial and C.acento_esc or C.off,
        })
        Theme.cantos(trilha, 11)

        local bola = Theme.frame(trilha, {
            Name = "Bola", Size = UDim2.new(0, 16, 0, 16),
            Position = inicial and UDim2.new(1, -18, 0.5, -8)
                                or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = C.texto,
        })
        Theme.cantos(bola, 8)

        local function aplicar(v, disparar)
            v = v and true or false
            -- Escreve na flag: e isso que sobrevive a troca de aba.
            flag_set(chave, v)
            pcall(function()
                trilha.BackgroundColor3 = v and C.acento_esc or C.off
                bola.Position = v and UDim2.new(1, -18, 0.5, -8)
                                   or UDim2.new(0, 2, 0.5, -8)
            end)
            if disparar then
                local ok, err = pcall(callback, v)
                if not ok then
                    warn("[LC/UI] toggle '" .. chave .. "': " .. tostring(err))
                    -- Se o modulo recusou, a flag volta para o estado real.
                    if vivo then
                        local ok2, real = pcall(vivo)
                        if ok2 and real ~= nil and real ~= v then
                            flag_set(chave, real)
                        end
                    end
                end
            end
        end

        local clicavel = Theme.botao(holder, {
            Name = "Hit", Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Text = "",
        })
        clicavel.MouseButton1Click:Connect(function()
            aplicar(not flag_get(chave, inicial), true)
        end)

        -- Sincroniza a parte visual com a flag, sem disparar callback.
        aplicar(inicial, false)
        return holder
    end

    -- Slider arrastavel com flag persistente
    function Panel.slider(texto, min, max, inc, valor_inicial, callback, chave)
        chave = chave or texto
        local valor = flag_get(chave, valor_inicial)

        local holder = Theme.frame(UI.corpo, {
            Name = "Slider", Size = UDim2.new(1, -16, 0, 44),
        })
        Theme.cantos(holder, 6)

        Theme.label(holder, {
            Size = UDim2.new(1, -70, 0, 18), Position = UDim2.new(0, 10, 0, 4),
            Text = texto,
        })

        local valor_lbl = Theme.label(holder, {
            Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -70, 0, 4),
            Text = tostring(math.floor(valor + 0.5)),
            Font = Theme.fonte_mono,
            TextColor3 = C.acento,
        })
        valor_lbl.TextXAlignment = Enum.TextXAlignment.Right

        local trilha = Theme.frame(holder, {
            Name = "Trilha", Size = UDim2.new(1, -20, 0, 6),
            Position = UDim2.new(0, 10, 0, 30),
            BackgroundColor3 = C.off,
        })
        Theme.cantos(trilha, 3)

        local preench = Theme.frame(trilha, {
            Name = "Preench", Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = C.acento,
        })
        Theme.cantos(preench, 3)

        local arrastando = false

        local function snap(v)
            v = math.clamp(v, min, max)
            return math.floor((v - min) / inc + 0.5) * inc + min
        end

        local function pintar(v)
            valor = v
            flag_set(chave, v)
            local p = (v - min) / math.max(max - min, 1)
            pcall(function()
                preench.Size = UDim2.new(p, 0, 1, 0)
                valor_lbl.Text = tostring(math.floor(v + 0.5))
            end)
        end

        local function de_x(x, disparar)
            local ok_abs, abs = pcall(function() return trilha.AbsolutePosition.X end)
            local ok_lar, larg = pcall(function() return trilha.AbsoluteSize.X end)
            if not (ok_abs and ok_lar) or larg <= 0 then return end
            pintar(snap(min + ((x - abs) / larg) * (max - min)))
            if disparar then
                local ok, err = pcall(callback, valor)
                if not ok then warn("[LC/UI] slider: " .. tostring(err)) end
            end
        end

        local hit = Theme.botao(holder, {
            Name = "Hit", Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.new(0, 0, 0, 22),
            BackgroundTransparency = 1, Text = "",
        })
        hit.MouseButton1Down:Connect(function(x) arrastando = true de_x(x, false) end)
        hit.MouseMoved:Connect(function(x) if arrastando then de_x(x, false) end end)
        hit.MouseButton1Up:Connect(function(x) de_x(x, true) end)
        Services.UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                if arrastando then
                    arrastando = false
                    pcall(callback, valor)
                end
            end
        end)

        pintar(valor)
        return holder
    end

    -- Dropdown ciclavel (toque = proxima opcao). Leve para mobile.
    function Panel.dropdown(texto, opcoes, indice_inicial, callback, chave)
        chave = chave or texto
        local idx = flag_get(chave, indice_inicial or 1)
        if type(idx) ~= "number" then idx = indice_inicial or 1 end
        idx = math.clamp(idx, 1, math.max(#opcoes, 1))

        local holder = Theme.frame(UI.corpo, {
            Name = "Dropdown", Size = UDim2.new(1, -16, 0, 34),
        })
        Theme.cantos(holder, 6)

        Theme.label(holder, {
            Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0),
            Text = texto,
        })

        local valor_lbl = Theme.label(holder, {
            Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.new(0.5, 10, 0, 0),
            Text = tostring(opcoes[idx]),
            TextColor3 = C.acento,
            Font = Theme.fonte_bold,
        })
        valor_lbl.TextXAlignment = Enum.TextXAlignment.Right

        local function pintar()
            pcall(function() valor_lbl.Text = tostring(opcoes[idx]) end)
        end

        local hit = Theme.botao(holder, {
            Name = "Hit", Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Text = "",
        })
        hit.MouseButton1Click:Connect(function()
            idx = idx % #opcoes + 1
            flag_set(chave, idx)
            pintar()
            local ok, err = pcall(callback, opcoes[idx], idx)
            if not ok then warn("[LC/UI] dropdown: " .. tostring(err)) end
        end)

        Theme.hover(holder)
        pintar()
        return holder
    end

    -- Input de texto com flag persistente
    function Panel.input(texto, valor_inicial, callback, chave)
        chave = chave or texto
        local guardado = flag_get(chave, valor_inicial)

        local holder = Theme.frame(UI.corpo, {
            Name = "Input", Size = UDim2.new(1, -16, 0, 54),
        })
        Theme.cantos(holder, 6)

        Theme.label(holder, {
            Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 4),
            Text = texto, TextSize = 11, TextColor3 = C.texto_dim,
        })

        local caixa = Instance.new("TextBox")
        caixa.Size = UDim2.new(1, -20, 0, 26)
        caixa.Position = UDim2.new(0, 10, 0, 22)
        caixa.BackgroundColor3 = C.fundo_alt
        caixa.BorderSizePixel = 0
        caixa.Font = Theme.fonte_mono
        caixa.TextSize = 12
        caixa.TextColor3 = C.texto
        caixa.PlaceholderText = "..."
        caixa.PlaceholderColor3 = C.texto_dim
        caixa.Text = tostring(guardado or "")
        caixa.ClearTextOnFocus = false
        caixa.TextXAlignment = Enum.TextXAlignment.Left
        Theme.cantos(caixa, 5)
        Theme.padding(caixa, 6)
        caixa.Parent = holder

        caixa.FocusLost:Connect(function()
            flag_set(chave, caixa.Text)
            local ok, err = pcall(callback, caixa.Text)
            if not ok then warn("[LC/UI] input: " .. tostring(err)) end
        end)

        return holder
    end

    -- Label informativo
    function Panel.texto(conteudo, cor)
        local l = Theme.label(UI.corpo, {
            Name = "Texto", Size = UDim2.new(1, -16, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true, TextSize = 12,
            TextColor3 = cor or C.texto_dim,
            Text = conteudo,
        })
        return l
    end

    -- ---------------------------------------------------------
    -- Troca de aba
    -- ---------------------------------------------------------
    local CONSTRUTORES = {}

    local function trocar_aba(nome)
        UI.aba_atual = nome
        for n, b in pairs(UI.abas) do
            local ativo = (n == nome)
            pcall(function()
                b.BackgroundColor3 = ativo and C.acento_esc or C.card
                b.TextColor3 = ativo and Color3.new(1, 1, 1) or C.texto_dim
            end)
        end
        limpar_corpo()
        UI.widgets = {}
        local f = CONSTRUTORES[nome]
        if f then
            local ok, err = pcall(f)
            if not ok then
                warn("[LC/UI] aba " .. nome .. ": " .. tostring(err))
                Panel.texto("Erro ao montar aba: " .. tostring(err), C.perigo)
            end
        end
    end

    -- Exposto para inspecao/depuracao de fora do modulo.
    Panel.limpar   = limpar_corpo
    Panel.trocar   = trocar_aba
    Panel.flags    = UI.Flags
    Panel.abas     = CONSTRUTORES
    Panel.flag_get = flag_get
    Panel.flag_set = flag_set

    -- ---------------------------------------------------------
    -- Contexto entregue a g2.
    -- As abas sao construidas por outro modulo para manter cada arquivo
    -- pequeno (o editor do GitHub trunca arquivos grandes). Tudo que os
    -- construtores precisam vem por aqui.
    -- ---------------------------------------------------------
    Panel.ctx = {
        Panel = Panel, UI = UI, C = C, Theme = Theme,
        secao = secao,
        trocar_aba = trocar_aba,
        Registry = REGISTRY,
        Mods = {
            Services  = Services,  Util     = Util,   Dump   = Dump,
            Theme     = Theme,     Graphics = Graphics, Black = Black,
            MemSaver  = MemSaver,  KillsHook = KillsHook, Tween = Tween,
            Level     = Level,     Mastery  = Mastery, SeaEvents = SeaEvents,
            Raids     = Raids,     Sniper   = Sniper, Store  = Store,
            Gacha     = Gacha,     RaceV4   = RaceV4, Calibrador = Calibrador,
            Weapons   = Weapons,   Bosses   = Bosses,
        },
    }

    -- ---------------------------------------------------------
    -- Construtores por aba: definidos em g2
    -- (arquivo separado para nao passar do limite do editor do GitHub).
    -- ---------------------------------------------------------

    -- ---------------------------------------------------------
    -- Botao flutuante
    -- ---------------------------------------------------------
    local function criar_flutuante()
        local pg = Services.LocalPlayer:WaitForChild("PlayerGui", 10)
        local existente = pg:FindFirstChild("LCFloat")
        if existente then existente:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "LCFloat"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        Theme.prop(gui, { ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
        gui.Parent = pg

        local btn = Theme.botao(gui, {
            Name = "Botao",
            Size = UDim2.new(0, 50, 0, 50),
            Position = UDim2.new(1, -66, 0, 100),
            BackgroundColor3 = C.painel,
            Text = "N",
            Font = Theme.fonte_bold,
            TextSize = 22,
            TextColor3 = C.acento,
        })
        Theme.cantos(btn, 25)
        Theme.contorno(btn, C.acento, 1.5, 0.3)

        -- Arrasto compativel com toque
        local arrastando, offset = false, nil
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
               or input.UserInputType == Enum.UserInputType.MouseButton1 then
                arrastando = true
                offset = input.Position - btn.AbsolutePosition
            end
        end)
        btn.InputChanged:Connect(function(input)
            if arrastando
               and (input.UserInputType == Enum.UserInputType.Touch
                    or input.UserInputType == Enum.UserInputType.MouseMovement) then
                pcall(function()
                    btn.Position = UDim2.new(0,
                        input.Position.X - offset.X, 0,
                        input.Position.Y - offset.Y)
                end)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
               or input.UserInputType == Enum.UserInputType.MouseButton1 then
                arrastando = false
            end
        end)

        local tocou = false
        btn.MouseButton1Down:Connect(function() tocou = false end)
        btn.MouseButton1Click:Connect(function()
            Panel.alternar()
        end)

        return gui
    end

    -- ---------------------------------------------------------
    -- Montagem da janela
    -- ---------------------------------------------------------
    function Panel.alternar()
        if not UI.janela then return end
        UI.aberto = not UI.aberto
        pcall(function() UI.janela.Visible = UI.aberto end)
    end

    function Panel.mostrar() 
        UI.aberto = true
        if UI.janela then pcall(function() UI.janela.Visible = true end) end
    end

    function Panel.esconder()
        UI.aberto = false
        if UI.janela then pcall(function() UI.janela.Visible = false end) end
    end

    function Panel.visivel() return UI.aberto end

    function Panel.build()
        local pg = Services.LocalPlayer:WaitForChild("PlayerGui", 10)

        local antigo = pg:FindFirstChild("NanaHub")
        if antigo then antigo:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "NanaHub"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 998
        Theme.prop(gui, { ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
        gui.Parent = pg

        -- Janela
        local janela = Theme.frame(gui, {
            Name = "Janela",
            Size = UDim2.new(0, 380, 0, 300),
            Position = UDim2.new(0.5, -190, 0.5, -150),
            BackgroundColor3 = C.fundo,
        })
        Theme.cantos(janela, 12)
        Theme.contorno(janela, C.borda, 1)
        UI.janela = janela

        -- Barra de titulo (arrastavel)
        local titulo = Theme.frame(janela, {
            Name = "Titulo", Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = C.painel,
        })
        Theme.cantos(titulo, 12)
        local tampao = Theme.frame(titulo, {
            Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
            BackgroundColor3 = C.painel,
        })

        Theme.label(titulo, {
            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0),
            Text = "LuaCore", Font = Theme.fonte_bold,
            TextSize = 15, TextColor3 = C.acento,
        })

        local fechar = Theme.botao(titulo, {
            Name = "Fechar", Size = UDim2.new(0, 28, 0, 22),
            Position = UDim2.new(1, -36, 0.5, -11),
            BackgroundColor3 = C.card, Text = "X", TextSize = 13,
            TextColor3 = C.perigo,
        })
        fechar.MouseButton1Click:Connect(function() Panel.esconder() end)

        -- Arrasto da janela
        local arrastando, offset = false, nil
        titulo.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
               or input.UserInputType == Enum.UserInputType.MouseButton1 then
                arrastando = true
                offset = input.Position - janela.AbsolutePosition
            end
        end)
        titulo.InputChanged:Connect(function(input)
            if arrastando
               and (input.UserInputType == Enum.UserInputType.Touch
                    or input.UserInputType == Enum.UserInputType.MouseMovement) then
                pcall(function()
                    janela.Position = UDim2.new(0,
                        input.Position.X - offset.X, 0,
                        input.Position.Y - offset.Y)
                end)
            end
        end)
        titulo.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
               or input.UserInputType == Enum.UserInputType.MouseButton1 then
                arrastando = false
            end
        end)

        -- Faixa de abas
        local faixa = Theme.frame(janela, {
            Name = "Abas", Size = UDim2.new(1, -16, 0, 30),
            Position = UDim2.new(0, 8, 0, 40),
        })
        Theme.cantos(faixa, 6)
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = faixa

        for i, def in ipairs(ABAS_DEF) do
            local b = Theme.botao(faixa, {
                Name = def.nome,
                Size = UDim2.new(0, 58, 1, 0),
                Text = def.nome,
                TextSize = 11,
                LayoutOrder = i,
            })
            Theme.cantos(b, 5)
            b.MouseButton1Click:Connect(function() trocar_aba(def.nome) end)
            UI.abas[def.nome] = b
        end

        -- Corpo com scroll (essencial em mobile)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Corpo"
        scroll.Size = UDim2.new(1, 0, 1, -78)
        scroll.Position = UDim2.new(0, 0, 0, 78)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5
        scroll.ScrollBarImageColor3 = C.borda
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.Parent = janela
        UI.scroll = scroll

        local lista = Instance.new("UIListLayout")
        lista.Padding = UDim.new(0, 6)
        lista.SortOrder = Enum.SortOrder.LayoutOrder
        lista.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.Parent = scroll

        UI.corpo = scroll

        -- Botao flutuante + atalhos
        criar_flutuante()

        Services.UserInputService.InputBegan:Connect(function(i, processado)
            if processado then return end
            if i.KeyCode == Enum.KeyCode.RightControl then
                Panel.alternar()
            elseif i.KeyCode == Enum.KeyCode.RightShift then
                Panel.panic()
            end
        end)

        -- Aba inicial
        trocar_aba("Home")

        Util.notify("LuaCore", "UI nativa carregada (offline)", 4)
        return {
            Gui = gui, Janela = janela,
            Toggle = function(_, v) if v then Panel.esconder() else Panel.mostrar() end end,
        }
    end

    function Panel.panic()
        for _, nome in ipairs({
            "d1", "d2", "d5",
            "d4", "e2", "e3",
            "e1", "f3", "b3",
        }) do
            local m = REGISTRY[nome]
            if m and type(m.stop) == "function" then pcall(m.stop) end
        end
        pcall(function() Graphics.low_end_off() end)
        pcall(function() Black.disable() end)
        Panel.esconder()
        Util.notify("LuaCore", "PANIC: tudo parado", 3)
    end

    Panel.UI = UI
    return Panel
end)()

-- ============================================================
-- g2
-- Construtores das abas do painel.
--
-- Ficam num modulo separado de g1 so para manter os arquivos
-- pequenos: o editor web do GitHub trunca arquivos grandes, e o Panel
-- sozinho passava de 38 KB.
--
-- Tudo que estas abas usam vem de Panel.ctx (Panel, UI, C, Theme, secao,
-- Mods). Nenhum estado novo e criado aqui.
-- ============================================================

REGISTRY["g2"] = (function()
    local Panel = require_mod("g1")
    local ctx   = Panel.ctx

    local UI    = ctx.UI
    local C     = ctx.C
    local Theme = ctx.Theme
    local secao = ctx.secao
    local Mods  = ctx.Mods

    local Services  = Mods.Services
    local Util      = Mods.Util
    local Dump      = Mods.Dump
    local Graphics  = Mods.Graphics
    local Black     = Mods.Black
    local MemSaver  = Mods.MemSaver
    local KillsHook = Mods.KillsHook
    local Tween     = Mods.Tween
    local Level     = Mods.Level
    local Mastery   = Mods.Mastery
    local SeaEvents = Mods.SeaEvents
    local Raids     = Mods.Raids
    local Sniper    = Mods.Sniper
    local Store     = Mods.Store
    local Gacha     = Mods.Gacha
    local RaceV4    = Mods.RaceV4
    local Calibrador = Mods.Calibrador
    local Weapons   = Mods.Weapons
    local Bosses    = Mods.Bosses

    -- Tabs se registra no mesmo dicionario que o Panel usa.
    local Tabs = Panel.abas
    local REGISTRY = ctx.Registry

        -- ---------------------------------------------------------
        -- Construtores por aba
        -- ---------------------------------------------------------
    Tabs.Home = function()
        secao("Status do sistema")

        -- Diagnostico do remote principal: e isso que faz o farm funcionar.
        local pronto = Mods.Dump.pronto()
        Panel.texto(pronto
            and ("REMOTE OK -> " .. Mods.Dump.nome("StartQuest"))
            or "REMOTE PRINCIPAL AUSENTE - o farm nao vai funcionar. Toque em 'Listar Remotes' e me mande o console.",
            pronto and C.acento or C.perigo)

        Panel.texto("LuaCore v2 - build nativa offline. Sem HttpGet de UI, "
            .. "sem dependencia externa.")

        secao("Diagnostico de remotes")
        Panel.botao("Re-dump de Remotes", function()
            local r = Mods.Dump.run(false)
            local cont = 0
            for _ in pairs(r.resolvidos) do cont += 1 end
            Mods.Util.notify("LuaCore",
                ("%d remotes, principal: %s"):format(
                    r.total, r.comm and "OK" or "AUSENTE"), 4)
        end)
        Panel.botao("Listar Remotes no Console", function()
            Mods.Dump.cru()
            Mods.Util.notify("LuaCore", "Saida no console (F9)", 3)
        end)
        Panel.botao("Testar Comandos (leitura)", function()
            if not Mods.Dump.pronto() then
                Mods.Util.notify("LuaCore", "Sem remote principal", 3)
                return
            end
            print("[LC] === TESTE DE COMANDOS ===")
            for _, par in ipairs({
                { "getLevel",     { "getLevel" } },
                { "getBeli",      { "getBeli" } },
                { "getPoints",    { "getPoints" } },
                { "getFragments", { "getFragments" } },
                { "CheckQuest",   { "CheckQuest" } },
            }) do
                local ok, res = pcall(function()
                    return Mods.Dump.raw(par[2][1], table.unpack(par[2], 2))
                end)
                print(("  %-14s ok=%s  %s"):format(
                    par[1], tostring(ok),
                    type(res) == "table" and "TABELA" or tostring(res)))
            end
            print("[LC] === FIM ===")
            Mods.Util.notify("LuaCore", "Resultado no console (F9)", 4)
        end)

        secao("Informacoes")
        Panel.texto(("Modulos carregados: %d\nVersao: 2.0-native\nPlataforma: mobile-safe")
            :format((function()
                local n = 0
                for _ in pairs(REGISTRY) do n += 1 end
                return n
            end)()))
    end

    Tabs.Perf = function()
        secao("Graficos")
        Panel.toggle("Ultra Low-End (FPS Booster)", false, function(v)
            if v then Mods.Graphics.low_end_on() else Mods.Graphics.low_end_off() end
        end, "perf.low_end", function() return Mods.Graphics.estado().low_end end)
        Panel.slider("FPS Cap", 30, 240, 10, 120, function(v)
            Mods.Graphics.set_fps_cap(v)
        end, "perf.fps_cap")

        secao("Render")
        Panel.toggle("Black Screen AFK Mode", false, function(v)
            if v then Mods.Black.enable(Mods.Black.telemetria().fonte_kills == "hook")
            else Mods.Black.disable() end
        end, "perf.black", function() return Mods.Black.ativo() end)
        Panel.toggle("Kills/min Preciso (HealthChanged)", false, function(v)
            local pg = Mods.Services.LocalPlayer:FindFirstChild("PlayerGui")
            if pg and pg:FindFirstChild("LCHUD") then
                Mods.Black.set_hook(v)
            else
                if v then Mods.KillsHook.start() else Mods.KillsHook.stop() end
            end
            Mods.Util.notify("LuaCore",
                v and "Kills: fonte exata" or "Kills: fonte proxy", 3)
        end, "perf.kills_hook")

        secao("Memoria")
        Panel.toggle("CPU & Memory Saver", true, function(v)
            if v then Mods.MemSaver.start() else Mods.MemSaver.stop() end
        end, "perf.memsaver", function() return Mods.MemSaver.estado().ativo end)
        Panel.botao("Forcar GC agora", function()
            Mods.Util.gc()
            Mods.Util.notify("LuaCore", "GC executado", 2)
        end)
    end

    Tabs.Farm = function()
        secao("Level & Mobs")
        Panel.toggle("Auto Level", false, function(v)
            if v then Mods.Level.start() else Mods.Level.stop() end
        end, "farm.level", function() return Mods.Level.estado().ativo end)
        Panel.toggle("Auto Aceitar Quest", true, function(v)
            Mods.Level.config({ auto_quest = v })
        end, "farm.auto_quest", function() return Mods.Level.estado().auto_quest end)
        Panel.dropdown("Stats Alvo",
            { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }, 1,
            function(o) Mods.Level.config({ stats_alvo = o }) end, "farm.stats")
        Panel.dropdown("Modo de Ataque", { "seguro", "blatant" }, 1,
            function(o)
                Mods.Level.config({ modo = o })
                Mods.Mastery.estado().modo = o
                Mods.SeaEvents.estado().modo = o
                Mods.Raids.estado().modo = o
            end, "farm.modo")

        secao("Mastery")
        Panel.input("Armas (separadas por virgula)",
            "Superhuman,Sharkman Karate,Godhuman", function(txt)
                Mods.Mastery.start(txt, Mods.Mastery.estado().alvo_nivel)
            end, "farm.mastery_armas")
        Panel.slider("Mastery Alvo", 50, 600, 25, 300, function(v)
            Mods.Mastery.estado().alvo_nivel = v
        end, "farm.mastery_nivel")
        Panel.botao("Iniciar Mastery Farm", function()
            Mods.Mastery.start(Panel.UI.Flags["farm.mastery_armas"]
                          or Mods.Mastery.estado().lista,
                          Panel.UI.Flags["farm.mastery_nivel"]
                          or Mods.Mastery.estado().alvo_nivel)
        end)
        Panel.botao("Parar Mastery", function() Mods.Mastery.stop() end)

        secao("Sea Events")
        local evs = { "ship", "terror", "leviathan", "seabeast" }
        for _, ev in ipairs(evs) do
            Panel.toggle("Auto " .. ev, false, function(v)
                Mods.SeaEvents.toggle(ev, v)
            end, "farm.sea." .. ev, function()
                return Mods.SeaEvents.estado().ativos
                   and Mods.SeaEvents.estado().ativos[ev]
            end)
        end
        Panel.botao("Iniciar Sea Events", function()
            Mods.SeaEvents.start({ ship = true, terror = true,
                              leviathan = true, seabeast = true })
        end)
        Panel.botao("Parar Sea Events", function() Mods.SeaEvents.stop() end)

        secao("Raids")
        Panel.dropdown("Group Target",
            { "Dough", "Flame", "Ice", "Quake", "Light", "Dark",
              "Rumble", "Magma", "Blizzard" }, 1,
            function(o) Mods.Raids.estado().fruta = o end, "farm.raid_fruta")
        Panel.toggle("Auto Awaken ao final", true, function(v)
            Mods.Raids.estado().auto_awaken = v
        end, "farm.raid_awaken", function() return Mods.Raids.estado().auto_awaken end)
        Panel.toggle("Auto Group", false, function(v)
            if v then Mods.Raids.start() else Mods.Raids.stop() end
        end, "farm.raid", function() return Mods.Raids.estado().ativo end)
    end

    Tabs.Frutas = function()
        secao("Collector & ESP")
        Panel.toggle("Fruit ESP", true, function(v)
            Mods.Sniper.config({ esp = v })
        end, "fruta.esp", function() return Mods.Sniper.estado().esp end)
        Panel.toggle("Auto Coletar Fruta", false, function(v)
            Mods.Sniper.config({ auto_coletar = v })
        end, "fruta.coletar", function() return Mods.Sniper.estado().auto_coletar end)
        Panel.slider("Raio de Coleta", 0, 20000, 500, 0, function(v)
            -- 0 = sem limite: cobre o mapa inteiro, qualquer ilha.
            Mods.Sniper.config({ raio_coleta = (v <= 0) and math.huge or v,
                            raio_esp    = (v <= 0) and math.huge or v })
        end, "fruta.raio")
        Panel.botao("Start Collector", function() Mods.Sniper.start() end)
        Panel.botao("Stop Collector", function() Mods.Sniper.stop() end)

        secao("Bau & Gacha")
        Panel.toggle("Auto Store Fruit", false, function(v)
            if v then Mods.Store.start() else Mods.Store.stop() end
        end)
        Panel.toggle("Auto Gacha (Zioles)", false, function(v)
            if v then Mods.Gacha.start() else Mods.Gacha.stop() end
        end)
        Panel.slider("Gacha: Beli Minimo", 100000, 5000000, 100000, 1000000,
            function(v) Mods.Gacha.estado().preco_max = v end)
    end

    Tabs.Prog = function()
        secao("Raca V4")
        Panel.toggle("Auto Mirage (navegar)", true, function(v)
            Mods.RaceV4.estado().auto_mirage = v
        end)
        Panel.toggle("Auto Gear Solver (BFS)", true, function(v)
            Mods.RaceV4.estado().auto_gear = v
        end)
        Panel.toggle("Auto Trial (lua cheia)", true, function(v)
            Mods.RaceV4.estado().auto_trial = v
        end)
        Panel.toggle("Iniciar Race V4", false, function(v)
            if v then Mods.RaceV4.start() else Mods.RaceV4.stop() end
        end)
        Panel.botao("Calibrar Gear (auto-detectar)", function()
            local ok, modelo = Mods.RaceV4.calibrar()
            if ok then
                Mods.Util.notify("LuaCore",
                    ("Modelo: %d gears, %d avisos")
                    :format(modelo.n_gears, #modelo.suspeitos), 5)
            end
        end)
        Panel.botao("Validar Modelo Calibrado", function()
            local modelo = Mods.RaceV4.modelo()
            if not modelo then
                Mods.Util.notify("LuaCore", "Nenhum modelo calibrado", 3)
                return
            end
            local mirage = Mods.Services.Workspace:FindFirstChild("Mirage", true)
            if not mirage then
                Mods.Util.notify("LuaCore", "Mirage nao encontrada", 3)
                return
            end
            local ok, erros = Mods.Calibrador.validar(mirage, modelo)
            Mods.Util.notify("LuaCore",
                ok and "Modelo validado" or ("%d divergencias"):format(erros), 4)
        end)
        Panel.botao("Limpar Modelo de Gear", function()
            Mods.RaceV4.limpar_modelo()
            Mods.Util.notify("LuaCore", "Modelo limpo", 3)
        end)

        secao("Armas & Estilos")
        Panel.dropdown("Alvo",
            { "Superhuman", "DeathStep", "SharkmanKarate", "ElectricClaw",
              "DragonTalon", "Godhuman", "TTK", "CDK", "HallowScythe",
              "SoulGuitar", "Canvander" }, 6,
            function(o) Panel._alvo_arma = o end)
        Panel.botao("Rodar Solver", function()
            Mods.Weapons.resolver(Panel._alvo_arma or "Godhuman")
        end)
        Panel.botao("Auto Solver (loop)", function()
            Mods.Weapons.auto(Panel._alvo_arma or "Godhuman")
        end)
        Panel.botao("Parar Auto Solver", function()
            Mods.Weapons.parar(Panel._alvo_arma or "Godhuman")
        end)

        secao("Bosses")
        Panel.toggle("Monitorar Spawns", false, function(v)
            Mods.Bosses.monitorar(v)
        end)
        Panel.toggle("Auto-Kill no Spawn", false, function(v)
            Mods.Bosses.auto_kill(v)
        end)
        for _, b in ipairs({ "saber", "ice_admiral", "don_swan", "bartilo",
                             "cake_prince", "dough_king" }) do
            Panel.botao("Farm " .. b, function() Mods.Bosses.run(b) end)
        end
    end

    Tabs.Config = function()
        secao("Movimento")
        Panel.slider("Tween Speed (studs/s)", 150, 600, 25, 320, function(v)
            Mods.Tween.set_velocidade(v)
        end)

        secao("Seguranca")
        Panel.toggle("Anti-AFK", true, function(v)
            local A = require_mod("a1")
            if v then A.start() else A.stop() end
        end)
        Panel.botao("Parar TODOS os modulos", function()
            for _, nome in ipairs({
                "Farm/Mods.Level.lua", "Farm/Mods.Mastery.lua", "Farm/Mods.SeaEvents.lua",
                "Farm/Mods.Raids.lua", "Fruit/Mods.Sniper.lua", "Fruit/Mods.Store.lua",
                "Fruit/Mods.Gacha.lua", "Progression/Mods.RaceV4.lua",
                "Perf/Mods.KillsHook.lua",
            }) do
                local m = REGISTRY[nome]
                if m and type(m.stop) == "function" then pcall(m.stop) end
            end
            pcall(function() Mods.Graphics.low_end_off() end)
            pcall(function() Mods.Black.disable() end)
            Mods.Util.notify("LuaCore", "Todos os modulos parados", 3)
        end)

        secao("Interface")
        Panel.slider("Transparencia", 0, 80, 5, 0, function(v)
            pcall(function()
                UI.janela.BackgroundTransparency = v / 100
            end)
        end)

        secao("Sobre")
        Panel.texto("LuaCore v2 - native build\n"
            .. "UI em Instance.new, sem HttpGet.\n"
            .. "RightControl: mostra/oculta painel\n"
            .. "RightShift: panic (para tudo)")
    end


return Tabs
end)()

local function boot()
    local Services = require_mod("a4")
    local Util     = require_mod("a6")
    local Dump     = require_mod("a2")
    local Env      = require_mod("a3")
    local AntiAFK  = require_mod("a1")
    local MemSaver = require_mod("b4")

    -- 0) diagnostico do executor: reporta o que existe e o que falta.
    local tem, falta = Env.diagnostico()
    local executor, mobile = Env.identify()
    print(("[LC] executor: %s | mobile: %s | %d recursos ok, %d ausentes")
        :format(tostring(executor), tostring(mobile), #tem, #falta))
    if #falta > 0 then
        print("[LC] ausentes (o script contorna): " .. table.concat(falta, ", "))
    end

    -- 1) localizar o remote principal antes de qualquer farm tocar em remote
    local relatorio = Dump.run(true)
    if Dump.pronto() then
        print(("[LC] remote principal: %s (%s)")
            :format(relatorio.comm.obj:GetFullName(), relatorio.comm.obj.ClassName))
    else
        warn("[LC] *** REMOTE PRINCIPAL NAO ENCONTRADO ***")
        warn("[LC] o farm nao vai funcionar. Remotes disponiveis:")
        local n = 0
        for _, d in ipairs(Services.ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteFunction") or d:IsA("RemoteEvent") then
                n = n + 1
                if n <= 25 then warn("   " .. d.ClassName .. "  " .. d:GetFullName()) end
            end
        end
        warn(("[LC] total de remotes: %d. Me mande esta lista."):format(n))
    end

    -- 2) hooks de base (cada um ja se protege internamente)
    pcall(function() AntiAFK.start() end)

    -- 3) UI nativa: sem HttpGet, sem biblioteca externa.
    --    Se por qualquer motivo a UI falhar, o resto do script continua vivo.
    --
    --    IMPORTANTE: construir a UI ANTES de aplicar as flags torna a UI a
    --    fonte de verdade. Todo toggle que nasce ligado (CPU & Memory Saver,
    --    Auto Aceitar Quest, Fruit ESP, Anti-AFK...) grava sua flag padrao
    --    em UI.Flags, e o bloco abaixo liga o modulo correspondente. Assim o
    --    que aparece no painel e exatamente o que os modulos estao fazendo.
    local janela
    local Panel
    local okUI, errUI = pcall(function()
        Panel  = require_mod("g1")
        janela = Panel.build()
    end)
    if not okUI then
        warn("[LC] UI falhou: " .. tostring(errUI))
        Util.notify("LuaCore", "UI falhou - veja o console (F9)", 6)
        Panel = nil
    end

    -- 4) Sincronizar os modulos com as flags padrao da UI.
    --    S liga o que a flag diz; nao mexe em nada que o usuario ja mudou.
    if Panel and Panel.UI then
        -- Semear TODAS as abas uma vez: cada construtor grava as flags
        -- padrao dos seus widgets. Sem isso, uma aba nunca visitada nao tem
        -- flag nenhuma e o boot nao sabe o que ligar.
        local nomes = {}
        for nome in pairs(Panel.abas) do nomes[#nomes + 1] = nome end
        table.sort(nomes)
        for _, nome in ipairs(nomes) do
            pcall(function() Panel.trocar(nome) end)
        end
        -- Volta para a Home para o usuario abrir no painel de status.
        pcall(function() Panel.trocar("Home") end)

        local F = Panel.flags
        local function liga(chave, acao)
            if F[chave] == true then pcall(acao) end
        end
        liga("perf.memsaver",   function() MemSaver.start() end)
        liga("perf.low_end",    function() Graphics.low_end_on() end)
        liga("farm.auto_quest", function() Level.config({ auto_quest = true }) end)
        liga("fruta.esp",       function() Sniper.config({ esp = true }) end)
        liga("farm.raid_awaken",
             function() Raids.estado().auto_awaken = true end)

        local nf = 0
        for _ in pairs(F) do nf += 1 end
        print(("[LC] %d flags de UI semeadas (persistem na troca de aba)")
            :format(nf))
    end

    local n_res, n_mod = 0, 0
    for _ in pairs(relatorio.resolvidos) do n_res += 1 end
    for _ in pairs(REGISTRY) do n_mod += 1 end

    getgenv().LuaCore = {
        ui     = janela,
        reg    = REGISTRY,
        dump   = relatorio,
        env    = Env,
        versao = "2.0-native",
    }

    print(("[LuaCore] v2 native pronto. %d modulos, %d remotes, %d assinaturas.")
        :format(n_mod, relatorio.total, n_res))
    print("[LC] RightControl: painel | RightShift: panic")
end

-- Boot protegido: nada depois daqui pode derrubar o executor.
local ok_boot, err_boot = pcall(boot)
if not ok_boot then
    warn("[LC] falha no boot: " .. tostring(err_boot))
end
