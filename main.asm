.data
# Dados individuais dos 3 barris.
# Para adicionar NPCs, amplie as listas e atualize os 3 ciclos/limites.
barris_x:          .word 10, 10, 10
barris_y:          .word 49, 49, 49
barris_dir:        .word 1, 1, 1
# Atraso inicial em ciclos de 120 ms: 0, 57 e 113
# Segundo barril espera cerca de 6,8 s; terceiro, cerca de 13,6 s.
barris_atraso:     .word 0, 57, 113
barris_spawn_x:    .word 10, 10, 10
barris_spawn_y:    .word 49, 49, 49
# Somente o primeiro barril fica visivel no inicio
barris_ativo:      .word 1, 0, 0
# Estado anterior usado para redesenhar somente as celulas que mudaram.
barris_ant_x:      .word 10, 10, 10
barris_ant_y:      .word 49, 49, 49
barris_ant_ativo:  .word 1, 0, 0

.text
.globl main

main:
    # Base da imagem original do cenario
    la    $s0, imagem

    # Base do Bitmap Display
    lui   $s1, 0x1000
    ori   $s1, $s1, 0x8000

    # Cor laranja: 0x00FF8000
    lui   $s6, 0x00FF
    ori   $s6, $s6, 0x8000

    # Desenha o cenario: 128 linhas x 64 colunas
    addu  $t0, $s0, $zero
    addu  $t1, $s1, $zero
    addiu $t2, $zero, 128

desenhar_cenario_linha:
    addu  $t3, $t0, $zero
    addiu $t4, $zero, 64

desenhar_cenario_pixel:
    lw    $t5, 0($t3)
    sw    $t5, 0($t1)
    addiu $t3, $t3, 16
    addiu $t1, $t1, 4
    addiu $t4, $t4, -1
    bne   $t4, $zero, desenhar_cenario_pixel
    nop

    addiu $t0, $t0, 4096
    addiu $t2, $t2, -1
    bne   $t2, $zero, desenhar_cenario_linha
    nop

    # Desenha somente os barris ativos no inicio (apenas o primeiro)
    addu  $s7, $zero, $zero
    la    $t0, barris_x
    lw    $s2, 0($t0)
    la    $t0, barris_y
    lw    $s3, 0($t0)
    jal   desenhar_barril
    nop

    # Espera a tecla ESPACO
esperar_espaco:
    lui   $t0, 0xFFFF
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beq   $t1, $zero, esperar_espaco
    nop
    lw    $t1, 4($t0)
    addiu $t2, $zero, 32
    bne   $t1, $t2, esperar_espaco
    nop

loop_movimento:
    # Guarda o estado anterior, atualiza o NPC e redesenha somente a diferenca.
    addu  $a0, $zero, $zero
    jal   capturar_estado_anterior
    nop
    addu  $a0, $zero, $zero
    jal   atualizar_barril
    nop
    addu  $a0, $zero, $zero
    jal   renderizar_diferencial
    nop

    addiu $a0, $zero, 1
    jal   capturar_estado_anterior
    nop
    addiu $a0, $zero, 1
    jal   atualizar_barril
    nop
    addiu $a0, $zero, 1
    jal   renderizar_diferencial
    nop

    addiu $a0, $zero, 2
    jal   capturar_estado_anterior
    nop
    addiu $a0, $zero, 2
    jal   atualizar_barril
    nop
    addiu $a0, $zero, 2
    jal   renderizar_diferencial
    nop

    addiu $v0, $zero, 32
    addiu $a0, $zero, 120
    syscall
    j     loop_movimento
    nop

# Salva a posicao e o estado atuais antes de atualizar o barril ($a0 = indice).
capturar_estado_anterior:
    sll   $t0, $a0, 2
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    la    $t1, barris_ant_x
    addu  $t1, $t1, $t0
    sw    $t2, 0($t1)

    la    $t1, barris_y
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    la    $t1, barris_ant_y
    addu  $t1, $t1, $t0
    sw    $t2, 0($t1)

    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    la    $t1, barris_ant_ativo
    addu  $t1, $t1, $t0
    sw    $t2, 0($t1)
    jr    $ra
    nop

# Atualizacao diferencial: restaura apenas a parte antiga que ficou descoberta
# e pinta apenas as celulas novas. Entrada $a0 = indice do barril.
renderizar_diferencial:
    addiu $sp, $sp, -28
    sw    $ra, 24($sp)
    sw    $s2, 20($sp)
    sw    $s3, 16($sp)
    sw    $s4, 12($sp)
    sw    $s5, 8($sp)
    sw    $s7, 4($sp)
    addu  $s7, $a0, $zero
    sll   $t0, $s7, 2

    # $s2/$s3 = posicao anterior; $s4/$s5 = posicao nova.
    la    $t1, barris_ant_x
    addu  $t1, $t1, $t0
    lw    $s2, 0($t1)
    la    $t1, barris_ant_y
    addu  $t1, $t1, $t0
    lw    $s3, 0($t1)
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    lw    $s4, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    lw    $s5, 0($t1)

    la    $t1, barris_ant_ativo
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    sw    $t2, 0($sp)          # ativo anterior (slot proprio)
    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    lw    $t3, 0($t1)          # ativo atual

    # Se estava ativo, percorre o sprite antigo e restaura somente celulas
    # que nao pertencem ao sprite novo (ou se o barril foi desativado).
    beq   $t2, $zero, dif_pintar_novo
    nop
    addu  $t6, $zero, $zero    # dy = 0..2
 dif_rest_linha:
    addu  $t7, $zero, $zero    # dx = 0..2
 dif_rest_coluna:
    # Nao restaura se a celula antiga ainda estiver coberta pelo sprite novo.
    beq   $t3, $zero, dif_restaurar_celula
    nop
    subu  $t8, $s2, $s4
    addu  $t8, $t8, $t7
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_restaurar_celula
    nop
    slti  $t9, $t8, 3
    beq   $t9, $zero, dif_restaurar_celula
    nop
    subu  $t8, $s3, $s5
    addu  $t8, $t8, $t6
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_restaurar_celula
    nop
    slti  $t9, $t8, 3
    bne   $t9, $zero, dif_rest_proxima
    nop
 dif_restaurar_celula:
    # Antes de restaurar o cenario, verifica se OUTRO barril ativo
    # ainda ocupa esta celula. Isso evita apagar um sprite desenhado
    # anteriormente quando os retangulos dos barris se sobrepoem.
    addu  $t5, $s2, $t7       # x da celula antiga
    addu  $t0, $s3, $t6       # y da celula antiga
    addu  $t4, $zero, $zero   # indice do barril a verificar
 dif_verificar_cobertura:
    sll   $t1, $t4, 2
    la    $t2, barris_ativo
    addu  $t2, $t2, $t1
    lw    $t2, 0($t2)
    beq   $t2, $zero, dif_cobertura_proximo
    nop

    la    $t2, barris_x
    addu  $t2, $t2, $t1
    lw    $t2, 0($t2)         # x do barril verificado
    subu  $t8, $t5, $t2
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_cobertura_proximo
    nop
    slti  $t9, $t8, 3
    beq   $t9, $zero, dif_cobertura_proximo
    nop

    la    $t2, barris_y
    addu  $t2, $t2, $t1
    lw    $t2, 0($t2)         # y do barril verificado
    subu  $t8, $t0, $t2
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_cobertura_proximo
    nop
    slti  $t9, $t8, 3
    bne   $t9, $zero, dif_rest_proxima
    nop

 dif_cobertura_proximo:
    addiu $t4, $t4, 1
    slti  $t1, $t4, 3
    bne   $t1, $zero, dif_verificar_cobertura
    nop

    # Nenhum barril cobre a celula: restaura a cor original do cenario.
    addu  $t8, $s3, $t6
    sll   $t8, $t8, 12
    addu  $t8, $t8, $s0
    addu  $t9, $s2, $t7
    sll   $t9, $t9, 4
    addu  $t8, $t8, $t9
    lw    $t8, 0($t8)

    addu  $t9, $s3, $t6
    sll   $t9, $t9, 8
    addu  $t9, $t9, $s1
    addu  $t0, $s2, $t7
    sll   $t0, $t0, 2
    addu  $t9, $t9, $t0
    sw    $t8, 0($t9)
 dif_rest_proxima:
    addiu $t7, $t7, 1
    slti  $t8, $t7, 3
    bne   $t8, $zero, dif_rest_coluna
    nop
    addiu $t6, $t6, 1
    slti  $t8, $t6, 3
    bne   $t8, $zero, dif_rest_linha
    nop

 dif_pintar_novo:
    # Se o barril atual esta inativo, nao ha sprite novo para desenhar.
    beq   $t3, $zero, fim_renderizar_diferencial
    nop
    addu  $t6, $zero, $zero
 dif_pint_linha:
    addu  $t7, $zero, $zero
 dif_pint_coluna:
    # Se ja existia um sprite cobrindo esta celula, mantem a cor atual.
    lw    $t2, 0($sp)
    beq   $t2, $zero, dif_pintar_celula
    nop
    subu  $t8, $s4, $s2
    addu  $t8, $t8, $t7
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_pintar_celula
    nop
    slti  $t9, $t8, 3
    beq   $t9, $zero, dif_pintar_celula
    nop
    subu  $t8, $s5, $s3
    addu  $t8, $t8, $t6
    slti  $t9, $t8, 0
    bne   $t9, $zero, dif_pintar_celula
    nop
    slti  $t9, $t8, 3
    bne   $t9, $zero, dif_pint_proxima
    nop
 dif_pintar_celula:
    addu  $t8, $s5, $t6
    sll   $t8, $t8, 8
    addu  $t8, $t8, $s1
    addu  $t9, $s4, $t7
    sll   $t9, $t9, 2
    addu  $t8, $t8, $t9
    sw    $s6, 0($t8)
 dif_pint_proxima:
    addiu $t7, $t7, 1
    slti  $t8, $t7, 3
    bne   $t8, $zero, dif_pint_coluna
    nop
    addiu $t6, $t6, 1
    slti  $t8, $t6, 3
    bne   $t8, $zero, dif_pint_linha
    nop

fim_renderizar_diferencial:
    lw    $s7, 4($sp)
    lw    $s5, 8($sp)
    lw    $s4, 12($sp)
    lw    $s3, 16($sp)
    lw    $s2, 20($sp)
    lw    $ra, 24($sp)
    addiu $sp, $sp, 28
    jr    $ra
    nop

# Restaura o barril indicado em $a0 somente se estiver ativo.
restaurar_se_ativo:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $s7, 0($sp)
    addu  $s7, $a0, $zero
    sll   $t0, $s7, 2
    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    beq   $t2, $zero, fim_restaurar_se_ativo
    nop
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    lw    $s2, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    lw    $s3, 0($t1)
    jal   restaurar_barril
    nop
fim_restaurar_se_ativo:
    lw    $s7, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra
    nop

# Desenha o barril indicado em $a0 somente se estiver ativo.
desenhar_se_ativo:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $s7, 0($sp)
    addu  $s7, $a0, $zero
    sll   $t0, $s7, 2
    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    beq   $t2, $zero, fim_desenhar_se_ativo
    nop
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    lw    $s2, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    lw    $s3, 0($t1)
    jal   desenhar_barril
    nop
fim_desenhar_se_ativo:
    lw    $s7, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra
    nop

# Atualiza um NPC sem restaurar nem desenhar; $a0 = indice 0..2.
atualizar_barril:
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $s2, 12($sp)
    sw    $s3, 8($sp)
    sw    $s4, 4($sp)
    sw    $s7, 0($sp)
    addu  $s7, $a0, $zero
    sll   $t0, $s7, 2

    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    bne   $t2, $zero, carregar_barril_ativo
    nop

    # NPC inativo: conta o atraso antes de aparecer no spawn comum.
    la    $t1, barris_atraso
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    beq   $t2, $zero, ativar_barril
    nop
    addiu $t2, $t2, -1
    sw    $t2, 0($t1)
    j     fim_atualizar_barril
    nop

ativar_barril:
    # Todos usam o mesmo spawn, mas so entram quando ha espaco.
    addiu $s2, $zero, 10
    addiu $s3, $zero, 49
    addiu $s4, $zero, 1
    jal   posicao_livre
    nop
    beq   $v0, $zero, fim_atualizar_barril
    nop

    # Ativa o NPC correto.
    sll   $t0, $s7, 2
    la    $t1, barris_ativo
    addu  $t1, $t1, $t0
    addiu $t2, $zero, 1
    sw    $t2, 0($t1)

    la    $t1, barris_x
    addu  $t1, $t1, $t0
    sw    $s2, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    sw    $s3, 0($t1)
    la    $t1, barris_dir
    addu  $t1, $t1, $t0
    sw    $s4, 0($t1)
    j     fim_atualizar_barril
    nop

carregar_barril_ativo:
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    lw    $s2, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    lw    $s3, 0($t1)
    la    $t1, barris_dir
    addu  $t1, $t1, $t0
    lw    $s4, 0($t1)

    # Limites horizontais
    addiu $t0, $zero, 53
    slt   $t1, $t0, $s2
    beq   $t1, $zero, verificar_limite_esquerdo
    nop
    addiu $s4, $zero, -1
verificar_limite_esquerdo:
    addiu $t0, $zero, 8
    slt   $t1, $s2, $t0
    beq   $t1, $zero, atualizar_posicao
    nop
    addiu $s4, $zero, 1

atualizar_posicao:
    # Testa a proxima celula antes de aceitar o movimento.
    addu  $s2, $s2, $s4
    jal   posicao_livre
    nop
    bne   $v0, $zero, movimento_aceito
    nop
    # Ha outro barril perto: fica na posicao anterior neste ciclo.
    subu  $s2, $s2, $s4
    j     salvar_estado_barril
    nop

movimento_aceito:
    jal   verificar_reinicio
    nop
    bne   $v0, $zero, reiniciar_barril
    nop

    jal   contar_apoio
    nop
    addiu $t0, $zero, 2
    slt   $t1, $v0, $t0
    beq   $t1, $zero, salvar_estado_barril
    nop

queda_barril:
    addiu $s3, $s3, 1
    addiu $t0, $zero, 124
    slt   $t1, $t0, $s3
    bne   $t1, $zero, reiniciar_altura
    nop
    jal   verificar_reinicio
    nop
    bne   $v0, $zero, reiniciar_barril
    nop
    jal   contar_apoio
    nop
    addiu $t0, $zero, 2
    slt   $t1, $v0, $t0
    bne   $t1, $zero, queda_barril
    nop
    j     salvar_estado_barril
    nop

reiniciar_altura:
    addiu $s3, $zero, 124
    j     salvar_estado_barril
    nop

reiniciar_barril:
    # Reinicia este NPC no spawn comum; os outros estados nao sao alterados.
    addiu $s2, $zero, 10
    addiu $s3, $zero, 49
    addiu $s4, $zero, 1

salvar_estado_barril:
    sll   $t0, $s7, 2
    la    $t1, barris_x
    addu  $t1, $t1, $t0
    sw    $s2, 0($t1)
    la    $t1, barris_y
    addu  $t1, $t1, $t0
    sw    $s3, 0($t1)
    la    $t1, barris_dir
    addu  $t1, $t1, $t0
    sw    $s4, 0($t1)

fim_atualizar_barril:
    lw    $s7, 0($sp)
    lw    $s4, 4($sp)
    lw    $s3, 8($sp)
    lw    $s2, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra
    nop

# ------------------------------------------------
# POSICAO_LIVRE
# Entrada: $s7 indice do barril atual, $s2/$s3 posicao candidata.
# Retorna $v0=1 se nao houver outro barril a menos de 4 celulas
# horizontalmente enquanto seus sprites se sobrepoem verticalmente.
# Tambem impede que dois barris ocupem o mesmo spawn.
# ------------------------------------------------
posicao_livre:
    addu  $v0, $zero, $zero
    addu  $t0, $zero, $zero       # indice do outro barril
checar_outro_barril:
    beq   $t0, $s7, proximo_outro_barril
    nop
    sll   $t1, $t0, 2
    la    $t2, barris_ativo
    addu  $t2, $t2, $t1
    lw    $t3, 0($t2)
    beq   $t3, $zero, proximo_outro_barril
    nop

    la    $t2, barris_x
    addu  $t2, $t2, $t1
    lw    $t3, 0($t2)            # outro x
    subu  $t4, $s2, $t3          # dx = candidato - outro
    bgez  $t4, dx_positivo
    nop
    subu  $t4, $zero, $t4
 dx_positivo:
    addiu $t5, $zero, 4
    slt   $t6, $t4, $t5          # |dx| < 4?
    beq   $t6, $zero, proximo_outro_barril
    nop

    la    $t2, barris_y
    addu  $t2, $t2, $t1
    lw    $t3, 0($t2)            # outro y
    subu  $t4, $s3, $t3
    bgez  $t4, dy_positivo
    nop
    subu  $t4, $zero, $t4
 dy_positivo:
    addiu $t5, $zero, 3
    slt   $t6, $t4, $t5          # |dy| < 3? sprites sobrepostos
    bne   $t6, $zero, posicao_ocupada
    nop

proximo_outro_barril:
    addiu $t0, $t0, 1
    slti  $t1, $t0, 3
    bne   $t1, $zero, checar_outro_barril
    nop
    addiu $v0, $zero, 1
    jr    $ra
    nop

posicao_ocupada:
    addu  $v0, $zero, $zero
    jr    $ra
    nop

# ------------------------------------------------
# DESENHAR BARRIL: 3 x 3 celulas
# Entrada: $s2=x, $s3=y; cor em $s6
# ------------------------------------------------
desenhar_barril:
    sll   $t0, $s3, 8
    addu  $t0, $t0, $s1
    sll   $t1, $s2, 2
    addu  $t0, $t0, $t1
    addiu $t2, $zero, 3

desenhar_linha_barril:
    addu  $t3, $t0, $zero
    addiu $t4, $zero, 3

desenhar_coluna_barril:
    sw    $s6, 0($t3)
    addiu $t3, $t3, 4
    addiu $t4, $t4, -1
    bne   $t4, $zero, desenhar_coluna_barril
    nop
    addiu $t0, $t0, 256
    addiu $t2, $t2, -1
    bne   $t2, $zero, desenhar_linha_barril
    nop
    jr    $ra
    nop

# ------------------------------------------------
# RESTAURAR CENARIO SOB O BARRIL
# ------------------------------------------------
restaurar_barril:
    sll   $t0, $s3, 12
    addu  $t0, $t0, $s0
    sll   $t1, $s2, 4
    addu  $t0, $t0, $t1

    sll   $t1, $s3, 8
    addu  $t1, $t1, $s1
    sll   $t2, $s2, 2
    addu  $t1, $t1, $t2

    addiu $t2, $zero, 3
restaurar_linha:
    addu  $t3, $t0, $zero
    addu  $t4, $t1, $zero
    addiu $t5, $zero, 3
restaurar_coluna:
    lw    $t6, 0($t3)
    sw    $t6, 0($t4)
    addiu $t3, $t3, 16
    addiu $t4, $t4, 4
    addiu $t5, $t5, -1
    bne   $t5, $zero, restaurar_coluna
    nop
    addiu $t0, $t0, 4096
    addiu $t1, $t1, 256
    addiu $t2, $t2, -1
    bne   $t2, $zero, restaurar_linha
    nop
    jr    $ra
    nop

# Reinicia quando x=10 e y>=107.
verificar_reinicio:
    addu  $v0, $zero, $zero
    addiu $t0, $zero, 107
    slt   $t1, $s3, $t0
    bne   $t1, $zero, fim_verificar_reinicio
    nop
    addiu $t0, $zero, 10
    bne   $s2, $t0, fim_verificar_reinicio
    nop
    addiu $v0, $zero, 1
fim_verificar_reinicio:
    jr    $ra
    nop

# Conta os apoios vermelhos na linha imediatamente abaixo do barril.
contar_apoio:
    addiu $t0, $s3, 3
    sll   $t0, $t0, 12
    addu  $t0, $t0, $s0
    sll   $t1, $s2, 4
    addu  $t0, $t0, $t1

    lui   $t2, 0x0092
    ori   $t2, $t2, 0x0D28
    addu  $v0, $zero, $zero
    addiu $t4, $zero, 3
verificar_bloco_apoio:
    lw    $t5, 0($t0)
    bne   $t5, $t2, proximo_bloco_apoio
    nop
    addiu $v0, $v0, 1
proximo_bloco_apoio:
    addiu $t0, $t0, 16
    addiu $t4, $t4, -1
    bne   $t4, $zero, verificar_bloco_apoio
    nop
    jr    $ra
    nop
