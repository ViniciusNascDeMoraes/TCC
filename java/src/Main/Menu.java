package Main;

import java.awt.*;

public class Menu {
    // 0 = novo jogo, 1 = creditos, 2 = idioma, 3 = sair.
    public int optionAtual = 0;
    public int optionMax = 3;
    public int tam1, tam2, tam3, tam4;

    // Cada texto em { portugues, ingles }, usado como texto[Game.idioma].
    public String[] txtmenu1 = { "Novo jogo", "New game" }, txtmenu2 = { "Créditos", "Credits" },
            txtidioma = { "Idioma: Português", "Language: English" }, txtmenu3 = { "Sair", "Quit" };
    public String[] txtcred1 = { "Voltar", "Back" };
    public boolean w = false, s = false, enter = false;
    public boolean stateInicio = true, stateCreditos = false, stateJogo = false, stateLoading = false;
    public int time, volta, limiteVolta = 3;
    String[] loadingTitle1 = { "Carregando", "Loading" }, loadingTitle2 = { "Carregando.", "Loading." },
            loadingTitle3 = { "Carregando..", "Loading.." }, loadingTitle4 = { "Carregando...", "Loading..." };

    public void tick() {
        if (stateInicio == true) {


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

                if (optionAtual == 3) {


                    System.exit(0);

                } else if (optionAtual == 2) {

                    // Troca o idioma; o menu continua aberto, ja no outro idioma.
                    Game.idioma = Game.idioma == Game.PORTUGUES ? Game.INGLES : Game.PORTUGUES;

                } else if (optionAtual == 1) {

                    stateLoading = false;
                    stateInicio = false;
                    stateJogo = false;
                    stateCreditos = true;

                } else if (optionAtual == 0) {


                    stateLoading = true;
                    stateInicio = false;
                    stateJogo = false;
                    stateCreditos = false;

                }

            }
        } else if (stateCreditos == true) {

            if (enter == true) {

                Sound.play("res/Select.wav");

                enter = false;

                stateLoading = false;
                stateInicio = true;
                stateJogo = false;
                stateCreditos = false;

            }
        }


    }

    public void render(Graphics g) {
        if (stateInicio == true) {

            g.drawImage(Game.Menu[Game.idioma], 0, 0, Game.widthfm, Game.heightfm, null);

            g.setColor(Color.black);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 40));
            tam1 = g.getFontMetrics().stringWidth(txtmenu1[Game.idioma]);
            g.drawString(txtmenu1[Game.idioma], (Game.widthfm / 2) - (tam1 / 2), (Game.heightfm / 2) - 50);
            tam2 = g.getFontMetrics().stringWidth(txtmenu2[Game.idioma]);
            g.drawString(txtmenu2[Game.idioma], (Game.widthfm / 2) - (tam2 / 2), (Game.heightfm / 2));
            tam4 = g.getFontMetrics().stringWidth(txtidioma[Game.idioma]);
            g.drawString(txtidioma[Game.idioma], (Game.widthfm / 2) - (tam4 / 2), (Game.heightfm / 2) + 50);
            tam3 = g.getFontMetrics().stringWidth(txtmenu3[Game.idioma]);
            g.drawString(txtmenu3[Game.idioma], (Game.widthfm / 2) - (tam3 / 2), (Game.heightfm / 2) + 100);

            if (optionAtual == 0) {
                g.drawString(">", ((Game.widthfm / 2) - (tam1 / 2)) - 50, (Game.heightfm / 2) - 50);
            } else if (optionAtual == 1) {
                g.drawString(">", ((Game.widthfm / 2) - (tam2 / 2)) - 50, (Game.heightfm / 2));
            } else if (optionAtual == 2) {
                g.drawString(">", ((Game.widthfm / 2) - (tam4 / 2)) - 50, (Game.heightfm / 2) + 50);
            } else if (optionAtual == 3) {
                g.drawString(">", ((Game.widthfm / 2) - (tam3 / 2)) - 50, (Game.heightfm / 2) + 100);
            }

        } else if (stateCreditos == true) {

            g.drawImage(Game.Creditos[Game.idioma], 0, 0, Game.widthfm, Game.heightfm, null);

            g.setColor(Color.black);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 40));
            tam3 = g.getFontMetrics().stringWidth(txtcred1[Game.idioma]);
            g.drawString(txtcred1[Game.idioma], (Game.widthfm / 2) - (tam3 / 2), (Game.heightfm / 2) + 150);
            g.drawString(">", ((Game.widthfm / 2) - (tam3 / 2)) - 50, (Game.heightfm / 2) + 150);

        } else if (stateLoading == true) {
            time++;
            g.clearRect(0, 0, Game.widthfm, Game.heightfm);
            g.setColor(Game.BLUE);
            g.fillRect(0, 0, Game.widthfm, Game.heightfm);
            if (volta < limiteVolta) {
                if (time < 25) {

                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam1 = g.getFontMetrics().stringWidth(loadingTitle1[Game.idioma]);
                    g.drawString(loadingTitle1[Game.idioma], (Game.widthfm / 2) - (tam1 / 2), Game.heightfm - 50);
                } else if (time == 25) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 25 && time < 50) {

                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam2 = g.getFontMetrics().stringWidth(loadingTitle2[Game.idioma]);
                    g.drawString(loadingTitle2[Game.idioma], (Game.widthfm / 2) - (tam2 / 2), Game.heightfm - 50);
                } else if (time == 50) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 50 && time < 75) {

                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam3 = g.getFontMetrics().stringWidth(loadingTitle3[Game.idioma]);
                    g.drawString(loadingTitle3[Game.idioma], (Game.widthfm / 2) - (tam3 / 2), Game.heightfm - 50);
                } else if (time == 75) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 75 && time < 100) {


                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam4 = g.getFontMetrics().stringWidth(loadingTitle4[Game.idioma]);
                    g.drawString(loadingTitle4[Game.idioma], (Game.widthfm / 2) - (tam4 / 2), Game.heightfm - 50);


                } else if (time > 100) {


                    time = 0;
                    volta = volta + 1;
                }
            } else if (volta >= limiteVolta) {


                stateLoading = false;
                stateJogo = true;
            }

        }

    }

}
