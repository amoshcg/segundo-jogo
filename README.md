# Tumba das Mil Balas

Jogo de tiro em masmorra para o Lupi, para 1 ou 2 jogadores na mesma tela.
As salas, os inimigos e os itens são sorteados a cada partida. São 3 andares
(Catacumba, Fornalha e Abismo), cada um com um chefe no final.

## Como jogar

Limpe as salas para abrir as portas, pegue itens na sala do tesouro (amarela
no minimapa), compre na loja (verde) e derrote o chefe (vermelha) para descer
pelo alçapão. Se os corações acabarem, a partida recomeça do andar 1.

Com 2 jogadores, quem cair vira fantasma e volta com 1 coração quando o
parceiro limpar a sala.

## Controles

Mesmo mapeamento do [primeiro-jogo](https://github.com/amoshcg/primeiro-jogo)
(controle SNES, botões em losango):

| Botão | Ação |
| --- | --- |
| Direcional | Andar |
| Y / X / A / B | Atirar para esquerda / cima / direita / baixo (dois juntos = diagonal) |
| L | Rolar: fica invencível no começo do rolamento |
| R | Pulso: apaga as balas inimigas da sala (gasta uma carga) |
| L + R | Pausa |
| B / A (menus) | Confirmar / voltar |

Teclado: `W A S D` anda, `G J H K` atira (esquerda, cima, direita, baixo).
O jogador 2 usa o segundo controle.

## Arquivos

- `game.lua`: entrada do Lupi (`update`).
- `main.lua`: fluxo da partida, salas, barra de cima e telas.
- `core.lua`: cores, desenho, leitura do controle, balas e partículas.
- `dungeon.lua`: sorteio do andar, moldes das salas e colisão com os blocos.
- `player.lua`: movimento, tiro, rolamento e pulso.
- `enemies.lua`: inimigos comuns e os três chefes.
- `items.lua`: itens passivos.
