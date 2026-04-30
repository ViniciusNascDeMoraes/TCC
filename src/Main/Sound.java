package Main;

import java.io.File;

import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;



public class Sound {

	private static Clip clip;
	private static AudioInputStream inputStream;
	
	public static synchronized void play(final String fileName) {        
        new Thread(new Runnable() {
            public void run() {
                try {
                    clip = AudioSystem.getClip();
                    inputStream = AudioSystem.getAudioInputStream(new File(fileName));
                    clip.open(inputStream);
                    clip.start();
                } catch (Exception e) {
                    System.out.println("play sound error: " + e.getMessage() + " for " + fileName);
                }
            }
        }).start();
    }

}
