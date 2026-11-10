-- ===================================================================
-- player.lua - os herois
--   direcional: anda
--   Y / X / A / B: atira para esquerda / cima / direita / baixo
--                  (dois juntos atiram na diagonal)
--   L: rolamento (fica invencivel no comeco)
--   R: pulso (apaga as balas inimigas da sala)
-- ===================================================================
local K = require "core"
local D = require "dungeon"

local P = {}

local W, col = K.W, K.col
local flr, sin, cos, sqrt = math.floor, math.sin, math.cos, math.sqrt
local atan2 = K.atan2
local rf, cf, ln = K.rf, K.cf, K.ln

local ROLL_T = 20       -- duracao do rolamento
local ROLL_SAFE = 6     -- invencivel enquanto roll > ROLL_SAFE

function P.new(idx)
    return {
        idx = idx, x = 240, y = 120, r = 5,
        hp = 6, maxhp = 6,          -- em meios coracoes
        pulses = 2,
        dmg = 3, rate = 20, spd = 1.7, shotspd = 4.2, range = 42,
        multi = 1, pierce = 0, bounce = 0, bulr = 2,
        homing = false, back = false, magnet = false, vamp = false,
        rolldelay = 24, vk = 0,
        cd = 0, roll = 0, rollcd = 0, rdx = 0, rdy = 0,
        inv = 0, fx = 1, fy = 0, walk = 0, flash = 0,
        dead = false, items = {},
    }
end

-- esta protegido pelo rolamento?
function P.safe(p)
    return p.roll > ROLL_SAFE
end

function P.hurt(p, n)
    if p.dead or p.inv > 0 or p.roll > ROLL_SAFE then return false end
    p.hp = p.hp - (n or 1)
    p.inv = 70
    K.shake(5)
    K.burst(p.x, p.y, 8, col.rose, 2)
    if p.hp <= 0 then
        p.hp = 0
        p.dead = true
        p.roll = 0
        K.burst(p.x, p.y, 14, p.idx == 1 and col.cyan or col.lime, 3)
        K.shake(9)
    end
    return true
end

function P.heal(p, n)
    if p.hp >= p.maxhp then return false end
    p.hp = math.min(p.maxhp, p.hp + n)
    return true
end

local function spawn_bullet(p, a, mx, my)
    local list = W.pbul
    if #list >= 90 then return end
    local ca, sa = cos(a), sin(a)
    list[#list + 1] = {
        x = p.x + ca * 7, y = p.y + sa * 7,
        vx = ca * p.shotspd + mx * 0.5, vy = sa * p.shotspd + my * 0.5,
        spd = p.shotspd, r = p.bulr, dmg = p.dmg, life = p.range,
        pierce = p.pierce, bounce = p.bounce, homing = p.homing,
        own = p.idx,
    }
end

local function fire(p, ax, ay, mx, my)
    p.cd = p.rate
    p.flash = 3
    local base = atan2(ay, ax)
    local n = p.multi
    for i = 1, n do
        spawn_bullet(p, base + (i - (n + 1) / 2) * 0.17, mx, my)
    end
    if p.back then spawn_bullet(p, base + math.pi, mx, my) end
end

local function pulse(p)
    p.pulses = p.pulses - 1
    local list = W.ebul
    for i = #list, 1, -1 do
        local b = list[i]
        if i % 3 == 0 then K.burst(b.x, b.y, 1, col.cyan, 1) end
        K.free_bullet(b)
        list[i] = nil
    end
    W.warns = {}
    -- o dano nos inimigos e aplicado em enemies.lua (fresh = true)
    W.pulse = { x = p.x, y = p.y, t = 0, fresh = true }
    K.shake(6)
end

function P.update(p)
    local pl = p.idx
    local mx, my = 0, 0
    if K.down(pl, "left") then mx = mx - 1 end
    if K.down(pl, "right") then mx = mx + 1 end
    if K.down(pl, "up") then my = my - 1 end
    if K.down(pl, "down") then my = my + 1 end
    if mx ~= 0 and my ~= 0 then mx, my = mx * 0.7071, my * 0.7071 end

    if p.inv > 0 then p.inv = p.inv - 1 end
    if p.cd > 0 then p.cd = p.cd - 1 end
    if p.rollcd > 0 then p.rollcd = p.rollcd - 1 end
    if p.flash > 0 then p.flash = p.flash - 1 end

    -- caido: vira fantasma e so anda, esperando a sala ser limpa
    if p.dead then
        D.move(p, mx * 1.2, my * 1.2, 5, false)
        return
    end

    local moving = mx ~= 0 or my ~= 0

    if p.roll > 0 then
        p.roll = p.roll - 1
        local s = p.roll > ROLL_SAFE and 3.1 or 1.3
        D.move(p, p.rdx * s, p.rdy * s, 5, false)
        if p.roll % 4 == 0 then K.burst(p.x, p.y + 4, 1, col.gray, 0.5) end
    elseif K.pressed(pl, "l") and p.rollcd == 0 then
        local dx, dy = mx, my
        if not moving then dx, dy = p.fx, p.fy end
        p.rdx, p.rdy = dx, dy
        p.roll = ROLL_T
        p.rollcd = ROLL_T + p.rolldelay
    elseif moving then
        D.move(p, mx * p.spd, my * p.spd, 5, false)
        p.walk = p.walk + 1
    end

    -- mira com os quatro botoes em losango
    local ax, ay = 0, 0
    if K.down(pl, "y") then ax = ax - 1 end
    if K.down(pl, "a") then ax = ax + 1 end
    if K.down(pl, "x") then ay = ay - 1 end
    if K.down(pl, "b") then ay = ay + 1 end
    if ax ~= 0 or ay ~= 0 then
        if ax ~= 0 and ay ~= 0 then ax, ay = ax * 0.7071, ay * 0.7071 end
        p.fx, p.fy = ax, ay
        if p.cd <= 0 and p.roll == 0 then fire(p, ax, ay, mx, my) end
    elseif moving and p.roll == 0 then
        p.fx, p.fy = mx, my
    end

    if K.pressed(pl, "r") and p.pulses > 0 then pulse(p) end

    -- espinhos machucam quem pisa (rolando passa por cima)
    if p.roll == 0 and D.tile_at(p.x, p.y + 3) == 4 then P.hurt(p, 1) end
end

function P.draw(p)
    local x, y = flr(p.x), flr(p.y)
    local main = p.idx == 1 and col.blue or col.green
    local light = p.idx == 1 and col.cyan or col.lime

    if p.dead then
        local b = flr(sin(W.time * 0.1 + p.idx) * 2)
        K.circ(x, y - 3 + b, 5, light)
        rf(x - 2, y - 4 + b, x - 1, y - 3 + b, light)
        rf(x + 1, y - 4 + b, x + 2, y - 3 + b, light)
        return
    end

    rf(x - 5, y + 6, x + 5, y + 7, W.shadow)
    -- pisca enquanto esta invencivel depois de apanhar
    if p.inv > 0 and p.roll == 0 and p.inv % 6 < 3 then return end

    if p.roll > 0 then
        local a = p.roll * 0.9
        local hx, hy = flr(x + cos(a) * 2), flr(y + sin(a) * 2)
        cf(x, y, 4, main)
        rf(hx - 1, hy - 1, hx + 1, hy + 1, light)
        return
    end

    local step = flr(p.walk / 5) % 2
    rf(x - 4, y + 3, x - 2, y + 5 + step, col.ink)
    rf(x + 2, y + 3, x + 4, y + 6 - step, col.ink)
    cf(x, y - 1, 5, main)
    rf(x - 5, y, x + 5, y + 3, main)
    rf(x - 4, y - 7, x + 4, y - 6, light)
    local vx, vy = flr(p.fx * 2 + 0.5), flr(p.fy * 2 + 0.5)
    rf(x - 3 + vx, y - 3 + vy, x + 3 + vx, y + vy, col.skin)
    rf(x - 2 + vx, y - 2 + vy, x - 2 + vx, y - 1 + vy, col.ink)
    rf(x + 2 + vx, y - 2 + vy, x + 2 + vx, y - 1 + vy, col.ink)
    -- arma apontando para onde mira
    local gx, gy = x + p.fx * 10, y + 2 + p.fy * 10
    ln(x + p.fx * 4, y + 2 + p.fy * 4, gx, gy, col.silver)
    ln(x + p.fx * 4, y + 3 + p.fy * 4, gx, gy + 1, col.gray)
    if p.flash > 0 then cf(gx, gy, 2, col.yellow) end
end

return P
