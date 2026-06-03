#include "esp_camera.h"
#include <WiFi.h>

// ===========================
// ESP32-CAM AI Thinker
// ===========================
#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

const char *ssid = "ManhHung";
const char *password = "baanhkhoa";
const char *apSsid = "ESP32-CAM-Posturer";
const char *apPassword = "12345678";

void startCameraServer();

const char *wifiStatusName(wl_status_t status) {
  switch (status) {
    case WL_IDLE_STATUS:
      return "idle";
    case WL_NO_SSID_AVAIL:
      return "ssid not found";
    case WL_SCAN_COMPLETED:
      return "scan completed";
    case WL_CONNECTED:
      return "connected";
    case WL_CONNECT_FAILED:
      return "connect failed";
    case WL_CONNECTION_LOST:
      return "connection lost";
    case WL_DISCONNECTED:
      return "disconnected";
    default:
      return "unknown";
  }
}

bool connectToWiFi() {
  WiFi.persistent(false);
  WiFi.disconnect(true, true);
  delay(500);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  Serial.printf("Scanning for WiFi SSID: %s\n", ssid);
  int networkCount = WiFi.scanNetworks();
  Serial.printf("Found %d WiFi network(s):\n", networkCount);

  bool foundTarget = false;
  for (int i = 0; i < networkCount; i++) {
    Serial.printf("  %d. %s, RSSI: %d dBm, channel: %d\n", i + 1, WiFi.SSID(i).c_str(), WiFi.RSSI(i), WiFi.channel(i));
    if (WiFi.SSID(i) == ssid) {
      foundTarget = true;
    }
  }

  if (!foundTarget) {
    Serial.println("Target SSID was not found during scan. Check spelling, 2.4 GHz support, and hotspot visibility.");
  }

  Serial.print("WiFi connecting");
  WiFi.begin(ssid, password);
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 30000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected");
    Serial.print("Camera Ready! Open: http://");
    Serial.println(WiFi.localIP());
    return true;
  }

  Serial.print("WiFi failed: ");
  Serial.println(wifiStatusName(WiFi.status()));
  return false;
}

void startFallbackAccessPoint() {
  WiFi.disconnect(true, true);
  delay(500);
  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);

  if (!WiFi.softAP(apSsid, apPassword)) {
    Serial.println("Failed to start fallback AP.");
    return;
  }

  Serial.println("Started fallback WiFi access point.");
  Serial.print("Connect your Mac/iPhone to WiFi: ");
  Serial.println(apSsid);
  Serial.print("Password: ");
  Serial.println(apPassword);
  Serial.print("Camera Ready! Open: http://");
  Serial.println(WiFi.softAPIP());
}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println();

  // ===== Camera config =====
  camera_config_t config = {};
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
  if (!connectToWiFi()) {
    startFallbackAccessPoint();
  }

  // ===== Start server =====
  startCameraServer();
}

void loop() {
  delay(10000);
}
