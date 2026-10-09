package Entities;

import Camera.Camera;
import Main.Game;

import java.awt.*;
import java.awt.image.BufferedImage;

public class Entity {

    public static BufferedImage enemy_en = Game.spritesheet.getSprite(6 * 16, 0, 16, 16);
    public static BufferedImage enemy_en02 = Game.spritesheet.getSprite(6 * 16, 32, 16, 16);
    public static BufferedImage enemy_en03 = Game.spritesheet.getSprite(8 * 16, 32, 16, 16);

    protected int width, height;
    protected double x, y;

    private BufferedImage sprite;

    public Entity(int x, int y, int width, int height, BufferedImage sprite) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.sprite = sprite;
    }

    public void tick() {

    }

    public int getX() {
        return (int) this.x;
    }

    public void setX(int newX) {
        this.x = newX;
    }

    public int getY() {
        return (int) this.y;
    }

    public void setY(int newY) {
        this.y = newY;
    }

    public int getWidth() {
        return this.width;
    }

    public int getHeight() {
        return this.height;
    }

    public void render(Graphics g) {
        g.drawImage(sprite, this.getX() - Camera.x, this.getY() - Camera.y, null);
    }

}