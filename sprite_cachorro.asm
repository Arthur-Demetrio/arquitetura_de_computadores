# Sprite do Caco: cachorro caramelo sentado, coleira azul, olhando
# para a esquerda (lado de onde o jogador chega). 6 x 6 unidades.
# 0xFFFFFFFF = transparente (nao e desenhado)
.data
.globl sprite_cachorro
sprite_cachorro:
    .word 0xFFFFFFFF, 0x00A0602A, 0xFFFFFFFF, 0x00A0602A, 0xFFFFFFFF, 0xFFFFFFFF   # orelhas
    .word 0xFFFFFFFF, 0x00D2914B, 0x00D2914B, 0x00D2914B, 0xFFFFFFFF, 0xFFFFFFFF   # cabeca
    .word 0x00201008, 0x00D2914B, 0x00201008, 0x00D2914B, 0xFFFFFFFF, 0xFFFFFFFF   # focinho e olho
    .word 0xFFFFFFFF, 0x002060FF, 0x002060FF, 0x002060FF, 0xFFFFFFFF, 0x00D2914B   # coleira + rabo
    .word 0xFFFFFFFF, 0x00D2914B, 0x00F0D0A0, 0x00D2914B, 0x00D2914B, 0x00D2914B   # corpo (peito claro)
    .word 0xFFFFFFFF, 0x00D2914B, 0xFFFFFFFF, 0x00D2914B, 0x00D2914B, 0xFFFFFFFF   # patas sentado
