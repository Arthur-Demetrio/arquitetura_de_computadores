# =====================================================================
# Save Caco - MARS 4.5
# Bitmap Display: unidade 4x4, tela 256x512  ->  64 x 128 unidades
# Base do display: 0x10008000 ($gp)
# Montar com "Assemble all files in directory" (main, cenario, sprites).
#
# Como o desenho funciona (sem piscar):
#   1. todos os barris sao atualizados (so a posicao muda na memoria);
#   2. para cada barril, a area antiga e a area nova sao "redesenhadas":
#      cada unidade recebe a cor que DEVERIA ter (sprite ou cenario) e so
#      e escrita no display se for diferente da cor atual. Assim nenhuma
#      unidade passa pelo fundo antes de virar sprite -> nada pisca.
# =====================================================================

.eqv NUM_BARRIS   3
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
.eqv VERMELHO     0x00920D28 # cor do chao no cenario
.eqv TRANSPARENTE -1         # 0xFFFFFFFF no sprite = nao desenha
.eqv ESPERA_MS    80         # duracao de um ciclo do jogo
# O MARS nao calcula "CONST + 1": constantes auxiliares
.eqv Y_MAX_MAIS1      124
.eqv LIMITE_DIR_MAIS1 53
.eqv X_FINAL_MAIS1    11
.eqv BARRIL_L_MAIS1   6

.data
# Dados individuais dos barris (indice 0..NUM_BARRIS-1).
barris_x:          .word 10, 10, 10
barris_y:          .word 30, 30, 30
barris_dir:        .word 1, 1, 1
# Atraso inicial em ciclos antes de cada barril aparecer.
barris_atraso:     .word 0, 60, 120
barris_ativo:      .word 1, 0, 0
# Estado do ciclo anterior (para saber que area redesenhar).
barris_ant_x:      .word 10, 10, 10
barris_ant_y:      .word 30, 30, 30
barris_ant_ativo:  .word 1, 0, 0

.text
.globl main

main:
    la    $s0, imagem              # $s0 = cenario (64 x 128 words)
    lui   $s1, 0x1000
    ori   $s1, $s1, 0x8000         # $s1 = Bitmap Display

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

    # Desenha os barris que comecam ativos.
    addu  $s7, $zero, $zero
desenhar_iniciais:
    addu  $a0, $s7, $zero
    jal   redesenhar_barril
    addiu $s7, $s7, 1
    slti  $t0, $s7, NUM_BARRIS
    bne   $t0, $zero, desenhar_iniciais

    # Espera a tecla ESPACO (Keyboard and Display MMIO Simulator).
esperar_espaco:
    lui   $t0, 0xFFFF
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beq   $t1, $zero, esperar_espaco
    lw    $t1, 4($t0)
    addiu $t2, $zero, 32
    bne   $t1, $t2, esperar_espaco

loop_jogo:
    # 1) atualiza todos os barris (somente memoria)
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

    addiu $v0, $zero, 32           # sleep
    addiu $a0, $zero, ESPERA_MS
    syscall
    j     loop_jogo

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
# Cor que a unidade deve ter: pixel opaco de algum barril ativo que a
# cubra; senao, a cor do cenario. (Usa somente registradores $t.)
# Quando houver personagem, teste o sprite dele aqui tambem.
# ---------------------------------------------------------------------
cor_desejada:
    addu  $t0, $zero, $zero        # indice do barril
cor_barril:
    sll   $t1, $t0, 2
    lw    $t2, barris_ativo($t1)
    beq   $t2, $zero, cor_proximo
    lw    $t3, barris_x($t1)
    subu  $t3, $a0, $t3            # dx
    bltz  $t3, cor_proximo
    slti  $t4, $t3, BARRIL_L
    beq   $t4, $zero, cor_proximo
    lw    $t5, barris_y($t1)
    subu  $t5, $a1, $t5            # dy
    bltz  $t5, cor_proximo
    slti  $t4, $t5, BARRIL_A
    beq   $t4, $zero, cor_proximo
    addiu $t6, $zero, BARRIL_L     # indice = dy * L + dx
    mul   $t6, $t5, $t6
    addu  $t6, $t6, $t3
    sll   $t6, $t6, 2
    lw    $v0, sprite_barril($t6)
    addiu $t7, $zero, TRANSPARENTE
    bne   $v0, $t7, cor_fim        # pixel opaco: e essa a cor
cor_proximo:
    addiu $t0, $t0, 1
    slti  $t1, $t0, NUM_BARRIS
    bne   $t1, $zero, cor_barril
    # nenhum sprite cobre: cor do cenario
    sll   $t0, $a1, 6
    addu  $t0, $t0, $a0
    sll   $t0, $t0, 2
    addu  $t0, $t0, $s0
    lw    $v0, 0($t0)
cor_fim:
    jr    $ra

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
# contar_apoio: $s2/$s3 = posicao. $v0 = unidades vermelhas (chao) na
# linha logo abaixo do sprite, de x ate x + BARRIL_L - 1.
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
