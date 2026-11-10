-- ===================================================================
-- dungeon.lua - gera o andar (mapa de salas) e cuida dos blocos da sala
-- Cada sala tem 30x15 blocos de 16 px. Posicoes em pixels da sala:
-- x de 0 a 479 e y de 0 a 239.
-- ===================================================================
local D = {}

local flr, rnd = math.floor, math.random
local COLS, ROWS = 30, 15

-- valores dos blocos
--   0 chao, 1 parede, 2 pedra, 3 caixote (quebra com tiro),
--   4 espinho, 5 porta
local FLOOR, WALL, ROCK, CRATE, SPIKE, DOOR = 0, 1, 2, 3, 4, 5

-- Moldes das salas de combate. Cada molde e so o canto de cima/esquerda
-- (14x7); ele e espelhado para os outros tres cantos. A linha 7 e o meio
-- da sala e a coluna 14 e o centro.
--   . chao   # pedra   c caixote   ^ espinho
local TEMPLATES = {
    {
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
    },
    {
        "..............",
        "..............",
        "...##.........",
        "...##.........",
        "..............",
        "..............",
        "..............",
    },
    {
        "cc............",
        "c.............",
        "..............",
        ".......#......",
        "..............",
        ".............#",
        "............##",
    },
    {
        "..............",
        "..............",
        "....^^^^^^....",
        "....^.........",
        "....^.....##..",
        "..............",
        "..............",
    },
    {
        "..............",
        "..#....#....#.",
        "..............",
        "..............",
        "..#....#....#.",
        "..............",
        "..............",
    },
    {
        "..............",
        "..............",
        "...#######....",
        "..............",
        "..............",
        "........cc....",
        "..............",
    },
    {
        "..............",
        ".#............",
        "..#...........",
        "...#......^...",
        "..........^...",
        "..............",
        "..............",
    },
    {
        "..............",
        "..c..c..c..c..",
        "..............",
        "....c....c....",
        "..............",
        "..c....#....c.",
        "..............",
    },
    {
        "..............",
        "..............",
        ".............^",
        ".............^",
        "....##.......^",
        ".........^^^^^",
        "..............",
    },
    {
        "..............",
        "..............",
        ".....####.....",
        ".....#........",
        ".....#........",
        "..............",
        "..............",
    },
}

local DIRS = {
    { name = "n", dx = 0, dy = -1 },
    { name = "s", dx = 0, dy = 1 },
    { name = "w", dx = -1, dy = 0 },
    { name = "e", dx = 1, dy = 0 },
}
D.DIRS = DIRS

-- -------------------------------------------------------------------
-- Sala atual
-- -------------------------------------------------------------------
local cur = nil         -- blocos da sala atual
local locked = false    -- portas trancadas (tem inimigo vivo)

function D.use(room) cur = room.t end

function D.lock(v) locked = v end

function D.tile_at(x, y)
    if x < 0 or y < 0 or x >= 480 or y >= 240 then return WALL end
    return cur[flr(y / 16) * COLS + flr(x / 16) + 1]
end

local function blocked(x, y, fly)
    if x < 0 or y < 0 or x >= 480 or y >= 240 then return true end
    local v = cur[flr(y / 16) * COLS + flr(x / 16) + 1]
    if v == FLOOR or v == SPIKE then return false end
    if v == DOOR then return locked end
    if fly then return v == WALL end
    return true
end

local function box_blocked(x, y, h, fly)
    return blocked(x - h, y - h, fly) or blocked(x + h, y - h, fly)
        or blocked(x - h, y + h, fly) or blocked(x + h, y + h, fly)
end

-- Anda um eixo de cada vez (assim desliza nas paredes).
-- h = metade do tamanho da caixa; fly = voa por cima de pedras.
-- Devolve se bateu em x e se bateu em y.
function D.move(e, dx, dy, h, fly)
    local hx, hy = false, false
    if dx ~= 0 then
        if box_blocked(e.x + dx, e.y, h, fly) then hx = true else e.x = e.x + dx end
    end
    if dy ~= 0 then
        if box_blocked(e.x, e.y + dy, h, fly) then hy = true else e.y = e.y + dy end
    end
    return hx, hy
end

-- Bala bateu em algo? Devolve o bloco e o indice, ou nil se esta livre.
function D.bullet_tile(x, y)
    if x < 0 or y < 0 or x >= 480 or y >= 240 then return WALL, 0 end
    local idx = flr(y / 16) * COLS + flr(x / 16) + 1
    local v = cur[idx]
    if v == FLOOR or v == SPIKE then return nil end
    return v, idx
end

function D.break_crate(idx)
    if cur[idx] == CRATE then cur[idx] = FLOOR end
end

-- Um ponto de chao livre, longe dos jogadores (para nascer inimigo)
function D.free_spot(players, mind)
    local bx, by = 240, 120
    local m2 = mind * mind
    for _ = 1, 40 do
        local tx, ty = rnd(3, 28), rnd(3, 13)
        if cur[(ty - 1) * COLS + tx] == FLOOR then
            local x, y = tx * 16 - 8, ty * 16 - 8
            local ok = true
            for i = 1, #players do
                local p = players[i]
                local dx, dy = p.x - x, p.y - y
                if dx * dx + dy * dy < m2 then ok = false end
            end
            if ok then return x, y end
            bx, by = x, y
        end
    end
    return bx, by
end

-- O chao livre mais perto de (x, y)
function D.free_near(x, y)
    local tx0, ty0 = flr(x / 16) + 1, flr(y / 16) + 1
    for rad = 0, 6 do
        for ty = ty0 - rad, ty0 + rad do
            for tx = tx0 - rad, tx0 + rad do
                if tx >= 2 and tx <= 29 and ty >= 2 and ty <= 14
                    and cur[(ty - 1) * COLS + tx] == FLOOR then
                    return tx * 16 - 8, ty * 16 - 8
                end
            end
        end
    end
    return x, y
end

-- -------------------------------------------------------------------
-- Montagem dos blocos de uma sala
-- -------------------------------------------------------------------
local function build(room)
    local t = {}
    for ty = 1, ROWS do
        for tx = 1, COLS do
            local v = FLOOR
            if tx == 1 or tx == COLS or ty == 1 or ty == ROWS then v = WALL end
            t[(ty - 1) * COLS + tx] = v
        end
    end

    if room.kind == "normal" then
        local tp = TEMPLATES[rnd(#TEMPLATES)]
        for r = 1, 13 do
            local row = tp[r <= 7 and r or 14 - r]
            for c = 1, 28 do
                local qc = c <= 14 and c or 29 - c
                local ch = row:sub(qc, qc)
                local v = FLOOR
                if ch == "#" then v = ROCK elseif ch == "c" then v = CRATE
                elseif ch == "^" then v = SPIKE end
                t[r * COLS + c + 1] = v
            end
        end
    end

    local d = room.doors
    if d.n then t[15], t[16] = DOOR, DOOR end
    if d.s then t[14 * COLS + 15], t[14 * COLS + 16] = DOOR, DOOR end
    for ty = 7, 9 do
        if d.w then t[(ty - 1) * COLS + 1] = DOOR end
        if d.e then t[(ty - 1) * COLS + COLS] = DOOR end
    end
    room.t = t

    -- Para desenhar com poucas chamadas: pedras e espinhos vizinhos na
    -- mesma linha viram uma faixa so. Caixotes ficam um por um.
    local runs, crates = {}, {}
    for ty = 2, ROWS - 1 do
        local tx = 2
        while tx <= COLS - 1 do
            local v = t[(ty - 1) * COLS + tx]
            if v == ROCK or v == SPIKE then
                local x1 = tx
                while x1 < COLS - 1 and t[(ty - 1) * COLS + x1 + 1] == v do
                    x1 = x1 + 1
                end
                runs[#runs + 1] = { v = v, x0 = (tx - 1) * 16, x1 = x1 * 16 - 1, y = (ty - 1) * 16 }
                tx = x1 + 1
            else
                if v == CRATE then
                    crates[#crates + 1] = { idx = (ty - 1) * COLS + tx, x = (tx - 1) * 16, y = (ty - 1) * 16 }
                end
                tx = tx + 1
            end
        end
    end
    room.runs, room.crates = runs, crates

    -- enfeites do chao (pedrinhas e rachaduras)
    local deco = {}
    for _ = 1, 7 do
        deco[#deco + 1] = { x = rnd(24, 450), y = rnd(24, 210), k = rnd(3) }
    end
    room.deco = deco
end

-- -------------------------------------------------------------------
-- Geracao do andar: as salas ficam numa grade 9x7 e formam uma arvore.
-- A folha mais funda e o chefe; outras duas viram tesouro e loja.
-- -------------------------------------------------------------------
local GW, GH = 9, 7
D.GW, D.GH = GW, GH

local function key(x, y) return y * 16 + x end

local function try_layout(target)
    local cells, list = {}, {}

    local function add(x, y, depth)
        local r = {
            gx = x, gy = y, depth = depth, kind = "normal", doors = {},
            cleared = false, visited = false, seen = false,
            pickups = {}, peds = {}, guns = {},
        }
        cells[key(x, y)] = r
        list[#list + 1] = r
    end

    local function ncount(x, y)
        local n = 0
        for i = 1, 4 do
            if cells[key(x + DIRS[i].dx, y + DIRS[i].dy)] then n = n + 1 end
        end
        return n
    end

    add(5, 4, 0)
    local pass = 0
    while #list < target and pass < 40 do
        pass = pass + 1
        local n0 = #list
        for i = 1, n0 do
            local c = list[i]
            for d = 1, 4 do
                local nx, ny = c.gx + DIRS[d].dx, c.gy + DIRS[d].dy
                if #list < target and nx >= 1 and nx <= GW and ny >= 1 and ny <= GH
                    and not cells[key(nx, ny)] and ncount(nx, ny) == 1
                    and rnd() < 0.3 then
                    add(nx, ny, c.depth + 1)
                end
            end
        end
    end
    if #list < target then return nil end

    local leaves = {}
    for i = 2, #list do
        local c = list[i]
        if ncount(c.gx, c.gy) == 1 then leaves[#leaves + 1] = c end
    end
    if #leaves < 3 then return nil end

    -- chefe = folha mais funda
    local bi = 1
    for i = 2, #leaves do
        if leaves[i].depth > leaves[bi].depth then bi = i end
    end
    if leaves[bi].depth < 3 then return nil end
    leaves[bi].kind = "boss"
    table.remove(leaves, bi)
    table.remove(leaves, rnd(#leaves)).kind = "treasure"
    table.remove(leaves, rnd(#leaves)).kind = "shop"
    list[1].kind = "start"

    return cells, list
end

-- Mapa fixo, so para o caso (quase impossivel) do sorteio falhar sempre
local function fallback_layout()
    local cells, list = {}, {}
    local spec = {
        { 5, 4, "start" }, { 6, 4, "normal" }, { 7, 4, "normal" },
        { 8, 4, "boss" }, { 4, 4, "normal" }, { 3, 4, "treasure" },
        { 5, 3, "normal" }, { 5, 2, "shop" },
    }
    for i, s in ipairs(spec) do
        local r = {
            gx = s[1], gy = s[2], depth = i, kind = s[3], doors = {},
            cleared = false, visited = false, seen = false,
            pickups = {}, peds = {}, guns = {},
        }
        cells[key(s[1], s[2])] = r
        list[#list + 1] = r
    end
    return cells, list
end

function D.gen_floor(level)
    local target = 7 + level * 2 + rnd(0, 1)
    local cells, list
    for _ = 1, 200 do
        cells, list = try_layout(target)
        if cells then break end
    end
    if not cells then cells, list = fallback_layout() end

    for i = 1, #list do
        local c = list[i]
        for d = 1, 4 do
            local n = cells[key(c.gx + DIRS[d].dx, c.gy + DIRS[d].dy)]
            if n then c.doors[DIRS[d].name] = n end
        end
    end
    for i = 1, #list do build(list[i]) end

    return { cells = cells, list = list, start = list[1] }
end

return D
