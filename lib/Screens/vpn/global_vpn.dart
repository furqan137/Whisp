class GlobalVPN {
  static bool isConnected = false;
  static String? selectedCountry;
  static String? selectedFile;

  static String vpnStatus = "Disconnected";
  static String vpnStage = "Idle";

  static Function(String)? onStatusCallback;
  static Function(String)? onStageCallback;

  static void init() {
    // Nothing to initialize now, but required for compatibility
    print("🌍 Global VPN system initialized.");
  }

  static void connect(String country, String file) {
    selectedCountry = country;
    selectedFile = file;
    isConnected = true;

    vpnStatus = "Connected";
    vpnStage = "Virtual tunnel active";

    onStatusCallback?.call(vpnStatus);
    onStageCallback?.call(vpnStage);
  }

  static void disconnect() {
    isConnected = false;

    vpnStatus = "Disconnected";
    vpnStage = "Idle";

    onStatusCallback?.call(vpnStatus);
    onStageCallback?.call(vpnStage);
  }

  static String get lastStatus => vpnStatus;
  static String get lastStage => vpnStage;
}
