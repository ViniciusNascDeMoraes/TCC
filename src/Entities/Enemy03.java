package Entities;

import Camera.Camera;
import Main.Game;
import Main.Sound;
import World.World;

import java.awt.*;
import java.awt.image.BufferedImage;

public class Enemy03 extends Entity {


    public static String state = "GAMENORMAL";
    public static boolean escudo = true;
    public int right_dir = 0, left_dir = 1;
    public int dir = right_dir;
    private int maskx = 6, masky = 3, maskw = 8, maskh = 12;
    private double speed = 1.5;
    private BufferedImage[] rightEnemy;
    private BufferedImage[] leftEnemy;
    private int frames = 0, maxFrames = 20, index = 0, Maxindex = 1;
    private boolean moved = false;

    public Enemy03(int x, int y, int width, int height, BufferedImage sprite) {
        super(x, y, width, height, sprite);

        rightEnemy = new BufferedImage[2];
        leftEnemy = new BufferedImage[2];

        for (int i = 0; i < 2; i++) {
            rightEnemy[i] = Game.spritesheet.getSprite(128 + (i * 16), 32, 16, 16);
        }

        for (int i = 0; i < 2; i++) {
            leftEnemy[i] = Game.spritesheet.getSprite(128 + (i * 16), 48, 16, 16);
        }

    }

    public void moviment() {
        if (World.place_free((int) (x + speed), this.getY())) {
            x += speed;
            moved = true;
        } else if (!World.place_free((int) (x + speed), this.getY())) {
            moved = true;
            speed *= -1;
            x += speed;
        }

        if (speed < 0) {
            dir = left_dir;
        } else {
            dir = right_dir;
        }
    }

    public void tick() {

        maskx = 6;
        masky = 3;
        maskw = 8;
        maskh = 12;
        moved = false;

        if (this.isCollidingWithPlayer() == false) {
            this.moviment();

        } else if (this.isCollidingWithPlayer() == true && Game.LEVEL == 3) {

            Sound.play("res/Monstro.wav");

            escudo = false;
            Game.entities.remove(this);
            Game.enemies03.remove(this);

            Game.contador++;
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

    }

    public boolean isCollidingWithPlayer() {
        Rectangle enemyAtual = new Rectangle(this.getX() + maskx, this.getY() + masky, maskw, maskh);
        Rectangle player = new Rectangle(Game.player.getX(), Game.player.getY(), 16, 16);

        return enemyAtual.intersects(player);
    }

    public void render(Graphics g) {
        if (dir == right_dir) {
            g.drawImage(rightEnemy[index], this.getX() - Camera.x, this.getY() - Camera.y, null);
        } else if (dir == left_dir) {
            g.drawImage(leftEnemy[index], this.getX() - Camera.x, this.getY() - Camera.y, null);
        }

    }

}