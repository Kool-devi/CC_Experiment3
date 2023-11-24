// Referred from: Daniel Shiffman
// http://codingtra.in
// http://patreon.com/codingtrain
// Code for: https://youtu.be/1scFcY-xMrI

//Importing relevant libraries

import processing.video.*;
import processing.serial.*;
import cc.arduino.*;

//Calling the arduino using Firmata

Arduino myArduino;
Serial arduinoPort;  // Create object from Serial class

//Starting video capture

Capture video;


//Declaring variables

int servoPin = 2;
int servoAngle_value;
int CVPin = 9; //arduino pin to attach 3.5 mm control voltage jack
int CVvolt; //record and send captured voltage to sound synth

//used for converting from pixels to angles
int minServoAngle = 0;
int maxServoAngle = 180;

//color for tracking the motion in the blob
color trackColor; 
float threshold = 25;
float distThreshold = 50;

int maxLife = 50;
int blobCounter = 0;



ArrayList<Blob> blobs = new ArrayList<Blob>();

void setup() {
  size(640, 360);
  
  //printArray(Serial.list());  // List COM-ports
  // Open the port that the Arduino is connected to (change this to match your setup)
  printArray(Arduino.list());
  myArduino = new Arduino(this, Arduino.list()[2], 57600);
  myArduino.pinMode(servoPin, Arduino.SERVO);
  
  String[] cameras = Capture.list();
  printArray(cameras);
  video = new Capture(this,cameras[1]);
  video.start();
}

void captureEvent(Capture video) {
  video.read();
}

//Useful function to increase and decrease thresholds while the sketch is running for debugging

void keyPressed() {
  if (key == 'a') {
    distThreshold+=5;
  } else if (key == 'z') {
    distThreshold-=5;
  }
  if (key == 's') {
    threshold+=5;
  } else if (key == 'x') {
    threshold-=5;
  }


  println(distThreshold);
}


void draw() {
  video.loadPixels();
  image(video, 0, 0);
  
  trackColor = color(255, 105, 52);
  
  ArrayList<Blob> currentBlobs = new ArrayList<Blob>();

  
  //blobs.clear();


  // Begin loop to walk through every pixel
  for (int x = 0; x < video.width; x++ ) {
    for (int y = 0; y < video.height; y++ ) {
      int loc = x + y * video.width;
      // What is current color
      color currentColor = video.pixels[loc];
      float r1 = red(currentColor);
      float g1 = green(currentColor);
      float b1 = blue(currentColor);
      float r2 = red(trackColor);
      float g2 = green(trackColor);
      float b2 = blue(trackColor);

      float d = distSq(r1, g1, b1, r2, g2, b2); 

      if (d < threshold*threshold) {

        boolean found = false;
        for (Blob b : blobs) {
          if (b.isNear(x, y)) {
            b.add(x, y);
            found = true;
            break;
          }
        }

        if (!found) {
          Blob b = new Blob(x, y);
          blobs.add(b);
        }
      }
    }
  }
  
  for (int i = currentBlobs.size()-1; i >= 0; i--) {
    if (currentBlobs.get(i).size() < 500) {
      currentBlobs.remove(i);
    }
  }


  // There are no blobs!
  if (blobs.isEmpty() && currentBlobs.size() > 0) {
    println("Adding blobs!");
    for (Blob b : currentBlobs) {
      b.id = blobCounter;
      blobs.add(b);
      blobCounter++;
    }
  } else if (blobs.size() <= currentBlobs.size()) {
    // Match whatever blobs you can match
    for (Blob b : blobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob cb : currentBlobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();         
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !cb.taken) {
          recordD = d; 
          matched = cb;
        }
      }
      matched.taken = true;
      b.become(matched);
    }
    
    
for (Blob b : currentBlobs) {
      if (!b.taken) {
        b.id = blobCounter;
        blobs.add(b);
        blobCounter++;
      }
    }
  } else if (blobs.size() > currentBlobs.size()) {
    for (Blob b : blobs) {
      b.taken = false;
    }

    // Match whatever blobs you can match
    for (Blob cb : currentBlobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob b : blobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();         
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !b.taken) {
          recordD = d; 
          matched = b;
        }
      }
      if (matched != null) {
        matched.taken = true;
        // Resetting the lifespan here is no longer necessary since setting `lifespan = maxLife;` in the become() method in Blob.pde
        // matched.lifespan = maxLife;
        matched.become(cb);
      }
    }
    
        for (int i = blobs.size() - 1; i >= 0; i--) {
      Blob b = blobs.get(i);
      if (!b.taken) {
        if (b.checkLife()) {
          blobs.remove(i);
        }
      }
    }
  }

  textAlign(RIGHT);
  fill(0);
  text("distance threshold: " + distThreshold, width-10, 25);
  text("color threshold: " + threshold, width-10, 50);
  
  
  //show which port is connected
  text("Port: "+Serial.list()[0],20,20);
  //get mouseX and convert it to 0 - 180 as an integer
  //servoAngle_value = round(map(avgX,0,width,minServoAngle,maxServoAngle));
  
  
//creating a section that checks for all the blobs in the sketch 
  for (Blob b : blobs){
    
    b.show(); //starts by showing the blobs detected 
    servoAngle_value = round(map(b.getCenterX(), 0, width, 46.4, 136.6)); //mapping the X value of the center of the blobs to the servo angle
  //println(servoAngle_value);
  // Send the servo angle to the Arduino
  myArduino.servoWrite(servoPin, servoAngle_value);
  
  CVvolt = round(map(servoAngle_value, 136.6, 46.4, 0, 255)); //mapping the servo angle to output voltage to be sent to 3.5 mm control voltage jack
    //CVvolt = 255;
  myArduino.analogWrite(9, CVvolt);
  }
} //End of draw loop


// Custom distance functions w/ no square root for optimization
float distSq(float x1, float y1, float x2, float y2) {
  float d = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1);
  return d;
}


float distSq(float x1, float y1, float z1, float x2, float y2, float z2) {
  float d = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1) +(z2-z1)*(z2-z1);
  return d;
}

//void getColor(float r, float g, float b) {
//  trackColor = color(r,g,b);
//}

//using a mouse function to quickly check the color of the thing to be tracked and set the r g b values as the track color 
void mousePressed() {
trackColor = getColor();
println("R=" + red(trackColor) + "G=" + green(trackColor) + "B=" + blue(trackColor));
  
//  // Save color where the mouse is clicked in trackColor variable
//  int loc = mouseX + mouseY*video.width;
//  trackColor = video.pixels[loc];
}

color getColor() {
  loadPixels();
  int x = mouseX;
  int y = mouseY;
  if(x >= 0 && x <= width && y >= 0 && y <= height) {
    int loc = x + y * width;
    return pixels[loc];
  }
  else{
    return color(0);
  }
}
