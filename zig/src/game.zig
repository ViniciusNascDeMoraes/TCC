//! `Main.Game`: estado global do jogo, `tick`, `render` e tratamento de teclas.
//!
//! As condicoes seguem o Java ao pe da letra (inclusive a precedencia de
//! `a || b && c` e a ordem dos `else if`), para o jogo se comportar igual.
//! `game_over` corresponde ao `Game.gameOver` do Java.

const std = @import("std");
const assets = @import("assets");
const gfx = @import("gfx.zig");
const platform = @import("platform.zig");
const Camera = @import("camera.zig").Camera;
const Enemy = @import("entities.zig").Enemy;
const Key = platform.Key;
const KeyEvent = platform.KeyEvent;
const Menu = @import("menu.zig").Menu;
const Mixer = @import("mixer.zig").Mixer;
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
    menu: gfx.Image,
    creditos: gfx.Image,
    morreu: gfx.Image,
    imagem_fim: gfx.Image,
    tela_vacina: gfx.Image,
    vacinando: [4]gfx.Image,

    const files = [_][]const u8{
        assets.tela_menu,
        assets.tela_creditos,
        assets.game_over,
        assets.tela_fim,
        assets.tela_vacina,
        assets.vacinando,
        assets.vacinando1,
        assets.vacinando2,
        assets.vacinando3,
    };

    fn load(gpa: std.mem.Allocator) !Screens {
        var images: [files.len]gfx.Image = undefined;
        for (files, 0..) |png, i| {
            errdefer for (images[0..i]) |image| image.deinit(gpa);
            images[i] = try gfx.loadImage(gpa, png);
        }
        return .{
            .menu = images[0],
            .creditos = images[1],
            .morreu = images[2],
            .imagem_fim = images[3],
            .tela_vacina = images[4],
            .vacinando = images[5..9].*,
        };
    }

    fn unload(self: Screens, gpa: std.mem.Allocator) void {
        for ([_]gfx.Image{ self.menu, self.creditos, self.morreu, self.imagem_fim, self.tela_vacina } ++ self.vacinando) |image| {
            image.deinit(gpa);
        }
    }
};

/// Esc e Enter so contam quando apertados de novo: segurar a tecla nao
/// repete a acao (no Java, as flags `escPressionado`/`enterPressionado`).
fn repeatsWhenHeld(key: Key) bool {
    return switch (key) {
        .escape, .enter => false,
        else => true,
    };
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
    image: gfx.Canvas,
    /// O quadro inteiro (960x640) que vai para a janela.
    frame: gfx.Canvas,
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
    game_over: bool = false,
    /// `Enemy.escudo`, `Enemy02.escudo` e `Enemy03.escudo`.
    escudo: [3]bool = @splat(true),
    /// Opcao do menu de pausa / game over: 0 = primeira opcao, 1 = segunda.
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

    /// `mixer` e `null` quando nao ha audio. `io` le as fontes do sistema.
    pub fn init(self: *Game, gpa: std.mem.Allocator, io: std.Io, mixer: ?*Mixer) !void {
        const spritesheet: Spritesheet = try .load(gpa);
        errdefer spritesheet.unload(gpa);
        const screens: Screens = try .load(gpa);
        errdefer screens.unload(gpa);
        const image: gfx.Canvas = try .init(gpa, width, height);
        errdefer image.deinit(gpa);
        const frame: gfx.Canvas = try .init(gpa, widthfm, heightfm);
        errdefer frame.deinit(gpa);
        const text: Text = try .load(gpa, io);
        errdefer text.unload(gpa);

        self.* = .{
            .gpa = gpa,
            .spritesheet = spritesheet,
            .screens = screens,
            .image = image,
            .frame = frame,
            .text = text,
            .sounds = .{ .mixer = mixer },
            .player = .init(1),
            .world = undefined,
        };
        errdefer self.enemies.deinit(gpa);
        self.world = try World.load(self, assets.level1);
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit(self);
        self.enemies.deinit(self.gpa);
        self.text.unload(self.gpa);
        self.frame.deinit(self.gpa);
        self.image.deinit(self.gpa);
        self.screens.unload(self.gpa);
        self.spritesheet.unload(self.gpa);
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

            // Todos os inimigos eliminados e o jogador chegou em casa: fim de jogo.
            if (self.level == 3 and self.contador >= self.total_inimigos and self.player.getY() < 175 and
                self.player.getX() > 559 and self.player.getX() < 593)
            {
                self.fim = true;
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

    /// Desenha o quadro em `frame`.
    pub fn render(self: *Game) void {
        // Mundo e entidades na imagem 240x160.
        self.image.clear(gfx.black);
        if (self.menu.state_jogo and self.normal()) {
            self.world.render(self);
            self.player.render(self);
            for (self.enemies.items) |enemy| enemy.render(self);
        }

        // A imagem ampliada cobre o quadro inteiro.
        self.frame.drawScaled(self.image, scale);

        self.renderScreens();
        self.renderMission();
    }

    /// Menus, game over, vacinacao e tela final, desenhados em 960x640.
    fn renderScreens(self: *Game) void {
        if (self.menu.state_inicio or self.menu.state_creditos or
            self.menu.state_loading and !self.menu.state_jogo and !self.pause)
        {
            self.menu.render(self);
        } else if (self.fim) {
            gfx.fillScreen(self.frame, gfx.blue);
            gfx.drawScreen(self.frame, self.screens.imagem_fim);
        } else if (self.pause and self.normal()) {
            self.renderOptions(txtmenu1, txtmenu2, gfx.white);
        } else if (self.game_over) {
            gfx.drawScreen(self.frame, self.screens.morreu);
            self.renderOptions(txtgo1, txtgo2, gfx.black);
        } else if (self.player.getY() < 20 and self.player.getX() > 93 and self.player.getX() < 98 and self.level == 2) {
            self.dialogo = true;
            gfx.fillScreen(self.frame, gfx.blue);

            self.time += 1;
            if (self.volta < 3) {
                // Cada imagem fica 39 quadros; os quadros 40, 80, 120 e 160 ficam so azuis.
                if (self.time < 40) {
                    gfx.drawScreen(self.frame, self.screens.vacinando[0]);
                } else if (self.time > 40 and self.time < 80) {
                    gfx.drawScreen(self.frame, self.screens.vacinando[1]);
                } else if (self.time > 80 and self.time < 120) {
                    gfx.drawScreen(self.frame, self.screens.vacinando[2]);
                } else if (self.time > 120 and self.time < 160) {
                    gfx.drawScreen(self.frame, self.screens.vacinando[3]);
                } else if (self.time > 160) {
                    self.time = 0;
                    self.volta += 1;
                }
            } else if (self.volta >= 3 and self.volta < 5) {
                gfx.drawScreen(self.frame, self.screens.tela_vacina);

                if (self.time > 100) {
                    self.volta += 1;
                    self.time = 0;
                }
            } else if (self.volta == 5) {
                self.dialogo = false;
                self.vacinado = true;
            }
        }
    }

    /// As duas opcoes centralizadas dos menus de pausa e de game over.
    fn renderOptions(self: *Game, op1: []const u8, op2: []const u8, color: gfx.Color) void {
        const cx = widthfm / 2;
        const cy = heightfm / 2;

        const tam1 = self.text.width(op1, .s30);
        self.text.draw(self.frame, op1, .s30, cx - @divTrunc(tam1, 2), cy - 50, color);
        const tam2 = self.text.width(op2, .s30);
        self.text.draw(self.frame, op2, .s30, cx - @divTrunc(tam2, 2), cy, color);

        if (self.option_atual == 0) {
            self.text.draw(self.frame, ">", .s30, cx - @divTrunc(tam1, 2) - 40, cy - 50, color);
        } else if (self.option_atual == 1) {
            self.text.draw(self.frame, ">", .s30, cx - @divTrunc(tam2, 2) - 40, cy, color);
        }
    }

    /// Textos de missao no canto superior esquerdo (desenhados por cima de tudo).
    fn renderMission(self: *Game) void {
        if (self.level == 1 and self.normal() and self.menu.state_jogo and self.player.getY() > 160) {
            self.text.draw(self.frame, txt_missao_texto, .s23, 15, 30, gfx.white);
            self.text.draw(self.frame, txt_missao_texto1, .s23, 15, 60, gfx.white);
            self.text.draw(self.frame, txt_missao_texto3, .s23, 15, 100, gfx.white);
        } else if (self.level == 2 and self.normal() and self.menu.state_jogo and !self.vacinado and !self.dialogo) {
            self.text.draw(self.frame, txt_missao_texto4, .s20, 15, 30, gfx.black);
            self.text.draw(self.frame, txt_missao_texto5, .s20, 15, 60, gfx.black);
        } else if (self.level == 3 and self.normal() and self.menu.state_jogo and self.player.getY() > 160) {
            if (self.contador < self.total_inimigos) {
                self.text.draw(self.frame, txt_missao_texto6, .s23, 15, 30, gfx.white);
                self.text.draw(self.frame, txt_missao_texto7, .s23, 15, 60, gfx.white);
                self.text.draw(self.frame, txt_missao_texto8, .s23, 15, 100, gfx.white);
                var buffer: [16]u8 = undefined;
                const contador = std.fmt.bufPrint(&buffer, "{d}", .{self.contador}) catch unreachable;
                self.text.draw(self.frame, contador, .s23, 275, 101, gfx.white);
            }
            if (self.contador >= self.total_inimigos and !self.fim) {
                self.text.draw(self.frame, txt_missao_texto9, .s20, 15, 30, gfx.white);
                self.text.draw(self.frame, txt_missao_texto10, .s20, 15, 60, gfx.white);
            }
        }
    }

    /// Repassa os eventos de teclado do quadro, na ordem em que aconteceram,
    /// para `keyPressed`/`keyReleased`, como o `KeyListener` do Java
    /// (incluindo a repeticao automatica de W/A/S/D segurado).
    pub fn handleInput(self: *Game, events: []const KeyEvent) void {
        for (events) |event| switch (event.action) {
            .press => self.keyPressed(event.key),
            .repeat => if (repeatsWhenHeld(event.key)) self.keyPressed(event.key),
            .release => self.keyReleased(event.key),
        };
    }

    pub fn keyPressed(self: *Game, key: Key) void {
        if (self.menu.state_inicio and self.normal()) {
            if (key == .w) {
                self.menu.w = true;
            } else if (key == .s) {
                self.menu.s = true;
            }
            if (key == .enter) {
                self.menu.enter = true;
            }
        } else if (self.menu.state_creditos and self.normal()) {
            if (key == .enter or key == .escape) {
                self.menu.enter = true;
            }
        } else if (self.menu.state_jogo and self.normal() and !self.fim) {
            if (key == .w) {
                self.player.up = true;
            } else if (key == .s) {
                self.player.down = true;
            }

            if (key == .d) {
                self.player.right = true;
            } else if (key == .a) {
                self.player.left = true;
            }

            if (key == .escape) {
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

            if (key == .w and self.pause) {
                self.w = true;
            } else if (key == .s and self.pause) {
                self.s = true;
            }
            if (key == .enter and self.pause) {
                self.enter = true;
            }
        } else if (self.menu.state_jogo and self.fim) {
            if (key == .enter or key == .escape) {
                self.enter = true;
            }
        } else if (self.game_over) {
            if (key == .w) {
                self.w = true;
            } else if (key == .s) {
                self.s = true;
            }
            if (key == .enter) {
                self.enter = true;
            }
        }
    }

    pub fn keyReleased(self: *Game, key: Key) void {
        if (self.menu.state_jogo) {
            if (key == .w) {
                self.player.up = false;
            } else if (key == .s) {
                self.player.down = false;
            }

            if (key == .d) {
                self.player.right = false;
            } else if (key == .a) {
                self.player.left = false;
            }
        }
    }
};
