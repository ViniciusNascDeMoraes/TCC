# Vacina

Jogo 2D do TCC em duas versões independentes, uma em cada pasta:

| Pasta | Versão | Tecnologia |
|---|---|---|
| [`java/`](java/) | Original | Java 27, AWT/Swing |
| [`odin/`](odin/) | Port fiel da versão Java | Odin + raylib (o que vem com o Odin) |

As duas versões têm a mesma jogabilidade, as mesmas fases, telas e sons, em
português e em inglês: a opção "Idioma: Português" / "Language: English" do menu
inicial troca o idioma na hora (o jogo sempre abre em português).

## Controles

- `W` / `S`: navegar nos menus
- `Enter`: selecionar (na opção de idioma, alterna entre português e inglês)
- `Esc`: pausar e despausar / voltar dos créditos
- `Enter` ou `Esc` na tela final: voltar ao menu inicial
- `W` `A` `S` `D`: mover o personagem

## Versão Java

Requer um JDK 27 no `PATH`. Na pasta `java/`:

```sh
cd java
javac -cp "src;res" -d bin src\Main\Game.java
java -cp "bin;res" Main.Game
```

No Linux/macOS, troque `;` por `:` e `\` por `/`. Também dá para abrir a raiz do
repositório no IntelliJ IDEA.

## Versão Odin

Requer o [Odin](https://odin-lang.org/docs/install/) dev-2026-11a ou mais novo.
Janela, teclado, som, PNG e o desenho das fontes vêm do raylib que acompanha o
compilador (`vendor:raylib`), então nada é baixado. Na pasta `odin/`:

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

O texto usa a fonte "Bookman Old Style" se ela estiver instalada (vem com o
Microsoft Office), na pasta de fontes do sistema ou do usuário. Sem ela, usa o
clone livre URW Bookman no Linux (pacote `fonts-urw-base35`) e, se também não
houver, Arial/DejaVu Sans/Liberation Sans em negrito, como o Java faria. Sem
nenhuma dessas, usa a fonte bitmap do raylib, ampliada. As larguras do texto (e o
centro dos menus) vêm das métricas da fonte, como no Java.

Limitações conhecidas da versão Odin:

- Foi testada só no Linux. O raylib do Odin também existe para Windows e macOS,
  mas o jogo não foi testado neles.
