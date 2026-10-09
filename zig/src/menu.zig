//! `Main.Menu`: tela inicial, creditos e animacao de "Carregando".

const gfx = @import("gfx.zig");
const Game = @import("game.zig").Game;

const txtmenu1 = "Novo jogo";
const txtmenu2 = "Créditos";
const txtmenu3 = "Sair";
const txtcred1 = "Voltar";
const loading_titles = [_][]const u8{ "Carregando", "Carregando.", "Carregando..", "Carregando..." };

pub const Menu = struct {
    /// 0 = "novo jogo", 1 = "creditos", 2 = "sair".
    option_atual: i32 = 0,
    w: bool = false,
    s: bool = false,
    enter: bool = false,
    state_inicio: bool = true,
    state_creditos: bool = false,
    state_jogo: bool = false,
    state_loading: bool = false,
    time: i32 = 0,
    volta: i32 = 0,

    const option_max = 2;
    const limite_volta = 3;

    pub fn tick(self: *Menu, g: *Game) void {
        if (self.state_inicio) {
            if (self.w) {
                g.sounds.play(.menu);
                self.w = false;
                self.option_atual -= 1;
                if (self.option_atual < 0) self.option_atual = option_max;
            }

            if (self.s) {
                g.sounds.play(.menu);
                self.s = false;
                self.option_atual += 1;
                if (self.option_atual > option_max) self.option_atual = 0;
            }

            if (self.enter) {
                g.sounds.play(.select);
                self.enter = false;

                if (self.option_atual == 2) {
                    g.quit = true;
                } else if (self.option_atual == 1) {
                    self.state_loading = false;
                    self.state_inicio = false;
                    self.state_jogo = false;
                    self.state_creditos = true;
                } else if (self.option_atual == 0) {
                    self.state_loading = true;
                    self.state_inicio = false;
                    self.state_jogo = false;
                    self.state_creditos = false;
                }
            }
        } else if (self.state_creditos) {
            if (self.enter) {
                g.sounds.play(.select);
                self.enter = false;

                self.state_loading = false;
                self.state_inicio = true;
                self.state_jogo = false;
                self.state_creditos = false;
            }
        }
    }

    pub fn render(self: *Menu, g: *Game) void {
        const cx = Game.widthfm / 2;
        const cy = Game.heightfm / 2;

        if (self.state_inicio) {
            gfx.drawScreen(g.frame, g.screens.menu);

            const tam1 = g.text.width(txtmenu1, .s40);
            g.text.draw(g.frame, txtmenu1, .s40, cx - @divTrunc(tam1, 2), cy - 50, gfx.black);
            const tam2 = g.text.width(txtmenu2, .s40);
            g.text.draw(g.frame, txtmenu2, .s40, cx - @divTrunc(tam2, 2), cy, gfx.black);
            const tam3 = g.text.width(txtmenu3, .s40);
            g.text.draw(g.frame, txtmenu3, .s40, cx - @divTrunc(tam3, 2), cy + 50, gfx.black);

            switch (self.option_atual) {
                0 => g.text.draw(g.frame, ">", .s40, cx - @divTrunc(tam1, 2) - 50, cy - 50, gfx.black),
                1 => g.text.draw(g.frame, ">", .s40, cx - @divTrunc(tam2, 2) - 50, cy, gfx.black),
                2 => g.text.draw(g.frame, ">", .s40, cx - @divTrunc(tam3, 2) - 50, cy + 50, gfx.black),
                else => {},
            }
        } else if (self.state_creditos) {
            gfx.drawScreen(g.frame, g.screens.creditos);

            const tam3 = g.text.width(txtcred1, .s40);
            g.text.draw(g.frame, txtcred1, .s40, cx - @divTrunc(tam3, 2), cy + 150, gfx.black);
            g.text.draw(g.frame, ">", .s40, cx - @divTrunc(tam3, 2) - 50, cy + 150, gfx.black);
        } else if (self.state_loading) {
            self.time += 1;
            gfx.fillScreen(g.frame, gfx.blue);
            if (self.volta < limite_volta) {
                // Cada titulo fica 24 quadros; os quadros 25, 50, 75 e 100 ficam so azuis.
                const title: ?[]const u8 = if (self.time < 25)
                    loading_titles[0]
                else if (self.time > 25 and self.time < 50)
                    loading_titles[1]
                else if (self.time > 50 and self.time < 75)
                    loading_titles[2]
                else if (self.time > 75 and self.time < 100)
                    loading_titles[3]
                else
                    null;

                if (title) |t| {
                    const tam = g.text.width(t, .s50);
                    g.text.draw(g.frame, t, .s50, cx - @divTrunc(tam, 2), Game.heightfm - 50, gfx.black);
                } else if (self.time > 100) {
                    self.time = 0;
                    self.volta += 1;
                }
            } else {
                self.state_loading = false;
                self.state_jogo = true;
            }
        }
    }
};
