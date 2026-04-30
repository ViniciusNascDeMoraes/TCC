package World;

import java.awt.Graphics;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.ArrayList;
import javax.imageio.ImageIO;

import Camera.Camera;
import Entities.Enemy;
import Entities.Enemy02;
import Entities.Enemy03;
import Entities.Entity;
import Entities.Player;
import Graphics.Asfalto;
import Graphics.AsfaltoParede;
import Graphics.C1;
import Graphics.C2;
import Graphics.C3;
import Graphics.CC1;
import Graphics.CC2;
import Graphics.CC3;
import Graphics.Calcada;
import Graphics.CalcadaParede;
import Graphics.Casa;
import Graphics.Chao;
import Graphics.Check;
import Graphics.Cruz;
import Graphics.Floor;
import Graphics.Hosp;
import Graphics.Janela;
import Graphics.Listra;
import Graphics.ListraParede;
import Graphics.Porta;
import Graphics.Porta2;
import Graphics.Porta3;
import Graphics.Spritesheet;
import Graphics.Tile;
import Graphics.Wall;
import Main.Game;

public class World {

	public static Tile[] tiles;
	public static int width, height;
	public static final int Tile_size = 16;

	public World(String path) {

		try {
			BufferedImage map = ImageIO.read(getClass().getResource(path));
			int[] pixels = new int[map.getWidth() * map.getHeight()];
			width = map.getWidth();
			height = map.getHeight();
			tiles = new Tile[map.getWidth() * map.getHeight()];
			map.getRGB(0, 0, map.getWidth(), map.getHeight(), pixels, 0, map.getWidth());

			for (int xx = 0; xx < map.getWidth(); xx++) {
				for (int yy = 0; yy < map.getHeight(); yy++) {
	
					int pixelAtual = pixels[xx + (yy * map.getWidth())];
					
					if (Game.LEVEL == 1) {

						tiles[xx + (yy * width)] = new Asfalto(xx * 16, yy * 16, Tile.Asfalto);

						if (pixelAtual == 0xFF007F0E) {
							tiles[xx + (yy * width)] = new Floor(xx * 16, yy * 16, Tile.Floor);
						} else if (pixelAtual == 0xFFFF6A00) {
							tiles[xx + (yy * width)] = new Wall(xx * 16, yy * 16, Tile.Wall);
						} else if (pixelAtual == 0xFF0026FF) {
							Game.player.setX(xx * 16);
							Game.player.setY(yy * 16);
						} else if (pixelAtual == 0xFF404040) {
							tiles[xx + (yy * width)] = new Calcada(xx * 16, yy * 16, Tile.Calcada);
						} else if (pixelAtual == 0xFF5ECEFF) {
							tiles[xx + (yy * width)] = new CalcadaParede(xx * 16, yy * 16, Tile.CalcadaParede);
						}else if (pixelAtual == 0xFFFF0000) {
							Enemy en = new Enemy(xx * 16, yy * 16, 16, 16, Entity.enemy_en);
							Game.entities.add(en);
							Game.enemies.add(en);
						} else if (pixelAtual == 0xFF000000) {
							tiles[xx + (yy * width)] = new Asfalto(xx * 16, yy * 16, Tile.Asfalto);
						} else if (pixelAtual == 0xFF66FFED) {
							tiles[xx + (yy * width)] = new AsfaltoParede(xx * 16, yy * 16, Tile.AsfaltoParede);
						}else if (pixelAtual == 0xFFFF006E) {
							tiles[xx + (yy * width)] = new Cruz(xx * 16, yy * 16, Tile.Cruz);
						} else if (pixelAtual == 0xFF4800FF) {
							tiles[xx + (yy * width)] = new Hosp(xx * 16, yy * 16, Tile.Hosp);
						} else if (pixelAtual == 0xFF7F3300) {
							tiles[xx + (yy * width)] = new Janela(xx * 16, yy * 16, Tile.Janela);
						} else if (pixelAtual == 0xFFFF00DC) {
							tiles[xx + (yy * width)] = new Porta(xx * 16, yy * 16, Tile.Porta);
						} else if (pixelAtual == 0xFFFFD800) {
							tiles[xx + (yy * width)] = new Listra(xx * 16, yy * 16, Tile.Listra);
						} else if (pixelAtual == 0xFF38FF8A) {
							tiles[xx + (yy * width)] = new ListraParede(xx * 16, yy * 16, Tile.ListraParede);
						}else if (pixelAtual == 0xFF5B7F00) {
							tiles[xx + (yy * width)] = new Porta2(xx * 16, yy * 16, Tile.Porta2);
						} else if (pixelAtual == 0xFF007F7F) {
							tiles[xx + (yy * width)] = new Porta3(xx * 16, yy * 16, Tile.Porta3);
						}
						
					} else if (Game.LEVEL == 2) {
						tiles[xx + (yy * width)] = new Chao(xx * 16, yy * 16, Tile.Chao);

						if (pixelAtual == 0xFFFF0000) {
							tiles[xx + (yy * width)] = new Hosp(xx * 16, yy * 16, Tile.Medico);
						} else if (pixelAtual == 0xFF000000) {
							tiles[xx + (yy * width)] = new Chao(xx * 16, yy * 16, Tile.Chao);	
						}else if (pixelAtual == 0xFF0026FF) {
							Game.player.setX(xx * 16);
							Game.player.setY(yy * 16);
						} else if (pixelAtual == 0xFFFFFFFF) {
							tiles[xx + (yy * width)] = new Hosp(xx * 16, yy * 16, Tile.Hosp);
						} else if (pixelAtual == 0xFFFF00DC) {
							tiles[xx + (yy * width)] = new Porta(xx * 16, yy * 16, Tile.Porta);
						} else if (pixelAtual == 0xFF5B7F00) {
							tiles[xx + (yy * width)] = new Porta2(xx * 16, yy * 16, Tile.Porta2);
						} else if (pixelAtual == 0xFF007F7F) {
							tiles[xx + (yy * width)] = new Porta3(xx * 16, yy * 16, Tile.Porta3);
						} else if (pixelAtual == 0XFF007F0E) {
							tiles[xx + (yy * width)] = new Check(xx * 16, yy * 16, Tile.Check);
						} else if (pixelAtual == 0xFF7F0037) {
							Enemy02 en02 = new Enemy02(xx * 16, yy * 16, 16, 16, Entity.enemy_en02);
							Game.entities.add(en02);
							Game.enemies02.add(en02);
						} else if (pixelAtual == 0xFFF4FF68) {
							tiles[xx + (yy * width)] = new C1(xx * 16, yy * 16, Tile.C1);
						} else if (pixelAtual == 0xFFFFD760) {
							tiles[xx + (yy * width)] = new C2(xx * 16, yy * 16, Tile.C2);
						} else if (pixelAtual == 0xFFFF9E44) {
							tiles[xx + (yy * width)] = new C3(xx * 16, yy * 16, Tile.C3);
						}
					} else if (Game.LEVEL == 3) {

						tiles[xx + (yy * width)] = new Asfalto(xx * 16, yy * 16, Tile.Asfalto);

						if (pixelAtual == 0xFF007F0E) {
							tiles[xx + (yy * width)] = new Floor(xx * 16, yy * 16, Tile.Floor);
						} else if (pixelAtual == 0xFFFF6A00) {
							tiles[xx + (yy * width)] = new Wall(xx * 16, yy * 16, Tile.Wall);
						} else if (pixelAtual == 0xFF0026FF) {
							Game.player.setX(xx * 16);
							Game.player.setY(yy * 16);
						} else if (pixelAtual == 0xFF404040) {
							tiles[xx + (yy * width)] = new Calcada(xx * 16, yy * 16, Tile.Calcada);
						} else if (pixelAtual == 0xFF5ECEFF) {
							tiles[xx + (yy * width)] = new CalcadaParede(xx * 16, yy * 16, Tile.CalcadaParede);
						} else if (pixelAtual == 0xFFFF0000) {
							Enemy en = new Enemy(xx * 16, yy * 16, 16, 16, Entity.enemy_en);
							Game.entities.add(en);
							Game.enemies.add(en);
						} else if (pixelAtual == 0xFFFF5956) {
							Enemy02 en2 = new Enemy02(xx * 16, yy * 16, 16, 16, Entity.enemy_en02);
							Game.entities.add(en2);
							Game.enemies02.add(en2);
						} else if (pixelAtual == 0xFFFF96A0) {
							Enemy03 en3 = new Enemy03(xx * 16, yy * 16, 16, 16, Entity.enemy_en03);
							Game.entities.add(en3);
							Game.enemies03.add(en3);
						} else if (pixelAtual == 0xFF000000) {
							tiles[xx + (yy * width)] = new Asfalto(xx * 16, yy * 16, Tile.Asfalto);
						} else if (pixelAtual == 0xFF66FFED) {
							tiles[xx + (yy * width)] = new AsfaltoParede(xx * 16, yy * 16, Tile.AsfaltoParede);
						} else if (pixelAtual == 0xFFFF006E) {
							tiles[xx + (yy * width)] = new Cruz(xx * 16, yy * 16, Tile.Cruz);
						} else if (pixelAtual == 0xFF4800FF) {
							tiles[xx + (yy * width)] = new Hosp(xx * 16, yy * 16, Tile.Hosp);
						} else if (pixelAtual == 0xFF7F3300) {
							tiles[xx + (yy * width)] = new Janela(xx * 16, yy * 16, Tile.Janela);
						} else if (pixelAtual == 0xFFFF00DC) {
							tiles[xx + (yy * width)] = new Porta(xx * 16, yy * 16, Tile.Porta);
						} else if (pixelAtual == 0xFFFFD800) {
							tiles[xx + (yy * width)] = new Listra(xx * 16, yy * 16, Tile.Listra);
						} else if (pixelAtual == 0xFF38FF8A) {
							tiles[xx + (yy * width)] = new ListraParede(xx * 16, yy * 16, Tile.ListraParede);
						} else if (pixelAtual == 0xFF5B7F00) {
							tiles[xx + (yy * width)] = new Porta2(xx * 16, yy * 16, Tile.Porta2);
						} else if (pixelAtual == 0xFF007F7F) {
							tiles[xx + (yy * width)] = new Porta3(xx * 16, yy * 16, Tile.Porta3);
						} else if (pixelAtual == 0xFFD6FFCC) {
							tiles[xx + (yy * width)] = new Casa(xx * 16, yy * 16, Tile.Casa);
						} else if (pixelAtual == 0xFF503F7F) {
							tiles[xx + (yy * width)] = new CC1(xx * 16, yy * 16, Tile.CC1);
						} else if (pixelAtual == 0xFF527F3F) {
							tiles[xx + (yy * width)] = new CC2(xx * 16, yy * 16, Tile.CC2);
						} else if (pixelAtual == 0xFFA5FF7F) {
							tiles[xx + (yy * width)] = new CC3(xx * 16, yy * 16, Tile.CC3);
						}
					}
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	public static void restartGame(String LEVEL) {
		Game.entities.clear();
		Game.enemies.clear();
		Game.enemies02.clear();
		Game.entities = new ArrayList<Entity>();
		Game.enemies = new ArrayList<Enemy>();
		Game.enemies02 = new ArrayList<Enemy02>();
		Game.spritesheet = new Spritesheet("/spritesheet.png");
		Game.player = new Player(0, 0, 16, 16, Game.spritesheet.getSprite(32, 0, 16, 16));
		Game.entities.add(Game.player);
		Game.world = new World("/" + LEVEL);
		
		return;

	}

	public static boolean place_free(int xnext, int ynext) {
		int x1 = xnext / Tile_size;
		int y1 = ynext / Tile_size;

		int x2 = (xnext + Tile_size - 1) / Tile_size;
		int y2 = ynext / Tile_size;

		int x3 = xnext / Tile_size;
		int y3 = (ynext + Tile_size - 1) / Tile_size;

		int x4 = (xnext + Tile_size - 1) / Tile_size;
		int y4 = (ynext + Tile_size - 1) / Tile_size;

		return !((tiles[x1 + (y1 * World.width)] instanceof Floor) || (tiles[x2 + (y2 * World.width)] instanceof Floor)
				|| (tiles[x3 + (y3 * World.width)] instanceof Floor)
				|| (tiles[x4 + (y4 * World.width)] instanceof Floor) || (tiles[x1 + (y1 * World.width)] instanceof Hosp)
				|| (tiles[x2 + (y2 * World.width)] instanceof Hosp) || (tiles[x3 + (y3 * World.width)] instanceof Hosp)
				|| (tiles[x4 + (y4 * World.width)] instanceof Hosp) || (tiles[x1 + (y1 * World.width)] instanceof CalcadaParede)
				|| (tiles[x2 + (y2 * World.width)] instanceof CalcadaParede) || (tiles[x3 + (y3 * World.width)] instanceof CalcadaParede)
				|| (tiles[x4 + (y4 * World.width)] instanceof CalcadaParede) || (tiles[x1 + (y1 * World.width)] instanceof ListraParede)
				|| (tiles[x2 + (y2 * World.width)] instanceof ListraParede) || (tiles[x3 + (y3 * World.width)] instanceof ListraParede)
				|| (tiles[x4 + (y4 * World.width)] instanceof ListraParede) || (tiles[x1 + (y1 * World.width)] instanceof AsfaltoParede)
				|| (tiles[x2 + (y2 * World.width)] instanceof AsfaltoParede) || (tiles[x3 + (y3 * World.width)] instanceof AsfaltoParede)
				|| (tiles[x4 + (y4 * World.width)] instanceof AsfaltoParede) || (tiles[x1 + (y1 * World.width)] instanceof Casa)
				|| (tiles[x2 + (y2 * World.width)] instanceof Casa) || (tiles[x3 + (y3 * World.width)] instanceof Casa)
				|| (tiles[x4 + (y4 * World.width)] instanceof Casa) || (tiles[x1 + (y1 * World.width)] instanceof C1)
				|| (tiles[x2 + (y2 * World.width)] instanceof C1) || (tiles[x3 + (y3 * World.width)] instanceof C1)
				|| (tiles[x4 + (y4 * World.width)] instanceof C1) || (tiles[x1 + (y1 * World.width)] instanceof C2)
				|| (tiles[x2 + (y2 * World.width)] instanceof C2) || (tiles[x3 + (y3 * World.width)] instanceof C2)
				|| (tiles[x4 + (y4 * World.width)] instanceof C2) || (tiles[x1 + (y1 * World.width)] instanceof C3)
				|| (tiles[x2 + (y2 * World.width)] instanceof C3) || (tiles[x3 + (y3 * World.width)] instanceof C3)
				|| (tiles[x4 + (y4 * World.width)] instanceof C3));

	}

	public void render(Graphics g) {
		int xstart = Camera.x / 16;
		int ystart = Camera.y / 16;

		int xfinal = xstart + (Game.width / 16);
		int yfinal = ystart + (Game.height / 16);

		for (int xx = xstart; xx <= xfinal; xx++) {
			for (int yy = ystart; yy <= yfinal; yy++) {
				if (xx < 0 || yy < 0 || xx >= width || yy >= height)
					continue;
				Tile tile = tiles[xx + (yy * width)];
				tile.render(g);
			}
		}
	}

}
