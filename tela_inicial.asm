# =====================================================================
# Tela inicial do Save Caco
# tela_inicial: desenha o titulo no Bitmap Display e espera o ESPACO
# (com "APERTE ESPACO" piscando). Usa $s1 = endereco do display.
#
# Rotinas de desenho que podem ser reaproveitadas:
#   pintar_retangulo      ($a0 x, $a1 y, $a2 largura, $a3 altura, $v1 cor)
#   desenhar_texto        ($a0 string, $a1 x, $a2 y, $a3 escala, $v1 cor)
#                          so letras A..Z maiusculas e espaco
#   desenhar_sprite_escala($a0 sprite, $a1 x, $a2 y,
#                          $a3 = escala<<16 | largura<<8 | altura)
# =====================================================================

.eqv TI_PISCAR_MS 400          # tempo entre piscadas do "APERTE ESPACO"
.eqv TI_AMARELO   0x00FFD700
.eqv TI_CARAMELO  0x00D2914B
.eqv TI_BRANCO    0x00FFFFFF
.eqv TI_CINZA     0x00A0A0A0
.eqv TI_VERMELHO  0x00920D28

.data
# Fonte 3x5: cada letra em 15 bits (linha de cima primeiro, bit 14 =
# canto superior esquerdo). Gerada a partir dos desenhos nos comentarios.
ti_fonte:
    .word 0x2BED   # A  .#. #.# ### #.# #.#
    .word 0x6BAE   # B  ##. #.# ##. #.# ##.
    .word 0x3923   # C  .## #.. #.. #.. .##
    .word 0x6B6E   # D  ##. #.# #.# #.# ##.
    .word 0x79A7   # E  ### #.. ##. #.. ###
    .word 0x79A4   # F  ### #.. ##. #.. #..
    .word 0x396B   # G  .## #.. #.# #.# .##
    .word 0x5BED   # H  #.# #.# ### #.# #.#
    .word 0x7497   # I  ### .#. .#. .#. ###
    .word 0x126A   # J  ..# ..# ..# #.# .#.
    .word 0x5BAD   # K  #.# #.# ##. #.# #.#
    .word 0x4927   # L  #.. #.. #.. #.. ###
    .word 0x5FED   # M  #.# ### ### #.# #.#
    .word 0x6B6D   # N  ##. #.# #.# #.# #.#
    .word 0x2B6A   # O  .#. #.# #.# #.# .#.
    .word 0x6BA4   # P  ##. #.# ##. #.. #..
    .word 0x2B73   # Q  .#. #.# #.# ##. .##
    .word 0x6BAD   # R  ##. #.# ##. #.# #.#
    .word 0x388E   # S  .## #.. .#. ..# ##.
    .word 0x7492   # T  ### .#. .#. .#. .#.
    .word 0x5B6F   # U  #.# #.# #.# #.# ###
    .word 0x5B6A   # V  #.# #.# #.# #.# .#.
    .word 0x5BFD   # W  #.# #.# ### ### #.#
    .word 0x5AAD   # X  #.# #.# .#. #.# #.#
    .word 0x5A92   # Y  #.# #.# .#. .#. .#.
    .word 0x72A7   # Z  ### ..# .#. #.. ###

ti_txt_save:   .asciiz "SAVE"
ti_txt_caco:   .asciiz "CACO"
ti_txt_aperte: .asciiz "APERTE"
ti_txt_espaco: .asciiz "ESPACO"
ti_txt_dica:   .asciiz "PULE OS BARRIS"

.text
.globl tela_inicial
.globl pintar_retangulo
.globl desenhar_texto
.globl desenhar_sprite_escala

# ---------------------------------------------------------------------
# tela_inicial: desenha a tela de titulo e volta quando o ESPACO e
# apertado.
# ---------------------------------------------------------------------
tela_inicial:
    addiu $sp, $sp, -12
    sw    $ra, 8($sp)
    sw    $s2, 4($sp)
    sw    $s3, 0($sp)

    # Fundo preto.
    addu  $t0, $s1, $zero
    addiu $t1, $zero, 8192
ti_limpar:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bne   $t1, $zero, ti_limpar

    # Titulo em letras grandes (escala 3: cada letra 9 x 15).
    la    $a0, ti_txt_save
    addiu $a1, $zero, 10
    addiu $a2, $zero, 8
    addiu $a3, $zero, 3
    li    $v1, TI_AMARELO
    jal   desenhar_texto
    la    $a0, ti_txt_caco
    addiu $a1, $zero, 10
    addiu $a2, $zero, 27
    addiu $a3, $zero, 3
    li    $v1, TI_CARAMELO
    jal   desenhar_texto

    # Cena: jogador, Caco e um barril em cima de um pedaco de chao.
    addiu $a0, $zero, 4
    addiu $a1, $zero, 72
    addiu $a2, $zero, 56
    addiu $a3, $zero, 2
    li    $v1, TI_VERMELHO
    jal   pintar_retangulo
    la    $a0, sprite_jogador      # escala 2, 4 x 6
    addiu $a1, $zero, 8
    addiu $a2, $zero, 60
    li    $a3, 0x00020406
    jal   desenhar_sprite_escala
    la    $a0, sprite_cachorro     # escala 3, 6 x 6
    addiu $a1, $zero, 23
    addiu $a2, $zero, 54
    li    $a3, 0x00030606
    jal   desenhar_sprite_escala
    la    $a0, sprite_barril       # escala 2, 5 x 5
    addiu $a1, $zero, 46
    addiu $a2, $zero, 62
    li    $a3, 0x00020505
    jal   desenhar_sprite_escala

    # Dica pequena no rodape.
    la    $a0, ti_txt_dica
    addiu $a1, $zero, 4
    addiu $a2, $zero, 118
    addiu $a3, $zero, 1
    li    $v1, TI_CINZA
    jal   desenhar_texto

    # "APERTE ESPACO" piscando ate o ESPACO ser apertado.
    addiu $s2, $zero, 1            # 1 = texto visivel
ti_piscar:
    li    $v1, TI_BRANCO
    bne   $s2, $zero, ti_cor_ok
    addu  $v1, $zero, $zero        # "apaga" pintando de preto
ti_cor_ok:
    la    $a0, ti_txt_aperte
    addiu $a1, $zero, 9
    addiu $a2, $zero, 86
    addiu $a3, $zero, 2
    jal   desenhar_texto
    la    $a0, ti_txt_espaco
    addiu $a1, $zero, 9
    addiu $a2, $zero, 99
    addiu $a3, $zero, 2
    jal   desenhar_texto

    addiu $v0, $zero, 30           # inicio da espera (ms)
    syscall
    addu  $s3, $a0, $zero
ti_esperar:
    lui   $t0, 0xFFFF              # tecla apertada?
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beq   $t1, $zero, ti_relogio
    lw    $t1, 4($t0)
    addiu $t2, $zero, 32
    beq   $t1, $t2, ti_fim         # ESPACO: comeca o jogo
ti_relogio:
    addiu $v0, $zero, 30
    syscall
    subu  $t1, $a0, $s3
    slti  $t1, $t1, TI_PISCAR_MS
    bne   $t1, $zero, ti_esperar
    xori  $s2, $s2, 1              # alterna visivel/apagado
    j     ti_piscar

ti_fim:
    lw    $s3, 0($sp)
    lw    $s2, 4($sp)
    lw    $ra, 8($sp)
    addiu $sp, $sp, 12
    jr    $ra

# ---------------------------------------------------------------------
# pintar_retangulo($a0 x, $a1 y, $a2 largura, $a3 altura, $v1 cor)
# Usa somente $t0..$t4.
# ---------------------------------------------------------------------
pintar_retangulo:
    addu  $t0, $a1, $zero          # y atual
    addu  $t1, $a1, $a3            # y final
pr_linha:
    slt   $t2, $t0, $t1
    beq   $t2, $zero, pr_fim
    sll   $t3, $t0, 6              # endereco = display + (y*64 + x)*4
    addu  $t3, $t3, $a0
    sll   $t3, $t3, 2
    addu  $t3, $t3, $s1
    addu  $t4, $a2, $zero          # colunas restantes
pr_coluna:
    sw    $v1, 0($t3)
    addiu $t3, $t3, 4
    addiu $t4, $t4, -1
    bne   $t4, $zero, pr_coluna
    addiu $t0, $t0, 1
    j     pr_linha
pr_fim:
    jr    $ra

# ---------------------------------------------------------------------
# desenhar_texto($a0 string, $a1 x, $a2 y, $a3 escala, $v1 cor)
# Cada letra ocupa 3 x 5 blocos de escala x escala, com 1 bloco de
# espaco entre letras.
# ---------------------------------------------------------------------
desenhar_texto:
    addiu $sp, $sp, -28
    sw    $ra, 24($sp)
    sw    $s2, 20($sp)
    sw    $s3, 16($sp)
    sw    $s4, 12($sp)
    sw    $s5, 8($sp)
    sw    $s6, 4($sp)
    sw    $s7, 0($sp)
    addu  $s2, $a0, $zero          # ponteiro na string
    addu  $s3, $a1, $zero          # x da letra atual
    addu  $s4, $a2, $zero          # y
    addu  $s5, $a3, $zero          # escala
dt_letra:
    lbu   $t0, 0($s2)
    beq   $t0, $zero, dt_fim
    addiu $t1, $zero, 32
    beq   $t0, $t1, dt_avancar     # espaco
    addiu $t0, $t0, -65            # 'A' = 0
    sll   $t0, $t0, 2
    lw    $s6, ti_fonte($t0)       # desenho da letra
    addu  $s7, $zero, $zero        # bit 0..14
dt_bit:
    addiu $t0, $zero, 14
    subu  $t0, $t0, $s7
    srlv  $t1, $s6, $t0
    andi  $t1, $t1, 1
    beq   $t1, $zero, dt_proximo_bit
    addiu $t2, $zero, 3            # linha = bit / 3, coluna = bit % 3
    div   $s7, $t2
    mflo  $t3
    mfhi  $t4
    mul   $t3, $t3, $s5
    mul   $t4, $t4, $s5
    addu  $a0, $s3, $t4
    addu  $a1, $s4, $t3
    addu  $a2, $s5, $zero
    addu  $a3, $s5, $zero
    jal   pintar_retangulo
dt_proximo_bit:
    addiu $s7, $s7, 1
    slti  $t0, $s7, 15
    bne   $t0, $zero, dt_bit
dt_avancar:
    sll   $t0, $s5, 2              # proxima letra: 4 * escala
    addu  $s3, $s3, $t0
    addiu $s2, $s2, 1
    j     dt_letra
dt_fim:
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
# desenhar_sprite_escala($a0 sprite, $a1 x, $a2 y,
#                        $a3 = escala<<16 | largura<<8 | altura)
# Desenha os pixels opacos do sprite ampliados (0xFFFFFFFF = transparente).
# ---------------------------------------------------------------------
desenhar_sprite_escala:
    addiu $sp, $sp, -36
    sw    $ra, 32($sp)
    sw    $s2, 28($sp)
    sw    $s3, 24($sp)
    sw    $s4, 20($sp)
    sw    $s5, 16($sp)
    sw    $s6, 12($sp)
    sw    $s7, 8($sp)
    addu  $s2, $a0, $zero          # sprite
    addu  $s3, $a1, $zero          # x
    addu  $s4, $a2, $zero          # y
    srl   $s5, $a3, 16             # escala
    andi  $s5, $s5, 0xFF
    srl   $s6, $a3, 8              # largura
    andi  $s6, $s6, 0xFF
    andi  $s7, $a3, 0xFF           # altura
    mul   $t0, $s6, $s7
    sw    $t0, 0($sp)              # total de pixels
    sw    $zero, 4($sp)            # pixel atual
ds_pixel:
    lw    $t0, 4($sp)
    lw    $t1, 0($sp)
    slt   $t2, $t0, $t1
    beq   $t2, $zero, ds_fim
    sll   $t2, $t0, 2
    addu  $t2, $t2, $s2
    lw    $v1, 0($t2)              # cor do pixel
    addiu $t3, $zero, -1
    beq   $v1, $t3, ds_proximo     # transparente
    div   $t0, $s6                 # linha = i / largura, coluna = i % largura
    mflo  $t4
    mfhi  $t5
    mul   $t4, $t4, $s5
    mul   $t5, $t5, $s5
    addu  $a0, $s3, $t5
    addu  $a1, $s4, $t4
    addu  $a2, $s5, $zero
    addu  $a3, $s5, $zero
    jal   pintar_retangulo
ds_proximo:
    lw    $t0, 4($sp)
    addiu $t0, $t0, 1
    sw    $t0, 4($sp)
    j     ds_pixel
ds_fim:
    lw    $s7, 8($sp)
    lw    $s6, 12($sp)
    lw    $s5, 16($sp)
    lw    $s4, 20($sp)
    lw    $s3, 24($sp)
    lw    $s2, 28($sp)
    lw    $ra, 32($sp)
    addiu $sp, $sp, 36
    jr    $ra
