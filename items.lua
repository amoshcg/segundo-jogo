-- ===================================================================
-- items.lua - itens passivos. Quem pega o item fica com o efeito ate
-- o fim da partida. Cada item: nome, descricao, letra/cor do icone e
-- a funcao que muda os atributos do jogador.
-- ===================================================================
local K = require "core"
local col = K.col

local I = {}

I.list = {
    {
        name = "POLVORA SECA", desc = "DANO +", icon = "D", c = col.orange,
        apply = function(p) p.dmg = p.dmg + 1.2 end,
    },
    {
        name = "GATILHO LEVE", desc = "ATIRA MAIS RAPIDO", icon = "G", c = col.yellow,
        apply = function(p) p.rate = math.max(6, p.rate * 0.78) end,
    },
    {
        name = "BOTAS AGEIS", desc = "VELOCIDADE +", icon = "V", c = col.lime,
        apply = function(p) p.spd = math.min(2.6, p.spd + 0.25) end,
    },
    {
        name = "CANO LONGO", desc = "TIRO VAI MAIS LONGE", icon = "L", c = col.silver,
        apply = function(p)
            p.range = p.range + 14
            p.shotspd = math.min(6.5, p.shotspd + 0.7)
        end,
    },
    {
        name = "TIRO TRIPLO", desc = "TRES BALAS POR TIRO", icon = "3", c = col.cyan,
        apply = function(p)
            p.multi = math.min(5, p.multi + 2)
            p.dmg = p.dmg * 0.8
        end,
    },
    {
        name = "BALA PERFURANTE", desc = "ATRAVESSA INIMIGOS", icon = "P", c = col.ice,
        apply = function(p) p.pierce = p.pierce + 2 end,
    },
    {
        name = "BALA RICOCHETE", desc = "QUICA NAS PAREDES", icon = "R", c = col.sky,
        apply = function(p)
            p.bounce = p.bounce + 2
            p.range = p.range + 10
        end,
    },
    {
        name = "OLHO DE CORVO", desc = "BALAS PERSEGUEM", icon = "O", c = col.pink,
        apply = function(p) p.homing = true end,
    },
    {
        name = "CORACAO DE PEDRA", desc = "+1 CORACAO", icon = "C", c = col.rose,
        apply = function(p)
            p.maxhp = math.min(12, p.maxhp + 2)
            p.hp = math.min(p.maxhp, p.hp + 2)
        end,
    },
    {
        name = "CARGA EXTRA", desc = "+2 PULSOS", icon = "+", c = col.cyan,
        apply = function(p) p.pulses = math.min(6, p.pulses + 2) end,
    },
    {
        name = "BALA GIGANTE", desc = "DANO ++ / MAIS LENTA", icon = "B", c = col.red,
        apply = function(p)
            p.dmg = p.dmg + 2.5
            p.bulr = math.min(5, p.bulr + 2)
            p.rate = p.rate * 1.2
        end,
    },
    {
        name = "TIRO TRASEIRO", desc = "ATIRA PARA TRAS TAMBEM", icon = "T", c = col.tan,
        apply = function(p) p.back = true end,
    },
    {
        name = "IMA DA SORTE", desc = "PUXA MOEDAS E CORACOES", icon = "I", c = col.gold,
        apply = function(p) p.magnet = true end,
    },
    {
        name = "DENTE SANGUESSUGA", desc = "CURA A CADA 12 ABATES", icon = "S", c = col.purple,
        apply = function(p) p.vamp = true end,
    },
    {
        name = "CAPA LEVE", desc = "ROLA MAIS VEZES", icon = "K", c = col.teal,
        apply = function(p) p.rolldelay = 12 end,
    },
}

return I
