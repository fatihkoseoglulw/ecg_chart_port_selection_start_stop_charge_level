import processing.serial.*;
import controlP5.*;

Serial myPort;                                             // 
ControlP5 cp5;
DropdownList ports;
Button openButton, closeButton, refreshButton;
float[] ekgValues;                                         //           
int maxValues = 1250;                                      //          
int dataIndex = 0;                                         // 
boolean isRunning = false;                                  //        
float pixelPerValue = 1600 / (250 * 5.0);                  //
float timeOffset = 0;                                      // 
float zoomFactor = 1.0;                                    // Yakınlaştırma faktörü
float panOffset = 0;                                       // Yatay kaydırma değeri
boolean isPlayButtonPressed = false;                       // Oynat butonunun basılı olup olmadığını kontrol et
boolean isStopButtonPressed = false;                       // Durdur butonunun basılı olup olmadığını kontrol et
float timePerData = 4;                                     // ms cinsinden her veri noktası arası süre
float pixelPerMs = pixelPerValue / (timePerData / 1000.0); // Her ms için kaç piksel kaydırılacağını hesapla
boolean portVisible = false;

void setup() {
  size(1600, 720);
  ekgValues = new float[maxValues];
  cp5 = new ControlP5(this);
  createUI();  
  listPorts();
}

void drawECGBackground() {
  background(255, 240, 245); // Arka planı açık pembe yap

  // Grid çizgileri için renkler
  int lightGridColor = color(255, 200, 200);
  int darkGridColor = color(255, 150, 150);

  // İnce çizgiler için çizgi kalınlığı
  strokeWeight(1);

  // Küçük grid çizgileri
  for (int i = 0; i < width; i += 10) {
    stroke(lightGridColor);
    line(i, 0, i, height);
  }
  for (int i = 0; i < height; i += 10) {
    stroke(lightGridColor);
    line(0, i, width, i);
  }

  // Kalın çizgiler için çizgi kalınlığı
  strokeWeight(2);

  // Büyük grid çizgileri
  for (int i = 0; i < width; i += 50) {
    stroke(darkGridColor);
    line(i, 0, i, height);
  }
  for (int i = 0; i < height; i += 50) {
    stroke(darkGridColor);
    line(0, i, width, i);
  }
}

void drawVoltageScale() {
  // mV değerlerini çiz
  fill(0);
  textSize(12);
  textAlign(RIGHT, CENTER);
  // Y eksenini ortala
  float centerY = height / 2; 
  // Her büyük karede 0.5 mV artış
  for (int i = 0; i <= centerY; i += 50) { 
    float voltage = (centerY - i) / 10.0; // 10 piksel = 0.5 mV
    String voltageLabel = nf(voltage, 0, 1) + " mV";
    text(voltageLabel, 40, i);
    if(i != centerY) { // 0 mV etiketi sadece bir kere yazılmalı
      text("-" + voltageLabel, 40, centerY * 2 - i);
    }
  }
}

void drawTimeScale() {
  // Zaman çizelgesini çiz, zoomFactor ile ölçeklendirme yap
  fill(0);
  textSize(12);
  textAlign(CENTER, TOP);
  
  float timePerDivision = 0.4; // Her büyük karedeki zaman (saniye) artırıldı
  for (int division = 0; division < width / (100 * zoomFactor); division++) { // 100 pikselde bir bölüm, zoomFactor ile ölçeklendir
    float time = (division * timePerDivision * zoomFactor) + timeOffset; // Zamanı hesapla ve zoomFactor ile ölçeklendir
    String timeLabel = nf(time, 0, 2) + " s";
    text(timeLabel, division * 100 * zoomFactor, height - 15); // Metni zoomFactor ile ölçeklendir
  }
}

void drawBatteryLevel(float x, float y, float width, float height, float level) {
  // Pil çerçevesini çiz
  stroke(0);
  strokeWeight(3);
  fill(255);
  rect(x, y, width, height);

  // Pilin üst kısmını (bağlantı noktasını) çiz
  float connectorHeight = height * 0.15;
  rect(x + width * 0.3, y - connectorHeight, width * 0.4, connectorHeight);

  // Pil seviyesini çiz
  noStroke();
  float levels[] = {0.0, 0.2, 0.4, 0.6, 0.8, 1.0};
  int levelIndex = parseInt(level / 20); // Seviyeyi indexe dönüştür
  for (int i = 0; i <= levelIndex; i++) {
    if (i < levelIndex) {
      fill(0, 200, 0); // Tam dolu seviyeler için yeşil
    } else {
      float lastLevel = map(level % 20, 0, 20, 0, 1); // Son seviyeyi hesapla
      fill(0, 200, 0, 255 * lastLevel); // Yarı saydam yeşil
    }
    rect(x + 2, y + height - (i + 1) * (height / levels.length) + 2, 
         width - 4, (height / levels.length) - 4);
  }
  
  // Eğer pil seviyesi düşükse kırmızıyı göster
  if (level <= 20) {
    fill(200, 0, 0);
    rect(x + 2, y + height - (height / levels.length) + 2, 
         width - 4, (height / levels.length) - 4);
  }
}

void drawButtons() {
  // Oynat butonu
  if (isPlayButtonPressed) {
    fill(0, 150, 0); // Basıldığında rengi koyulaştır
  } else {
    fill(0, 200, 0);
  }
  rect(width - 150, 20, 100, 40);
  fill(255);
  text("Oynat", width - 100, 37);

  // Durdur butonu
  if (isStopButtonPressed) {
    fill(150, 0, 0); // Basıldığında rengi koyulaştır
  } else {
    fill(200, 0, 0);
  }
  rect(width - 150, 70, 100, 40);
  fill(255);
  text("Durdur", width - 100, 88);
}

void mousePressed() {
  // Oynat butonuna basıldığında
  if (mouseX > width - 150 && mouseX < width - 50 && mouseY > 20 && mouseY < 60) {
    myPort.write("1");
    isRunning = true;
    isPlayButtonPressed = true;
    isStopButtonPressed = false;
    
    if(isRunning)
    {      
      ports.setVisible(true);
      openButton.setVisible(true);
      closeButton.setVisible(true);
      refreshButton.setVisible(true); 
    }
  }
  
  // Durdur butonuna basıldığında
  if (mouseX > width - 150 && mouseX < width - 50 && mouseY > 70 && mouseY < 110) {
    myPort.write("2");
    isRunning = false;
    isStopButtonPressed = true;
    isPlayButtonPressed = false;
    if(isRunning)
    {      
      ports.setVisible(false);
      openButton.setVisible(false);
      closeButton.setVisible(false);
      refreshButton.setVisible(false); 
    }
  }
}

void mouseDragged() {
  // Mouse sürüklenirken yatay kaydırma değerini güncelle, yönü tersine çevir
  if (mouseButton == LEFT) {
    panOffset -= mouseX - pmouseX; // Buradaki değişiklik yönü tersine çevirecek
  }
}

void mouseWheel(MouseEvent event) {
  // Grafiği durdurulduğunda mouse tekerleği ile yakınlaştırma/uzaklaştırma
  if (!isRunning) { // Sadece grafik durdurulduğunda çalışır
    float e = -event.getCount();
    zoomFactor += e * 0.05;
    zoomFactor = constrain(zoomFactor, 0.5, 5.0); // Zoom sınırlarını belirle
  }
}


void drawECG() {
  stroke(0);
  noFill();
  beginShape();
  for (int i = 0; i < maxValues; i++) {
    int index = (dataIndex + i) % maxValues;
    float x = (i * pixelPerValue - panOffset) * zoomFactor; // Kaydırma ve zoom uygula
    float y = height / 2 - ekgValues[index] * 100;
    vertex(x, y);
  }
  endShape();
}

void draw() 
{
  drawECGBackground();
  drawVoltageScale();
  drawTimeScale();

  if(portVisible)
   {
      drawBatteryLevel(50, 50, 60, 120, 10); // Örnek kullanım, %40 dolulukta pil çiz
     drawButtons();
   }

  if (isRunning) {
    // Veri okuma ve işleme
    while (myPort.available() > 0) {
      String valueStr = myPort.readStringUntil('\n');
      if (valueStr != null && valueStr.trim().length() > 0) {
        String[] strValues = split(valueStr.trim(), '/');
        for (int i = 0; i < strValues.length; i++) {
          float value = float(strValues[i]);
          ekgValues[dataIndex] = value;
          dataIndex = (dataIndex + 1) % maxValues;

          // Her veri geldiğinde zaman çizelgesini sabit bir miktar kaydır
          timeOffset += 4.0 / 1000; // 4ms için pixelPerMs kullanarak kaydır
        }
      }
    }
  }

  drawECG();
}

void createUI()
{
   ports = cp5.addDropdownList("ports")
            .setPosition(1100, 20)
            .setSize(200, 100)
            .setItemHeight(20)
            .setBarHeight(20);

  // Butonlar
  openButton = cp5.addButton("openPort")
                .setPosition(1320, 20)
                .setSize(80, 30)
                .setLabel("Port Ac");

  closeButton = cp5.addButton("closePort")
                 .setPosition(1320, 55)
                 .setSize(80, 30)
                 .setLabel("Port Kapat");

  refreshButton = cp5.addButton("refreshPorts")
                   .setPosition(1320, 90)
                   .setSize(80, 30)
                   .setLabel("Port Yenile"); 
}

void listPorts() 
{
  String[] portNames = Serial.list();
  ports.clear();
  for (int i = 0; i < portNames.length; i++) 
  {
    ports.addItem(portNames[i], i);
  }
}

void openPort() 
{
  if (ports.getValue() != -1) 
  {
    String selectedPort = Serial.list()[(int)ports.getValue()];
    myPort = new Serial(this, selectedPort, 115200);
    isRunning = true;
    portVisible = true;
  }
}

void closePort() {
  if (myPort != null) {
    myPort.stop();
    myPort = null;
  }
  isRunning = false; // EKG veri akışını durdur
  portVisible = false;

  // UI elemanlarını tekrar görünür yap
  ports.setVisible(true);
  openButton.setVisible(true);
  closeButton.setVisible(true);
  refreshButton.setVisible(true);
}

void refreshPorts() 
{
  println("refresh");
  listPorts();
}
