package Main;

import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.LineEvent;
import javax.sound.sampled.LineListener;
import java.io.File;


public class Sound {

    public static void play(final String fileName) {
        new Thread(new Runnable() {
            public void run() {
                try (AudioInputStream inputStream = AudioSystem.getAudioInputStream(new File(fileName))) {
                    final Clip clip = AudioSystem.getClip();
                    // Libera a linha de audio quando o som termina; sem isso cada som tocado fica aberto.
                    clip.addLineListener(new LineListener() {
                        public void update(LineEvent event) {
                            if (event.getType() == LineEvent.Type.STOP) {
                                clip.close();
                            }
                        }
                    });
                    clip.open(inputStream);
                    clip.start();
                } catch (Exception e) {
                    System.out.println("play sound error: " + e.getMessage() + " for " + fileName);
                }
            }
        }).start();
    }

}
