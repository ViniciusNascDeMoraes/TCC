# Vacina

Jogo 2D do TCC em duas versões independentes, uma em cada pasta:

| Pasta | Versão | Tecnologia |
|---|---|---|
| [`java/`](java/) | Original | Java 25, AWT/Swing |
| [`zig/`](zig/) | Port fiel da versão Java | Zig 0.16 + raylib 6.0 |

As duas versões têm a mesma jogabilidade, as mesmas fases, telas e sons.

## Controles

- `W` / `S`: navegar nos menus
- `Enter`: selecionar
- `Esc`: pausar e despausar / voltar dos créditos
- `Enter` ou `Esc` na tela final: voltar ao menu inicial
- `W` `A` `S` `D`: mover o personagem

## Versão Java

Requer um JDK 25 no `PATH`. Na pasta `java/`:

```sh
cd java
javac -cp "src;res" -d bin src\Main\Game.java
java -cp "bin;res" Main.Game
```

No Linux/macOS, troque `;` por `:` e `\` por `/`. Também dá para abrir a raiz do
repositório no IntelliJ IDEA.

## Versão Zig

Requer o [Zig 0.16](https://ziglang.org/download/). Na pasta `zig/`:

```sh
cd zig
zig build run
```

O primeiro build baixa e compila o raylib automaticamente. Outros comandos:

- `zig build -Doptimize=ReleaseFast`: executável otimizado em `zig-out/bin/`
  (no Windows ele abre sem a janela de console; o build de Debug mantém o console com o FPS)
- `zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast`: gera o `.exe` do Windows a partir de qualquer sistema
- `zig build test`: testes da lógica do jogo

As imagens e sons ficam embutidos no executável, então ele roda de qualquer pasta.
No Linux são necessários os pacotes de desenvolvimento do X11/OpenGL
(`libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libgl-dev`).

O texto usa a fonte "Bookman Old Style" se ela estiver instalada (vem com o
Microsoft Office); sem ela, usa Arial/DejaVu Sans em negrito, como o Java faria.
