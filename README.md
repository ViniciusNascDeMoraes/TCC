# Vacina

Jogo 2D do TCC em três versões independentes, uma em cada pasta:

| Pasta | Versão | Tecnologia |
|---|---|---|
| [`java/`](java/) | Original | Java 25, AWT/Swing |
| [`zig/`](zig/) | Port fiel da versão Java | Zig 0.16 puro, sem dependências |
| [`odin/`](odin/) | Port fiel da versão Java | Odin + raylib (o que vem com o Odin) |

As três versões têm a mesma jogabilidade, as mesmas fases, telas e sons, em
português e em inglês: a opção "Idioma: Português" / "Language: English" do menu
inicial troca o idioma na hora (o jogo sempre abre em português).

## Controles

- `W` / `S`: navegar nos menus
- `Enter`: selecionar (na opção de idioma, alterna entre português e inglês)
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

Requer o [Zig 0.16](https://ziglang.org/download/) e roda no Linux (X11 ou
XWayland) e no Windows. Na pasta `zig/`:

```sh
cd zig
zig build run
```

O build não baixa nada: janela, teclado, áudio, imagens, fontes e desenho são
feitos em Zig, sem bibliotecas. Outros comandos:

- `zig build -Doptimize=ReleaseFast`: executável otimizado em `zig-out/bin/`
  (no Windows ele abre sem a janela de console; o build de Debug mantém o console com o FPS)
- `zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast`: gera o `.exe` do Windows a partir de qualquer sistema
- `zig build test`: testes da lógica do jogo

As imagens e sons ficam embutidos no executável, então ele roda de qualquer pasta.
No Linux o executável é estático e conversa direto com o servidor X11 (ou o
XWayland) e com o PulseAudio/PipeWire pelos sockets deles; sem servidor de áudio
o jogo roda sem som. No Windows ele usa só as DLLs do próprio sistema.

O texto usa a fonte "Bookman Old Style" se ela estiver instalada (vem com o
Microsoft Office), na pasta de fontes do Windows ou do usuário. Sem ela, usa o clone livre URW Bookman no Linux (pacote
`fonts-urw-base35`) e, se também não houver, Arial/DejaVu Sans/Liberation Sans em negrito,
como o Java faria. Sem nenhuma dessas, usa uma fonte bitmap 8x8 embutida (font8x8, domínio público).

Limitações conhecidas da versão Zig:

- macOS não é suportado (era enquanto o jogo usava o raylib); lá só os testes compilam.
- No Linux o som sai pelo PulseAudio ou PipeWire. Sistemas só com ALSA ficam sem som, e
  `PULSE_SERVER` só aceita sockets Unix (não endereços TCP). Se o servidor de áudio
  reiniciar, o som volta sozinho em até 2 s.
- No X11 a tela precisa ter 24 bits de cor e cada quadro é enviado pelo socket
  (PutImage), sem memória compartilhada (MIT-SHM).

## Versão Odin

Requer o [Odin](https://odin-lang.org/docs/install/) dev-2026-11 ou mais novo
(testado com o dev-2026-11a). Janela, teclado, som, PNG e o desenho das fontes
vêm do raylib que acompanha o compilador (`vendor:raylib`), então nada é baixado.
Na pasta `odin/`:

```sh
cd odin
odin run vacina
```

Outros comandos:

- `odin build vacina -o:speed`: executável otimizado (`vacina.bin` no Linux, `vacina.exe` no Windows);
  no Windows, acrescente `-subsystem:windows` para ele abrir sem a janela de console
- `odin test tests`: testes da lógica do jogo

As imagens e sons ficam embutidos no executável (`#load`), então ele roda de
qualquer pasta. No Linux o link precisa da libX11 (pacote `libx11-dev` no
Debian/Ubuntu) e o jogo precisa de OpenGL 3.3 (Mesa serve); o som sai pelo que o
raylib encontrar (PulseAudio, PipeWire, ALSA...) e, sem dispositivo de áudio, o
jogo roda sem som. Se o Odin foi clonado do git em vez de baixado, as bibliotecas
do raylib vêm pelo Git LFS (`git lfs pull` na pasta do Odin).

O texto procura as mesmas fontes da versão Zig, na mesma ordem (Bookman Old Style,
URW Bookman, Arial/DejaVu Sans/Liberation Sans em negrito); sem nenhuma delas, usa
a fonte bitmap do raylib, ampliada. As larguras do texto (e o centro dos menus)
vêm das métricas da fonte, como no Java.

Limitações conhecidas da versão Odin:

- Foi testada só no Linux. O raylib do Odin também existe para Windows e macOS,
  mas o jogo não foi testado neles.
