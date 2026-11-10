-- ===================================================================
-- enemies.lua - inimigos comuns e chefes
-- Cada tipo tem: vida, raio, custo (para montar as ondas), update e draw.
-- ===================================================================
local K = require "core"
local D = require "dungeon"
local P = require "player"

local E = {}

local W, col = K.W, K.col
local flr, rnd, sin, cos, sqrt, abs = math.floor, math.random, math.sin, math.cos, math.sqrt, math.abs
local pi = math.pi
local atan2 = K.atan2
local rf, cf, tri, ln = K.rf, K.cf, K.tri, K.ln

-- jogador vivo mais perto e a distancia ate ele
local function target(x, y)
    local best, bd = nil, 1e12
    local ps = W.players
    for i = 1, #ps do
        local p = ps[i]
        if not p.dead then
            local dx, dy = p.x - x, p.y - y
            local d = dx * dx + dy * dy
            if d < bd then best, bd = p, d end
        end
    end
    if not best then return nil, 0 end
    return best, sqrt(bd)
end

local function aim(e, p)
    return atan2(p.y - e.y, p.x - e.x)
end

-- anda na direcao do jogador; se travar numa pedra, contorna de lado
local function steer(e, p, spd)
    local dx, dy = p.x - e.x, p.y - e.y
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return end
    dx, dy = dx / d, dy / d
    local fly = e.def.fly
    local hx, hy = D.move(e, dx * spd, dy * spd, e.hb, fly)
    if hx and abs(dy) < 0.5 then
        D.move(e, 0, e.side * spd * 0.8, e.hb, fly)
    elseif hy and abs(dx) < 0.5 then
        D.move(e, e.side * spd * 0.8, 0, e.hb, fly)
    end
    if dx > 0.2 then e.face = 1 elseif dx < -0.2 then e.face = -1 end
end

-- cor do corpo: pisca branco quando leva tiro
local function fl(e, c)
    if e.hit > 0 then return col.white end
    return c
end

local function shadow(x, y, w)
    rf(x - w, y, x + w, y + 1, W.shadow)
end

-- marca um ponto onde um inimigo vai nascer daqui a t quadros
function E.telegraph(kind, x, y, t)
    W.spawns[#W.spawns + 1] = { kind = kind, x = x, y = y, t = t, max = t }
end

-- -------------------------------------------------------------------
-- Inimigos comuns
-- -------------------------------------------------------------------
local defs = {}
E.defs = defs

local function slime_update(e)
    local p = target(e.x, e.y)
    if not p then return end
    if e.t % 46 < 22 then steer(e, p, e.def.spd) end
end

local function slime_draw(e)
    local x, y, r = flr(e.x), flr(e.y), e.r
    local ph = e.t % 46
    local h = ph < 22 and flr(sin(ph / 22 * pi) * 5) or 0
    local c = fl(e, col.purple)
    local ex = flr(r / 2)
    shadow(x, y + r - 1, r - 1)
    cf(x, y - h, r, c)
    rf(x - r, y - h, x + r, y - h + r - 2, c)
    rf(x - ex, y - h - 2, x - ex + 1, y - h, col.white)
    rf(x + ex - 1, y - h - 2, x + ex, y - h, col.white)
    rf(x - r + 2, y - h - r + 2, x - r + 3, y - h - r + 3, col.pink)
end

-- GOSMA: pula na direcao do jogador
defs.gosma = { hp = 8, r = 6, spd = 1.25, cost = 1, update = slime_update, draw = slime_draw }

-- GOSMAO: gosma grande que se divide em duas ao morrer
defs.gosmao = {
    hp = 20, r = 10, spd = 1.0, cost = 3, update = slime_update, draw = slime_draw,
    die = function(e)
        for i = -1, 1, 2 do
            local c = E.spawn("gosma", e.x, e.y)
            c.kx = i * 2.5
        end
    end,
}

-- MORCEGO: voa em zigue-zague por cima das pedras
defs.morcego = {
    hp = 4, r = 4, spd = 1.05, cost = 1, fly = true,
    update = function(e)
        local p = target(e.x, e.y)
        if not p then return end
        local a = aim(e, p) + sin(e.t * 0.09 + e.seed) * 1.1
        D.move(e, cos(a) * e.def.spd, sin(a) * e.def.spd, e.hb, true)
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y) - 4
        local w = flr(sin(e.t * 0.5) * 3)
        local c = fl(e, col.silver)
        shadow(x, y + 9, 3)
        tri(x - 2, y, x - 9, y - 2 + w, x - 4, y + 3, c)
        tri(x + 2, y, x + 9, y - 2 + w, x + 4, y + 3, c)
        cf(x, y, 3, c)
        rf(x - 2, y - 1, x - 1, y - 1, col.red)
        rf(x + 1, y - 1, x + 2, y - 1, col.red)
    end,
}

-- ATIRADOR: mantem distancia, anda de lado e atira mirando
defs.atirador = {
    hp = 8, r = 6, spd = 0.6, cost = 2,
    update = function(e)
        local p, d = target(e.x, e.y)
        if not p or d < 1 then return end
        local dx, dy = (p.x - e.x) / d, (p.y - e.y) / d
        local mx, my
        if d < 70 then
            mx, my = -dx, -dy
        elseif d > 130 then
            mx, my = dx, dy
        else
            mx, my = -dy * e.side, dx * e.side
        end
        local hx, hy = D.move(e, mx * e.def.spd, my * e.def.spd, e.hb, false)
        if (hx or hy) and e.t % 30 == 0 then e.side = -e.side end
        e.face = dx >= 0 and 1 or -1
        e.cd = e.cd - 1
        if e.cd <= 0 then
            if W.level >= 2 then
                K.fan(e.x, e.y, aim(e, p), 3, 0.5, 1.9)
            else
                K.shoot(e.x, e.y, aim(e, p), 1.9)
            end
            e.cd = 95 + rnd(40)
        end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y)
        local c = fl(e, col.red)
        shadow(x, y + 6, 5)
        tri(x - 6, y + 6, x + 6, y + 6, x, y - 7, c)
        cf(x, y - 4, 4, c)
        rf(x - 2, y - 5, x + 2, y - 3, col.ink)
        rf(x - 2, y - 4, x - 2, y - 4, col.yellow)
        rf(x + 2, y - 4, x + 2, y - 4, col.yellow)
        if e.cd < 14 then cf(x + e.face * 6, y + 1, 2, col.yellow) end
    end,
}

-- TOTEM: parado, solta balas em cruz e depois em X
defs.totem = {
    hp = 14, r = 7, spd = 0, cost = 2, static = true,
    update = function(e)
        e.cd = e.cd - 1
        if e.cd <= 0 then
            e.alt = not e.alt
            if W.level >= 3 then
                K.ring(e.x, e.y, 8, 1.5, e.alt and 0.3927 or 0)
            else
                K.ring(e.x, e.y, 4, 1.5, e.alt and 0.7854 or 0)
            end
            e.cd = 85
        end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y)
        shadow(x, y + 8, 7)
        rf(x - 6, y - 8, x + 6, y + 7, fl(e, col.tan))
        rf(x - 6, y + 5, x + 6, y + 7, col.rust)
        rf(x - 6, y - 8, x + 6, y - 7, col.skin)
        rf(x - 3, y - 4, x + 3, y, col.ink)
        rf(x - 1, y - 3, x + 1, y - 1, e.cd < 16 and col.yellow or col.orange)
    end,
}

-- JAVALI: pisca e depois dispara em linha reta ate bater
defs.javali = {
    hp = 12, r = 7, spd = 0.6, cost = 2,
    update = function(e)
        local p, d = target(e.x, e.y)
        if not p then return end
        if e.st == 0 then
            steer(e, p, e.def.spd)
            e.cd = e.cd - 1
            if e.cd <= 0 and d < 170 and d > 1 then
                e.st, e.cd = 1, 26
                e.dx, e.dy = (p.x - e.x) / d, (p.y - e.y) / d
                e.face = e.dx >= 0 and 1 or -1
            end
        elseif e.st == 1 then
            e.cd = e.cd - 1
            if e.cd <= 0 then e.st, e.cd = 2, 55 end
        elseif e.st == 2 then
            local hx, hy = D.move(e, e.dx * 3.4, e.dy * 3.4, e.hb, false)
            e.cd = e.cd - 1
            if hx or hy or e.cd <= 0 then
                if hx or hy then
                    K.shake(3)
                    K.burst(e.x, e.y, 5, col.tan, 2)
                end
                e.st, e.cd = 3, 45
            end
        else
            e.cd = e.cd - 1
            if e.cd <= 0 then e.st, e.cd = 0, 40 + rnd(40) end
        end
    end,
    draw = function(e)
        local x, y, f = flr(e.x), flr(e.y), e.face
        local c = fl(e, col.rust)
        if e.st == 1 and e.cd % 6 < 3 then c = col.white end
        shadow(x, y + 7, 7)
        cf(x, y, 6, c)
        cf(x + f * 6, y + 1, 4, c)
        rf(x + f * 9 - 1, y + 2, x + f * 9, y + 4, col.white)
        rf(x + f * 6, y - 1, x + f * 6, y - 1, col.ink)
        if e.st == 3 then
            local a = e.t * 0.3
            rf(x + cos(a) * 6, y - 9, x + cos(a) * 6 + 1, y - 8, col.yellow)
            rf(x - cos(a) * 6, y - 9, x - cos(a) * 6 + 1, y - 8, col.yellow)
        end
    end,
}

-- ESPIRAL: olho voador que gira soltando balas
defs.espiral = {
    hp = 12, r = 7, spd = 0.25, cost = 3, fly = true,
    update = function(e)
        local p = target(e.x, e.y)
        if not p then return end
        steer(e, p, e.def.spd)
        if e.t % 200 < 120 and e.t % 12 == 0 then
            e.a = (e.a or 0) + 0.4
            K.shoot(e.x, e.y, e.a, 1.4, 3, 1)
            K.shoot(e.x, e.y, e.a + pi, 1.4, 3, 1)
        end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y) - 3
        local a = e.a or 0
        shadow(x, y + 11, 5)
        cf(x, y, 7, fl(e, col.white))
        cf(x + cos(a) * 3, y + sin(a) * 3, 3, col.rose)
        rf(x + cos(a) * 3, y + sin(a) * 3, x + cos(a) * 3 + 1, y + sin(a) * 3 + 1, col.ink)
    end,
}

-- BOMBA: corre ate o jogador e explode num anel de balas
defs.bomba = {
    hp = 5, r = 5, spd = 1.2, cost = 2,
    update = function(e)
        local p, d = target(e.x, e.y)
        if not p then return end
        if e.st == 0 then
            steer(e, p, e.def.spd)
            if d < 28 then e.st, e.cd = 1, 26 end
        else
            e.cd = e.cd - 1
            if e.cd <= 0 then
                e.boomed = true
                e.hp = 0
                K.ring(e.x, e.y, 10, 1.7, rnd() * 6.28)
                K.burst(e.x, e.y, 12, col.orange, 3)
                K.shake(6)
                local ps = W.players
                for i = 1, #ps do
                    local q = ps[i]
                    local dx, dy = q.x - e.x, q.y - e.y
                    if dx * dx + dy * dy < 26 * 26 then P.hurt(q, 1) end
                end
            end
        end
    end,
    die = function(e)
        if not e.boomed then K.ring(e.x, e.y, 5, 1.4, rnd() * 6.28) end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y)
        local c = fl(e, col.orange)
        if e.st == 1 and e.cd % 6 < 3 then c = col.yellow end
        shadow(x, y + 5, 4)
        cf(x, y, 5, c)
        ln(x, y - 5, x + 2, y - 8, col.tan)
        rf(x + 2, y - 9, x + 3, y - 8, col.yellow)
        rf(x - 2, y - 1, x - 2, y, col.ink)
        rf(x + 2, y - 1, x + 2, y, col.ink)
    end,
}

-- MAGO: atira um leque e se teleporta
defs.mago = {
    hp = 11, r = 6, spd = 0, cost = 3,
    update = function(e)
        local p = target(e.x, e.y)
        if not p then return end
        local ph = e.t % 170
        e.face = p.x >= e.x and 1 or -1
        if ph == 60 or (W.level >= 3 and ph == 90) then
            K.fan(e.x, e.y, aim(e, p), 5, 1.0, 1.7, 1)
        elseif ph == 150 then
            K.burst(e.x, e.y, 8, col.pink, 2)
            e.x, e.y = D.free_spot(W.players, 70)
            K.burst(e.x, e.y, 8, col.pink, 2)
        end
    end,
    draw = function(e)
        local x, y, f = flr(e.x), flr(e.y), e.face
        local ph = e.t % 170
        local c = fl(e, col.pink)
        shadow(x, y + 6, 5)
        tri(x - 6, y + 6, x + 6, y + 6, x, y - 6, c)
        cf(x, y - 3, 3, col.skin)
        tri(x - 5, y - 4, x + 5, y - 4, x, y - 13, col.indigo)
        ln(x + f * 7, y + 6, x + f * 7, y - 6, col.rust)
        cf(x + f * 7, y - 7, 2, (ph > 40 and ph < 62) and col.white or col.cyan)
    end,
}

-- FANTASMA: atravessa pedras devagar e solta aneis de balas lentas
defs.fantasma = {
    hp = 9, r = 6, spd = 0.45, cost = 2, fly = true,
    update = function(e)
        local p = target(e.x, e.y)
        if not p then return end
        steer(e, p, e.def.spd)
        e.cd = e.cd - 1
        if e.cd <= 0 then
            K.ring(e.x, e.y, 8, 1.1, rnd() * 6.28, 1)
            e.cd = 150
        end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y) - 3 + flr(sin(e.t * 0.1) * 2)
        local c = fl(e, e.cd < 18 and col.pink or col.ice)
        cf(x, y, 6, c)
        rf(x - 6, y, x + 6, y + 5, c)
        rf(x - 6, y + 6, x - 4, y + 7, c)
        rf(x - 1, y + 6, x + 1, y + 7, c)
        rf(x + 4, y + 6, x + 6, y + 7, c)
        rf(x - 3, y - 2, x - 2, y, col.ink)
        rf(x + 2, y - 2, x + 3, y, col.ink)
    end,
}

-- -------------------------------------------------------------------
-- Chefes (um por andar)
-- -------------------------------------------------------------------

-- REI GOSMA: da tres pulos (cada queda solta um anel) e depois cospe leques
defs.rei = {
    boss = true, name = "REI GOSMA", hp = 230, r = 17, hb = 10, static = true,
    init = function(e)
        e.st, e.cd, e.hops, e.h, e.n = 0, 70, 0, 0, 0
    end,
    update = function(e)
        local p = target(e.x, e.y)
        if not p then return end
        local rage = e.hp < e.maxhp * 0.5
        if e.st == 0 then
            e.cd = e.cd - 1
            if e.cd <= 0 then
                if e.hops < 3 then
                    e.st, e.jt, e.hops = 1, 0, e.hops + 1
                    e.sx, e.sy = e.x, e.y
                    e.tx = math.max(40, math.min(440, p.x))
                    e.ty = math.max(40, math.min(200, p.y))
                else
                    e.st, e.cd, e.n, e.hops = 2, 10, 0, 0
                end
            end
        elseif e.st == 1 then
            local dur = rage and 34 or 42
            e.jt = e.jt + 1
            local k = e.jt / dur
            e.x = e.sx + (e.tx - e.sx) * k
            e.y = e.sy + (e.ty - e.sy) * k
            e.h = sin(k * pi) * 46
            e.air = e.h > 12
            if e.jt >= dur then
                e.h, e.air = 0, false
                e.st, e.cd = 0, rage and 22 or 34
                K.ring(e.x, e.y, rage and 16 or 12, 1.5, rnd() * 6.28)
                K.burst(e.x, e.y + 10, 10, col.pink, 3)
                K.shake(7)
            end
        else
            e.cd = e.cd - 1
            if e.cd <= 0 then
                e.n = e.n + 1
                K.fan(e.x, e.y, aim(e, p), rage and 7 or 5, 0.9, 2.0)
                e.cd = 26
                if e.n >= 3 then
                    e.st, e.cd = 0, 50
                    if rage and #W.enemies < 4 then
                        E.telegraph("gosma", e.x - 34, e.y, 40)
                        E.telegraph("gosma", e.x + 34, e.y, 40)
                    end
                end
            end
        end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y)
        local h = flr(e.h)
        local c = fl(e, col.purple)
        local sw = 16 - flr(h / 5)
        rf(x - sw, y + 14, x + sw, y + 16, W.shadow)
        local by = y - h
        if e.st == 2 then by = by + flr(sin(e.t * 0.6) * 1.5) end
        cf(x, by, 17, c)
        rf(x - 17, by, x + 17, by + 14, c)
        rf(x - 12, by - 12, x - 9, by - 9, col.pink)
        rf(x - 8, by - 4, x - 4, by + 1, col.white)
        rf(x + 4, by - 4, x + 8, by + 1, col.white)
        rf(x - 6, by - 2, x - 5, by + 1, col.ink)
        rf(x + 5, by - 2, x + 6, by + 1, col.ink)
        rf(x - 6, by + 6, x + 6, by + 7, col.plum)
        -- coroa
        rf(x - 8, by - 20, x + 8, by - 16, col.yellow)
        tri(x - 8, by - 20, x - 4, by - 20, x - 8, by - 26, col.yellow)
        tri(x - 3, by - 20, x + 3, by - 20, x, by - 27, col.yellow)
        tri(x + 4, by - 20, x + 8, by - 20, x + 8, by - 26, col.yellow)
        rf(x - 1, by - 19, x + 1, by - 17, col.red)
    end,
}

-- OLHO DO ABISMO: flutua e alterna espiral, leques mirados e aneis
defs.olho = {
    boss = true, name = "OLHO DO ABISMO", hp = 330, r = 16, hb = 10, fly = true, static = true,
    init = function(e)
        e.st, e.cd, e.pat, e.pt, e.a = 0, 80, 0, 0, 0
        e.wx, e.wy = 240, 100
        e.lx, e.ly = 0, 1
    end,
    update = function(e)
        local p, d = target(e.x, e.y)
        if not p then return end
        local rage = e.hp < e.maxhp * 0.5
        if d > 1 then e.lx, e.ly = (p.x - e.x) / d, (p.y - e.y) / d end

        -- passeia ate um ponto e sorteia outro
        local dx, dy = e.wx - e.x, e.wy - e.y
        local dd = sqrt(dx * dx + dy * dy)
        if dd > 4 then
            e.x, e.y = e.x + dx / dd * 0.6, e.y + dy / dd * 0.6
        elseif e.t % 60 == 0 then
            e.wx, e.wy = 110 + rnd(260), 60 + rnd(120)
        end

        if e.st == 0 then
            e.cd = e.cd - 1
            if e.cd <= 0 then
                e.pat = e.pat % 3 + 1
                e.st, e.pt = 1, 0
            end
            return
        end

        e.pt = e.pt + 1
        local done = false
        if e.pat == 1 then
            if e.pt % 5 == 0 then
                e.a = e.a + 0.21
                for k = 0, 2 do K.shoot(e.x, e.y, e.a + k * 2.0944, 1.6) end
                if rage and e.pt % 10 == 0 then
                    K.shoot(e.x, e.y, -e.a * 1.3, 1.25, 3, 1)
                end
            end
            done = e.pt >= 150
        elseif e.pat == 2 then
            if e.pt % 28 == 1 then
                K.fan(e.x, e.y, aim(e, p), rage and 9 or 7, 1.3, 2.1)
            end
            done = e.pt >= 112
        else
            if e.pt % 34 == 1 then
                e.alt = not e.alt
                K.ring(e.x, e.y, rage and 22 or 18, 1.35, e.alt and 0.17 or 0, 1)
            end
            done = e.pt >= 136
        end
        if done then e.st, e.cd = 0, rage and 35 or 55 end
    end,
    draw = function(e)
        local x, y = flr(e.x), flr(e.y) - 4 + flr(sin(e.t * 0.07) * 3)
        rf(x - 12, flr(e.y) + 16, x + 12, flr(e.y) + 18, W.shadow)
        -- tentaculos
        for i = -1, 1 do
            local wx = flr(sin(e.t * 0.12 + i) * 4)
            ln(x + i * 8, y + 12, x + i * 10 + wx, y + 24, col.rose)
        end
        cf(x, y, 16, fl(e, col.white))
        K.circ(x, y, 16, col.rose)
        local ix, iy = flr(x + e.lx * 6), flr(y + e.ly * 6)
        cf(ix, iy, 8, e.st == 1 and col.red or col.rose)
        cf(ix, iy, 4, col.ink)
        rf(ix - 3, iy - 3, ix - 2, iy - 2, col.white)
    end,
}

-- FERREIRO DE ALMAS: martelada em 8 direcoes, investidas que deixam
-- brasas e chuva de fogo marcada no chao
defs.ferreiro = {
    boss = true, name = "FERREIRO DE ALMAS", hp = 430, r = 16, hb = 10, static = true,
    init = function(e)
        e.st, e.cd, e.pat, e.n = 0, 90, 0, 0
        e.dx, e.dy = 0, 1
    end,
    update = function(e)
        local p, d = target(e.x, e.y)
        if not p then return end
        local rage = e.hp < e.maxhp * 0.45
        if rage and not e.summoned then
            e.summoned = true
            E.telegraph("fantasma", 60, 60, 50)
            E.telegraph("fantasma", 420, 180, 50)
        end

        if e.st == 0 then           -- anda atras do jogador e escolhe o golpe
            steer(e, p, rage and 0.75 or 0.55)
            e.cd = e.cd - 1
            if e.cd <= 0 then
                e.pat = e.pat % 3 + 1
                e.n = 0
                if e.pat == 1 then
                    e.st, e.cd = 1, 28
                elseif e.pat == 2 then
                    e.st, e.cd = 2, 32
                else
                    e.st, e.cd = 4, 0
                end
            end
        elseif e.st == 1 then       -- martelada
            e.cd = e.cd - 1
            if e.cd <= 0 then
                local off = (e.n % 2) * 0.3927
                for k = 0, 7 do
                    for s = 1, 4 do
                        K.shoot(e.x, e.y, off + k * 0.7854, 0.9 + s * 0.45)
                    end
                end
                K.shake(8)
                K.burst(e.x, e.y + 8, 10, col.orange, 3)
                e.n = e.n + 1
                if e.n >= (rage and 3 or 2) then e.st, e.cd = 0, 80 else e.cd = 42 end
            end
        elseif e.st == 2 then       -- mira a investida
            e.cd = e.cd - 1
            if e.cd > 8 and d > 1 then
                e.dx, e.dy = (p.x - e.x) / d, (p.y - e.y) / d
                e.face = e.dx >= 0 and 1 or -1
            end
            if e.cd <= 0 then e.st, e.cd = 3, 70 end
        elseif e.st == 3 then       -- investida
            local hx, hy = D.move(e, e.dx * 4, e.dy * 4, e.hb, false)
            if e.t % 4 == 0 then K.shoot(e.x, e.y, 0, 0, 3, 2, 130) end
            e.cd = e.cd - 1
            if hx or hy or e.cd <= 0 then
                K.ring(e.x, e.y, 14, 1.6, rnd() * 6.28)
                K.shake(6)
                e.n = e.n + 1
                if e.n >= (rage and 4 or 3) then e.st, e.cd = 0, 70 else e.st, e.cd = 2, 26 end
            end
        else                        -- chuva de fogo
            e.cd = e.cd - 1
            if e.cd <= 0 then
                e.n = e.n + 1
                e.cd = rage and 7 or 10
                K.warn(p.x + rnd(-55, 55), p.y + rnd(-55, 55), 13, 50)
                if e.n >= 12 then e.st, e.cd = 0, 110 end
            end
        end
    end,
    draw = function(e)
        local x, y, f = flr(e.x), flr(e.y), e.face
        local c = fl(e, col.dgray)
        if e.st == 2 and e.cd % 6 < 3 then c = col.white end
        rf(x - 13, y + 15, x + 13, y + 17, W.shadow)
        rf(x - 7, y + 8, x - 2, y + 15, col.coal)
        rf(x + 2, y + 8, x + 7, y + 15, col.coal)
        rf(x - 11, y - 8, x + 11, y + 9, c)
        rf(x - 11, y + 4, x + 11, y + 6, col.rust)
        rf(x - 15, y - 9, x - 10, y - 2, col.gray)
        rf(x + 10, y - 9, x + 15, y - 2, col.gray)
        rf(x - 6, y - 18, x + 6, y - 8, col.gray)
        rf(x - 6, y - 18, x + 6, y - 16, col.silver)
        rf(x - 4, y - 14, x + 4, y - 12, col.ink)
        local eye = (e.st == 4 or e.st == 1) and col.yellow or col.orange
        rf(x - 3, y - 14, x - 2, y - 13, eye)
        rf(x + 2, y - 14, x + 3, y - 13, eye)
        -- martelo: levantado enquanto prepara a martelada
        local hx = x + f * 17
        local hy = y - 6
        if e.st == 1 then hy = y - 20 + flr((28 - math.min(28, e.cd)) / 4) end
        ln(hx, y + 6, hx, hy, col.rust)
        rf(hx - 5, hy - 7, hx + 5, hy, col.silver)
        rf(hx - 5, hy - 2, hx + 5, hy, col.gray)
    end,
}

E.BOSSES = { "rei", "olho", "ferreiro" }

-- -------------------------------------------------------------------
-- Criar, machucar e atualizar
-- -------------------------------------------------------------------
function E.spawn(kind, x, y)
    local def = defs[kind]
    local hp = def.hp
    if def.boss then
        if W.nplayers == 2 then hp = hp * 1.6 end
    else
        hp = hp * (1 + (W.level - 1) * 0.25)
        if W.nplayers == 2 then hp = hp * 1.35 end
    end
    local e = {
        def = def, kind = kind, x = x, y = y, r = def.r,
        hb = def.hb or math.min(def.r, 7),
        hp = hp, maxhp = hp, t = rnd(0, 40), hit = 0, kx = 0, ky = 0,
        cd = 40 + rnd(60), side = rnd(2) == 1 and 1 or -1, face = 1,
        st = 0, seed = rnd() * 6, air = false,
    }
    if def.init then def.init(e) end
    W.enemies[#W.enemies + 1] = e
    if def.boss then W.boss = e end
    return e
end

function E.damage(e, dmg, kx, ky, own)
    e.hp = e.hp - dmg
    e.hit = 4
    if own then e.own = own end
    if not e.def.static then
        e.kx, e.ky = e.kx + (kx or 0), e.ky + (ky or 0)
    end
end

local function drop(e)
    local r = rnd()
    local k
    if r < 0.22 then k = "coin" elseif r < 0.27 then k = "heart" elseif r < 0.29 then k = "pulse" end
    if k then
        local list = W.room.pickups
        list[#list + 1] = { k = k, x = e.x, y = e.y, t = 0 }
    end
end

local function die(e)
    local def = e.def
    K.burst(e.x, e.y, def.boss and 30 or 8, def.boss and col.yellow or col.silver, def.boss and 4 or 2)
    if def.die then def.die(e) end
    W.kills = W.kills + 1
    if def.boss then
        K.shake(14)
        W.boss = nil
    else
        drop(e)
    end
    -- sanguessuga: quem deu o ultimo tiro conta o abate
    local p = e.own and W.players[e.own]
    if p and p.vamp and not p.dead then
        p.vk = p.vk + 1
        if p.vk >= 12 then
            p.vk = 0
            if P.heal(p, 1) then K.float("+", p.x, p.y - 10, col.rose) end
        end
    end
end

function E.update_all()
    local list = W.enemies

    -- pulso do jogador: empurra e machuca quem esta perto
    local pu = W.pulse
    if pu and pu.fresh then
        pu.fresh = false
        for i = 1, #list do
            local e = list[i]
            local dx, dy = e.x - pu.x, e.y - pu.y
            local d = sqrt(dx * dx + dy * dy)
            if d < 110 then
                if d < 1 then dx, dy, d = 1, 0, 1 end
                E.damage(e, 4, dx / d * 4, dy / d * 4)
            end
        end
    end

    local players = W.players
    for i = #list, 1, -1 do
        local e = list[i]
        local def = e.def
        e.t = e.t + 1
        if e.hit > 0 then e.hit = e.hit - 1 end
        if e.kx ~= 0 or e.ky ~= 0 then
            D.move(e, e.kx, e.ky, e.hb, def.fly)
            e.kx, e.ky = e.kx * 0.8, e.ky * 0.8
            if abs(e.kx) < 0.05 then e.kx = 0 end
            if abs(e.ky) < 0.05 then e.ky = 0 end
        end
        def.update(e)

        if not e.air then
            for j = 1, #players do
                local p = players[j]
                if not p.dead then
                    local dx, dy = p.x - e.x, p.y - e.y
                    local rr = e.r + 3
                    if dx * dx + dy * dy < rr * rr then P.hurt(p, 1) end
                end
            end
        end

        if e.hp <= 0 then
            -- tira da lista antes: die() pode criar inimigos novos no fim
            table.remove(list, i)
            die(e)
        end
    end

    -- nao deixa os inimigos empilharem um em cima do outro
    local n = #list
    for i = 1, n - 1 do
        local a = list[i]
        if not a.def.static then
            for j = i + 1, n do
                local b = list[j]
                if not b.def.static then
                    local dx, dy = b.x - a.x, b.y - a.y
                    local rr = (a.r + b.r) * 0.8
                    local d2 = dx * dx + dy * dy
                    if d2 < rr * rr and d2 > 0.01 then
                        local d = sqrt(d2)
                        local px, py = dx / d * 0.4, dy / d * 0.4
                        D.move(a, -px, -py, a.hb, a.def.fly)
                        D.move(b, px, py, b.hb, b.def.fly)
                    end
                end
            end
        end
    end
end

function E.draw_all()
    local list = W.enemies
    for i = 1, #list do
        local e = list[i]
        e.def.draw(e)
    end
end

return E
