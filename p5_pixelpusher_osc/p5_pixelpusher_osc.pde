/*
 * 
 * scene compose de zone + etat   
 * message osc recu doit etre /pixelpusher/scene [int] (ZONE) [int] (ETAT)
 * example : /pixelpusher/scene 1 0 
 *   envoie un blackout a la zone 1 
 * example : /pixelpusher/scene 3 1 
 *   envoie l etat 1 dans la zone 3
 * zone = groupe de strip ayant le meme comportement;  total 4 zones dans le projets
 * etat (state)= defintion de comportement ; variable en fonction des zones
 * strip = une longueur de led physique total de 8 sur le hardware
 * les strip peuvent etre mappe en utilisant le array strips_zones
 * l etat de depart peut etre defini en utilisant scenes_zones
 *  le zero = desactive et un chiffre correspond a une zone
 *   ex; int[]{strip_zone = {1,2,2,2,3,3,3,0}  
 * etat = comportement lumineux attribuable 
 * 0; blackout, 1; allume, 2; fadeinout; etc...
 * GESTION D'ETAT
 *  Des etats peuvent etre infini ou auto-folow
 * une horloge 
 */

// Set net_without_led true to bypass checking 
// Serve to test when no pixel pusher on network
public boolean net_without_led = false; 

// choses importantes a potentiellement modifier
int[] strips_zones=   {1, 2, 3, 3, 3, 3, 4, 4};   // mapping des strips vers les zones
int[] init_scene_zones_states = {0, 3, 1, 1, 1}; 

int osc_host_port = 9090;

// automodifiee

int[] scenes_zones=   {0, 0, 0, 0, 0};           //start state (zone 0 is unassigned, all ) // premier element = void
int[] strips_states = {1, 1, 1, 1, 1, 1, 1, 1};
long[] zones_timestamps= {0, 0, 0, 0, 0};
float[] strips_elapses= {0, 0, 0, 0, 0, 0, 0, 0};
String[] commentaires= {" ", " ", " ", " ", " ", " ", " ", " ", };
float[] strip_color_picker = {50, 50, 50};

// pixelpusher
import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import java.util.*;
DeviceRegistry registry;


// osc
import oscP5.*;
import netP5.*;
OscP5 oscP5;
NetAddress myRemoteLocation; //futur expansion...



void setup() 
{
  registry = new DeviceRegistry();


  oscP5 = new OscP5(this, osc_host_port);


  // passe cool ou des fonction sont mapppe vers des path osc 
  oscP5.plug(this, "set_strips_states_from_zone", "/pixelpusher/scene");
  oscP5.plug(this, "reset_zones_states", "/pixelpusher/reset");
  oscP5.plug(this, "set_cp_hue", "/pixelpusher/cp_hue");
  oscP5.plug(this, "set_cp_saturation", "/pixelpusher/cp_saturation");
  oscP5.plug(this, "set_cp_luma", "/pixelpusher/cp_luma");

  // future expansion si necessaire : pour implementer la bidirrectionnalite de la communication
  //myRemoteLocation = new NetAddress("127.0.0.1", 9090);

  // Mettre le mode de couleur en HUE SATURATION BRIGHTNESS 
  colorMode(HSB, 100);
  // grosseur de la fenetre 
  size(480, 480);
  frameRate(60);

  //permet le bypass de previz
  textFont(createFont("SourceCodePro-Regular.ttf", 14));

  // set strips at init state 
  scenes_zones = init_scene_zones_states ;
  for (int i=0; i<scenes_zones.length; i++)
  {

    set_strips_states_from_zone(i, scenes_zones[i]);
  }
}

// OSC PARSING FUNCTIONS
void set_cp_hue(float _hue) {
  strip_color_picker[0]=_hue;
}
void set_cp_saturation(float _saturation) {
  strip_color_picker[1]=_saturation;
}
void set_cp_luma(float _luma) {
  strip_color_picker[2]=_luma;
}

void reset_zones_states()
{
  for (int i = 0; i < init_scene_zones_states.length; i++ )
  {
    set_strips_states_from_zone(i, init_scene_zones_states[i] );
  }
}

void set_strips_states_from_zone(int _zone, int _state)
{
  for (int zone =0; zone<8; zone++)
  {
    if (strips_zones[zone] == _zone )
    {
      strips_states[zone]=_state;
      zones_timestamps[_zone]=System.nanoTime();
    }
  }
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) 
{
  if (theOscMessage.isPlugged()==false) 
  {
    // implementer callback de reception ici si necessaire 
    // voir example plug dans OSCp5 si besoin
  }
}

void draw() 
{
  int x=0; // sert pour l indexation du readback de pixels pour le pixelpusher
  int y=0;  // idem

  // sert au pixel pusher
  registry.setFrameLimit(1000);   
  registry.startPushing();
  registry.setAntiLog(true);  
  int stripy = 0;
  List<Strip> strips = registry.getStrips();
  int numStrips = 0;
  int yscale = 0;

  if (!net_without_led)
  {
    numStrips = strips.size();
    // println("Strips total = "+numStrips);
    yscale = height / strips.size();
  } else {
    numStrips = 8;
  }

  // update et draw les couleurs  
  if (numStrips == 0)
    return;
  for (int stripNo = 0; stripNo < numStrips; stripNo++) 
  {
    // checker l'etat de la strip actuelle
    // lance le comportement associé 
    // heavy lifting.... >
    color led_color = zone_state_to_color(strips_zones[stripNo], strips_states[stripNo], stripNo);
    fill(led_color);
    rect(0, stripNo * (height/numStrips), width, (stripNo+1) * (height/numStrips)); 
    fill (100-hue(led_color), 100, 100);
    textSize(14);
    String label = "zone: " + strips_zones[stripNo] +" state: "+ strips_states[stripNo]+ " :: " +commentaires[stripNo];
    text(label, 0, height/numStrips*(stripNo+1)-24);
    text(strips_elapses[stripNo], 0, height/numStrips*(stripNo+1)-10);
  }    


  //get la couleur et update les pixels
  for (Strip strip : strips) 
  {
    int xscale = width / strip.getLength();
    for (int stripx = 0; stripx < strip.getLength(); stripx++) {
      x = stripx*xscale + 1;
      y = stripy*yscale + 1; 
      color c = get(x, y);

      // update the strips 
      if (!net_without_led) {
        strip.setPixel(c, stripx);
      };
    }
    stripy++;
  }
}


color zone_state_to_color(int _zone, int _state, int _strip)
{
  colorMode(HSB, 100);
  color return_color = color(50, 50, 50);
  String commentaire = "invalid";
  //convertir le timestamp en secondes 
  strips_elapses[_strip] = (System.nanoTime()-zones_timestamps[_zone])*0.000000001;

  // parse zones
  if (_zone == 1 )
  {
    if (_state == 0)
    {
      commentaire = "blackout";
      return_color = color (0, 0, 0);
    } else if (_state == 1)
    {
      commentaire =  "voyage dans le temps ";

      // séquence voyage dans le temps
      // bleu pale rentre en 5 sec à 75 %
      // suivi d un effet stroboscopique: couleur bleu pâle pendant 7 secondes
      //référence : https://www.tweaking4all.com/ hardware/arduino/adruino-led-strip-effects/ #LEDStripEffectStrobe
      //suivi de blanc 100 % d’un coup sec qui tombe à 25 % en 3 secondes

      if (strips_elapses[_strip] < 5)
      {
        float intensity = map(strips_elapses[_strip], 0, 5, 0, 75);
        return_color=color(60, 100, intensity);
      } else if (strips_elapses[_strip] < 12 )
      {
        float intensity = 60*((strips_elapses[_strip]*10)%2); 
        return_color=color(60, 100, intensity);
      } else if (strips_elapses[_strip] < 15 )
      {
        float intensity = map(strips_elapses[_strip], 12, 15, 100, 25);
        return_color=color(60, 0, intensity);
      } else {
        return_color=color(60, 0, 25);
      }
    } else if (_state == 2)
    {
      commentaire = "arrêt voyage";
      // arrêt voyage  
      //bleu pâle à 75 % quitte en 9 secondes   
      if (strips_elapses[_strip] < 9)
      {
        float intensity = map(strips_elapses[_strip], 0, 9, 75, 0);
        return_color=color(60, 100, intensity);
      } else {
        return_color = color (60, 100, 0);
      }
    } else if (_state == 3)
    {
      commentaire = "arrivée futur";
      //arrivée futur
      //intensité 25 % : bleu pâle
      return_color = color (60, 100, 25);
    } else // undef
    {
      commentaire = "state undefined ";
    }
  } else if (_zone == 2 ) 
  {
    if (_state == 0)
    {
      commentaire = "blackout";
      return_color = color (0, 0, 0);
    } else if (_state == 1)
    {
      commentaire = "arrivée futur ";
      return_color = color (60, 50, 100);
      //blanc froid à 50 % intensité
    } else // undef
    {
      commentaire = "state undefined ";
    }
  } else if (_zone == 3 ) 
  {
    if (_state == 0)
    {
      commentaire = "blackout";
      return_color = color (0, 0, 0);
    } else if (_state == 1)
    {
      commentaire = "ambiance pendant laser";
      //pulsation en vert
      //passe de 15 % à 50% en intensité lumineuse
      //rythme: respiration en apnée ( scaphandrier ou, darth vader)

      float LFO = sin(strips_elapses[_strip]*0.2);
      float intensity = map(LFO, -1, 1, 15, 50 );
      return_color = color (50, 100, intensity);
    } else if (_state == 2)
    {
      commentaire = "alarme lorsque lasers touchés";
      //pulsation rouge
      //commence à 100 %
      //descend à 25 % en 1 sec
      //revient d’un coup sec à 100 %
      float PHASOR = strips_elapses[_strip] % 1 /1;
      float intensity = map(PHASOR, 0, 1, 100, 25 );
      return_color = color (0, 100, intensity);
    } else if (_state == 3)
    {
      commentaire = "ambiance futur à la fin des lasers";
      //à 50 % d’intensité
      //mélange de bleu pâle et vert fluo (presque jaune)
      //style 1 mètres une couleur, 1 mètres une autres couleur
      color bleu_pale = color(60, 50, 60);
      color vert_fluo = color(30, 100, 60);

      if (_strip%2 == 0) //hack pas clean, mais permet un offset
      {
        return_color = bleu_pale;
      } else {
        return_color = vert_fluo;
      }
    } else if (_state == 4)
    {
      commentaire = "victoire";
      //blanc chaud â 100%
      return_color=color(30, 10, 100);
    } else // undef
    {
      commentaire = "state undefined";
    }
  } else if (_zone == 4 ) 
  {
    if (_state == 0)
    {
      commentaire = "blackout";
      return_color = color (0, 0, 0);
    } else if (_state == 1)
    {
      commentaire = "ambiance salle secrète";
      //une stripe rouge à 60 %
      if (_strip%2 == 0) //hack pas clean, mais permet un offset
      {
        return_color = color(0, 100, 60);
      } else {
        return_color = color(90, 100, 60);
      }

      //une stripe mauve 60 %
    } else if (_state == 2)
    {
      commentaire = "Victoire";
      return_color = color(0, 5, 100);
      //blanc chaud â 100%
    } else // undef
    {
      commentaire = "state undefined";
    }
  }

  if (_state == -1)
  {
    // color picker pour any strip
    commentaire = "Color Picker HSL";

    return_color = color(strip_color_picker[0], strip_color_picker[1], strip_color_picker[2]);
  }  

  commentaires[_strip]=commentaire;
  return return_color ;
}
