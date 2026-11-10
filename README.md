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
(controle SNES, botões em losango). O botão L não é usado.

| Botão | Ação |
| --- | --- |
| Direcional | Andar e virar: o tiro sai para onde o herói olha |
| B | Atirar. Segurando, a mira trava e dá para andar de lado ou recuar atirando |
| A | Rolar: fica invencível no começo do rolamento |
| Y | Pulso: apaga as balas inimigas da sala (gasta uma carga) |
| X | Trocar de arma. Perto de uma arma no chão, pega ou troca por ela |
| X (segurar) | Largar a arma atual |
| R | Pausa |
| B / A (menus) | Confirmar / voltar |

Teclado: `W A S D` anda, `K` atira, `H` rola, `G` pulso, `J` arma.
O jogador 2 usa o segundo controle.

## Armas

Cada jogador carrega a pistola (munição infinita, não pode ser largada) e
mais duas armas. As outras gastam munição, que se repõe com as caixas verdes
ou na loja. Armas aparecem na primeira sala, nas salas de tesouro, na loja,
depois dos chefes e, às vezes, ao limpar uma sala.

| Arma | Como atira |
| --- | --- |
| Pistola | Tiro simples, munição infinita |
| Escopeta | Cinco balas em leque, alcance curto |
| Metralha | Rajada rápida e imprecisa |
| Fuzil | Tiro forte que atravessa inimigos |
| Chamas | Jato de fogo de curto alcance |
| Bazuca | Explode em área |
| Rebote | Balas que quicam nas paredes |
| Buscador | Balas que perseguem o alvo |

Os itens passivos (dano, tiro triplo, perfurante etc.) valem para qualquer arma.

## Arquivos

- `game.lua`: entrada do Lupi (`update`).
- `main.lua`: fluxo da partida, salas, barra de cima e telas.
- `core.lua`: cores, desenho, leitura do controle, balas e partículas.
- `dungeon.lua`: sorteio do andar, moldes das salas e colisão com os blocos.
- `player.lua`: movimento, tiro, rolamento, pulso e troca de armas.
- `weapons.lua`: lista de armas.
- `enemies.lua`: inimigos comuns e os três chefes.
- `items.lua`: itens passivos.
