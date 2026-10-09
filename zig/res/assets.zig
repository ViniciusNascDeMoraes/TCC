//! Assets usados pelo jogo, embutidos no executavel em tempo de compilacao.
//! Equivalem aos arquivos de `java/res` que o codigo Java carrega.

pub const spritesheet = @embedFile("Spritesheet.png");

pub const level1 = @embedFile("level1.png");
pub const level2 = @embedFile("level2.png");
pub const level3 = @embedFile("level3.png");

pub const tela_menu = @embedFile("TelaMenu.png");
pub const tela_creditos = @embedFile("TelaCreditos.png");
pub const game_over = @embedFile("GameOver.png");
pub const tela_fim = @embedFile("TelaFim.png");
pub const tela_vacina = @embedFile("TelaVacina.png");
pub const vacinando = @embedFile("Vacinando.png");
pub const vacinando1 = @embedFile("Vacinando1.png");
pub const vacinando2 = @embedFile("Vacinando2.png");
pub const vacinando3 = @embedFile("Vacinando3.png");

pub const som_menu = @embedFile("Menu.wav");
pub const som_select = @embedFile("Select.wav");
pub const som_menino = @embedFile("Menino.wav");
pub const som_monstro = @embedFile("Monstro.wav");
