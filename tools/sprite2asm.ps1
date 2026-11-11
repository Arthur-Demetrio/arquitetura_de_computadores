<#
  sprite2asm.ps1 - converte uma imagem (png/jpg/bmp) em dados .word para o MARS.

  - Remove a borda de fundo (branco) automaticamente (auto-crop).
  - Reduz a imagem para LARGURA x ALTURA unidades do Bitmap Display,
    calculando a cor media de cada bloco.
  - Pixels de fundo viram TRANSPARENTE (0xFFFFFFFF), que a rotina de
    desenho em assembly ignora (o cenario aparece por tras).

  Uso (PowerShell, na raiz do projeto):
    powershell -ExecutionPolicy Bypass -File tools\sprite2asm.ps1 `
        -Imagem sprites\npc_barrel_1.jpeg -Rotulo sprite_barril `
        -Largura 5 -Altura 5 -Saida sprite_barril.asm

  O arquivo de saida deve ficar na MESMA pasta do main.asm (raiz do repo), pois o MARS
  (opcao "Assemble all files in directory") so monta os .asm dessa pasta.
#>
param(
    [Parameter(Mandatory = $true)] [string] $Imagem,
    [Parameter(Mandatory = $true)] [string] $Rotulo,
    [int] $Largura = 5,
    [int] $Altura = 5,
    [string] $Saida = "",
    # Um pixel e "fundo" quando R, G e B sao todos >= LimiarFundo (branco).
    [int] $LimiarFundo = 200,
    # Fracao minima de pixels nao-fundo para que o bloco seja opaco.
    [double] $Cobertura = 0.5,
    # Mostra so a previa em ASCII, sem gerar arquivo.
    [switch] $Previa
)

Add-Type -AssemblyName System.Drawing
$caminho = (Resolve-Path $Imagem).Path
$bmp = [System.Drawing.Bitmap]::FromFile($caminho)

function EhFundo($c) { return ($c.R -ge $LimiarFundo -and $c.G -ge $LimiarFundo -and $c.B -ge $LimiarFundo) }

# --- auto-crop: menor retangulo com pixels que nao sao fundo ---
$minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        if (-not (EhFundo $bmp.GetPixel($x, $y))) {
            if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
if ($maxX -lt 0) { throw "A imagem parece ser toda fundo." }
$cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1

$TRANSP = "0xFFFFFFFF"
$palavras = @(); $previaLinhas = @()
for ($ty = 0; $ty -lt $Altura; $ty++) {
    $linha = ""
    for ($tx = 0; $tx -lt $Largura; $tx++) {
        $x0 = $minX + [math]::Floor($tx * $cw / $Largura); $x1 = $minX + [math]::Floor(($tx + 1) * $cw / $Largura)
        $y0 = $minY + [math]::Floor($ty * $ch / $Altura);  $y1 = $minY + [math]::Floor(($ty + 1) * $ch / $Altura)
        if ($x1 -le $x0) { $x1 = $x0 + 1 }; if ($y1 -le $y0) { $y1 = $y0 + 1 }
        $r = 0; $g = 0; $b = 0; $n = 0; $total = 0
        for ($y = $y0; $y -lt $y1; $y++) {
            for ($x = $x0; $x -lt $x1; $x++) {
                $total++
                $c = $bmp.GetPixel($x, $y)
                if (-not (EhFundo $c)) { $r += $c.R; $g += $c.G; $b += $c.B; $n++ }
            }
        }
        if ($n -lt $total * $Cobertura) {
            $palavras += $TRANSP; $linha += " ."
        } else {
            $r = [int]($r / $n); $g = [int]($g / $n); $b = [int]($b / $n)
            $palavras += ("0x00{0:X2}{1:X2}{2:X2}" -f $r, $g, $b)
            $linha += if ($b -gt $r + 40) { " B" } else { " o" }
        }
    }
    $previaLinhas += $linha
}
$bmp.Dispose()

Write-Host "Previa ${Largura}x${Altura} (. = transparente):"
$previaLinhas | ForEach-Object { Write-Host $_ }
if ($Previa) { return }

if ($Saida -eq "") { $Saida = "$Rotulo.asm" }
$out = New-Object System.Collections.Generic.List[string]
$out.Add("# Sprite gerado por tools/sprite2asm.ps1")
$out.Add("# Origem: $(Split-Path $caminho -Leaf)  ->  ${Largura} x ${Altura} unidades")
$out.Add("# 0xFFFFFFFF = transparente (nao e desenhado)")
$out.Add(".data")
$out.Add(".globl $Rotulo")
$out.Add("${Rotulo}:")
for ($ty = 0; $ty -lt $Altura; $ty++) {
    $out.Add("    .word " + (($palavras[($ty * $Largura)..(($ty + 1) * $Largura - 1)]) -join ", "))
}
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $Saida), $out)
Write-Host "Gerado: $Saida"
