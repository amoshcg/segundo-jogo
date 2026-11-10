-- ===================================================================
-- core.lua - base compartilhada: cores, desenho, controle e efeitos
-- ===================================================================
require "palette"

local K = {}

local flr = math.floor
local sin, cos = math.sin, math.cos

K.atan2 = math.atan2 or math.atan
K.HUD = 30          -- altura da barra de cima; a sala fica logo abaixo
K.RW, K.RH = 480, 240

-- -------------------------------------------------------------------
-- Cores (paleta DB32). Palette.hex e lento: resolve tudo uma vez so.
-- O preto puro fica de fora porque o indice 0 e transparente.
-- -------------------------------------------------------------------
local function C(hex) return Palette.hex(hex) end

K.col = {
    ink = C(0x222034), plum = C(0x45283c), brown = C(0x663931),
    rust = C(0x8f563b), orange = C(0xdf7126), tan = C(0xd9a066),
    skin = C(0xeec39a), yellow = C(0xfbf236), lime = C(0x99e550),
    green = C(0x6abe30), teal = C(0x37946e), moss = C(0x4b692f),
    olive = C(0x524b24), slate = C(0x323c39), indigo = C(0x3f3f74),
    navy = C(0x306082), blue = C(0x5b6ee1), sky = C(0x639bff),
    cyan = C(0x5fcde4), ice = C(0xcbdbfc), white = C(0xffffff),
    silver = C(0x9badb7), gray = C(0x847e87), dgray = C(0x696a6a),
    coal = C(0x595652), purple = C(0x76428a), red = C(0xac3232),
    rose = C(0xd95763), pink = C(0xd77bba), khaki = C(0x8f974a),
    gold = C(0x8a6f30),
}
local col = K.col

-- -------------------------------------------------------------------
-- Desenho: tudo passa por aqui para virar inteiro (o Lupi nao aceita
-- coordenada quebrada) e para somar o deslocamento da sala/tremor.
-- -------------------------------------------------------------------
local ox, oy = 0, 0

function K.offset(x, y)
    ox, oy = flr(x), flr(y)
end

function K.rf(x0, y0, x1, y1, c)
    ui.rectfill(flr(x0) + ox, flr(y0) + oy, flr(x1) + ox, flr(y1) + oy, c)
end

function K.rect(x0, y0, x1, y1, c)
    ui.rect(flr(x0) + ox, flr(y0) + oy, flr(x1) + ox, flr(y1) + oy, c)
end

function K.cf(x, y, r, c)
    ui.circfill(flr(x) + ox, flr(y) + oy, flr(r), c)
end

function K.circ(x, y, r, c)
    ui.circ(flr(x) + ox, flr(y) + oy, flr(r), c)
end

function K.ln(x0, y0, x1, y1, c)
    ui.line(flr(x0) + ox, flr(y0) + oy, flr(x1) + ox, flr(y1) + oy, c)
end

function K.tri(x1, y1, x2, y2, x3, y3, c)
    ui.trisfill(flr(x1) + ox, flr(y1) + oy, flr(x2) + ox, flr(y2) + oy,
        flr(x3) + ox, flr(y3) + oy, c)
end

function K.pr(s, x, y, c)
    ui.print(s, flr(x) + ox, flr(y) + oy, c)
end

function K.tw(s)
    if ui.text_width then return ui.text_width(s) end
    return #s * 6
end

-- texto centralizado em cx
function K.prc(s, cx, y, c)
    ui.print(s, flr(cx - K.tw(s) / 2) + ox, flr(y) + oy, c)
end

-- texto centralizado com sombra
function K.prs(s, cx, y, c)
    local x = flr(cx - K.tw(s) / 2)
    ui.print(s, x + 1 + ox, flr(y) + 1 + oy, col.ink)
    ui.print(s, x + ox, flr(y) + oy, c)
end

-- numero inteiro como texto (evita "3.0" no Lua novo)
function K.str(n)
    return string.format("%d", flr(n))
end

-- Pontilhado: 1 = 25%, 2 = 50%, 3 = 75%, 0 = volta ao solido.
-- Devolve false se o firmware nao tiver ui.fillp (ai quem chamou decide).
local has_fillp = ui.fillp ~= nil

function K.dither(level)
    if not has_fillp then return false end
    if level == 1 then
        ui.fillp(0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00)
    elseif level == 2 then
        ui.fillp(0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55)
    elseif level == 3 then
        ui.fillp(0x77, 0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF)
    else
        ui.fillp()
    end
    return true
end

-- -------------------------------------------------------------------
-- Controle. Mesmo mapeamento do primeiro-jogo (controle SNES):
--   A = BTN_G, B = BTN_Z, X = BTN_X, Y = BTN_F, L = BTN_Q, R = BTN_E
--   Teclado: W A S D = direcional, G = Y, J = X, H = A, K = B
-- Os botoes ficam em losango: Y esquerda, X cima, A direita, B baixo.
-- Jogador 1 e o controle 0 e jogador 2 e o controle 1.
-- -------------------------------------------------------------------
local NAMES = { "left", "right", "up", "down", "a", "b", "x", "y", "l", "r" }
local IDS = { LEFT, RIGHT, UP, DOWN, BTN_G, BTN_Z, BTN_X, BTN_F, BTN_Q, BTN_E }
local now = { {}, {} }
local old = { {}, {} }
for pl = 1, 2 do
    for i = 1, #NAMES do
        now[pl][NAMES[i]] = false
        old[pl][NAMES[i]] = false
    end
end

-- le todos os botoes uma vez por quadro
function K.poll()
    for pl = 1, 2 do
        local n, o = now[pl], old[pl]
        for i = 1, 10 do
            local name, id = NAMES[i], IDS[i]
            o[name] = n[name]
            local v = false
            if id ~= nil then
                if pl == 1 then v = ui.btn(id) else v = ui.btn(id, 1) end
            end
            n[name] = (v and v ~= 0) and true or false
        end
    end
end

-- segurando
function K.down(pl, name) return now[pl][name] end

-- acabou de apertar
function K.pressed(pl, name) return now[pl][name] and not old[pl][name] end

-- qualquer um dos dois controles acabou de apertar
function K.any(name)
    return K.pressed(1, name) or K.pressed(2, name)
end

-- -------------------------------------------------------------------
-- Mundo: estado da partida, visivel para todos os modulos
-- -------------------------------------------------------------------
local W = {
    screen = "title",
    players = {}, enemies = {}, ebul = {}, pbul = {},
    parts = {}, spawns = {}, warns = {}, texts = {},
    shake = 0, time = 0, level = 1, coins = 0, kills = 0, rooms = 0,
    nplayers = 1, locked = false, shadow = col.ink,
}
K.W = W

function K.shake(n)
    if n > W.shake then W.shake = n end
end

-- Balas dos inimigos. As tabelas sao reaproveitadas para nao gerar lixo.
local bpool = {}

-- kind: 0 = comum, 1 = roxa, 2 = brasa parada
function K.shoot(x, y, ang, spd, r, kind, life)
    local list = W.ebul
    if #list >= 170 then return end
    local b = bpool[#bpool]
    if b then bpool[#bpool] = nil else b = {} end
    b.x, b.y = x, y
    b.vx, b.vy = cos(ang) * spd, sin(ang) * spd
    b.r = r or 3
    b.k = kind or 0
    b.life = life or 420
    list[#list + 1] = b
end

function K.free_bullet(b)
    if #bpool < 200 then bpool[#bpool + 1] = b end
end

-- n balas em circulo
function K.ring(x, y, n, spd, off, kind)
    off = off or 0
    for i = 0, n - 1 do
        K.shoot(x, y, off + i * 6.2832 / n, spd, 3, kind)
    end
end

-- n balas em leque, abrindo `spread` radianos em volta de ang
function K.fan(x, y, ang, n, spread, spd, kind)
    if n <= 1 then
        K.shoot(x, y, ang, spd, 3, kind)
        return
    end
    for i = 0, n - 1 do
        K.shoot(x, y, ang - spread / 2 + spread * i / (n - 1), spd, 3, kind)
    end
end

-- Particulas
local ppool = {}

function K.burst(x, y, n, c, spd)
    local list = W.parts
    spd = spd or 1.5
    for _ = 1, n do
        if #list >= 70 then return end
        local p = ppool[#ppool]
        if p then ppool[#ppool] = nil else p = {} end
        local a = math.random() * 6.2832
        local s = (0.3 + math.random() * 0.7) * spd
        p.x, p.y = x, y
        p.vx, p.vy = cos(a) * s, sin(a) * s
        p.life = 10 + math.random(12)
        p.c = c
        list[#list + 1] = p
    end
end

function K.update_parts()
    local list = W.parts
    for i = #list, 1, -1 do
        local p = list[i]
        p.x, p.y = p.x + p.vx, p.y + p.vy
        p.vx, p.vy = p.vx * 0.92, p.vy * 0.92
        p.life = p.life - 1
        if p.life <= 0 then
            if #ppool < 80 then ppool[#ppool + 1] = p end
            list[i] = list[#list]
            list[#list] = nil
        end
    end
end

-- Aviso no chao: depois de `t` quadros explode e machuca quem estiver em cima
function K.warn(x, y, r, t)
    if x < 30 then x = 30 elseif x > 450 then x = 450 end
    if y < 30 then y = 30 elseif y > 210 then y = 210 end
    W.warns[#W.warns + 1] = { x = x, y = y, r = r, t = t, max = t }
end

-- Texto que sobe e some (ex.: "+1")
function K.float(s, x, y, c)
    if #W.texts >= 6 then return end
    W.texts[#W.texts + 1] = { s = s, x = x, y = y, c = c, life = 40 }
end

return K
