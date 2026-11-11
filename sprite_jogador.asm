# Sprite do personagem principal: 4 x 6 unidades (desenhado a mao).
# Para usar uma imagem, gere este arquivo com tools/sprite2asm.ps1:
#   -Rotulo sprite_jogador -Largura 4 -Altura 6 -Saida sprite_jogador.asm
# 0xFFFFFFFF = transparente (nao e desenhado)
.data
.globl sprite_jogador
sprite_jogador:
    .word 0xFFFFFFFF, 0x00E02020, 0x00E02020, 0xFFFFFFFF   # bone
    .word 0xFFFFFFFF, 0x00F8C890, 0x00F8C890, 0xFFFFFFFF   # rosto
    .word 0x00E02020, 0x00E02020, 0x00E02020, 0x00E02020   # camisa
    .word 0x00F8C890, 0x0030B030, 0x0030B030, 0x00F8C890   # maos + macacao
    .word 0xFFFFFFFF, 0x0030B030, 0x0030B030, 0xFFFFFFFF   # macacao
    .word 0x00804000, 0xFFFFFFFF, 0xFFFFFFFF, 0x00804000   # sapatos
