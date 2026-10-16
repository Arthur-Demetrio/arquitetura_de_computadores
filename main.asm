.text

main:
    lui   $16, 0x1001

    lui   $17, 0x1000
    ori   $17, $17, 0x8000

    addiu $18, $0, 128

linha:
    addu  $8, $16, $0
    addiu $9, $0, 64

pixel:
    lw    $10, 0($8)
    sw    $10, 0($17)
    addiu $8, $8, 16
    addiu $17, $17, 4
    addiu $9, $9, -1
    bne   $9, $0, pixel
    addiu $16, $16, 4096
    addiu $18, $18, -1
    bne   $18, $0, linha
    
fim:
    j     fim