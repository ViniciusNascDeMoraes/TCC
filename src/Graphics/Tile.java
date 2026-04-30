package Graphics;

import java.awt.Graphics;
import java.awt.image.BufferedImage;

import Camera.Camera;
import Main.Game;

public class Tile {

	public static BufferedImage Wall = Game.spritesheet.getSprite(0, 0, 16, 16);
	public static BufferedImage Floor = Game.spritesheet.getSprite(16, 0, 16, 16);
	public static BufferedImage Calcada = Game.spritesheet.getSprite(0, 32, 16, 16);
	public static BufferedImage CalcadaParede = Game.spritesheet.getSprite(0, 32, 16, 16);
	public static BufferedImage Asfalto = Game.spritesheet.getSprite(0, 16, 16, 16);
	public static BufferedImage AsfaltoParede = Game.spritesheet.getSprite(0, 16, 16, 16);
	public static BufferedImage Cruz = Game.spritesheet.getSprite(0, 48, 16, 16);
	public static BufferedImage Hosp = Game.spritesheet.getSprite(16, 32, 16, 16);
	public static BufferedImage Listra = Game.spritesheet.getSprite(16, 16, 16, 16);
	public static BufferedImage ListraParede = Game.spritesheet.getSprite(16, 16, 16, 16);
	public static BufferedImage Porta = Game.spritesheet.getSprite(0, 64, 16, 16);
	public static BufferedImage Porta2 = Game.spritesheet.getSprite(16, 64, 16, 16);
	public static BufferedImage Porta3 = Game.spritesheet.getSprite(32, 64, 16, 16);
	public static BufferedImage Janela = Game.spritesheet.getSprite(16, 48, 16, 16);
	
	public static BufferedImage Medico = Game.spritesheet.getSprite(128, 0, 16, 16);
	public static BufferedImage Chao = Game.spritesheet.getSprite(32, 32, 16, 16);
	
	public static BufferedImage Check = Game.spritesheet.getSprite(144, 0, 16, 16);
	
	public static BufferedImage Casa = Game.spritesheet.getSprite(0, 80, 16, 16);
	public static BufferedImage C1 = Game.spritesheet.getSprite(0, 64, 16, 16);
	public static BufferedImage C2 = Game.spritesheet.getSprite(16, 64, 16, 16);
	public static BufferedImage C3 = Game.spritesheet.getSprite(32, 64, 16, 16);

	public static BufferedImage CC1 = Game.spritesheet.getSprite(0, 96, 16, 16);
	public static BufferedImage CC2 = Game.spritesheet.getSprite(16, 96, 16, 16);
	public static BufferedImage CC3 = Game.spritesheet.getSprite(32, 96, 16, 16);
	
	private BufferedImage sprite;
	private int x, y;

	public Tile(int x, int y, BufferedImage sprite) {
		this.x = x;
		this.y = y;
		this.sprite = sprite;
	}

	public void render(Graphics g) {
		g.drawImage(sprite, x - Camera.x, y - Camera.y, null);

	}
}
