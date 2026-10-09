//! `Main.Game`: estado global do jogo, `tick`, `render` e tratamento de teclas.
//!
//! As condicoes seguem o Java ao pe da letra (inclusive a precedencia de
//! `a || b && c` e a ordem dos `else if`), para o jogo se comportar igual.
//! Os tres `Enemy*.state` do Java so sao lidos como "algum GAMEOVER" ou
//! "todos GAMENORMAL", entao viraram um unico `game_over`.

const std = @import("std");
const rl = @import("raylib");
const assets = @import("assets");
const gfx = @import("gfx.zig");
const Camera = @import("camera.zig").Camera;
const Enemy = @import("entities.zig").Enemy;
const Menu = @import("menu.zig").Menu;
const Player = @import("entities.zig").Player;
const Sounds = @import("sound.zig").Sounds;
const Spritesheet = @import("spritesheet.zig").Spritesheet;
const Text = @import("text.zig").Text;
const world_mod = @import("world.zig");
const World = world_mod.World;

const txtmenu1 = "Retornar ao jogo";
const txtmenu2 = "Sair do jogo";
const txtgo1 = "Reiniciar a fase";
const txtgo2 = "Sair do jogo";
const txt_missao_texto = "Chegue no hospital";
const txt_missao_texto1 = "para se vacinar!";
const txt_missao_texto3 = "Dica: Desvie das bactérias.";
const txt_missao_texto4 = "Vá para a área amarela";
const txt_missao_texto5 = "para se vacinar";
const txt_missao_texto6 = "Utilize seu escudo para ";
const txt_missao_texto7 = "eliminar todos os vírus e bactérias";
const txt_missao_texto8 = "Inimigos eliminados: ";
const txt_missao_texto9 = "Todos os inimigos foram eliminados,";
const txt_missao_texto10 = "volte para casa!";

/// Imagens de tela inteira (960x640).
pub const Screens = struct {
    menu: rl.Texture2D,
    creditos: rl.Texture2D,
    morreu: rl.Texture2D,
    imagem_fim: rl.Texture2D,
    tela_vacina: rl.Texture2D,
    vacinando: [4]rl.Texture2D,

    fn load() Screens {
        return .{
            .menu = gfx.loadTexture(assets.tela_menu),
            .creditos = gfx.loadTexture(assets.tela_creditos),
            .morreu = gfx.loadTexture(assets.game_over),
            .imagem_fim = gfx.loadTexture(assets.tela_fim),
            .tela_vacina = gfx.loadTexture(assets.tela_vacina),
            .vacinando = .{
                gfx.loadTexture(assets.vacinando),
                gfx.loadTexture(assets.vacinando1),
                gfx.loadTexture(assets.vacinando2),
                gfx.loadTexture(assets.vacinando3),
            },
        };
    }

    fn unload(self: Screens) void {
        for ([_]rl.Texture2D{ self.menu, self.creditos, self.morreu, self.imagem_fim, self.tela_vacina } ++ self.vacinando) |texture| {
            rl.UnloadTexture(texture);
        }
    }
};

/// Teclas que o jogo trata. O Enter do teclado numerico conta como Enter,
/// como o `KeyEvent.VK_ENTER` do Java.
const keys = [_]c_int{ rl.KEY_W, rl.KEY_A, rl.KEY_S, rl.KEY_D, rl.KEY_ENTER, rl.KEY_KP_ENTER, rl.KEY_ESCAPE };

fn keyIndex(key: c_int) ?usize {
    return std.mem.indexOfScalar(c_int, &keys, key);
}

fn normalizeKey(key: c_int) c_int {
    return if (key == rl.KEY_KP_ENTER) rl.KEY_ENTER else key;
}

pub const Game = struct {
    /// Resolucao interna do mundo; a janela e `scale` vezes maior.
    pub const width = 240;
    pub const height = 160;
    pub const scale = 4;
    pub const widthfm = width * scale;
    pub const heightfm = height * scale;

    gpa: std.mem.Allocator,

    spritesheet: Spritesheet,
    screens: Screens,
    /// O `BufferedImage image` 240x160 onde o mundo e desenhado.
    image: rl.RenderTexture2D,
    text: Text,
    sounds: Sounds,

    level: i32 = 1,
    contador: i32 = 0,
    /// Inimigos criados no mapa do nivel atual; no nivel 3 e preciso eliminar todos.
    total_inimigos: i32 = 0,
    pause: bool = false,
    dialogo: bool = false,
    vacinado: bool = false,
    fim: bool = false,
    /// Esc ainda segurado: a auto-repeticao da tecla nao alterna a pausa de novo.
    esc_pressionado: bool = false,
    game_over: bool = false,
    /// `Enemy.escudo`, `Enemy02.escudo` e `Enemy03.escudo`.
    escudo: [3]bool = @splat(true),
    /// Opcao do menu de pausa / game over: 0 = "op1", 1 = "op2".
    option_atual: i32 = 0,
    w: bool = false,
    s: bool = false,
    enter: bool = false,
    time: i32 = 0,
    volta: i32 = 0,
    /// `System.exit(0)` pedido pelo menu.
    quit: bool = false,

    camera: Camera = .{},
    menu: Menu = .{},
    player: Player,
    /// `Game.entities` sem o jogador (que no Java e sempre o indice 0).
    enemies: std.ArrayList(Enemy) = .empty,
    world: World,

    const option_max = 1;

    /// Requer a janela e o dispositivo de audio ja inicializados.
    pub fn init(self: *Game, gpa: std.mem.Allocator) !void {
        self.* = .{
            .gpa = gpa,
            .spritesheet = .load(),
            .screens = .load(),
            .image = rl.LoadRenderTexture(width, height),
            .text = .load(),
            .sounds = .load(),
            .player = .init(1),
            .world = undefined,
        };
        self.world = try World.load(self, assets.level1);
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit(self);
        self.enemies.deinit(self.gpa);
        self.sounds.unload();
        self.text.unload();
        rl.UnloadRenderTexture(self.image);
        self.screens.unload();
        self.spritesheet.unload();
    }

    fn normal(self: Game) bool {
        return !self.game_over;
    }

    fn restartGame(self: *Game) !void {
        try world_mod.restartGame(self);
    }

    /// Depois da tela final: zera o progresso do jogo e volta ao menu inicial.
    fn voltarAoMenu(self: *Game) !void {
        self.level = 1;
        self.contador = 0;
        self.pause = false;
        self.dialogo = false;
        self.vacinado = false;
        self.game_over = false;
        self.fim = false;
        self.time = 0;
        self.volta = 0;
        self.option_atual = 0;
        self.w = false;
        self.s = false;
        self.enter = false;
        self.escudo = @splat(true);
        self.menu = .{};
        try self.restartGame();
    }

    pub fn tick(self: *Game) !void {
        if (self.menu.state_inicio or self.menu.state_creditos and !self.pause and self.normal()) {
            self.menu.tick(self);
        } else if (self.menu.state_jogo and !self.pause and self.normal() and !self.dialogo and !self.fim) {
            self.player.tick(self);
            // Um inimigo eliminado sai da lista sem fazer o seguinte perder o tick.
            var i: usize = 0;
            while (i < self.enemies.items.len) {
                if (self.enemies.items[i].tick(self)) {
                    _ = self.enemies.orderedRemove(i);
                } else {
                    i += 1;
                }
            }

            if (self.player.getY() < 80 and self.level == 1) {
                self.level = 2;
                try self.restartGame();
            }

            if (self.vacinado) {
                self.level = 3;
                try self.restartGame();
                self.vacinado = false;
            }
        } else if (self.fim) {
            // Tela final: tudo parado ate Enter/Esc.
            if (self.enter) {
                self.sounds.play(.select);
                self.enter = false;
                try self.voltarAoMenu();
            }
        } else if (self.pause and self.normal()) {
            self.navigateOptions();

            if (self.enter) {
                self.sounds.play(.select);
                self.enter = false;

                if (self.option_atual == 1) {
                    self.quit = true;
                } else if (self.option_atual == 0) {
                    self.pause = false;
                    self.option_atual = 0;
                }
            }
        } else if (self.game_over) {
            self.navigateOptions();

            if (self.enter) {
                self.sounds.play(.select);
                self.enter = false;

                if (self.option_atual == 0) {
                    self.game_over = false;
                    try self.restartGame();
                } else if (self.option_atual == 1) {
                    self.quit = true;
                }
            }
        }
    }

    /// W/S nos menus de pausa e de game over.
    fn navigateOptions(self: *Game) void {
        if (self.w) {
            self.sounds.play(.menu);
            self.w = false;
            self.option_atual -= 1;
            if (self.option_atual < 0) self.option_atual = option_max;
        }

        if (self.s) {
            self.sounds.play(.menu);
            self.s = false;
            self.option_atual += 1;
            if (self.option_atual > option_max) self.option_atual = 0;
        }
    }

    pub fn render(self: *Game) void {
        // Mundo e entidades na imagem 240x160.
        rl.BeginTextureMode(self.image);
        rl.ClearBackground(gfx.black);
        if (self.menu.state_jogo and self.normal()) {
            self.world.render(self);
            self.player.render(self);
            for (self.enemies.items) |enemy| enemy.render(self);
        }
        rl.EndTextureMode();

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(gfx.black);

        // A textura de um RenderTexture fica de cabeca para baixo: altura negativa.
        const source: rl.Rectangle = .{ .x = 0, .y = 0, .width = width, .height = -height };
        const dest: rl.Rectangle = .{ .x = 0, .y = 0, .width = widthfm, .height = heightfm };
        rl.DrawTexturePro(self.image.texture, source, dest, .{ .x = 0, .y = 0 }, 0, gfx.white);

        self.renderScreens();
        self.renderMission();
    }

    /// Menus, game over, vacinacao e tela final, desenhados em 960x640.
    fn renderScreens(self: *Game) void {
        if (self.menu.state_inicio or self.menu.state_creditos or
            self.menu.state_loading and !self.menu.state_jogo and !self.pause)
        {
            self.menu.render(self);
        } else if (self.pause and self.normal()) {
            self.renderOptions(txtmenu1, txtmenu2, gfx.white);
        } else if (self.game_over) {
            gfx.drawScreen(self.screens.morreu);
            self.renderOptions(txtgo1, txtgo2, gfx.black);
        } else if (self.player.getY() < 20 and self.player.getX() > 93 and self.player.getX() < 98 and self.level == 2) {
            self.dialogo = true;
            gfx.fillScreen(gfx.blue);

            self.time += 1;
            if (self.volta < 3) {
                // Cada imagem fica 39 quadros; os quadros 40, 80, 120 e 160 ficam so azuis.
                if (self.time < 40) {
                    gfx.drawScreen(self.screens.vacinando[0]);
                } else if (self.time > 40 and self.time < 80) {
                    gfx.drawScreen(self.screens.vacinando[1]);
                } else if (self.time > 80 and self.time < 120) {
                    gfx.drawScreen(self.screens.vacinando[2]);
                } else if (self.time > 120 and self.time < 160) {
                    gfx.drawScreen(self.screens.vacinando[3]);
                } else if (self.time > 160) {
                    self.time = 0;
                    self.volta += 1;
                }
            } else if (self.volta >= 3 and self.volta < 5) {
                gfx.drawScreen(self.screens.tela_vacina);

                if (self.time > 100) {
                    self.volta += 1;
                    self.time = 0;
                }
            } else if (self.volta == 5) {
                self.dialogo = false;
                self.vacinado = true;
            }
        } else if (self.fim or
            self.player.getY() < 175 and self.player.getX() > 559 and self.player.getX() < 593 and self.level == 3 and self.contador >= self.total_inimigos)
        {
            self.fim = true;
            gfx.fillScreen(gfx.blue);
            gfx.drawScreen(self.screens.imagem_fim);
        }
    }

    /// As duas opcoes centralizadas dos menus de pausa e de game over.
    fn renderOptions(self: *Game, op1: [:0]const u8, op2: [:0]const u8, color: rl.Color) void {
        const cx = widthfm / 2;
        const cy = heightfm / 2;

        const tam1 = self.text.width(op1, .s30);
        self.text.draw(op1, .s30, cx - @divTrunc(tam1, 2), cy - 50, color);
        const tam2 = self.text.width(op2, .s30);
        self.text.draw(op2, .s30, cx - @divTrunc(tam2, 2), cy, color);

        if (self.option_atual == 0) {
            self.text.draw(">", .s30, cx - @divTrunc(tam1, 2) - 40, cy - 50, color);
        } else if (self.option_atual == 1) {
            self.text.draw(">", .s30, cx - @divTrunc(tam2, 2) - 40, cy, color);
        }
    }

    /// Textos de missao no canto superior esquerdo (desenhados por cima de tudo).
    fn renderMission(self: *Game) void {
        if (self.level == 1 and self.normal() and self.menu.state_jogo and self.player.getY() > 160) {
            self.text.draw(txt_missao_texto, .s23, 15, 30, gfx.white);
            self.text.draw(txt_missao_texto1, .s23, 15, 60, gfx.white);
            self.text.draw(txt_missao_texto3, .s23, 15, 100, gfx.white);
        } else if (self.level == 2 and self.normal() and self.menu.state_jogo and !self.vacinado and !self.dialogo) {
            self.text.draw(txt_missao_texto4, .s20, 15, 30, gfx.black);
            self.text.draw(txt_missao_texto5, .s20, 15, 60, gfx.black);
        } else if (self.level == 3 and self.normal() and self.menu.state_jogo and self.player.getY() > 160) {
            if (self.contador < self.total_inimigos) {
                self.text.draw(txt_missao_texto6, .s23, 15, 30, gfx.white);
                self.text.draw(txt_missao_texto7, .s23, 15, 60, gfx.white);
                self.text.draw(txt_missao_texto8, .s23, 15, 100, gfx.white);
                var buffer: [16]u8 = undefined;
                const contador = std.fmt.bufPrintZ(&buffer, "{d}", .{self.contador}) catch unreachable;
                self.text.draw(contador, .s23, 275, 101, gfx.white);
            }
            if (self.contador >= self.total_inimigos and !self.fim) {
                self.text.draw(txt_missao_texto9, .s20, 15, 30, gfx.white);
                self.text.draw(txt_missao_texto10, .s20, 15, 60, gfx.white);
            }
        }
    }

    /// Le o teclado do quadro e repassa para `keyPressed`/`keyReleased`,
    /// como os eventos do `KeyListener` do Java (incluindo a repeticao
    /// automatica de tecla segurada).
    pub fn handleInput(self: *Game) void {
        var pressed_now: [keys.len]bool = @splat(false);
        while (true) {
            const key = rl.GetKeyPressed();
            if (key == 0) break;
            const i = keyIndex(key) orelse continue;
            pressed_now[i] = true;
            self.keyPressed(normalizeKey(key));
        }

        for (keys, pressed_now) |key, pressed| {
            if (rl.IsKeyPressedRepeat(key)) self.keyPressed(normalizeKey(key));
            // Tecla apertada e solta no mesmo quadro tambem gera a soltura.
            if (rl.IsKeyReleased(key) or (pressed and !rl.IsKeyDown(key))) self.keyReleased(normalizeKey(key));
        }
    }

    pub fn keyPressed(self: *Game, key: c_int) void {
        const esc_repetido = key == rl.KEY_ESCAPE and self.esc_pressionado;
        if (key == rl.KEY_ESCAPE) self.esc_pressionado = true;

        if (self.menu.state_inicio and self.normal()) {
            if (key == rl.KEY_W) {
                self.menu.w = true;
            } else if (key == rl.KEY_S) {
                self.menu.s = true;
            }
            if (key == rl.KEY_ENTER and self.normal()) {
                self.menu.enter = true;
            }
        } else if (self.menu.state_creditos and self.normal()) {
            if (key == rl.KEY_ENTER or key == rl.KEY_ESCAPE) {
                self.menu.enter = true;
            }
        } else if (self.menu.state_jogo and self.normal() and !self.fim) {
            if (key == rl.KEY_W) {
                self.player.up = true;
            } else if (key == rl.KEY_S) {
                self.player.down = true;
            }

            if (key == rl.KEY_D) {
                self.player.right = true;
            } else if (key == rl.KEY_A) {
                self.player.left = true;
            }

            if (key == rl.KEY_ESCAPE and self.normal() and !esc_repetido) {
                if (self.pause) {
                    // Descarta W/S/Enter apertados no menu de pausa e ainda nao processados.
                    self.pause = false;
                    self.option_atual = 0;
                    self.w = false;
                    self.s = false;
                    self.enter = false;
                } else {
                    self.pause = true;
                }
            }

            if (key == rl.KEY_W and self.pause or self.game_over) {
                self.w = true;
            } else if (key == rl.KEY_S and self.pause) {
                self.s = true;
            }
            if (key == rl.KEY_ENTER and self.pause) {
                self.enter = true;
            }
        } else if (self.menu.state_jogo and self.fim) {
            if (key == rl.KEY_ENTER or key == rl.KEY_ESCAPE) {
                self.enter = true;
            }
        } else if (self.game_over) {
            if (key == rl.KEY_W) {
                self.w = true;
            } else if (key == rl.KEY_S) {
                self.s = true;
            }
            if (key == rl.KEY_ENTER) {
                self.enter = true;
            }
        }
    }

    pub fn keyReleased(self: *Game, key: c_int) void {
        if (key == rl.KEY_ESCAPE) self.esc_pressionado = false;

        if (self.menu.state_jogo) {
            if (key == rl.KEY_W) {
                self.player.up = false;
            } else if (key == rl.KEY_S) {
                self.player.down = false;
            }

            if (key == rl.KEY_D) {
                self.player.right = false;
            } else if (key == rl.KEY_A) {
                self.player.left = false;
            }
        }
    }
};
