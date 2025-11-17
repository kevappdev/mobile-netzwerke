import Flutter
import UIKit
import CoreTelephony
import SystemConfiguration.CaptiveNetwork

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.example.netzwerk/nav", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAllInfo":
        result([
          "telephony": self.getTelephonyInfo(),
          "network": self.getNetworkInfo(),
        ])
      case "getWifiInfo":
        result(self.getWifiInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getTelephonyInfo() -> [String: Any?] {
    var dict: [String: Any?] = [:]
    if #available(iOS 12.0, *) {
      let netInfo = CTTelephonyNetworkInfo()
      if let providers = netInfo.serviceSubscriberCellularProviders {
        let names = providers.values.compactMap { $0.carrierName }
        dict["simOperatorName"] = names.first ?? "unbekannt"
        dict["simCountryIso"] = providers.values.compactMap { $0.isoCountryCode }.first ?? ""
      }
      if let techs = CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology?.values {
        dict["dataNetworkType"] = techs.first ?? ""
      }
    } else {
      let netInfo = CTTelephonyNetworkInfo()
      if let carrier = netInfo.subscriberCellularProvider {
        dict["simOperatorName"] = carrier.carrierName
        dict["simCountryIso"] = carrier.isoCountryCode
      }
      dict["dataNetworkType"] = CTTelephonyNetworkInfo().currentRadioAccessTechnology
    }
    dict["cells"] = []
    dict["emergencyNumbers"] = ["112", "911"]
    return dict
  }

  private func getNetworkInfo() -> [String: Any?] {
    return [
      "wifi": NSNull(),
      "cellular": NSNull(),
      "bluetooth": NSNull(),
      "satellite": NSNull(),
      "roaming": NSNull(),
      "metered": NSNull(),
      "downKbps": NSNull(),
      "upKbps": NSNull(),
      "vpn": NSNull(),
      "validated": NSNull()
    ]
  }

  private func getWifiInfo() -> [String: Any?] {
    // Ohne spezielle Entitlements sind SSID/BSSID unter iOS oft nicht zugänglich.
    var map: [String: Any?] = [:]
    map["ssid"] = "(erfordert spezielle iOS-Entitlements)"
    map["frequencyMHz"] = NSNull() // iOS liefert Frequenz nicht über öffentliche APIs
    map["linkSpeedMbps"] = NSNull()
    map["rssiDbm"] = NSNull()
    map["bssid"] = NSNull()
    map["ip"] = NSNull()
    map["bandsSupported"] = [
      "2_4GHz": NSNull(),
      "5GHz": NSNull(),
      "6GHz": NSNull(),
      "60GHz": NSNull()
    ]
    return map
  }
}
