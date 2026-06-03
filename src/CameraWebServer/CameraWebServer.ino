#include "esp_camera.h"
#include <WiFi.h>

// ===========================
// ESP32-CAM AI Thinker
// ===========================
#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

const char *ssid = "Tachi";
const char *password = "Huy27022004";

void startCameraServer();

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println();

  // ===== Camera config =====
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;

  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // ===== CẤU HÌNH STREAM ỔN ĐỊNH =====
  config.frame_size   = FRAMESIZE_QVGA;   // 320x240
  config.jpeg_quality = 10;               // nhỏ hơn = chất lượng cao hơn (8-12 là hợp lý)
  config.fb_count     = 2;               // 2 buffer: 1 capture, 1 đang gửi → giảm độ trễ
  config.grab_mode    = CAMERA_GRAB_LATEST;
  config.fb_location  = CAMERA_FB_IN_PSRAM;

  // ===== Init camera =====
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("❌ Camera init failed: 0x%x\n", err);
    return;
  }
  Serial.println("✅ Camera init OK");
  delay(500); // chờ I2C bus ổn định trước khi ghi sensor

  // ===== KHÓA SENSOR (CHỐNG ĐEN MÀN) =====
  sensor_t *s = esp_camera_sensor_get();
  s->set_brightness(s, 1);
  s->set_saturation(s, 0);
  s->set_contrast(s, 0);

  // ===== WiFi =====
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  Serial.print("WiFi connecting");
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - wifiStart > 15000) {
      Serial.println("\n❌ WiFi timeout — restarting...");
      ESP.restart();
    }
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("✅ WiFi connected");

  // ===== Start server =====
  startCameraServer();

  Serial.print("📷 Camera Ready! Open: http://");
  Serial.println(WiFi.localIP());
}

void loop() {
  delay(10000);
}