package Main;

import java.awt.*;

public class Menu {
    public String[] options = {"novo jogo", "creditos", "sair"};
    public int optionAtual = 0;
    public int optionMax = options.length - 1;
    public int tam1, tam2, tam3, tam4;

    public String txtmenu1 = "Novo jogo", txtmenu2 = "Cr�ditos",
            txtmenu3 = "Sair";
    public String txttitulocred = "Desenvolvido por:",
            txtcred1 = "Voltar";
    public boolean w = false, s = false, enter = false;
    public boolean stateInicio = true, stateCreditos = false, stateJogo = false, stateLoading = false;
    public int time, volta, limiteVolta = 3;
    String loadingTitle1 = "Carregando", loadingTitle2 = "Carregando.", loadingTitle3 = "Carregando..", loadingTitle4 = "Carregando...";

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

                if (optionAtual == 2) {


                    System.exit(0);

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

            g.drawImage(Game.Menu, 0, 0, Game.widthfm, Game.heightfm, null);

            g.setColor(Color.black);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 40));
            tam1 = g.getFontMetrics().stringWidth(txtmenu1);
            g.drawString(txtmenu1, (Game.widthfm / 2) - (tam1 / 2), (Game.heightfm / 2) - 50);
            tam2 = g.getFontMetrics().stringWidth(txtmenu2);
            g.drawString(txtmenu2, (Game.widthfm / 2) - (tam2 / 2), (Game.heightfm / 2));
            tam3 = g.getFontMetrics().stringWidth(txtmenu3);
            g.drawString(txtmenu3, (Game.widthfm / 2) - (tam3 / 2), (Game.heightfm / 2) + 50);

            if (options[optionAtual] == "novo jogo") {
                g.drawString(">", ((Game.widthfm / 2) - (tam1 / 2)) - 50, (Game.heightfm / 2) - 50);
            } else if (options[optionAtual] == "creditos") {
                g.drawString(">", ((Game.widthfm / 2) - (tam2 / 2)) - 50, (Game.heightfm / 2));
            } else if (options[optionAtual] == "sair") {
                g.drawString(">", ((Game.widthfm / 2) - (tam3 / 2)) - 50, (Game.heightfm / 2) + 50);
            }

        } else if (stateCreditos == true) {

            g.drawImage(Game.Creditos, 0, 0, Game.widthfm, Game.heightfm, null);

            g.setColor(Color.black);
            g.setFont(new Font("Bookman Old Style", Font.BOLD, 40));
            tam3 = g.getFontMetrics().stringWidth(txtcred1);
            g.drawString(txtcred1, (Game.widthfm / 2) - (tam3 / 2), (Game.heightfm / 2) + 150);
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
                    tam1 = g.getFontMetrics().stringWidth(loadingTitle1);
                    g.drawString(loadingTitle1, (Game.widthfm / 2) - (tam1 / 2), Game.heightfm - 50);
                } else if (time == 25) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 25 && time < 50) {

                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam2 = g.getFontMetrics().stringWidth(loadingTitle2);
                    g.drawString(loadingTitle2, (Game.widthfm / 2) - (tam2 / 2), Game.heightfm - 50);
                } else if (time == 50) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 50 && time < 75) {

                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam3 = g.getFontMetrics().stringWidth(loadingTitle3);
                    g.drawString(loadingTitle3, (Game.widthfm / 2) - (tam3 / 2), Game.heightfm - 50);
                } else if (time == 75) {
                    g.clearRect(0, 0, Game.widthfm, Game.heightfm);
                    g.setColor(Game.BLUE);
                    g.fillRect(0, 0, Game.widthfm, Game.heightfm);
                } else if (time > 75 && time < 100) {


                    g.setColor(Color.black);
                    g.setFont(new Font("Bookman Old Style", Font.BOLD, 50));
                    tam4 = g.getFontMetrics().stringWidth(loadingTitle4);
                    g.drawString(loadingTitle4, (Game.widthfm / 2) - (tam4 / 2), Game.heightfm - 50);


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
