package Main;

import Entities.*;
import Graphics.Spritesheet;
import World.World;

import javax.imageio.ImageIO;
import javax.swing.*;
import java.awt.*;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.awt.image.BufferStrategy;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

public class Game extends Canvas implements Runnable, KeyListener {

    public static final int width = 240, height = 160, scale = 4;
    public static final Color BLUE = new Color(9, 156, 147);
    private static final long serialVersionUID = 1L;
    public static JFrame frame;
    public static BufferedImage Menu, Creditos, Morreu, ImagemFim, TelaVacina, Vacinando, Vacinando1, Vacinando2, Vacinando3;

    public static List<Entity> entities;

    public static Player player;

    public static int contador = 0;
    public static World world;
    public static int widthfm = 0, heightfm = 0;
    public static Spritesheet spritesheet;
    public static int tam1, tam2;
    public static String txtmenu1 = "Retornar ao jogo", txtmenu2 = "Sair do jogo", txtgo1 = "Reiniciar a fase",
            txtgo2 = "Sair do jogo";
    public static String txt_missao_texto = "Chegue no hospital", txt_missao_texto1 = "para se vacinar!",
            txt_missao_texto3 = "Dica: Desvie das bactérias.", txt_missao_texto4 = "Vá para a área amarela",
            txt_missao_texto5 = "para se vacinar", txt_missao_texto6 = "Utilize seu escudo para ",
            txt_missao_texto7 = "eliminar todos os vírus e bactérias", txt_missao_texto8 = "Inimigos eliminados: ",
            txt_missao_texto9 = "Todos os inimigos foram eliminados,", txt_missao_texto10 = "volte para casa!";
    public static boolean pause = false, dialogo = false, vacinado = false, gameOver = false;
    public static int LEVEL = 1;
    // Menus de pausa e de game over: 0 = primeira opcao, 1 = segunda.
    public int optionAtual = 0;
    public int optionMax = 1;
    public boolean w = false, s = false, enter = false;
    public Menu menu;
    public int time, volta;
    private Thread thread;
    private BufferedImage image;
    private boolean running, fim = false;

    public Game() {

        URL Caminho = getClass().getResource("/TelaMenu.png");
        try {
            Menu = ImageIO.read(Caminho);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho2 = getClass().getResource("/TelaCreditos.png");
        try {
            Creditos = ImageIO.read(Caminho2);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho3 = getClass().getResource("/GameOver.png");
        try {
            Morreu = ImageIO.read(Caminho3);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho4 = getClass().getResource("/TelaFim.png");
        try {
            ImagemFim = ImageIO.read(Caminho4);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho5 = getClass().getResource("/TelaVacina.png");
        try {
            TelaVacina = ImageIO.read(Caminho5);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho6 = getClass().getResource("/Vacinando.png");
        try {
            Vacinando = ImageIO.read(Caminho6);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho7 = getClass().getResource("/Vacinando1.png");
        try {
            Vacinando1 = ImageIO.read(Caminho7);
        } catch (IOException e) {
            e.printStackTrace();
        }

        URL Caminho8 = getClass().getResource("/Vacinando2.png");
        try {
            Vacinando2 = ImageIO.read(Caminho8);
        } catch (IOException e) {
            e.printStackTrace();
        }


        URL Caminho9 = getClass().getResource("/Vacinando3.png");
        try {
            Vacinando3 = ImageIO.read(Caminho9);
        } catch (IOException e) {
            e.printStackTrace();
        }

        addKeyListener(this);
        setPreferredSize(new Dimension(width * scale, height * scale));

        frameinit();

        image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);

        spritesheet = new Spritesheet("/Spritesheet.png");
        entities = new ArrayList<Entity>();
        player = new Player(0, 0, 16, 16, spritesheet.getSprite(32, 0, 16, 16));
        entities.add(player);
        world = new World("/level1.png");

        menu = new Menu();

        widthfm = width * scale;
        heightfm = height * scale;

    }

    public static void main(String args[]) {
        Game game = new Game();
        game.start();
    }

    public void frameinit() {

        frame = new JFrame("Vacina");
        frame.add(this);
        frame.setResizable(false);
        frame.pack();
        frame.setLocationRelativeTo(null);
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setVisible(true);

    }

    public synchronized void start() {
        thread = new Thread(this);
        running = true;
        thread.start();
    }

    public void run() {
        long lastTime = System.nanoTime();
        double amountOfTicks = 60.0;
        double ns = 1000000000 / amountOfTicks;
        double delta = 0;
        int frames = 0;
        double timer = System.currentTimeMillis();
        requestFocus();

        while (running) {
            long now = System.nanoTime();
            delta += (now - lastTime) / ns;
            lastTime = now;
            if (delta >= 1) {
                tick();
                render();
                frames++;
                delta--;
            } else {
                // Ainda nao e hora do proximo quadro: libera a CPU em vez de girar em vazio.
                try {
                    Thread.sleep(1);
                } catch (InterruptedException e) {
                    return;
                }
            }

            if (System.currentTimeMillis() - timer >= 1000) {
                System.out.println("FPS: " + frames);
                frames = 0;
                timer += 1000;
            }

        }

    }

    public void tick() {

        if (menu.stateInicio == true || menu.stateCreditos == true && pause == false && gameOver == false) {

            menu.tick();

        } else if (menu.stateJogo == true && pause == false && gameOver == false && dialogo == false
                && fim == false) {
            for (int i = 0; i < entities.size(); i++) {
                Entity e = entities.get(i);
                e.tick();
            }

            if (player.getY() < 80 && LEVEL == 1) {
                if (LEVEL == 1) {
                    LEVEL = 2;

                }

                String newWorld = "level" + LEVEL + ".png";
                World.restartGame(newWorld);

            }

            if (vacinado == true) {
                LEVEL = 3;
                String newWorld = "level" + LEVEL + ".png";
                World.restartGame(newWorld);
                vacinado = false;
            }

        } else if (fim == true) {
            if (enter == true) {

                Sound.play("res/Select.wav");

                enter = false;
                voltarAoMenu();

            }
        } else if (pause == true && gameOver == false) {
            if (w == true) {

                Sound.play("res/Menu.wav");

                w = false;
                optionAtual--;

                if (optionAtual < 0) {

                    optionAtual = optionMax;

                }

            }

            if (s == true) {

                Sound.play("res/Menu.wav");

                s = false;
                optionAtual++;

                if (optionAtual > optionMax) {

                    optionAtual = 0;

                }
            }

            if (enter == true) {

                Sound.play("res/Select.wav");

                enter = false;

                if (optionAtual == 1) {

                    System.exit(0);

                } else if (optionAtual == 0) {

                    pause = false;
                    optionAtual = 0;

                }
            }
        } else if (gameOver == true) {
            if (w == true) {

                Sound.play("res/Menu.wav");

                w = false;
                optionAtual--;

                if (optionAtual < 0) {

                    optionAtual = optionMax;

                }

            }

            if (s == true) {

                Sound.play("res/Menu.wav");

                s = false;
                optionAtual++;

                if (optionAtual > optionMax) {

                    optionAtual = 0;

                }
            }

            if (enter == true) {

                Sound.play("res/Select.wav");

                enter = false;

                if (optionAtual == 0) {
                    gameOver = false;
                    String newWorld = "level" + LEVEL + ".png";
                    World.restartGame(newWorld);

                } else if (optionAtual == 1) {

                    System.exit(0);

                }
            }
        }

    }

    public void render() {
        BufferStrategy bs = this.getBufferStrategy();
        if (bs == null) {
            this.createBufferStrategy(3);
            return;
        }

        Graphics g = image.getGraphics();
        g.setColor(new Color(0, 0, 0));
        g.fillRect(0, 0, widthfm, heightfm);

        if (menu.stateJogo == true && gameOver == false) {

            world.render(g);
            for (int i = 0; i < entities.size(); i++) {
                Entity e = entities.get(i);
                e.render(g);
            }

        }

        g.dispose();
        g = bs.getDrawGraphics();
        g.drawImage(image, 0, 0, width * scale, height * scale, null);

        if (menu.stateInicio == true || menu.stateCreditos == true
                || menu.stateLoading == true && menu.stateJogo == false && pause == false) {

            menu.render(g);

        } else if (pause == true && gameOver == false) {
            g.setColor(Color.white);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 30));
            tam1 = g.getFontMetrics().stringWidth(txtmenu1);
            g.drawString(txtmenu1, (Game.widthfm / 2) - (tam1 / 2), (Game.heightfm / 2) - 50);
            tam2 = g.getFontMetrics().stringWidth(txtmenu2);
            g.drawString(txtmenu2, (Game.widthfm / 2) - (tam2 / 2), (Game.heightfm / 2));

            if (optionAtual == 0) {
                g.drawString(">", ((Game.widthfm / 2) - (tam1 / 2)) - 40, (Game.heightfm / 2) - 50);
            } else if (optionAtual == 1) {
                g.drawString(">", ((Game.widthfm / 2) - (tam2 / 2)) - 40, (Game.heightfm / 2));
            }

        } else if (gameOver == true) {

            g.drawImage(Game.Morreu, 0, 0, Game.widthfm, Game.heightfm, null);

            g.setColor(Color.black);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 30));
            tam1 = g.getFontMetrics().stringWidth(txtgo1);
            g.drawString(txtgo1, (Game.widthfm / 2) - (tam1 / 2), (Game.heightfm / 2) - 50);
            tam2 = g.getFontMetrics().stringWidth(txtgo2);
            g.drawString(txtgo2, (Game.widthfm / 2) - (tam2 / 2), (Game.heightfm / 2));

            if (optionAtual == 0) {
                g.drawString(">", ((Game.widthfm / 2) - (tam1 / 2)) - 40, (Game.heightfm / 2) - 50);
            } else if (optionAtual == 1) {
                g.drawString(">", ((Game.widthfm / 2) - (tam2 / 2)) - 40, (Game.heightfm / 2));
            }
        } else if (player.getY() < 20 && player.getX() > 93 && player.getX() < 98 && LEVEL == 2) {
            dialogo = true;
            g.clearRect(0, 0, Game.widthfm, Game.heightfm);
            g.setColor(BLUE);
            g.fillRect(0, 0, Game.widthfm, Game.heightfm);

            time++;
            if (volta < 3) {
                if (time < 40) {
                    g.setColor(Color.black);

                    g.drawImage(Game.Vacinando, 0, 0, Game.widthfm, Game.heightfm, null);
                } else if (time == 40) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 40 && time < 80) {
                    g.setColor(Color.black);

                    g.drawImage(Game.Vacinando1, 0, 0, Game.widthfm, Game.heightfm, null);
                } else if (time == 80) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 80 && time < 120) {
                    g.setColor(Color.black);

                    g.drawImage(Game.Vacinando2, 0, 0, Game.widthfm, Game.heightfm, null);
                } else if (time == 120) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 120 && time < 160) {
                    g.setColor(Color.black);

                    g.drawImage(Game.Vacinando3, 0, 0, Game.widthfm, Game.heightfm, null);

                } else if (time > 160) {
                    time = 0;
                    volta = volta + 1;
                }
            } else if (volta >= 3 && volta < 5) {
                g.setColor(BLUE);
                g.drawImage(Game.TelaVacina, 0, 0, Game.widthfm, Game.heightfm, null);

                if (time > 100) {
                    volta = volta + 1;
                    time = 0;
                }
            } else if (volta == 5) {
                dialogo = false;
                vacinado = true;
            }

        } else if (fim == true
                || player.getY() < 175 && player.getX() > 559 && player.getX() < 593 && LEVEL == 3 && contador > 21) {
            fim = true;

            g.clearRect(0, 0, Game.widthfm, Game.heightfm);
            g.setColor(BLUE);
            g.fillRect(0, 0, Game.widthfm, Game.heightfm);

            g.drawImage(Game.ImagemFim, 0, 0, Game.widthfm, Game.heightfm, null);
        }

        if (LEVEL == 1 && gameOver == false && menu.stateJogo == true && player.getY() > 160) {
            g.setColor(Color.WHITE);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 23));
            g.drawString(txt_missao_texto, 15, 30);
            g.drawString(txt_missao_texto1, 15, 60);
            g.drawString(txt_missao_texto3, 15, 100);
        } else if (LEVEL == 2 && gameOver == false && menu.stateJogo == true && vacinado == false && dialogo == false) {

            g.setColor(Color.BLACK);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 20));
            g.drawString(txt_missao_texto4, 15, 30);
            g.drawString(txt_missao_texto5, 15, 60);
        } else if (LEVEL == 3 && gameOver == false && menu.stateJogo == true && player.getY() > 160) {
            if (Game.contador < 22) {
                g.setColor(Color.WHITE);
                g.setFont(new Font("Bookman Old Style", Font.BOLD, 23));
                g.drawString(txt_missao_texto6, 15, 30);
                g.drawString(txt_missao_texto7, 15, 60);
                g.drawString(txt_missao_texto8, 15, 100);
                g.drawString("" + contador, 275, 101);
            }
            if (Game.contador > 21 && fim == false) {
                g.setColor(Color.WHITE);
                g.setFont(new Font("Bookman Old Style", Font.BOLD, 20));
                g.drawString(txt_missao_texto9, 15, 30);
                g.drawString(txt_missao_texto10, 15, 60);
            }
        }

        bs.show();
    }

    /**
     * Depois da tela final: zera o progresso do jogo e volta ao menu inicial.
     */
    private void voltarAoMenu() {
        LEVEL = 1;
        contador = 0;
        pause = false;
        dialogo = false;
        vacinado = false;
        gameOver = false;
        fim = false;
        time = 0;
        volta = 0;
        optionAtual = 0;
        w = false;
        s = false;
        enter = false;
        Enemy.escudo = true;
        Enemy02.escudo = true;
        Enemy03.escudo = true;
        menu = new Menu();
        World.restartGame("level1.png");
    }

    public void keyPressed(KeyEvent e) {
        if (menu.stateInicio == true && gameOver == false) {
            if (e.getKeyCode() == KeyEvent.VK_W) {
                menu.w = true;
            } else if (e.getKeyCode() == KeyEvent.VK_S) {
                menu.s = true;
            }
            if (e.getKeyCode() == KeyEvent.VK_ENTER && gameOver == false) {
                menu.enter = true;
            }
        } else if (menu.stateCreditos == true && gameOver == false) {
            if (e.getKeyCode() == KeyEvent.VK_ENTER || e.getKeyCode() == KeyEvent.VK_ESCAPE) {
                menu.enter = true;
            }
        } else if (menu.stateJogo == true && gameOver == false && fim == false) {
            if (e.getKeyCode() == KeyEvent.VK_W) {
                player.up = true;
            } else if (e.getKeyCode() == KeyEvent.VK_S) {
                player.down = true;
            }

            if (e.getKeyCode() == KeyEvent.VK_D) {
                player.right = true;
            } else if (e.getKeyCode() == KeyEvent.VK_A) {
                player.left = true;
            }

            if (e.getKeyCode() == KeyEvent.VK_ESCAPE && gameOver == false) {
                pause = true;
            }

            if (e.getKeyCode() == KeyEvent.VK_W && pause == true || gameOver == true) {
                w = true;
            } else if (e.getKeyCode() == KeyEvent.VK_S && pause == true) {
                s = true;
            }
            if (e.getKeyCode() == KeyEvent.VK_ENTER && pause == true) {
                enter = true;
            }
        } else if (menu.stateJogo == true && fim == true) {
            if (e.getKeyCode() == KeyEvent.VK_ENTER || e.getKeyCode() == KeyEvent.VK_ESCAPE) {
                enter = true;
            }
        } else if (gameOver == true) {
            if (e.getKeyCode() == KeyEvent.VK_W) {
                w = true;
            } else if (e.getKeyCode() == KeyEvent.VK_S) {
                s = true;
            }
            if (e.getKeyCode() == KeyEvent.VK_ENTER) {
                enter = true;
            }
        }

    }

    public void keyReleased(KeyEvent e) {
        if (menu.stateJogo == true) {
            if (e.getKeyCode() == KeyEvent.VK_W) {
                player.up = false;
            } else if (e.getKeyCode() == KeyEvent.VK_S) {
                player.down = false;
            }

            if (e.getKeyCode() == KeyEvent.VK_D) {
                player.right = false;
            } else if (e.getKeyCode() == KeyEvent.VK_A) {
                player.left = false;
            }
        }
    }

    public void keyTyped(KeyEvent e) {

    }
}