-- ===================================================================
-- weapons.lua - armas
-- A primeira (pistola) e a arma inicial: municao infinita e nao pode
-- ser largada. As outras gastam municao.
--   dmg dano por bala      rate quadros entre tiros   spd velocidade
--   range quadros de vida  n balas por tiro           spread abertura
--   jitter tremida da mira pierce/bounce/homing       bulr raio da bala
--   boom raio da explosao  len tamanho do cano (desenho)
-- ===================================================================
local K = require "core"
local col = K.col

local G = {}

G.list = {
    {
        name = "PISTOLA", desc = "MUNICAO INFINITA", c = col.silver, len = 6,
        dmg = 3, rate = 20, spd = 4.2, range = 42, n = 1, spread = 0, jitter = 0, bulr = 2,
    },
    {
        name = "ESCOPETA", desc = "CINCO BALAS, BOA DE PERTO", c = col.tan, len = 8, ammo = 40,
        dmg = 2.2, rate = 40, spd = 4.6, range = 22, n = 5, spread = 0.55, jitter = 0.05, bulr = 2,
    },
    {
        name = "METRALHA", desc = "RAJADA RAPIDA", c = col.khaki, len = 7, ammo = 240,
        dmg = 1.3, rate = 6, spd = 4.8, range = 36, n = 1, spread = 0, jitter = 0.14, bulr = 2,
    },
    {
        name = "FUZIL", desc = "FORTE E ATRAVESSA INIMIGOS", c = col.ice, len = 11, ammo = 30,
        dmg = 9, rate = 46, spd = 7, range = 50, n = 1, spread = 0, jitter = 0, bulr = 2,
        pierce = 3,
    },
    {
        name = "CHAMAS", desc = "JATO DE FOGO CURTO", c = col.orange, len = 8, ammo = 320,
        dmg = 0.9, rate = 3, spd = 3.4, range = 17, n = 1, spread = 0, jitter = 0.3, bulr = 3,
        pierce = 99, flame = true,
    },
    {
        name = "BAZUCA", desc = "EXPLODE EM AREA", c = col.green, len = 10, ammo = 14,
        dmg = 5, rate = 55, spd = 3.2, range = 70, n = 1, spread = 0, jitter = 0, bulr = 3,
        boom = 36, boomdmg = 8,
    },
    {
        name = "REBOTE", desc = "BALAS QUICAM NAS PAREDES", c = col.sky, len = 7, ammo = 100,
        dmg = 3, rate = 14, spd = 4.4, range = 90, n = 1, spread = 0, jitter = 0, bulr = 2,
        bounce = 4,
    },
    {
        name = "BUSCADOR", desc = "BALAS PERSEGUEM O ALVO", c = col.pink, len = 7, ammo = 90,
        dmg = 2.6, rate = 16, spd = 3.8, range = 60, n = 1, spread = 0, jitter = 0, bulr = 2,
        homing = true,
    },
}

G.pistol = G.list[1]

-- desenho pequeno da arma (no chao, no pedestal e na barra de cima)
function G.icon(d, x, y)
    K.rf(x - 5, y - 2, x - 3 + d.len, y, d.c)
    K.rf(x - 5, y + 1, x - 3, y + 3, col.rust)
end

return G
