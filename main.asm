
.text
.globl main

main:
    # Base da imagem original do cenario
    lui   $s0, 0x1001

    # Base do Bitmap Display
    lui   $s1, 0x1000
    ori   $s1, $s1, 0x8000

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

    # Posicao inicial do barril
    addiu $s2, $zero, 10      # x
    addiu $s3, $zero, 49      # y
    addiu $s4, $zero, 1       # direcao: 1 = direita
    addiu $s5, $zero, 0       # movimento ainda nao iniciado

    # Cor laranja: 0x00FF8000
    lui   $s6, 0x00FF
    ori   $s6, $s6, 0x8000

    # Desenha o barril inicial
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

    # ESPACO pressionado: iniciar movimento
    addiu $s5, $zero, 1

loop_movimento:
    # Restaura o fundo onde o barril estava
    jal   restaurar_barril
    nop

    # Inverte a direcao nos limites
    addiu $t0, $zero, 40
    slt   $t1, $t0, $s2
    beq   $t1, $zero, verificar_limite_esquerdo
    nop

    addiu $s4, $zero, -1

verificar_limite_esquerdo:
    addiu $t0, $zero, 10
    slt   $t1, $s2, $t0
    beq   $t1, $zero, atualizar_posicao
    nop

    addiu $s4, $zero, 1

atualizar_posicao:
    # Avanca horizontalmente
    addu  $s2, $s2, $s4

    # Verifica quantos blocos dos pes possuem apoio
    jal   contar_apoio
    nop

    # Com 2 ou 3 blocos apoiados, continua no nivel
    addiu $t0, $zero, 2
    slt   $t1, $v0, $t0
    beq   $t1, $zero, desenhar_posicao_atual
    nop

queda_barril:
    # Desce uma linha por movimento de queda
    addiu $s3, $s3, 1

    # Evita que o barril ultrapasse a tela
    addiu $t0, $zero, 124
    slt   $t1, $t0, $s3
    bne   $t1, $zero, reiniciar_altura
    nop

    # Verifica o apoio na nova altura
    jal   contar_apoio
    nop

    # Continua caindo enquanto houver menos de 2 apoios
    addiu $t0, $zero, 2
    slt   $t1, $v0, $t0
    bne   $t1, $zero, queda_barril
    nop

    j     desenhar_posicao_atual
    nop

reiniciar_altura:
    addiu $s3, $zero, 124

desenhar_posicao_atual:
    jal   desenhar_barril
    nop

    # Aguarda antes do proximo movimento
    addiu $v0, $zero, 32
    addiu $a0, $zero, 120
    syscall

    j     loop_movimento
    nop

# ------------------------------------------------
# DESENHAR BARRIL: 3 x 3 celulas
# Entrada: $s2 = x, $s3 = y
# Cor: $s6
# ------------------------------------------------
desenhar_barril:
    # Endereco = base + y*256 + x*4
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
# Repõe as 9 celulas usando a imagem original.
# ------------------------------------------------
restaurar_barril:
    # Origem = base imagem + y*4096 + x*16
    sll   $t0, $s3, 12
    addu  $t0, $t0, $s0
    sll   $t1, $s2, 4
    addu  $t0, $t0, $t1

    # Destino = base tela + y*256 + x*4
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

    # Proxima linha da imagem e da tela
    addiu $t0, $t0, 4096
    addiu $t1, $t1, 256
    addiu $t2, $t2, -1
    bne   $t2, $zero, restaurar_linha
    nop

    jr    $ra
    nop

# ------------------------------------------------
# CONTAR APOIOS SOB O BARRIL
# Retorna em $v0 quantos dos 3 blocos tem apoio.
# ------------------------------------------------
contar_apoio:
    # Linha da imagem original correspondente
    # a celula imediatamente abaixo do barril
    addiu $t0, $s3, 3
    sll   $t0, $t0, 12
    addu  $t0, $t0, $s0

    # Coluna inicial
    sll   $t1, $s2, 4
    addu  $t0, $t0, $t1

    # Cor da plataforma: 0x00920D28
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
