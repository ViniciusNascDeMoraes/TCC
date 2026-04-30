package Entities;

import java.awt.Graphics;
import java.awt.image.BufferedImage;
import Camera.Camera;
import Main.Game;
import World.World;

public class Player extends Entity {

	public boolean right, left, up, down;
	public double speed = 1;

	public int right_dir = 0, left_dir = 1;
	public int dir = right_dir;

	public int life = 1;

	int escudo = 0;

	private int frames = 0, maxFrames = 5, index = 0, Maxindex = 3;
	private boolean moved = false;
	private BufferedImage[] rightPlayer;
	private BufferedImage[] leftPlayer;

	public Player(int x, int y, int width, int height, BufferedImage sprite) {
		super(x, y, width, height, sprite);

		rightPlayer = new BufferedImage[4];
		leftPlayer = new BufferedImage[4];

		if (Game.LEVEL == 1 || Game.LEVEL == 2) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(32 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(32 + (i * 16), 0, 16, 16);
			}
		} else if (Game.LEVEL == 3) {

			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 0, 16, 16);
			}

		}
	}

	public void tick() {
		moved = false;
		if (right == true && World.place_free((int) (x + speed), this.getY())) {
			moved = true;
			dir = right_dir;
			x = x + speed;
		} else if (left == true && World.place_free((int) (x - speed), this.getY())) {
			moved = true;
			dir = left_dir;
			x = x - speed;
		}

		if (up == true && World.place_free(this.getX(), (int) (y - speed))) {
			moved = true;
			y = y - speed;
		} else if (down == true && World.place_free(this.getX(), (int) (y + speed))) {
			moved = true;
			y = y + speed;
		}

		if (moved == true) {
			frames++;
			if (frames == maxFrames) {
				frames = 0;
				index++;
				if (index > Maxindex) {
					index = 0;
				}
			}
		}

		Camera.x = Camera.clamp(this.getX() - (Game.width / 2), 0, World.width * 16 - Game.width);
		Camera.y = Camera.clamp(this.getY() - (Game.height / 2), 0, World.height * 16 - Game.height);

	}

	public void render(Graphics g) {
		if (Enemy.escudo == false && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 0, 16, 16);
			}

			if (escudo > 15) {
				Enemy.escudo = true;
				escudo  = 0;
			}

			escudo++;
		} else if (Enemy02.escudo == false && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 0, 16, 16);
			}

			if (escudo > 15) {
				Enemy02.escudo = true;
				escudo  = 0;
			}

			escudo++;
		} else if (Enemy03.escudo == false && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(224 + (i * 16), 0, 16, 16);
			}

			if (escudo > 15) {
				Enemy03.escudo = true;
				escudo  = 0;
			}

			escudo++;
		} else if (Enemy.escudo == true && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 0, 16, 16);
			}
		} else if (Enemy02.escudo == true && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 0, 16, 16);
			}
		} else if (Enemy03.escudo == true && Game.LEVEL == 3) {
			for (int i = 0; i < 4; i++) {
				rightPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 16, 16, 16);
			}

			for (int i = 0; i < 4; i++) {
				leftPlayer[i] = Game.spritesheet.getSprite(160 + (i * 16), 0, 16, 16);
			}
		}

		if (dir == right_dir) {
			g.drawImage(rightPlayer[index], this.getX() - Camera.x, this.getY() - Camera.y, null);
		} else if (dir == left_dir) {
			g.drawImage(leftPlayer[index], this.getX() - Camera.x, this.getY() - Camera.y, null);
		}

	}

}
