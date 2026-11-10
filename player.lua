-- ===================================================================
-- player.lua - os herois
--   direcional: anda e vira (a mira e para onde o heroi olha)
--   B: atira para onde esta olhando. Segurando B a mira trava, entao
--      da para andar de lado ou recuar atirando; solte para virar.
--   A: rolamento (fica invencivel no comeco)
--   Y: pulso (apaga as balas inimigas da sala)
--   X: troca de arma. Perto de uma arma no chao, pega/troca por ela.
--      Segurando X, larga a arma atual.
-- O botao L nao e usado (trava o console).
-- ===================================================================
local K = require "core"
local D = require "dungeon"
local G = require "weapons"

local P = {}

local W, col = K.W, K.col
local flr, rnd, sin, cos = math.floor, math.random, math.sin, math.cos
local atan2 = K.atan2
local rf, cf, ln = K.rf, K.cf, K.ln

local ROLL_T = 20       -- duracao do rolamento
local ROLL_SAFE = 6     -- invencivel enquanto roll > ROLL_SAFE
local MAX_GUNS = 3      -- pistola + 2
local HOLD_T = 30       -- quadros segurando X para largar a arma

function P.new(idx)
    return {
        idx = idx, x = 240, y = 120, r = 5,
        hp = 6, maxhp = 6,          -- em meios coracoes
        pulses = 2,
        guns = { { def = G.pistol, ammo = 0 } }, gi = 1,
        -- bonus dos itens, aplicados em cima da arma
        dmgmul = 1, ratemul = 1, rangemul = 1, shotadd = 0,
        multi = 0, pierce = 0, bounce = 0, bulradd = 0,
        homing = false, back = false, magnet = false, vamp = false,
        spd = 1.7, rolldelay = 24, vk = 0,
        cd = 0, roll = 0, rollcd = 0, rdx = 0, rdy = 0,
        inv = 0, fx = 1, fy = 0, walk = 0, flash = 0, xt = -1,
        dead = false, items = {},
    }
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

-- -------------------------------------------------------------------
-- Armas
-- -------------------------------------------------------------------

-- repoe uma fracao da municao de todas as armas; false se ja estava cheio
function P.add_ammo(p, frac)
    local got = false
    for i = 1, #p.guns do
        local g = p.guns[i]
        local max = g.def.ammo
        if max and g.ammo < max then
            g.ammo = math.min(max, g.ammo + math.ceil(max * frac))
            got = true
        end
    end
    return got
end

function P.needs_ammo(p)
    for i = 1, #p.guns do
        local g = p.guns[i]
        if g.def.ammo and g.ammo < g.def.ammo then return true end
    end
    return false
end

-- vale a pena pegar/comprar esta arma? (nao, se ja tem igual e cheia)
function P.wants_gun(p, def)
    for i = 1, #p.guns do
        local g = p.guns[i]
        if g.def == def then return g.ammo < (def.ammo or 0) end
    end
    return true
end

local function drop_gun(p, i, x, y)
    local g = table.remove(p.guns, i)
    local list = W.room.guns
    -- block: quem largou so pega de novo sozinho depois de se afastar
    list[#list + 1] = { def = g.def, ammo = g.ammo, x = x, y = y, t = 0, block = p.idx }
    if p.gi > #p.guns then p.gi = #p.guns end
end

-- Da uma arma ao jogador. Se ja tem uma igual, soma a municao. Com as
-- maos cheias, larga a arma atual em (x, y) para abrir espaco.
function P.give_gun(p, def, ammo, x, y)
    for i = 1, #p.guns do
        local g = p.guns[i]
        if g.def == def then
            g.ammo = math.min(def.ammo or 0, g.ammo + ammo)
            p.gi = i
            return
        end
    end
    if #p.guns >= MAX_GUNS then
        local i = p.gi
        if i == 1 then i = 2 end    -- a pistola nunca sai
        drop_gun(p, i, x, y)
    end
    p.guns[#p.guns + 1] = { def = def, ammo = ammo }
    p.gi = #p.guns
    W.banner = { title = def.name, sub = def.desc, t = 120 }
end

local function has_gun(p, def)
    for i = 1, #p.guns do
        if p.guns[i].def == def then return p.guns[i] end
    end
    return nil
end

-- pega a arma i do chao da sala
local function take_ground(p, i)
    local g = table.remove(W.room.guns, i)
    P.give_gun(p, g.def, g.ammo, g.x, g.y)
    K.burst(g.x, g.y, 6, col.white, 1.5)
end

-- armas no chao: pega sozinho se tiver espaco (ou se for municao de uma
-- arma que ja tem). Devolve o indice da arma que esta ao alcance do X.
local function ground_guns(p)
    local list = W.room.guns
    local near = nil
    for i = #list, 1, -1 do
        local g = list[i]
        local dx, dy = g.x - p.x, g.y - p.y
        local d2 = dx * dx + dy * dy
        if g.block == p.idx then
            if d2 > 22 * 22 then g.block = nil end
        elseif d2 < 12 * 12 and g.t > 20 then
            local mine = has_gun(p, g.def)
            if mine then
                if mine.ammo < g.def.ammo then
                    take_ground(p, i)
                    K.float("+MUNICAO", p.x, p.y - 12, col.white)
                    return nil
                end
            elseif #p.guns < MAX_GUNS then
                take_ground(p, i)
                return nil
            end
        end
        if d2 < 14 * 14 then near = i end
    end
    return near
end

local function spawn_bullet(p, d, a, mx, my)
    local list = W.pbul
    if #list >= 90 then return end
    local ca, sa = cos(a), sin(a)
    local spd = d.spd + p.shotadd
    list[#list + 1] = {
        x = p.x + ca * 7, y = p.y + sa * 7,
        vx = ca * spd + mx * 0.5, vy = sa * spd + my * 0.5,
        spd = spd, r = d.bulr + p.bulradd, dmg = d.dmg * p.dmgmul,
        life = flr(d.range * p.rangemul),
        pierce = (d.pierce or 0) + p.pierce, bounce = (d.bounce or 0) + p.bounce,
        homing = d.homing or p.homing, flame = d.flame,
        boom = d.boom, boomdmg = d.boom and d.boomdmg * p.dmgmul or 0,
        own = p.idx,
    }
end

local function fire(p, mx, my)
    local g = p.guns[p.gi]
    local d = g.def
    if d.ammo then
        if g.ammo <= 0 then
            -- acabou: avisa e passa para uma arma que ainda atira
            p.cd = 15
            K.float("SEM MUNICAO", p.x, p.y - 12, col.rose)
            for i = 1, #p.guns do
                local o = p.guns[i]
                if not o.def.ammo or o.ammo > 0 then
                    p.gi = i
                    break
                end
            end
            return
        end
        g.ammo = g.ammo - 1
    end

    p.cd = d.rate * p.ratemul
    p.flash = 3
    local base = atan2(p.fy, p.fx)
    local n = d.n + p.multi
    local spread = d.spread
    if spread < 0.17 * (n - 1) then spread = 0.17 * (n - 1) end
    for i = 1, n do
        local a = base + (rnd() - 0.5) * d.jitter
        if n > 1 then a = a + ((i - 1) / (n - 1) - 0.5) * spread end
        spawn_bullet(p, d, a, mx, my)
    end
    if p.back then spawn_bullet(p, d, base + math.pi, mx, my) end
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

-- botao X: toque = trocar/pegar arma, segurar = largar a arma atual
local function weapon_button(p, pl, near)
    if K.pressed(pl, "x") then p.xt = 0 end
    if p.xt < 0 then return end
    if K.down(pl, "x") then
        p.xt = p.xt + 1
        if p.xt >= HOLD_T then
            p.xt = -1
            if p.gi > 1 then
                K.float("LARGOU " .. p.guns[p.gi].def.name, p.x, p.y - 12, col.silver)
                drop_gun(p, p.gi, p.x, p.y)
            else
                K.float("A PISTOLA FICA", p.x, p.y - 12, col.silver)
            end
        end
        return
    end
    -- soltou antes do tempo: foi um toque
    p.xt = -1
    if near then
        take_ground(p, near)
    elseif #p.guns > 1 then
        p.gi = p.gi % #p.guns + 1
        local d = p.guns[p.gi].def
        K.float(d.name, p.x, p.y - 12, d.c)
    end
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
        p.xt = -1
        D.move(p, mx * 1.2, my * 1.2, 5, false)
        return
    end

    local moving = mx ~= 0 or my ~= 0
    local shooting = K.down(pl, "b")

    if p.roll > 0 then
        p.roll = p.roll - 1
        local s = p.roll > ROLL_SAFE and 3.1 or 1.3
        D.move(p, p.rdx * s, p.rdy * s, 5, false)
        if p.roll % 4 == 0 then K.burst(p.x, p.y + 4, 1, col.gray, 0.5) end
    elseif K.pressed(pl, "a") and p.rollcd == 0 then
        -- rola para onde o direcional aponta (ou para onde olha, se parado)
        local dx, dy = mx, my
        if not moving then dx, dy = p.fx, p.fy end
        p.rdx, p.rdy = dx, dy
        p.roll = ROLL_T
        p.rollcd = ROLL_T + p.rolldelay
    elseif moving then
        D.move(p, mx * p.spd, my * p.spd, 5, false)
        p.walk = p.walk + 1
    end

    -- vira para onde anda; atirando, a mira fica travada
    if moving and not shooting and p.roll == 0 then
        p.fx, p.fy = mx, my
    end
    if shooting and p.cd <= 0 and p.roll == 0 then fire(p, mx, my) end

    if K.pressed(pl, "y") and p.pulses > 0 then pulse(p) end

    weapon_button(p, pl, ground_guns(p))

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
    -- pontinho de mira: mostra para onde o tiro vai
    local ax, ay = flr(x + p.fx * 24), flr(y + 2 + p.fy * 24)
    rf(ax, ay, ax + 1, ay + 1, light)
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
    -- arma atual apontando para onde olha
    local d = p.guns[p.gi].def
    local len = 4 + d.len
    local gx, gy = x + p.fx * len, y + 2 + p.fy * len
    ln(x + p.fx * 4, y + 2 + p.fy * 4, gx, gy, d.c)
    ln(x + p.fx * 4, y + 3 + p.fy * 4, gx, gy + 1, col.gray)
    if p.flash > 0 then cf(gx, gy, 2, col.yellow) end
end

return P
