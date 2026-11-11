# =====================================================================
# Save Caco - MARS 4.5
# Bitmap Display: unidade 4x4, tela 256x512  ->  64 x 128 unidades
# Base do display: 0x10008000 ($gp)
# Montar com "Assemble all files in directory" (main, cenario, sprites).
# Keyboard and Display MMIO Simulator conectado. "Delayed branching" OFF.
#
# Controles: a/d andar, w/s subir/descer escada, ESPACO pular.
# O pulo e curto (para passar por cima dos barris), mas nas areas marcadas
# em amarelo, nas aberturas entre os andares, ele e alto e leva ao andar
# de cima.
# Objetivo: chegar ao Caco, o cachorro caramelo na plataforma do topo
# (pela escada da esquerda), sem encostar em nenhum barril.
#
# Como o desenho funciona (sem piscar):
#   1. jogador e barris sao atualizados (so a posicao muda na memoria);
#   2. a area antiga e a nova de cada um sao "redesenhadas": cada unidade
#      recebe a cor que DEVERIA ter (jogador, barril ou cenario) e so e
#      escrita no display se for diferente da cor atual.
# =====================================================================

# ---------------- barris ----------------
.eqv NUM_BARRIS   6          # ao mudar, ajuste as listas ini_* e barris_*
.eqv NUM_BARRIS_X4 24        # NUM_BARRIS * 4 (bytes de cada lista)
.eqv BARRIL_L     5          # largura do sprite (sprite_barril.asm)
.eqv BARRIL_A     5          # altura do sprite
.eqv SPAWN_X      10
.eqv SPAWN_Y      30         # piso da linha 35 - BARRIL_A
.eqv LIMITE_ESQ   7          # x < LIMITE_ESQ  -> vira (deixa cair nas pontas x=9/10)
.eqv LIMITE_DIR   52         # x > LIMITE_DIR  -> vira (deixa cair nas pontas x=54/55)
.eqv Y_MAX        123        # 128 - BARRIL_A
.eqv Y_FINAL      116        # barril chegou ao ultimo andar...
.eqv X_FINAL      10         # ...e ao canto esquerdo: some e renasce
.eqv APOIO_MIN    3          # unidades de chao necessarias: (BARRIL_L+1)/2
.eqv ATRASO_RENASCER 15      # ciclos ate o barril reaparecer no spawn

# ---------------- jogador ----------------
.eqv JOG_L        4          # largura do sprite (sprite_jogador.asm)
.eqv JOG_A        6          # altura do sprite
.eqv JOG_X0       2          # posicao inicial: canto esquerdo do ultimo andar
.eqv JOG_Y0       117        # piso da linha 123 - JOG_A
.eqv JOG_X_MAX    60         # 64 - JOG_L
.eqv JOG_Y_MAX    122        # 128 - JOG_A
# Dois pulos, ambos no ESPACO. As plataformas sao "de mao unica":
# atravessa subindo, pousa caindo.
# Pulo curto (fora das areas): 1 linha/quadro por 6 quadros + 4 parado =
#   6 linhas, para passar por cima dos barris sem chegar no andar de cima.
# Pulo alto (dentro de uma area da tabela "zonas"): 2 linhas/quadro por
#   10 quadros + 2 parado = 20 linhas, atravessa e pousa no andar de cima.
.eqv PULO_CURTO_QUADROS 10   # 6 subindo + 4 parado no alto
.eqv PULO_CURTO_PASSO   1
.eqv PULO_CURTO_PAIRAR  4
.eqv PULO_ALTO_QUADROS  12   # 10 subindo + 2 parado no alto
.eqv PULO_ALTO_PASSO    2
.eqv PULO_ALTO_PAIRAR   2
.eqv PULO_ALTO_RETO     7    # quadros subindo reto (14 linhas) antes de ir de lado
.eqv DIR_TEMPO    4          # quadros em que a ultima direcao "vale" para o pulo
# O Caco (cachorro) fica sentado na plataforma pequena do topo (linha 20,
# x 19..33). Encostar nele = vitoria. Chega-se la pela escada x 15..18.
.eqv CAO_X        27
.eqv CAO_Y        14         # piso da linha 20 - CAO_A
.eqv CAO_L        6          # sprite_cachorro.asm
.eqv CAO_A        6
.eqv JOG_PIX_COLISAO 20      # so as 5 primeiras linhas do sprite batem (sapatos nao)

# ---------------- cores e tempo ----------------
.eqv VERMELHO     0x00920D28 # cor do chao no cenario
.eqv ESCADA       0x001843E4 # escada azul (a azul clara e quebrada: nao sobe)
.eqv TRANSPARENTE -1         # 0xFFFFFFFF no sprite = nao desenha
.eqv COR_DERROTA  0x00FF0000
.eqv COR_VITORIA  0x0000FF00
.eqv COR_ZONA     0x00FFFF00 # faixa amarela que marca as areas de pulo alto
.eqv NUM_ZONAS    5
.eqv ESPERA_MS    80         # duracao de um ciclo do jogo

# O MARS nao calcula "CONST + 1": constantes auxiliares
.eqv Y_MAX_MAIS1      124
.eqv LIMITE_DIR_MAIS1 53
.eqv X_FINAL_MAIS1    11
.eqv BARRIL_L_MAIS1   6
.eqv JOG_A_MAIS1      7
.eqv JOG_X_MAX_MAIS1  61
.eqv JOG_Y_MAX_MAIS1  123

# teclas (codigo ASCII)
.eqv TECLA_A      97
.eqv TECLA_D      100
.eqv TECLA_W      119
.eqv TECLA_S      115
.eqv TECLA_ESPACO 32

.data
# Valores iniciais (copiados a cada partida por reiniciar_jogo).
# Barris 0..4 ja comecam espalhados pelos andares 1..5; o barril 5 nasce
# no spawn depois de ini_atraso ciclos.
ini_x:             .word 10, 20, 28, 40, 34, 10
ini_y:             .word 30, 48, 64, 81, 100, 30
ini_dir:           .word 1, -1, 1, -1, 1, 1
ini_atraso:        .word 0, 0, 0, 0, 0, 40
ini_ativo:         .word 1, 1, 1, 1, 1, 0

# Estado dos barris (indice 0..NUM_BARRIS-1).
barris_x:          .word 0, 0, 0, 0, 0, 0
barris_y:          .word 0, 0, 0, 0, 0, 0
barris_dir:        .word 0, 0, 0, 0, 0, 0
barris_atraso:     .word 0, 0, 0, 0, 0, 0
barris_ativo:      .word 0, 0, 0, 0, 0, 0
# Estado do ciclo anterior (para saber que area redesenhar).
barris_ant_x:      .word 0, 0, 0, 0, 0, 0
barris_ant_y:      .word 0, 0, 0, 0, 0, 0
barris_ant_ativo:  .word 0, 0, 0, 0, 0, 0

# Estado do jogador.
jog_x:             .word 0
jog_y:             .word 0
jog_ant_x:         .word 0
jog_ant_y:         .word 0
jog_pulo:          .word 0     # quadros de pulo restantes (0 = nao esta pulando)
jog_passo:         .word 0     # linhas subidas por quadro neste pulo
jog_pairar:        .word 0     # ultimos quadros do pulo em que fica parado no alto
jog_atraso_lateral: .word 0    # quadros do pulo alto ainda sem andar para o lado
jog_vx:            .word 0     # deslocamento horizontal durante o pulo/queda
jog_dir:           .word 0     # ultima direcao andada (-1 ou 1)
jog_dir_tempo:     .word 0     # ha quantos quadros ainda vale jog_dir
jog_escada:        .word 0     # 1 = pendurado na escada (sem gravidade)
jog_chao:          .word 0     # 1 = terminou o quadro pisando no chao

quadro_inicio:     .word 0     # tempo (ms) em que o quadro atual comecou

# Areas de pulo alto: x inicial, x final, linha do piso, direcao.
# Ficam na abertura ao lado da ponta do andar de cima (com o alto livre).
# O jogador esta na area se pisa nessa linha com o corpo todo entre x0 e x1.
# O pulo alto sobe reto e, ja acima do andar de cima, vai na "direcao"
# (-1 esquerda, 1 direita) ate pousar na ponta dele, na diagonal.
zonas:             .word 55, 62, 121, -1    # andar 6 -> 5
                   .word  1,  7, 103,  1    # andar 5 -> 4
                   .word 55, 62, 85,  -1    # andar 4 -> 3
                   .word  1,  7, 68,   1    # andar 3 -> 2
                   .word 52, 59, 51,  -1    # andar 2 -> 1

msg_inicio:        .asciiz "Save Caco! a/d andar, w/s escada, ESPACO pular (pulo alto nas faixas amarelas).\n"
msg_derrota:       .asciiz "Voce foi atingido por um barril! Aperte ESPACO para voltar ao inicio.\n"
msg_vitoria:       .asciiz "Voce encontrou o Caco! Aperte ESPACO para voltar ao inicio.\n"

.text
.globl main

main:
    la    $s0, imagem              # $s0 = cenario (64 x 128 words)
    lui   $s1, 0x1000
    ori   $s1, $s1, 0x8000         # $s1 = Bitmap Display
    jal   marcar_zonas             # pinta as faixas amarelas no cenario
    jal   carimbar_cachorro        # desenha o Caco no cenario

novo_jogo:
    la    $a0, msg_inicio          # controles no Run I/O
    addiu $v0, $zero, 4
    syscall
    jal   tela_inicial             # titulo; volta quando apertar ESPACO
    jal   reiniciar_jogo           # desenha o cenario e ja comeca

loop_jogo:
    addiu $v0, $zero, 30           # marca o inicio do quadro (ms)
    syscall
    sw    $a0, quadro_inicio
    # 0) le a tecla (0 se nenhuma foi apertada)
    addu  $s6, $zero, $zero
    lui   $t0, 0xFFFF
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beq   $t1, $zero, atualizar_tudo
    lw    $s6, 4($t0)

atualizar_tudo:
    # 1) atualiza jogador e barris (somente memoria)
    lw    $t0, jog_x
    sw    $t0, jog_ant_x
    lw    $t0, jog_y
    sw    $t0, jog_ant_y
    addu  $a0, $s6, $zero
    jal   atualizar_jogador

    addu  $s7, $zero, $zero
loop_atualizar:
    addu  $a0, $s7, $zero
    jal   capturar_estado_anterior
    addu  $a0, $s7, $zero
    jal   atualizar_barril
    addiu $s7, $s7, 1
    slti  $t0, $s7, NUM_BARRIS
    bne   $t0, $zero, loop_atualizar

    # 2) redesenha somente o que mudou
    addu  $s7, $zero, $zero
loop_desenhar:
    addu  $a0, $s7, $zero
    jal   redesenhar_barril
    addiu $s7, $s7, 1
    slti  $t0, $s7, NUM_BARRIS
    bne   $t0, $zero, loop_desenhar
    jal   redesenhar_jogador

    # 3) regras: encostou em barril perde; chegou ao topo ganha
    jal   checar_colisao
    bne   $v0, $zero, perdeu
    jal   tocou_cachorro
    bne   $v0, $zero, ganhou

    jal   esperar_quadro
    j     loop_jogo

perdeu:
    li    $a0, COR_DERROTA
    jal   pintar_xadrez
    la    $a0, msg_derrota
    j     fim_de_partida
ganhou:
    li    $a0, COR_VITORIA
    jal   pintar_xadrez
    la    $a0, msg_vitoria
fim_de_partida:
    addiu $v0, $zero, 4
    syscall
    jal   esperar_espaco
    j     novo_jogo

# ---------------------------------------------------------------------
# esperar_quadro: espera ate passarem ESPERA_MS desde quadro_inicio.
# NAO use o syscall 32 (sleep): o MARS fica "travado" durante o sleep e
# cada tecla do Keyboard MMIO espera ele acabar. Segurando uma tecla as
# repeticoes se acumulam e a janela inteira congela. Este laco consulta o
# relogio (syscall 30) e deixa o teclado ser atendido entre as instrucoes.
# ---------------------------------------------------------------------
esperar_quadro:
    lw    $t0, quadro_inicio
eq_loop:
    addiu $v0, $zero, 30
    syscall                        # $a0 = tempo atual (ms, parte baixa)
    subu  $t1, $a0, $t0
    slti  $t1, $t1, ESPERA_MS
    bne   $t1, $zero, eq_loop
    jr    $ra

# ---------------------------------------------------------------------
# esperar_espaco: bloqueia ate a tecla ESPACO ser apertada.
# ---------------------------------------------------------------------
esperar_espaco:
    lui   $t0, 0xFFFF
espera_loop:
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beq   $t1, $zero, espera_loop
    lw    $t1, 4($t0)
    addiu $t2, $zero, TECLA_ESPACO
    bne   $t1, $t2, espera_loop
    jr    $ra

# ---------------------------------------------------------------------
# reiniciar_jogo: restaura o estado inicial e desenha a tela inteira.
# ---------------------------------------------------------------------
reiniciar_jogo:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $s7, 0($sp)

    addu  $t0, $zero, $zero        # deslocamento 0, 4, 8
reiniciar_barris:
    lw    $t1, ini_x($t0)
    sw    $t1, barris_x($t0)
    sw    $t1, barris_ant_x($t0)
    lw    $t1, ini_y($t0)
    sw    $t1, barris_y($t0)
    sw    $t1, barris_ant_y($t0)
    lw    $t1, ini_dir($t0)
    sw    $t1, barris_dir($t0)
    lw    $t1, ini_atraso($t0)
    sw    $t1, barris_atraso($t0)
    lw    $t1, ini_ativo($t0)
    sw    $t1, barris_ativo($t0)
    sw    $t1, barris_ant_ativo($t0)
    addiu $t0, $t0, 4
    slti  $t1, $t0, NUM_BARRIS_X4
    bne   $t1, $zero, reiniciar_barris

    addiu $t0, $zero, JOG_X0
    sw    $t0, jog_x
    sw    $t0, jog_ant_x
    addiu $t0, $zero, JOG_Y0
    sw    $t0, jog_y
    sw    $t0, jog_ant_y
    sw    $zero, jog_pulo
    sw    $zero, jog_vx
    sw    $zero, jog_dir_tempo
    sw    $zero, jog_escada
    sw    $zero, jog_chao
    sw    $zero, jog_atraso_lateral
    addiu $t0, $zero, 1
    sw    $t0, jog_dir

    # Copia o cenario inteiro para o display.
    addu  $t0, $s0, $zero
    addu  $t1, $s1, $zero
    addiu $t2, $zero, 8192         # 64 * 128 unidades
copiar_cenario:
    lw    $t3, 0($t0)
    sw    $t3, 0($t1)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bne   $t2, $zero, copiar_cenario

    # Desenha barris ativos e o jogador.
    addu  $s7, $zero, $zero
desenhar_iniciais:
    addu  $a0, $s7, $zero
    jal   redesenhar_barril
    addiu $s7, $s7, 1
    slti  $t0, $s7, NUM_BARRIS
    bne   $t0, $zero, desenhar_iniciais
    jal   redesenhar_jogador

    lw    $s7, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ---------------------------------------------------------------------
# pintar_xadrez($a0 = cor): pinta metade das unidades (padrao xadrez)
# para indicar fim de partida sem esconder o cenario.
# ---------------------------------------------------------------------
pintar_xadrez:
    addu  $t0, $zero, $zero        # indice da unidade
xadrez_loop:
    andi  $t1, $t0, 63             # x
    srl   $t2, $t0, 6              # y
    addu  $t1, $t1, $t2
    andi  $t1, $t1, 1
    bne   $t1, $zero, xadrez_proximo
    sll   $t3, $t0, 2
    addu  $t3, $t3, $s1
    sw    $a0, 0($t3)
xadrez_proximo:
    addiu $t0, $t0, 1
    slti  $t1, $t0, 8192
    bne   $t1, $zero, xadrez_loop
    jr    $ra

# ---------------------------------------------------------------------
# capturar_estado_anterior($a0 = indice): copia x, y e ativo para "ant".
# ---------------------------------------------------------------------
capturar_estado_anterior:
    sll   $t0, $a0, 2
    lw    $t1, barris_x($t0)
    sw    $t1, barris_ant_x($t0)
    lw    $t1, barris_y($t0)
    sw    $t1, barris_ant_y($t0)
    lw    $t1, barris_ativo($t0)
    sw    $t1, barris_ant_ativo($t0)
    jr    $ra

# ---------------------------------------------------------------------
# redesenhar_barril($a0 = indice): redesenha a area antiga e a nova.
# ---------------------------------------------------------------------
redesenhar_barril:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $s2, 0($sp)
    sll   $s2, $a0, 2

    lw    $t0, barris_ant_ativo($s2)
    beq   $t0, $zero, redesenhar_novo
    lw    $a0, barris_ant_x($s2)
    lw    $a1, barris_ant_y($s2)
    addiu $a2, $zero, BARRIL_L
    addiu $a3, $zero, BARRIL_A
    jal   redesenhar_area

redesenhar_novo:
    lw    $t0, barris_ativo($s2)
    beq   $t0, $zero, fim_redesenhar_barril
    lw    $a0, barris_x($s2)
    lw    $a1, barris_y($s2)
    addiu $a2, $zero, BARRIL_L
    addiu $a3, $zero, BARRIL_A
    jal   redesenhar_area

fim_redesenhar_barril:
    lw    $s2, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ---------------------------------------------------------------------
# redesenhar_jogador: redesenha a area antiga e a nova do jogador.
# ---------------------------------------------------------------------
redesenhar_jogador:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    lw    $a0, jog_ant_x
    lw    $a1, jog_ant_y
    addiu $a2, $zero, JOG_L
    addiu $a3, $zero, JOG_A
    jal   redesenhar_area
    lw    $a0, jog_x
    lw    $a1, jog_y
    addiu $a2, $zero, JOG_L
    addiu $a3, $zero, JOG_A
    jal   redesenhar_area
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# ---------------------------------------------------------------------
# redesenhar_area($a0 = x, $a1 = y, $a2 = largura, $a3 = altura)
# Para cada unidade do retangulo (recortado na tela) calcula a cor certa
# e escreve no display SOMENTE se ela for diferente da atual.
# ---------------------------------------------------------------------
redesenhar_area:
    addiu $sp, $sp, -28
    sw    $ra, 24($sp)
    sw    $s2, 20($sp)
    sw    $s3, 16($sp)
    sw    $s4, 12($sp)
    sw    $s5, 8($sp)
    sw    $s6, 4($sp)
    sw    $s7, 0($sp)

    addu  $s2, $a0, $zero          # x inicial
    addu  $s3, $a1, $zero          # y atual
    addu  $s4, $a0, $a2            # x final (exclusivo)
    addu  $s5, $a1, $a3            # y final (exclusivo)
    # recorte nas bordas da tela
    bgez  $s2, area_x_ok
    addu  $s2, $zero, $zero
area_x_ok:
    bgez  $s3, area_y_ok
    addu  $s3, $zero, $zero
area_y_ok:
    slti  $t0, $s4, 65
    bne   $t0, $zero, area_xf_ok
    addiu $s4, $zero, 64
area_xf_ok:
    slti  $t0, $s5, 129
    bne   $t0, $zero, area_linha
    addiu $s5, $zero, 128

area_linha:
    slt   $t0, $s3, $s5
    beq   $t0, $zero, fim_redesenhar_area
    addu  $s6, $s2, $zero          # x atual
area_coluna:
    slt   $t0, $s6, $s4
    beq   $t0, $zero, area_proxima_linha
    addu  $a0, $s6, $zero
    addu  $a1, $s3, $zero
    jal   cor_desejada             # $v0 = cor certa para (x, y)
    sll   $s7, $s3, 6              # endereco = display + (y*64 + x)*4
    addu  $s7, $s7, $s6
    sll   $s7, $s7, 2
    addu  $s7, $s7, $s1
    lw    $t0, 0($s7)
    beq   $t0, $v0, area_proxima_coluna
    sw    $v0, 0($s7)
area_proxima_coluna:
    addiu $s6, $s6, 1
    j     area_coluna
area_proxima_linha:
    addiu $s3, $s3, 1
    j     area_linha

fim_redesenhar_area:
    lw    $s7, 0($sp)
    lw    $s6, 4($sp)
    lw    $s5, 8($sp)
    lw    $s4, 12($sp)
    lw    $s3, 16($sp)
    lw    $s2, 20($sp)
    lw    $ra, 24($sp)
    addiu $sp, $sp, 28
    jr    $ra

# ---------------------------------------------------------------------
# cor_desejada($a0 = x, $a1 = y) -> $v0
# Ordem de prioridade: jogador, barris, cenario.
# Usa somente registradores $t ($t9 guarda o $ra).
# ---------------------------------------------------------------------
cor_desejada:
    lw    $t3, jog_x
    subu  $t3, $a0, $t3            # dx
    bltz  $t3, cor_nao_jogador
    slti  $t4, $t3, JOG_L
    beq   $t4, $zero, cor_nao_jogador
    lw    $t5, jog_y
    subu  $t5, $a1, $t5            # dy
    bltz  $t5, cor_nao_jogador
    slti  $t4, $t5, JOG_A
    beq   $t4, $zero, cor_nao_jogador
    sll   $t6, $t5, 2              # indice = dy * 4 + dx  (JOG_L = 4)
    addu  $t6, $t6, $t3
    sll   $t6, $t6, 2
    lw    $v0, sprite_jogador($t6)
    addiu $t7, $zero, TRANSPARENTE
    bne   $v0, $t7, cor_fim
cor_nao_jogador:
    addu  $t9, $ra, $zero
    jal   cor_barris
    addu  $ra, $t9, $zero
    addiu $t7, $zero, TRANSPARENTE
    bne   $v0, $t7, cor_fim
    # nenhum sprite cobre: cor do cenario
    sll   $t0, $a1, 6
    addu  $t0, $t0, $a0
    sll   $t0, $t0, 2
    addu  $t0, $t0, $s0
    lw    $v0, 0($t0)
cor_fim:
    jr    $ra

# ---------------------------------------------------------------------
# cor_barris($a0 = x, $a1 = y) -> $v0 = cor do pixel opaco de algum
# barril ativo nessa unidade, ou TRANSPARENTE se nenhum cobre.
# Usa somente $t0..$t7.
# ---------------------------------------------------------------------
cor_barris:
    addu  $t0, $zero, $zero        # indice do barril
cb_loop:
    sll   $t1, $t0, 2
    lw    $t2, barris_ativo($t1)
    beq   $t2, $zero, cb_proximo
    lw    $t3, barris_x($t1)
    subu  $t3, $a0, $t3            # dx
    bltz  $t3, cb_proximo
    slti  $t4, $t3, BARRIL_L
    beq   $t4, $zero, cb_proximo
    lw    $t5, barris_y($t1)
    subu  $t5, $a1, $t5            # dy
    bltz  $t5, cb_proximo
    slti  $t4, $t5, BARRIL_A
    beq   $t4, $zero, cb_proximo
    addiu $t6, $zero, BARRIL_L     # indice = dy * L + dx
    mul   $t6, $t5, $t6
    addu  $t6, $t6, $t3
    sll   $t6, $t6, 2
    lw    $v0, sprite_barril($t6)
    addiu $t7, $zero, TRANSPARENTE
    bne   $v0, $t7, cb_fim         # pixel opaco
cb_proximo:
    addiu $t0, $t0, 1
    slti  $t1, $t0, NUM_BARRIS
    bne   $t1, $zero, cb_loop
    addiu $v0, $zero, TRANSPARENTE
cb_fim:
    jr    $ra

# ---------------------------------------------------------------------
# checar_colisao -> $v0 = 1 se algum pixel opaco do jogador estiver
# sobre um pixel opaco de barril (colisao "pixel a pixel").
# ---------------------------------------------------------------------
checar_colisao:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s2, 8($sp)
    sw    $s3, 4($sp)
    sw    $s4, 0($sp)
    addu  $s2, $zero, $zero        # indice no sprite (0..23)
col_loop:
    sll   $t0, $s2, 2
    lw    $t0, sprite_jogador($t0)
    addiu $t1, $zero, TRANSPARENTE
    beq   $t0, $t1, col_proximo
    andi  $s3, $s2, 3              # dx (JOG_L = 4)
    srl   $s4, $s2, 2              # dy
    lw    $a0, jog_x
    addu  $a0, $a0, $s3
    lw    $a1, jog_y
    addu  $a1, $a1, $s4
    jal   cor_barris
    addiu $t1, $zero, TRANSPARENTE
    bne   $v0, $t1, col_bateu
col_proximo:
    addiu $s2, $s2, 1
    slti  $t0, $s2, JOG_PIX_COLISAO  # hitbox mais justa: ignora os sapatos
    bne   $t0, $zero, col_loop
    addu  $v0, $zero, $zero
    j     col_fim
col_bateu:
    addiu $v0, $zero, 1
col_fim:
    lw    $s4, 0($sp)
    lw    $s3, 4($sp)
    lw    $s2, 8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra

# ---------------------------------------------------------------------
# contar_cor($a0 = x, $a1 = y, $a2 = largura, $a3 = altura, $v1 = cor)
# -> $v0 = quantas unidades do retangulo tem essa cor NO CENARIO.
# Partes fora da tela sao ignoradas. Usa somente $t0..$t5.
# ---------------------------------------------------------------------
contar_cor:
    addu  $v0, $zero, $zero
    addu  $t0, $a1, $zero          # y atual
    addu  $t1, $a1, $a3            # y final (exclusivo)
cc_linha:
    slt   $t2, $t0, $t1
    beq   $t2, $zero, cc_fim
    bltz  $t0, cc_proxima_linha
    slti  $t2, $t0, 128
    beq   $t2, $zero, cc_fim
    addu  $t3, $a0, $zero          # x atual
    addu  $t4, $a0, $a2            # x final (exclusivo)
cc_coluna:
    slt   $t2, $t3, $t4
    beq   $t2, $zero, cc_proxima_linha
    bltz  $t3, cc_proxima_coluna
    slti  $t2, $t3, 64
    beq   $t2, $zero, cc_proxima_linha
    sll   $t5, $t0, 6
    addu  $t5, $t5, $t3
    sll   $t5, $t5, 2
    addu  $t5, $t5, $s0
    lw    $t5, 0($t5)
    bne   $t5, $v1, cc_proxima_coluna
    addiu $v0, $v0, 1
cc_proxima_coluna:
    addiu $t3, $t3, 1
    j     cc_coluna
cc_proxima_linha:
    addiu $t0, $t0, 1
    j     cc_linha
cc_fim:
    jr    $ra

# =====================================================================
# JOGADOR
# As rotinas abaixo usam $s2 = x e $s3 = y do jogador.
# =====================================================================

# jog_apoio -> $v0 = unidades de chao logo abaixo dos pes.
jog_apoio:
    addu  $a0, $s2, $zero
    addiu $a1, $s3, JOG_A
    addiu $a2, $zero, JOG_L
    addiu $a3, $zero, 1
    li    $v1, VERMELHO
    j     contar_cor

# jog_colide -> $v0 = unidades de chao dentro do corpo.
jog_colide:
    addu  $a0, $s2, $zero
    addu  $a1, $s3, $zero
    addiu $a2, $zero, JOG_L
    addiu $a3, $zero, JOG_A
    li    $v1, VERMELHO
    j     contar_cor

# escada_em($a1 = linha inicial, $a3 = numero de linhas)
# -> $v0 = unidades de escada nas colunas do jogador nessas linhas.
escada_em:
    addu  $a0, $s2, $zero
    addiu $a2, $zero, JOG_L
    li    $v1, ESCADA
    j     contar_cor

# na_zona -> $v0 = 1 se o jogador pisa em uma area de pulo alto (pes na
# linha do piso e corpo todo dentro de x0..x1); $v1 = direcao da area.
na_zona:
    la    $t0, zonas
    addiu $t1, $zero, NUM_ZONAS
    addiu $t2, $s3, JOG_A          # linha logo abaixo dos pes
    addiu $t3, $s2, JOG_L
    addiu $t3, $t3, -1             # ultima coluna do corpo
nz_loop:
    lw    $t4, 8($t0)              # linha do piso
    bne   $t4, $t2, nz_proxima
    lw    $t4, 0($t0)              # corpo comeca antes de x0? fora
    slt   $t5, $s2, $t4
    bne   $t5, $zero, nz_proxima
    lw    $t4, 4($t0)              # corpo termina depois de x1? fora
    slt   $t5, $t4, $t3
    bne   $t5, $zero, nz_proxima
    lw    $v1, 12($t0)             # direcao
    addiu $v0, $zero, 1
    jr    $ra
nz_proxima:
    addiu $t0, $t0, 16
    addiu $t1, $t1, -1
    bne   $t1, $zero, nz_loop
    addu  $v0, $zero, $zero
    jr    $ra

# marcar_zonas: pinta COR_ZONA na linha logo acima do piso de cada area,
# direto na imagem do cenario. Assim a faixa aparece e e restaurada como
# qualquer parte do cenario (e nao conta como chao, que e so o vermelho).
marcar_zonas:
    la    $t0, zonas
    addiu $t1, $zero, NUM_ZONAS
    li    $t6, COR_ZONA
mz_zona:
    lw    $t2, 0($t0)              # x atual
    lw    $t3, 4($t0)              # x final
    lw    $t4, 8($t0)
    addiu $t4, $t4, -1             # linha da faixa
    sll   $t4, $t4, 6
mz_coluna:
    addu  $t5, $t4, $t2            # endereco = imagem + (linha*64 + x)*4
    sll   $t5, $t5, 2
    addu  $t5, $t5, $s0
    sw    $t6, 0($t5)
    addiu $t2, $t2, 1
    slt   $t5, $t3, $t2
    beq   $t5, $zero, mz_coluna
    addiu $t0, $t0, 16
    addiu $t1, $t1, -1
    bne   $t1, $zero, mz_zona
    jr    $ra

# carimbar_cachorro: copia os pixels opacos do sprite do Caco para a
# imagem do cenario (ele fica parado, entao vira parte do cenario e e
# restaurado normalmente quando alguem passa na frente).
carimbar_cachorro:
    la    $t0, sprite_cachorro
    addu  $t1, $zero, $zero        # dy
cc_cao_linha:
    addu  $t2, $zero, $zero        # dx
cc_cao_coluna:
    lw    $t3, 0($t0)
    addiu $t4, $zero, TRANSPARENTE
    beq   $t3, $t4, cc_cao_proximo
    addiu $t4, $t1, CAO_Y          # endereco = imagem + ((CAO_Y+dy)*64 + CAO_X+dx)*4
    sll   $t4, $t4, 6
    addiu $t5, $t2, CAO_X
    addu  $t4, $t4, $t5
    sll   $t4, $t4, 2
    addu  $t4, $t4, $s0
    sw    $t3, 0($t4)
cc_cao_proximo:
    addiu $t0, $t0, 4
    addiu $t2, $t2, 1
    slti  $t4, $t2, CAO_L
    bne   $t4, $zero, cc_cao_coluna
    addiu $t1, $t1, 1
    slti  $t4, $t1, CAO_A
    bne   $t4, $zero, cc_cao_linha
    jr    $ra

# tocou_cachorro -> $v0 = 1 se o retangulo do jogador encosta no do Caco.
tocou_cachorro:
    addu  $v0, $zero, $zero
    lw    $t0, jog_x
    lw    $t1, jog_y
    addiu $t2, $t0, JOG_L          # precisa: CAO_X < x + JOG_L
    addiu $t4, $zero, CAO_X
    slt   $t3, $t4, $t2
    beq   $t3, $zero, tc_fim
    addiu $t2, $zero, CAO_X        # e: x < CAO_X + CAO_L
    addiu $t2, $t2, CAO_L
    slt   $t3, $t0, $t2
    beq   $t3, $zero, tc_fim
    addiu $t2, $t1, JOG_A          # e: CAO_Y < y + JOG_A
    addiu $t4, $zero, CAO_Y
    slt   $t3, $t4, $t2
    beq   $t3, $zero, tc_fim
    addiu $t2, $zero, CAO_Y        # e: y < CAO_Y + CAO_A
    addiu $t2, $t2, CAO_A
    slt   $t3, $t1, $t2
    beq   $t3, $zero, tc_fim
    addiu $v0, $zero, 1
tc_fim:
    jr    $ra

# no_chao -> $v0 = 1 se ha chao sob os pes E o corpo nao esta dentro de
# uma plataforma (subindo por dentro dela o jogador nao "pousa").
no_chao:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    jal   jog_colide
    bne   $v0, $zero, nc_nao
    jal   jog_apoio
    sltu  $v0, $zero, $v0          # $v0 = (apoio > 0)
    j     nc_fim
nc_nao:
    addu  $v0, $zero, $zero
nc_fim:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# tentar_mover($a0 = dx): anda na horizontal. Se bater em um degrau de
# 1 unidade sobe nele; se for parede, desfaz o movimento.
tentar_mover:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $a0, 0($sp)
    addu  $s2, $s2, $a0
    bltz  $s2, tm_desfazer_x
    slti  $t0, $s2, JOG_X_MAX_MAIS1
    beq   $t0, $zero, tm_desfazer_x
    jal   jog_colide
    beq   $v0, $zero, tm_fim
    addiu $s3, $s3, -1             # tenta subir 1 degrau
    jal   jog_colide
    beq   $v0, $zero, tm_fim
    addiu $s3, $s3, 1
tm_desfazer_x:
    lw    $t0, 0($sp)
    subu  $s2, $s2, $t0
tm_fim:
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ---------------------------------------------------------------------
# atualizar_jogador($a0 = tecla): le a tecla e aplica a fisica.
#   - no ar (pulando ou caindo) as teclas sao ignoradas;
#   - a/d andam 1 unidade; w/s sobem/descem escadas;
#   - ESPACO pula (se estiver no chao), levando a ultima direcao andada.
# ---------------------------------------------------------------------
atualizar_jogador:
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $s2, 12($sp)
    sw    $s3, 8($sp)
    sw    $s4, 4($sp)
    sw    $s5, 0($sp)
    addu  $s4, $a0, $zero          # tecla
    lw    $s2, jog_x
    lw    $s3, jog_y

    lw    $t0, jog_dir_tempo
    blez  $t0, aj_estado
    addiu $t0, $t0, -1
    sw    $t0, jog_dir_tempo

aj_estado:
    lw    $t0, jog_pulo
    bne   $t0, $zero, aj_fisica    # pulando: ignora teclas
    lw    $t0, jog_escada
    bne   $t0, $zero, aj_teclas    # na escada: aceita teclas
    jal   no_chao
    beq   $v0, $zero, aj_fisica    # caindo: ignora teclas

aj_teclas:
    addiu $t0, $zero, TECLA_A
    beq   $s4, $t0, aj_esquerda
    addiu $t0, $zero, TECLA_D
    beq   $s4, $t0, aj_direita
    addiu $t0, $zero, TECLA_W
    beq   $s4, $t0, aj_subir
    addiu $t0, $zero, TECLA_S
    beq   $s4, $t0, aj_descer
    addiu $t0, $zero, TECLA_ESPACO
    beq   $s4, $t0, aj_pular
    j     aj_fisica

aj_esquerda:
    addiu $s5, $zero, -1
    j     aj_andar
aj_direita:
    addiu $s5, $zero, 1
aj_andar:
    lw    $t0, jog_escada
    beq   $t0, $zero, aj_andar_ok
    # Na escada: so sai para o lado se la tiver chao livre (pe da escada,
    # ou o topo da escada do Caco, que fica AO LADO da plataforma).
    addu  $s2, $s2, $s5
    jal   no_chao
    bne   $v0, $zero, aj_saiu_escada
    subu  $s2, $s2, $s5
    j     aj_fisica
aj_saiu_escada:
    sw    $zero, jog_escada
    sw    $s5, jog_dir
    j     aj_fisica
aj_andar_ok:
    sw    $s5, jog_dir
    addiu $t0, $zero, DIR_TEMPO
    sw    $t0, jog_dir_tempo
    addu  $a0, $s5, $zero
    jal   tentar_mover
    j     aj_fisica

aj_subir:
    addu  $a1, $s3, $zero          # escada no corpo ou nos pes?
    addiu $a3, $zero, JOG_A_MAIS1
    jal   escada_em
    beq   $v0, $zero, aj_fisica
    addiu $t0, $zero, 1
    sw    $t0, jog_escada
    addiu $s3, $s3, -1
    addu  $a1, $s3, $zero
    addiu $a3, $zero, JOG_A_MAIS1
    jal   escada_em
    bne   $v0, $zero, aj_fisica    # ainda na escada
    # Saiu pelo topo da escada: sobe ate pisar no chao de cima.
    addiu $s5, $zero, 8
aj_topo:
    jal   jog_apoio
    bne   $v0, $zero, aj_topo_fim
    addiu $s3, $s3, -1
    addiu $s5, $s5, -1
    bne   $s5, $zero, aj_topo
    # Nao ha chao em cima (escada ao lado da plataforma): volta para o
    # ultimo degrau e continua pendurado. Dai e so andar para o lado.
    addiu $s3, $s3, 9
    j     aj_fisica
aj_topo_fim:
    sw    $zero, jog_escada
    j     aj_fisica

aj_descer:
    addiu $a1, $s3, JOG_A          # escada logo abaixo dos pes?
    addiu $a3, $zero, 3
    jal   escada_em
    beq   $v0, $zero, aj_fisica
    addiu $t0, $zero, 1
    sw    $t0, jog_escada
    addiu $s3, $s3, 1
    # Chegou no pe da escada (chao embaixo e nenhuma escada abaixo)?
    jal   jog_apoio
    beq   $v0, $zero, aj_fisica
    addiu $a1, $s3, JOG_A
    addiu $a3, $zero, 3
    jal   escada_em
    bne   $v0, $zero, aj_fisica
    sw    $zero, jog_escada
    j     aj_fisica

aj_pular:
    lw    $t0, jog_escada
    bne   $t0, $zero, aj_fisica    # nao pula da escada
    jal   no_chao
    beq   $v0, $zero, aj_fisica
    jal   na_zona                  # dentro de uma area de pulo alto?
    bne   $v0, $zero, aj_pulo_alto

    # Pulo curto: leva a ultima direcao andada desde o primeiro quadro.
    addiu $t0, $zero, PULO_CURTO_QUADROS
    sw    $t0, jog_pulo
    addiu $t0, $zero, PULO_CURTO_PASSO
    sw    $t0, jog_passo
    addiu $t0, $zero, PULO_CURTO_PAIRAR
    sw    $t0, jog_pairar
    sw    $zero, jog_atraso_lateral
    addu  $t1, $zero, $zero
    lw    $t0, jog_dir_tempo
    blez  $t0, aj_salvar_vx
    lw    $t1, jog_dir
aj_salvar_vx:
    sw    $t1, jog_vx
    j     aj_fisica

aj_pulo_alto:
    # Pulo alto: sobe reto e so depois anda na direcao da area.
    sw    $v1, jog_vx
    addiu $t0, $zero, PULO_ALTO_QUADROS
    sw    $t0, jog_pulo
    addiu $t0, $zero, PULO_ALTO_PASSO
    sw    $t0, jog_passo
    addiu $t0, $zero, PULO_ALTO_PAIRAR
    sw    $t0, jog_pairar
    addiu $t0, $zero, PULO_ALTO_RETO
    sw    $t0, jog_atraso_lateral

aj_fisica:
    sw    $zero, jog_chao
    lw    $t0, jog_escada
    bne   $t0, $zero, aj_salvar    # na escada nao ha gravidade
    lw    $t0, jog_pulo
    beq   $t0, $zero, aj_gravidade
    addiu $t0, $t0, -1             # pulando: sobe jog_passo linhas ou paira
    sw    $t0, jog_pulo
    lw    $t1, jog_pairar
    slt   $t1, $t0, $t1
    bne   $t1, $zero, aj_lateral
    lw    $t1, jog_passo
    subu  $s3, $s3, $t1            # atravessa plataformas subindo
    bgez  $s3, aj_lateral
    addu  $s3, $zero, $zero
aj_lateral:
    # Nos primeiros quadros do pulo alto ainda nao anda para o lado.
    lw    $t0, jog_atraso_lateral
    blez  $t0, aj_mover_ar
    addiu $t0, $t0, -1
    sw    $t0, jog_atraso_lateral
    j     aj_salvar

aj_gravidade:
    # Cai ate 2 linhas por quadro; pousa quando tem chao embaixo e o
    # corpo ja saiu de dentro das plataformas.
    jal   no_chao
    beq   $v0, $zero, aj_cair
    sw    $zero, jog_vx            # esta no chao
    addiu $t0, $zero, 1
    sw    $t0, jog_chao
    j     aj_salvar
aj_cair:
    addiu $s3, $s3, 1
    jal   no_chao
    bne   $v0, $zero, aj_limite_queda
    addiu $s3, $s3, 1
aj_limite_queda:
    slti  $t0, $s3, JOG_Y_MAX_MAIS1
    bne   $t0, $zero, aj_mover_ar
    addiu $s3, $zero, JOG_Y_MAX

aj_mover_ar:
    # No ar anda livremente (sem bater nas plataformas), so nas bordas.
    lw    $t0, jog_vx
    addu  $s2, $s2, $t0
    bgez  $s2, aj_ar_dir
    addu  $s2, $zero, $zero
aj_ar_dir:
    slti  $t0, $s2, JOG_X_MAX_MAIS1
    bne   $t0, $zero, aj_salvar
    addiu $s2, $zero, JOG_X_MAX

aj_salvar:
    sw    $s2, jog_x
    sw    $s3, jog_y
    lw    $s5, 0($sp)
    lw    $s4, 4($sp)
    lw    $s3, 8($sp)
    lw    $s2, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra

# =====================================================================
# BARRIS
# =====================================================================

# ---------------------------------------------------------------------
# atualizar_barril($a0 = indice): move o barril somente na memoria.
#   - inativo: conta o atraso e aparece no spawn quando houver espaco;
#   - sem chao embaixo: cai ate 2 linhas por ciclo;
#   - com chao: anda 1 unidade na direcao atual.
# ---------------------------------------------------------------------
atualizar_barril:
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $s2, 12($sp)
    sw    $s3, 8($sp)
    sw    $s4, 4($sp)
    sw    $s7, 0($sp)
    addu  $s7, $a0, $zero
    sll   $t0, $s7, 2

    lw    $t1, barris_ativo($t0)
    bne   $t1, $zero, carregar_barril

    # Inativo: espera o atraso.
    lw    $t1, barris_atraso($t0)
    beq   $t1, $zero, tentar_spawn
    addiu $t1, $t1, -1
    sw    $t1, barris_atraso($t0)
    j     fim_atualizar_barril

tentar_spawn:
    addiu $s2, $zero, SPAWN_X
    addiu $s3, $zero, SPAWN_Y
    addiu $s4, $zero, 1
    jal   posicao_livre
    beq   $v0, $zero, fim_atualizar_barril
    sll   $t0, $s7, 2
    addiu $t1, $zero, 1
    sw    $t1, barris_ativo($t0)
    j     salvar_barril

carregar_barril:
    lw    $s2, barris_x($t0)
    lw    $s3, barris_y($t0)
    lw    $s4, barris_dir($t0)

    # Gravidade: tem chao suficiente embaixo?
    jal   contar_apoio
    slti  $t0, $v0, APOIO_MIN
    beq   $t0, $zero, andar_barril

    # Caindo (2 linhas por ciclo no maximo).
    addiu $s3, $s3, 1
    slti  $t0, $s3, Y_MAX_MAIS1
    beq   $t0, $zero, sumir_barril
    jal   contar_apoio
    slti  $t0, $v0, APOIO_MIN
    beq   $t0, $zero, salvar_barril
    addiu $s3, $s3, 1
    slti  $t0, $s3, Y_MAX_MAIS1
    beq   $t0, $zero, sumir_barril
    j     salvar_barril

andar_barril:
    # Limites horizontais: inverte a direcao.
    slti  $t0, $s2, LIMITE_DIR_MAIS1
    bne   $t0, $zero, checar_esquerda
    addiu $s4, $zero, -1
checar_esquerda:
    slti  $t0, $s2, LIMITE_ESQ
    beq   $t0, $zero, mover_barril
    addiu $s4, $zero, 1
mover_barril:
    # Barris podem se sobrepor (como no Donkey Kong): se um bloqueasse o
    # outro, dois barris que caem um sobre o outro travariam para sempre.
    addu  $s2, $s2, $s4

checar_final:
    # Chegou ao ultimo andar, no canto esquerdo? Some e renasce depois.
    slti  $t0, $s3, Y_FINAL
    bne   $t0, $zero, salvar_barril
    slti  $t0, $s2, X_FINAL_MAIS1
    bne   $t0, $zero, sumir_barril
    j     salvar_barril

sumir_barril:
    sll   $t0, $s7, 2
    sw    $zero, barris_ativo($t0)
    addiu $t1, $zero, ATRASO_RENASCER
    sw    $t1, barris_atraso($t0)
    j     fim_atualizar_barril

salvar_barril:
    sll   $t0, $s7, 2
    sw    $s2, barris_x($t0)
    sw    $s3, barris_y($t0)
    sw    $s4, barris_dir($t0)

fim_atualizar_barril:
    lw    $s7, 0($sp)
    lw    $s4, 4($sp)
    lw    $s3, 8($sp)
    lw    $s2, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra

# ---------------------------------------------------------------------
# posicao_livre: $s7 = barril atual, $s2/$s3 = posicao candidata.
# $v0 = 1 se nenhum outro barril ativo estiver encostado/sobreposto.
# (usado so no spawn, para dois barris nao nascerem juntos)
# ---------------------------------------------------------------------
posicao_livre:
    addu  $t0, $zero, $zero
livre_loop:
    beq   $t0, $s7, livre_proximo
    sll   $t1, $t0, 2
    lw    $t2, barris_ativo($t1)
    beq   $t2, $zero, livre_proximo
    lw    $t3, barris_x($t1)
    subu  $t4, $s2, $t3
    bgez  $t4, livre_dx_pos
    subu  $t4, $zero, $t4
livre_dx_pos:
    slti  $t5, $t4, BARRIL_L_MAIS1  # |dx| <= L: muito perto
    beq   $t5, $zero, livre_proximo
    lw    $t3, barris_y($t1)
    subu  $t4, $s3, $t3
    bgez  $t4, livre_dy_pos
    subu  $t4, $zero, $t4
livre_dy_pos:
    slti  $t5, $t4, BARRIL_A       # |dy| < A: sprites na mesma faixa
    bne   $t5, $zero, livre_ocupada
livre_proximo:
    addiu $t0, $t0, 1
    slti  $t1, $t0, NUM_BARRIS
    bne   $t1, $zero, livre_loop
    addiu $v0, $zero, 1
    jr    $ra
livre_ocupada:
    addu  $v0, $zero, $zero
    jr    $ra

# ---------------------------------------------------------------------
# contar_apoio: $s2/$s3 = posicao do barril. $v0 = unidades vermelhas
# (chao) na linha logo abaixo do sprite, de x ate x + BARRIL_L - 1.
# ---------------------------------------------------------------------
contar_apoio:
    addiu $t0, $s3, BARRIL_A       # linha abaixo do sprite
    sll   $t0, $t0, 6
    addu  $t0, $t0, $s2
    sll   $t0, $t0, 2
    addu  $t0, $t0, $s0
    li    $t2, VERMELHO
    addu  $v0, $zero, $zero
    addiu $t4, $zero, BARRIL_L
apoio_loop:
    lw    $t5, 0($t0)
    bne   $t5, $t2, apoio_proximo
    addiu $v0, $v0, 1
apoio_proximo:
    addiu $t0, $t0, 4
    addiu $t4, $t4, -1
    bne   $t4, $zero, apoio_loop
    jr    $ra
