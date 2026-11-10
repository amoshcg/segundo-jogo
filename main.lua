require "palette"
require "sprites"

-- ===================================================================
-- TUMBA DAS MIL BALAS
-- Masmorra de salas sorteadas, para 1 ou 2 jogadores na mesma tela.
-- Limpe as salas, junte itens e derrote o chefe de cada um dos 3 andares.
--
-- Controle (mesmo mapeamento do primeiro-jogo; botoes em losango):
--   direcional ... anda e vira
--   B ............ atira para onde esta olhando (segurando, a mira trava)
--   A ............ rola (invencivel no comeco do rolamento)
--   Y ............ pulso: apaga as balas inimigas
--   X ............ troca de arma / pega arma do chao (segurar: larga)
--   R ............ pausa
--   Menus: B confirma, A volta. O L nao e usado (trava o console).
--
-- Arquivos: core (base), dungeon (salas), items, weapons, player, enemies.
-- ===================================================================
local K = require "core"
local D = require "dungeon"
local I = require "items"
local G = require "weapons"
local P = require "player"
local E = require "enemies"

local W, col = K.W, K.col
local flr, rnd, sin, cos, sqrt = math.floor, math.random, math.sin, math.cos, math.sqrt
local rf, cf, tri, ln, pr, prc, prs = K.rf, K.cf, K.tri, K.ln, K.pr, K.prc, K.prs

local LAST_LEVEL = 3

local THEMES = {
    {
        name = "CATACUMBA", floor = col.slate, floor2 = col.coal, wall = col.coal,
        wdark = col.ink, wlight = col.gray, rock = col.gray, rockl = col.silver,
        shadow = col.ink,
    },
    {
        name = "FORNALHA", floor = col.plum, floor2 = col.brown, wall = col.brown,
        wdark = col.ink, wlight = col.rust, rock = col.rust, rockl = col.tan,
        shadow = col.ink,
    },
    {
        name = "ABISMO", floor = col.ink, floor2 = col.indigo, wall = col.indigo,
        wdark = col.plum, wlight = col.blue, rock = col.navy, rockl = col.sky,
        shadow = col.plum,
    },
}

-- quem pode nascer em cada andar (repetido = mais comum)
local POOLS = {
    { "gosma", "gosma", "morcego", "morcego", "atirador", "javali", "totem" },
    { "gosma", "morcego", "atirador", "atirador", "javali", "totem", "gosmao", "bomba", "espiral" },
    { "morcego", "atirador", "javali", "totem", "gosmao", "bomba", "espiral", "mago", "fantasma", "fantasma" },
}

local frame_now = 0
local menu_sel = 1
local endT = 0

-- -------------------------------------------------------------------
-- Itens: saem de um baralho embaralhado, sem repetir ate acabar
-- -------------------------------------------------------------------
local function take_item()
    if #W.pool == 0 then
        local pool = {}
        for i = 1, #I.list do pool[i] = I.list[i] end
        for i = #pool, 2, -1 do
            local j = rnd(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        W.pool = pool
    end
    return table.remove(W.pool)
end

-- armas: mesmo esquema, sem a pistola (que todo mundo ja tem)
local function take_gun()
    if #W.gunpool == 0 then
        local pool = {}
        for i = 2, #G.list do pool[#pool + 1] = G.list[i] end
        for i = #pool, 2, -1 do
            local j = rnd(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        W.gunpool = pool
    end
    return table.remove(W.gunpool)
end

-- deixa uma arma cheia no chao da sala
local function place_gun(room, def, x, y)
    room.guns[#room.guns + 1] = { def = def, ammo = def.ammo, x = x, y = y, t = 0 }
end

local function banner(title, sub, t)
    W.banner = { title = title, sub = sub, t = t or 150 }
end

local function clear_list(list)
    for i = #list, 1, -1 do list[i] = nil end
end

local function clear_ebul(sparks)
    local list = W.ebul
    for i = #list, 1, -1 do
        local b = list[i]
        if sparks and i % 3 == 0 then K.burst(b.x, b.y, 1, col.yellow, 1) end
        K.free_bullet(b)
        list[i] = nil
    end
end

-- -------------------------------------------------------------------
-- Salas
-- -------------------------------------------------------------------
local function spawn_wave(room)
    local budget = 3 + W.level * 2 + rnd(0, 2)
    if W.nplayers == 2 then budget = budget + 2 end
    if room.depth <= 1 then budget = budget - 1 end
    local pool = POOLS[W.level]
    local n, guard = 0, 0
    while budget > 0 and n < 9 and guard < 60 do
        guard = guard + 1
        local kind = pool[rnd(#pool)]
        local cost = E.defs[kind].cost
        if cost <= budget then
            local x, y = D.free_spot(W.players, 80)
            E.telegraph(kind, x, y, 40 + n * 6)
            budget = budget - cost
            n = n + 1
        end
    end
end

-- dir = por qual lado os jogadores sairam da sala anterior (nil = comeco)
local function enter_room(room, dir)
    W.room = room
    room.visited, room.seen = true, true
    for _, n in pairs(room.doors) do n.seen = true end
    D.use(room)

    clear_list(W.enemies)
    clear_ebul(false)
    clear_list(W.pbul)
    clear_list(W.parts)
    clear_list(W.spawns)
    clear_list(W.texts)
    clear_list(W.booms)
    W.warns = {}
    W.boss, W.pulse = nil, nil
    W.fade = 12

    local ps = W.players
    for i = 1, #ps do
        local p = ps[i]
        local o = (i * 2 - #ps - 1) * 10
        if dir == "n" then
            p.x, p.y = 240 + o, 212
        elseif dir == "s" then
            p.x, p.y = 240 + o, 28
        elseif dir == "w" then
            p.x, p.y = 452, 120 + o
        elseif dir == "e" then
            p.x, p.y = 28, 120 + o
        else
            p.x, p.y = 240 + o * 1.5, 120
        end
        p.roll = 0
    end

    local fight = false
    if not room.cleared then
        if room.kind == "normal" then
            spawn_wave(room)
            fight = true
        elseif room.kind == "boss" then
            local kind = E.BOSSES[W.level]
            E.telegraph(kind, 240, 90, 80)
            banner(E.defs[kind].name, "CHEFE DO ANDAR", 110)
            fight = true
        else
            room.cleared = true
        end
    end
    W.locked = fight
    D.lock(fight)
end

local function setup_floor()
    local floor = D.gen_floor(W.level)
    W.floor = floor
    for i = 1, #floor.list do
        local room = floor.list[i]
        room.waves = 0
        if room.kind == "normal" and rnd() < 0.2 + W.level * 0.1 then room.waves = 1 end
        if room.kind == "treasure" then
            -- um item e uma arma para cada jogador
            for j = 1, W.nplayers do
                local x = 240 + (j * 2 - W.nplayers - 1) * 24
                room.peds[#room.peds + 1] = {
                    kind = "item", item = take_item(), price = 0, x = x, y = 108, t = 0,
                }
                place_gun(room, take_gun(), x, 150)
            end
        elseif room.kind == "shop" then
            room.peds[1] = { kind = "heart", price = 3, x = 152, y = 120, t = 0 }
            room.peds[2] = { kind = "pulse", price = 3, x = 196, y = 120, t = 0 }
            room.peds[3] = { kind = "ammo", price = 4, x = 240, y = 120, t = 0 }
            room.peds[4] = { kind = "gun", gun = take_gun(), price = 7 + W.level * 2, x = 284, y = 120, t = 0 }
            room.peds[5] = { kind = "item", item = take_item(), price = 6 + W.level * 2, x = 328, y = 120, t = 0 }
        elseif room.kind == "start" and W.level == 1 then
            -- uma arma logo de cara, para aprender a trocar
            for j = 1, W.nplayers do
                place_gun(room, take_gun(), 240 + (j * 2 - W.nplayers - 1) * 24, 76)
            end
        end
    end
    W.shadow = THEMES[W.level].shadow
    enter_room(floor.start, nil)
    banner("ANDAR " .. K.str(W.level), THEMES[W.level].name, 150)
end

local function start_game(n)
    math.randomseed(frame_now * 7919 + 17)
    W.nplayers = n
    W.players = {}
    for i = 1, n do W.players[i] = P.new(i) end
    W.level, W.coins, W.kills, W.rooms, W.time = 1, 0, 0, 0, 0
    W.shake, W.overt, W.wint = 0, 0, nil
    W.pool = {}
    W.gunpool = {}
    W.banner = nil
    W.screen = "play"
    setup_floor()
end

local function next_floor()
    W.level = W.level + 1
    local ps = W.players
    for i = 1, #ps do
        local p = ps[i]
        if p.dead then
            p.dead, p.hp = false, 2
        else
            P.heal(p, 2)
        end
        if p.pulses < 2 then p.pulses = 2 end
        p.inv = 60
    end
    setup_floor()
end

local function drop(kind, x, y)
    local list = W.room.pickups
    list[#list + 1] = { k = kind, x = x, y = y, t = 0 }
end

-- sala limpa: abre as portas, levanta quem caiu e talvez deixa um premio
local function room_cleared()
    local room = W.room
    room.cleared = true
    W.locked = false
    D.lock(false)
    W.rooms = W.rooms + 1
    clear_ebul(true)
    W.warns = {}

    local ps = W.players
    local alive = false
    for i = 1, #ps do
        if not ps[i].dead then alive = true end
    end
    if alive then
        for i = 1, #ps do
            local p = ps[i]
            if p.dead then
                p.dead, p.hp, p.inv = false, 2, 90
                K.burst(p.x, p.y, 12, col.white, 2)
                K.float("DE VOLTA!", p.x, p.y - 12, col.white)
            end
        end
    end

    if room.kind == "boss" then
        for j = 1, W.nplayers do
            room.peds[#room.peds + 1] = {
                kind = "item", item = take_item(), price = 0,
                x = 240 + (j * 2 - W.nplayers - 1) * 24, y = 140, t = 0,
            }
        end
        drop("heart", 200, 176)
        drop("heart", 280, 176)
        drop("ammo", 240, 176)
        if W.level < LAST_LEVEL then
            place_gun(room, take_gun(), 240, 204)
            room.trap = { x = 240, y = 72, t = 0 }
            banner("CHEFE DERROTADO", "DESCA PELO ALCAPAO", 180)
        else
            W.wint = 200
            banner("FERREIRO DERROTADO", "A TUMBA E SUA!", 200)
        end
        return
    end

    local x, y = D.free_near(240, 120)
    local r = rnd()
    if r < 0.3 then
        drop("coin", x, y)
    elseif r < 0.45 then
        drop("coin", x - 8, y)
        drop("coin", x + 8, y)
    elseif r < 0.65 then
        drop("heart", x, y)
    elseif r < 0.73 then
        drop("pulse", x, y)
    elseif r < 0.85 then
        drop("ammo", x, y)
    elseif r < 0.91 then
        place_gun(room, take_gun(), x, y)
    end
end

-- passou por uma porta aberta? troca de sala
local function check_doors()
    if W.locked then return false end
    local room = W.room
    local d = room.doors
    local ps = W.players
    for i = 1, #ps do
        local p = ps[i]
        if not p.dead then
            local dir
            if p.y < 9 and d.n then dir = "n"
            elseif p.y > 231 and d.s then dir = "s"
            elseif p.x < 9 and d.w then dir = "w"
            elseif p.x > 471 and d.e then dir = "e" end
            if dir then
                enter_room(d[dir], dir)
                return true
            end
        end
    end
    return false
end

-- -------------------------------------------------------------------
-- Atualizacao da partida
-- -------------------------------------------------------------------
local function update_spawns()
    local list = W.spawns
    for i = #list, 1, -1 do
        local s = list[i]
        s.t = s.t - 1
        if s.t <= 0 then
            table.remove(list, i)
            E.spawn(s.kind, s.x, s.y)
            K.burst(s.x, s.y, 6, col.rose, 2)
        end
    end
end

-- explosao da bazuca: machuca todos os inimigos no raio
local function explode(x, y, r, dmg, own)
    local en = W.enemies
    for j = 1, #en do
        local e = en[j]
        local dx, dy = e.x - x, e.y - y
        local rr = r + e.r
        local d2 = dx * dx + dy * dy
        if d2 < rr * rr and not e.air then
            local d = sqrt(d2) + 0.01
            E.damage(e, dmg, dx / d * 3, dy / d * 3, own)
        end
    end
    W.booms[#W.booms + 1] = { x = x, y = y, r = r, t = 0 }
    K.burst(x, y, 10, col.orange, 3)
    K.shake(5)
end

local function update_pbul()
    local list = W.pbul
    local en = W.enemies
    for i = #list, 1, -1 do
        local s = list[i]

        if s.homing and #en > 0 then
            local best, bd = nil, 130 * 130
            for j = 1, #en do
                local e = en[j]
                local dx, dy = e.x - s.x, e.y - s.y
                local d = dx * dx + dy * dy
                if d < bd and e ~= s.last then best, bd = e, d end
            end
            if best and bd > 1 then
                local d = sqrt(bd)
                s.vx = s.vx + (best.x - s.x) / d * 0.4
                s.vy = s.vy + (best.y - s.y) / d * 0.4
                local v = sqrt(s.vx * s.vx + s.vy * s.vy)
                if v > 0.01 then s.vx, s.vy = s.vx / v * s.spd, s.vy / v * s.spd end
            end
        end

        local px, py = s.x, s.y
        s.x, s.y = s.x + s.vx, s.y + s.vy
        s.life = s.life - 1
        local dead = s.life <= 0

        if not dead then
            local v, idx = D.bullet_tile(s.x, s.y)
            if v then
                if v == 3 then
                    D.break_crate(idx)
                    K.burst(s.x, s.y, 6, col.tan, 2)
                    if rnd() < 0.3 then drop("coin", s.x - s.vx, s.y - s.vy) end
                    dead = true
                elseif s.bounce > 0 then
                    s.bounce = s.bounce - 1
                    if D.bullet_tile(s.x, py) then s.vx = -s.vx else s.vy = -s.vy end
                    s.x, s.y = px, py
                else
                    K.burst(px, py, 1, col.white, 1)
                    dead = true
                end
            end
        end

        if not dead then
            for j = 1, #en do
                local e = en[j]
                if not e.air and e ~= s.last then
                    local dx, dy = e.x - s.x, e.y - s.y
                    local rr = e.r + s.r
                    if dx * dx + dy * dy < rr * rr then
                        E.damage(e, s.dmg, s.vx * 0.25, s.vy * 0.25, s.own)
                        K.burst(s.x, s.y, 2, col.white, 1.5)
                        if s.pierce > 0 then
                            s.pierce = s.pierce - 1
                            s.last = e
                        else
                            dead = true
                        end
                        break
                    end
                end
            end
        end

        if dead then
            if s.boom then explode(s.x, s.y, s.boom, s.boomdmg, s.own) end
            list[i] = list[#list]
            list[#list] = nil
        end
    end
end

local function update_ebul()
    local list = W.ebul
    local ps = W.players
    for i = #list, 1, -1 do
        local s = list[i]
        s.x, s.y = s.x + s.vx, s.y + s.vy
        s.life = s.life - 1
        local dead = s.life <= 0 or D.bullet_tile(s.x, s.y) ~= nil
        if not dead then
            for j = 1, #ps do
                local p = ps[j]
                if not p.dead then
                    local dx, dy = p.x - s.x, p.y - s.y
                    local rr = s.r + 3
                    if dx * dx + dy * dy < rr * rr and P.hurt(p, 1) then
                        dead = true
                        break
                    end
                end
            end
        end
        if dead then
            K.free_bullet(s)
            list[i] = list[#list]
            list[#list] = nil
        end
    end
end

local function update_warns()
    local list = W.warns
    local ps = W.players
    for i = #list, 1, -1 do
        local w = list[i]
        w.t = w.t - 1
        if w.t <= 0 then
            table.remove(list, i)
            K.burst(w.x, w.y, 8, col.orange, 2.5)
            K.ring(w.x, w.y, 6, 1.2, rnd() * 6.28)
            K.shake(3)
            for j = 1, #ps do
                local p = ps[j]
                local dx, dy = p.x - w.x, p.y - w.y
                local rr = w.r + 3
                if dx * dx + dy * dy < rr * rr then P.hurt(p, 1) end
            end
        end
    end
end

local function update_pickups()
    local room = W.room
    local ps = W.players

    local list = room.pickups
    for i = #list, 1, -1 do
        local it = list[i]
        it.t = it.t + 1
        for j = 1, #ps do
            local p = ps[j]
            local wants = not p.dead and (it.k == "coin"
                or (it.k == "heart" and p.hp < p.maxhp)
                or (it.k == "pulse" and p.pulses < 6)
                or (it.k == "ammo" and P.needs_ammo(p)))
            if wants then
                local dx, dy = p.x - it.x, p.y - it.y
                local d2 = dx * dx + dy * dy
                if p.magnet and d2 < 80 * 80 and d2 > 4 then
                    local d = sqrt(d2)
                    it.x, it.y = it.x + dx / d * 2.5, it.y + dy / d * 2.5
                end
                if d2 < 12 * 12 and it.t > 8 then
                    if it.k == "coin" then
                        W.coins = W.coins + 1
                    elseif it.k == "heart" then
                        P.heal(p, 2)
                    elseif it.k == "ammo" then
                        P.add_ammo(p, 0.5)
                        K.float("+MUNICAO", p.x, p.y - 12, col.white)
                    else
                        p.pulses = p.pulses + 1
                    end
                    K.burst(it.x, it.y, 4, col.white, 1.5)
                    table.remove(list, i)
                    break
                end
            end
        end
    end

    local guns = room.guns
    for i = 1, #guns do guns[i].t = guns[i].t + 1 end

    -- pedestais: itens gratis (tesouro/chefe) ou com preco (loja)
    local peds = room.peds
    for i = #peds, 1, -1 do
        local pd = peds[i]
        pd.t = pd.t + 1
        for j = 1, #ps do
            local p = ps[j]
            local dx, dy = p.x - pd.x, p.y - pd.y
            if not p.dead and pd.t > 30 and W.coins >= pd.price
                and dx * dx + dy * dy < 13 * 13 then
                local ok = true
                if pd.kind == "heart" then
                    ok = P.heal(p, 2)
                elseif pd.kind == "pulse" then
                    ok = p.pulses < 6
                    if ok then p.pulses = p.pulses + 1 end
                elseif pd.kind == "ammo" then
                    ok = P.add_ammo(p, 1)
                elseif pd.kind == "gun" then
                    ok = P.wants_gun(p, pd.gun)
                    if ok then P.give_gun(p, pd.gun, pd.gun.ammo, pd.x, pd.y + 22) end
                else
                    pd.item.apply(p)
                    p.items[#p.items + 1] = pd.item
                    banner(pd.item.name, pd.item.desc, 150)
                end
                if ok then
                    W.coins = W.coins - pd.price
                    K.burst(pd.x, pd.y - 6, 10, col.yellow, 2)
                    table.remove(peds, i)
                    break
                end
            end
        end
    end

    -- alcapao para o proximo andar
    local trap = room.trap
    if trap then
        trap.t = trap.t + 1
        if trap.t > 40 then
            for j = 1, #ps do
                local p = ps[j]
                local dx, dy = p.x - trap.x, p.y - trap.y
                if not p.dead and dx * dx + dy * dy < 10 * 10 then
                    next_floor()
                    return
                end
            end
        end
    end
end

local function update_texts()
    local list = W.texts
    for i = #list, 1, -1 do
        local t = list[i]
        t.y = t.y - 0.4
        t.life = t.life - 1
        if t.life <= 0 then table.remove(list, i) end
    end
end

local function update_play()
    -- pausa no R
    for i = 1, W.nplayers do
        if K.pressed(i, "r") then
            W.screen = "pause"
            return
        end
    end

    W.time = W.time + 1
    if W.fade > 0 then W.fade = W.fade - 1 end
    if W.shake > 0 then W.shake = W.shake - 1 end
    if W.banner then
        W.banner.t = W.banner.t - 1
        if W.banner.t <= 0 then W.banner = nil end
    end

    local ps = W.players
    for i = 1, #ps do P.update(ps[i]) end
    if check_doors() then return end

    update_spawns()
    E.update_all()
    update_pbul()
    update_ebul()
    update_warns()
    update_pickups()
    K.update_parts()
    update_texts()

    local pu = W.pulse
    if pu then
        pu.t = pu.t + 1
        if pu.t > 18 then W.pulse = nil end
    end
    local booms = W.booms
    for i = #booms, 1, -1 do
        booms[i].t = booms[i].t + 1
        if booms[i].t > 10 then table.remove(booms, i) end
    end

    if W.locked and #W.enemies == 0 and #W.spawns == 0 then
        local room = W.room
        if room.waves > 0 then
            room.waves = room.waves - 1
            spawn_wave(room)
        else
            room_cleared()
        end
    end

    -- fim de jogo: todo mundo caiu / ultimo chefe derrotado
    local alive = false
    for i = 1, #ps do
        if not ps[i].dead then alive = true end
    end
    if not alive then
        W.overt = W.overt + 1
        if W.overt > 80 then
            W.screen = "over"
            endT = 0
        end
    elseif W.wint then
        W.wint = W.wint - 1
        if W.wint % 12 == 0 then
            K.burst(rnd(60, 420), rnd(40, 200), 8, rnd(2) == 1 and col.yellow or col.cyan, 3)
        end
        if W.wint <= 0 then
            W.screen = "win"
            endT = 0
        end
    end
end

-- -------------------------------------------------------------------
-- Desenho da sala
-- -------------------------------------------------------------------
local function heart(x, y, c)
    cf(x + 2, y + 2, 2, c)
    cf(x + 6, y + 2, 2, c)
    tri(x, y + 3, x + 8, y + 3, x + 4, y + 8, c)
end

local function draw_door(th, n, x0, y0, x1, y1)
    if not n then return end
    local frame = th.wlight
    if n.kind == "boss" then frame = col.red
    elseif n.kind == "treasure" then frame = col.yellow
    elseif n.kind == "shop" then frame = col.green end
    if W.locked then
        rf(x0, y0, x1, y1, col.rust)
        if x1 - x0 > y1 - y0 then
            for x = x0 + 5, x1 - 3, 7 do rf(x, y0, x + 1, y1, col.ink) end
        else
            for y = y0 + 5, y1 - 3, 7 do rf(x0, y, x1, y + 1, col.ink) end
        end
    else
        rf(x0, y0, x1, y1, col.ink)
    end
    K.rect(x0, y0, x1, y1, frame)
end

-- caixinha de municao
local function draw_ammo(x, y)
    rf(x - 4, y - 3, x + 4, y + 3, col.moss)
    rf(x - 4, y - 1, x + 4, y, col.yellow)
end

local function draw_ped(pd)
    local x, y = pd.x, pd.y
    local b = flr(sin((W.time + x) * 0.08) * 2)
    rf(x - 6, y + 4, x + 6, y + 9, col.gray)
    rf(x - 8, y + 2, x + 8, y + 4, col.silver)
    if pd.kind == "heart" then
        heart(x - 4, y - 11 + b, col.red)
    elseif pd.kind == "pulse" then
        cf(x, y - 7 + b, 4, col.cyan)
        rf(x - 1, y - 8 + b, x, y - 7 + b, col.white)
    elseif pd.kind == "ammo" then
        draw_ammo(x, y - 7 + b)
    elseif pd.kind == "gun" then
        G.icon(pd.gun, x, y - 7 + b)
    else
        cf(x, y - 7 + b, 6, pd.item.c)
        K.circ(x, y - 7 + b, 6, col.white)
        pr(pd.item.icon, x - 2, y - 11 + b, col.ink)
    end
    if pd.price > 0 then
        local c = W.coins >= pd.price and col.yellow or col.rose
        cf(x - 7, y + 16, 2, c)
        pr(K.str(pd.price), x - 2, y + 12, c)
    end
end

local function draw_room()
    local th = THEMES[W.level]
    local room = W.room
    local sx, sy = 0, 0
    if W.shake > 0 then
        local m = W.shake > 6 and 3 or 2
        sx, sy = rnd(-m, m), rnd(-m, m)
    end

    ui.cls(th.wall)
    K.offset(sx, K.HUD + sy)

    -- chao e relevo das paredes
    rf(16, 16, 463, 223, th.floor)
    if K.dither(1) then
        rf(16, 16, 463, 223, th.floor2)
        K.dither(0)
    end
    rf(16, 10, 463, 15, th.wdark)
    rf(16, 16, 463, 17, th.shadow)
    K.rect(15, 15, 464, 224, th.wdark)
    rf(0, 225, 479, 226, th.wlight)
    for x = 24, 456, 48 do
        rf(x, 2, x + 1, 7, th.wdark)
        rf(x + 24, 230, x + 25, 235, th.wdark)
    end

    local d = room.doors
    draw_door(th, d.n, 224, 0, 255, 15)
    draw_door(th, d.s, 224, 224, 255, 239)
    draw_door(th, d.w, 0, 96, 15, 143)
    draw_door(th, d.e, 464, 96, 479, 143)

    -- enfeites do chao
    local deco = room.deco
    for i = 1, #deco do
        local e = deco[i]
        if e.k == 1 then
            rf(e.x, e.y, e.x + 1, e.y + 1, th.floor2)
        elseif e.k == 2 then
            ln(e.x, e.y, e.x + 5, e.y + 3, th.floor2)
        else
            rf(e.x, e.y, e.x + 3, e.y, th.floor2)
        end
    end

    -- dicas no chao da primeira sala
    if room.kind == "start" and W.level == 1 then
        prc("DIRECIONAL: ANDAR E MIRAR     B: ATIRAR (SEGURE PARA TRAVAR A MIRA)", 240, 168, th.wlight)
        prc("A: ROLAR     Y: PULSO     X: TROCAR OU PEGAR ARMA (SEGURE: LARGAR)", 240, 180, th.wlight)
        prc("R: PAUSA", 240, 192, th.wlight)
    end

    -- pedras e espinhos (em faixas), depois caixotes
    local runs = room.runs
    for i = 1, #runs do
        local r = runs[i]
        if r.v == 2 then
            rf(r.x0, r.y, r.x1, r.y + 15, th.rock)
            rf(r.x0, r.y, r.x1, r.y + 2, th.rockl)
            rf(r.x0, r.y + 13, r.x1, r.y + 15, th.wdark)
        else
            rf(r.x0, r.y, r.x1, r.y + 15, th.wdark)
            for x = r.x0 + 3, r.x1, 8 do
                rf(x, r.y + 3, x + 1, r.y + 6, col.silver)
                rf(x + 4, r.y + 10, x + 5, r.y + 13, col.silver)
            end
        end
    end
    local crates, t = room.crates, room.t
    for i = 1, #crates do
        local c = crates[i]
        if t[c.idx] == 3 then
            rf(c.x + 1, c.y + 1, c.x + 14, c.y + 14, col.tan)
            K.rect(c.x + 1, c.y + 1, c.x + 14, c.y + 14, col.brown)
            ln(c.x + 2, c.y + 2, c.x + 13, c.y + 13, col.brown)
        end
    end

    -- alcapao
    local trap = room.trap
    if trap then
        local x, y = trap.x, trap.y
        rf(x - 10, y - 10, x + 10, y + 10, col.ink)
        K.rect(x - 10, y - 10, x + 10, y + 10, col.yellow)
        for k = 0, 2 do
            rf(x - 7 + k * 3, y - 6 + k * 5, x + 7, y - 5 + k * 5, col.gray)
        end
    end

    local peds = room.peds
    for i = 1, #peds do draw_ped(peds[i]) end

    local picks = room.pickups
    for i = 1, #picks do
        local it = picks[i]
        local x, y = flr(it.x), flr(it.y) + flr(sin((W.time + i * 9) * 0.12) * 1.5)
        if it.k == "coin" then
            cf(x, y, 3, col.yellow)
            rf(x - 1, y - 2, x - 1, y, col.white)
        elseif it.k == "heart" then
            heart(x - 4, y - 4, col.red)
        elseif it.k == "ammo" then
            draw_ammo(x, y)
        else
            cf(x, y, 3, col.cyan)
            rf(x - 1, y - 1, x, y, col.white)
        end
    end

    -- armas no chao: o X aparece quando da para pegar/trocar com o botao
    local guns = room.guns
    local psl = W.players
    for i = 1, #guns do
        local g = guns[i]
        K.circ(g.x, g.y, 9, W.time % 30 < 15 and col.white or col.gray)
        G.icon(g.def, g.x, g.y + flr(sin((W.time + i * 13) * 0.1) * 1.5))
        if g.t > 25 then
            for j = 1, #psl do
                local p = psl[j]
                local dx, dy = p.x - g.x, p.y - g.y
                if not p.dead and dx * dx + dy * dy < 14 * 14 then
                    prs("X: " .. g.def.name, g.x, g.y - 22, col.yellow)
                    break
                end
            end
        end
    end

    -- avisos no chao (chuva de fogo) e pontos de nascimento
    local warns = W.warns
    for i = 1, #warns do
        local w = warns[i]
        K.circ(w.x, w.y, w.r, col.red)
        cf(w.x, w.y, flr(w.r * (1 - w.t / w.max)), col.orange)
    end
    local spawns = W.spawns
    for i = 1, #spawns do
        local s = spawns[i]
        if s.t < 44 then
            local r = 3 + flr(s.t / 5)
            K.circ(s.x, s.y, r, col.rose)
            if s.t % 8 < 4 then
                ln(s.x - 3, s.y - 3, s.x + 3, s.y + 3, col.rose)
                ln(s.x - 3, s.y + 3, s.x + 3, s.y - 3, col.rose)
            end
        end
    end

    E.draw_all()
    local ps = W.players
    for i = 1, #ps do P.draw(ps[i]) end

    -- balas dos jogadores
    local pb = W.pbul
    for i = 1, #pb do
        local s = pb[i]
        if s.flame then
            cf(s.x, s.y, s.life > 9 and 2 or 3, s.life % 4 < 2 and col.orange or col.yellow)
        else
            cf(s.x, s.y, s.r, s.own == 1 and col.cyan or col.lime)
            if s.r > 2 then rf(s.x - 1, s.y - 1, s.x + 1, s.y + 1, col.white) end
        end
    end

    -- balas dos inimigos (com muitas na tela, tira o miolo para aliviar)
    local eb = W.ebul
    local core = #eb < 90
    for i = 1, #eb do
        local s = eb[i]
        local x, y = flr(s.x), flr(s.y)
        local k = s.k
        if k == 0 then
            cf(x, y, s.r, col.rose)
            if core then rf(x - 1, y - 1, x + 1, y + 1, col.yellow) end
        elseif k == 1 then
            cf(x, y, s.r, col.purple)
            if core then rf(x - 1, y - 1, x + 1, y + 1, col.pink) end
        else
            cf(x, y, s.life % 8 < 4 and 3 or 2, s.life < 30 and col.red or col.orange)
        end
    end

    local parts = W.parts
    for i = 1, #parts do
        local p = parts[i]
        rf(p.x, p.y, p.x + 1, p.y + 1, p.c)
    end

    local pu = W.pulse
    if pu then
        K.circ(pu.x, pu.y, pu.t * 7 + 4, col.cyan)
        K.circ(pu.x, pu.y, pu.t * 7, col.white)
    end
    local booms = W.booms
    for i = 1, #booms do
        local b = booms[i]
        if b.t < 4 then cf(b.x, b.y, flr(b.r * 0.6), col.yellow) end
        K.circ(b.x, b.y, flr(b.r * (0.5 + b.t / 20)), col.orange)
    end

    local texts = W.texts
    for i = 1, #texts do
        local tx = texts[i]
        prs(tx.s, tx.x, tx.y, tx.c)
    end
end

-- -------------------------------------------------------------------
-- Barra de cima, chefe e avisos
-- -------------------------------------------------------------------
local function draw_hud()
    K.offset(0, 0)
    rf(0, 0, 479, 29, col.ink)
    rf(0, 29, 479, 29, col.indigo)

    local ps = W.players
    for i = 1, #ps do
        local p = ps[i]
        local c = i == 1 and col.cyan or col.lime
        local left = i == 1
        pr("P" .. K.str(i), left and 4 or 464, 4, c)
        for h = 1, p.maxhp / 2 do
            local x = left and (8 + h * 11) or (462 - h * 11)
            heart(x, 4, col.coal)
            if p.hp >= h * 2 then
                heart(x, 4, col.red)
            elseif p.hp == h * 2 - 1 then
                cf(x + 2, 6, 2, col.red)
                tri(x, 7, x + 4, 7, x + 4, 12, col.red)
            end
        end
        for k = 1, p.pulses do
            local x = left and (15 + k * 8) or (464 - k * 8)
            cf(x, 21, 2, col.cyan)
            rf(x, 20, x, 20, col.white)
        end
        if p.dead then
            pr("CAIDO", left and 20 or 428, 17, col.rose)
        end

        -- arma atual, municao e uma marquinha por arma carregada
        local gx = left and 92 or 284
        local g = p.guns[p.gi]
        local d = g.def
        G.icon(d, gx + 6, 8)
        pr(d.name, gx + 18, 4, d.c)
        if d.ammo then
            pr(K.str(g.ammo), gx + 18, 16, g.ammo > 0 and col.white or col.rose)
        else
            pr("INF", gx + 18, 16, col.gray)
        end
        for k = 1, #p.guns do
            rf(gx + k * 5 - 4, 19, gx + k * 5 - 1, 22, k == p.gi and col.yellow or col.coal)
        end
    end

    -- sozinho, sobra o lado direito: mostra os itens ja pegos
    if #ps == 1 then
        local items = ps[1].items
        for j = 1, math.min(#items, 20) do
            local k = j - 1
            pr(items[j].icon, 300 + (k % 10) * 8, 4 + flr(k / 10) * 12, items[j].c)
        end
    end

    -- andar e moedas
    pr("ANDAR " .. K.str(W.level), 160, 4, col.silver)
    cf(164, 20, 3, col.yellow)
    rf(163, 18, 163, 20, col.white)
    pr(K.str(W.coins), 172, 16, col.yellow)

    -- minimapa: so mostra as salas ja vistas
    local list = W.floor.list
    for i = 1, #list do
        local r = list[i]
        if r.seen then
            local x, y = 204 + (r.gx - 1) * 8, 1 + (r.gy - 1) * 4
            local c = col.coal
            if r.kind == "boss" then c = col.red
            elseif r.kind == "treasure" then c = col.yellow
            elseif r.kind == "shop" then c = col.green
            elseif r.visited then c = col.gray end
            rf(x, y, x + 6, y + 2, c)
            if r == W.room then K.rect(x - 1, y - 1, x + 7, y + 3, col.white) end
        end
    end

    -- vida do chefe, em cima da parede de baixo
    local b = W.boss
    if b then
        rf(96, 257, 384, 267, col.ink)
        local w = flr(286 * math.max(0, b.hp) / b.maxhp)
        if w > 0 then rf(97, 258, 97 + w, 266, col.red) end
        K.rect(96, 257, 384, 267, col.silver)
        prs(b.def.name, 240, 258, col.white)
    end

    local bn = W.banner
    if bn then
        local w = math.max(K.tw(bn.title), K.tw(bn.sub)) + 24
        local x0 = flr(240 - w / 2)
        rf(x0, 54, x0 + w, 86, col.ink)
        K.rect(x0, 54, x0 + w, 86, col.yellow)
        prc(bn.title, 240, 60, col.yellow)
        prc(bn.sub, 240, 73, col.white)
    end

    -- cortina pontilhada ao entrar numa sala
    if W.fade > 0 then
        local lv = W.fade > 8 and 3 or (W.fade > 4 and 2 or 1)
        if K.dither(lv) then
            rf(0, 30, 479, 269, col.ink)
            K.dither(0)
        end
    end
end

local function draw_play()
    draw_room()
    draw_hud()
end

-- -------------------------------------------------------------------
-- Telas: titulo, controles, pausa e fim
-- -------------------------------------------------------------------

-- letras grandes do titulo, feitas de retangulos {x, y, largura, altura}
local BIG = {
    T = { { 0, 0, 5, 1 }, { 2, 1, 1, 4 } },
    U = { { 0, 0, 1, 5 }, { 4, 0, 1, 5 }, { 1, 4, 3, 1 } },
    M = { { 0, 0, 1, 5 }, { 4, 0, 1, 5 }, { 1, 1, 1, 1 }, { 3, 1, 1, 1 }, { 2, 2, 1, 1 } },
    B = { { 0, 0, 1, 5 }, { 1, 0, 3, 1 }, { 1, 2, 3, 1 }, { 1, 4, 3, 1 }, { 4, 1, 1, 1 }, { 4, 3, 1, 1 } },
    A = { { 0, 1, 1, 4 }, { 4, 1, 1, 4 }, { 1, 0, 3, 1 }, { 1, 2, 3, 1 } },
}

local function draw_big(text, x, y, s, c)
    for i = 1, #text do
        local g = BIG[text:sub(i, i)]
        local gx = x + (i - 1) * 6 * s
        for j = 1, #g do
            local r = g[j]
            rf(gx + r[1] * s, y + r[2] * s, gx + (r[1] + r[3]) * s - 1, y + (r[2] + r[4]) * s - 1, c)
        end
    end
end

local MENU = { "1 JOGADOR", "2 JOGADORES", "CONTROLES" }

local function update_title()
    if K.any("down") then menu_sel = menu_sel % #MENU + 1 end
    if K.any("up") then menu_sel = (menu_sel - 2) % #MENU + 1 end
    if K.any("b") then
        if menu_sel == 3 then
            W.screen = "controls"
        else
            start_game(menu_sel)
        end
    end
end

local function draw_title()
    K.offset(0, 0)
    ui.cls(col.ink)
    -- balas girando em volta do titulo
    for i = 0, 23 do
        local a = frame_now * 0.012 + i * 0.2618
        local x, y = 240 + cos(a) * 215, 122 + sin(a) * 112
        cf(x, y, 3, i % 2 == 0 and col.rose or col.purple)
        rf(x - 1, y - 1, x + 1, y + 1, i % 2 == 0 and col.yellow or col.pink)
    end
    draw_big("TUMBA", 127, 43, 8, col.plum)
    draw_big("TUMBA", 124, 40, 8, col.yellow)
    prs("DAS  MIL  BALAS", 240, 90, col.rose)

    for i = 1, #MENU do
        local y = 126 + i * 16
        local on = i == menu_sel
        prc(MENU[i], 240, y, on and col.white or col.gray)
        if on then
            local w = flr(K.tw(MENU[i]) / 2) + 10 + flr(sin(frame_now * 0.15) * 2)
            tri(240 - w, y, 240 - w, y + 6, 240 - w + 5, y + 3, col.yellow)
            tri(240 + w, y, 240 + w, y + 6, 240 + w - 5, y + 3, col.yellow)
        end
    end
    prc("DIRECIONAL: ESCOLHER     B: CONFIRMAR", 240, 214, col.silver)
end

local function update_controls()
    if K.any("a") then W.screen = "title" end
end

local function lit(name)
    return K.down(1, name) or K.down(2, name)
end

local function draw_controls()
    K.offset(0, 0)
    ui.cls(col.ink)
    prc("CONTROLES", 240, 8, col.yellow)

    -- desenho do controle: os botoes acendem quando apertados
    local on, body = col.white, col.ice
    rf(118, 22, 178, 30, col.coal)
    rf(302, 22, 362, 30, lit("r") and on or col.gray)
    pr("R", 329, 23, col.ink)
    cf(160, 72, 42, body)
    cf(320, 72, 42, body)
    rf(160, 30, 320, 114, body)
    rf(152, 52, 168, 92, col.coal)
    rf(140, 64, 180, 80, col.coal)
    rf(154, 54, 166, 63, lit("up") and on or col.ink)
    rf(154, 81, 166, 90, lit("down") and on or col.ink)
    rf(142, 66, 151, 78, lit("left") and on or col.ink)
    rf(169, 66, 178, 78, lit("right") and on or col.ink)
    local face = {
        { "X", "x", 320, 52, col.blue },
        { "Y", "y", 300, 72, col.green },
        { "A", "a", 340, 72, col.red },
        { "B", "b", 320, 92, col.yellow },
    }
    for i = 1, #face do
        local f = face[i]
        cf(f[3], f[4], 9, lit(f[2]) and on or f[5])
        pr(f[1], f[3] - 2, f[4] - 3, col.ink)
    end

    local rows = {
        { "DIRECIONAL", "ANDAR E MIRAR (ATIRA PARA ONDE OLHA)" },
        { "B", "ATIRAR - SEGURANDO, A MIRA TRAVA: ANDE DE LADO" },
        { "A", "ROLAR (INVENCIVEL NO COMECO)" },
        { "Y", "PULSO: APAGA AS BALAS INIMIGAS" },
        { "X", "TROCAR DE ARMA / PEGAR ARMA DO CHAO" },
        { "X (SEGURAR)", "LARGAR A ARMA ATUAL" },
        { "R", "PAUSA" },
    }
    for i = 1, #rows do
        local y = 108 + i * 12
        pr(rows[i][1], 62, y, col.cyan)
        pr(rows[i][2], 146, y, col.white)
    end
    prc("2 JOGADORES: CADA UM NO SEU CONTROLE, NA MESMA SALA", 240, 210, col.lime)
    prc("TECLADO: W A S D ANDA   K ATIRA   H ROLA   G PULSO   J ARMA", 240, 224, col.gray)
    prc("A: VOLTAR", 240, 248, col.silver)
end

local function update_pause()
    for i = 1, W.nplayers do
        if K.pressed(i, "b") or K.pressed(i, "r") then W.screen = "play" end
        if K.pressed(i, "a") then W.screen = "title" end
    end
end

local function draw_pause()
    draw_play()
    K.offset(0, 0)
    if K.dither(2) then
        rf(0, 30, 479, 269, col.ink)
        K.dither(0)
    end
    rf(150, 96, 330, 186, col.ink)
    K.rect(150, 96, 330, 186, col.yellow)
    prc("PAUSA", 240, 106, col.yellow)
    prc("B OU R: CONTINUAR", 240, 128, col.white)
    prc("A: SAIR PARA O MENU", 240, 142, col.silver)
    -- itens de cada jogador
    local ps = W.players
    for i = 1, #ps do
        local items = ps[i].items
        pr("P" .. K.str(i), 160, 150 + i * 11, i == 1 and col.cyan or col.lime)
        for j = 1, math.min(#items, 15) do
            pr(items[j].icon, 172 + j * 9, 150 + i * 11, items[j].c)
        end
    end
end

local function update_end()
    endT = endT + 1
    if endT > 40 then
        if K.any("b") then
            start_game(W.nplayers)
        elseif K.any("a") then
            W.screen = "title"
        end
    end
end

local function draw_end(win)
    K.offset(0, 0)
    ui.cls(col.ink)
    if win then
        for i = 0, 11 do
            local a = frame_now * 0.02 + i * 0.5236
            cf(240 + cos(a) * 150, 60 + sin(a) * 34, 3, i % 2 == 0 and col.yellow or col.cyan)
        end
        prs("A TUMBA FOI CONQUISTADA!", 240, 56, col.yellow)
    else
        prs("VOCE CAIU NA TUMBA", 240, 56, col.rose)
    end
    local secs = flr(W.time / 60)
    prc("ANDAR " .. K.str(W.level) .. " - " .. THEMES[W.level].name, 240, 100, col.white)
    prc("SALAS LIMPAS: " .. K.str(W.rooms), 240, 116, col.silver)
    prc("ABATES: " .. K.str(W.kills), 240, 130, col.silver)
    prc("MOEDAS: " .. K.str(W.coins), 240, 144, col.silver)
    prc(string.format("TEMPO: %d:%02d", flr(secs / 60), secs % 60), 240, 158, col.silver)
    if endT > 40 then
        prc("B: JOGAR DE NOVO     A: MENU", 240, 200, col.white)
    end
end

-- -------------------------------------------------------------------
-- Loop principal
-- -------------------------------------------------------------------
function loop(frame)
    frame_now = frame

    -- a paleta zera a cada quadro
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end
    ui.clip()
    ui.camera()

    K.poll()

    local s = W.screen
    if s == "title" then
        update_title()
    elseif s == "controls" then
        update_controls()
    elseif s == "play" then
        update_play()
    elseif s == "pause" then
        update_pause()
    else
        update_end()
    end

    s = W.screen
    if s == "title" then
        draw_title()
    elseif s == "controls" then
        draw_controls()
    elseif s == "play" then
        draw_play()
    elseif s == "pause" then
        draw_pause()
    else
        draw_end(s == "win")
    end
end
