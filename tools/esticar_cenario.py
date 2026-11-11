"""
esticar_cenario.py - gera um cenario.asm com mais espaco entre os andares.

Le o cenario original (imagem 256x512, uma .word por pixel) e:
  1. reduz para 64x128 (1 .word por unidade do Bitmap Display 4x4),
     pegando 1 pixel a cada 4, igual ao main.asm antigo fazia;
  2. sobe o titulo (descarta as estrelas que ficariam por baixo dos andares);
  3. insere EXTRA linhas no topo de cada vao entre andares. Colunas com escada
     ou poste continuam desenhadas (o padrao de 2 linhas e repetido), o resto
     fica preto.

Uso (na raiz do projeto):
    python tools/esticar_cenario.py cenario_original.asm cenario.asm
"""
import re
import sys

ORIG_L, ORIG_A = 256, 512      # tamanho da imagem original
L, A = 64, 128                 # unidades do Bitmap Display
VERMELHO = 0x920D28            # cor dos andares
EXTRA = 6                      # linhas inseridas em cada vao (numero par!)
TOPO_ORIGEM = 8                # linha original que vira a linha 0 (titulo)
TOPO_LINHAS = 20               # linhas 0..19 = titulo/estrelas
BLOCO_INI, BLOCO_FIM = 43, 112  # linhas originais da estrutura dos andares


def ler(caminho):
    palavras = []
    with open(caminho) as f:
        for linha in f:
            if ".word" in linha:
                palavras += [int(p, 16) for p in re.findall(r"0x[0-9A-Fa-f]+", linha)]
    assert len(palavras) == ORIG_L * ORIG_A, len(palavras)
    return [[palavras[(y * 4) * ORIG_L + x * 4] for x in range(L)] for y in range(A)]


def esticar(g):
    saida = [list(g[TOPO_ORIGEM + y]) for y in range(TOPO_LINHAS)]

    sem_vermelho = [all(c != VERMELHO for c in g[y]) for y in range(A)]
    y = BLOCO_INI
    while y <= BLOCO_FIM:
        # inicio de um vao: linha sem vermelho logo abaixo de uma com vermelho
        if sem_vermelho[y] and not sem_vermelho[y - 1]:
            fim = y
            while sem_vermelho[fim + 1]:
                fim += 1
            vao = g[y:fim + 1]
            # colunas "continuas" (escadas/postes): preenchidas em >= metade do vao
            continuas = [x for x in range(L)
                         if sum(1 for r in vao if r[x] != 0) * 2 >= len(vao)]
            for i in range(EXTRA):
                modelo = g[y + (i % 2)]
                saida.append([modelo[x] if x in continuas else 0 for x in range(L)])
        saida.append(list(g[y]))
        y += 1

    while len(saida) < A:
        saida.append([0] * L)
    assert len(saida) == A, f"cenario ficou com {len(saida)} linhas"
    return saida


def escrever(g, caminho):
    with open(caminho, "w", newline="\n") as f:
        f.write("# Cenario 64 x 128 (1 .word por unidade do Bitmap Display 4x4)\n")
        f.write("# Gerado por tools/esticar_cenario.py\n")
        f.write(".data\n.globl imagem\nimagem:\n")
        for linha in g:
            for i in range(0, L, 8):
                f.write("    .word " + ", ".join(f"0x{c:08X}" for c in linha[i:i + 8]) + "\n")


def mapa(g):
    simb = {0: ".", VERMELHO: "#", 0x1843E4: "=", 0xFFD700: "*", 0xF7F7F7: "x",
            0x5D7BEC: "L", 0xD2691E: "o"}
    for y, linha in enumerate(g):
        print(f"{y:3d} " + "".join(simb.get(c, "?") for c in linha))


if __name__ == "__main__":
    novo = esticar(ler(sys.argv[1]))
    escrever(novo, sys.argv[2])
    if "--mapa" in sys.argv:
        mapa(novo)
