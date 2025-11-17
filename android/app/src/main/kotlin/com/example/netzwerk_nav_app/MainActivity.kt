package com.example.netzwerk_nav_app

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.telephony.*
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.example.netzwerk/nav"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call: MethodCall, result: MethodChannel.Result ->
      when (call.method) {
        "getAllInfo" -> {
          try {
            val data: HashMap<String, Any?> = hashMapOf(
              "telephony" to getTelephonyInfo(),
              "network" to getNetworkInfo()
            )
            result.success(data)
          } catch (e: SecurityException) {
            result.success(hashMapOf(
              "error" to ("SECURITY_EXCEPTION: ${e.message}"),
              "telephony" to null,
              "network" to null
            ))
          } catch (t: Throwable) {
            result.success(hashMapOf(
              "error" to ("ERROR: ${t.message}"),
              "telephony" to null,
              "network" to null
            ))
          }
        }
        "getWifiInfo" -> {
          try {
            result.success(getWifiInfo())
          } catch (e: SecurityException) {
            result.success(hashMapOf("error" to ("SECURITY_EXCEPTION: ${e.message}")))
          } catch (t: Throwable) {
            result.success(hashMapOf("error" to ("ERROR: ${t.message}")))
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun getTelephonyInfo(): HashMap<String, Any?> {
    val context = applicationContext
    val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    val info = hashMapOf<String, Any?>()

    // Basic
    info["simOperatorName"] = safe { telephony.simOperatorName }
    info["simCountryIso"] = safe { telephony.simCountryIso }
    info["dataNetworkType"] = safe { networkTypeToString(telephony.dataNetworkType) }

    // Cells
    val cellsList = arrayListOf<HashMap<String, Any?>>()
    val missingPermissions = arrayListOf<String>()
    try {
      val cells = telephony.allCellInfo
      if (cells != null) {
        for (c in cells) {
          cellsList.add(cellInfoToMap(c))
        }
      }
    } catch (se: SecurityException) {
      missingPermissions.add("ACCESS_FINE_LOCATION")
    }
    info["cells"] = cellsList

    // Emergency numbers (API 29+)
    info["emergencyNumbers"] = try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val map = telephony.emergencyNumberList
        val flat = mutableListOf<String>()
        map?.values?.forEach { list ->
          list.forEach { en ->
            flat.add(en.number)
          }
        }
        if (flat.isEmpty()) listOf("112", "911") else flat.distinct()
      } else listOf("112", "911")
    } catch (t: Throwable) { listOf("112", "911") }

    if (missingPermissions.isNotEmpty()) {
      info["missingPermissions"] = missingPermissions
    }

    return info
  }

  private fun cellInfoToMap(c: CellInfo): HashMap<String, Any?> {
    val m = hashMapOf<String, Any?>()
    m["registered"] = c.isRegistered
    when (c) {
      is CellInfoGsm -> {
        val id: CellIdentityGsm = c.cellIdentity
        val ss: CellSignalStrengthGsm = c.cellSignalStrength
        m["type"] = "GSM"
        m["cid"] = id.cid
        m["lac"] = id.lac
        m["mcc"] = safe { id.mccString }
        m["mnc"] = safe { id.mncString }
        m["asuLevel"] = ss.asuLevel
        m["dbm"] = ss.dbm
        m["level"] = ss.level
      }
      is CellInfoWcdma -> {
        val id: CellIdentityWcdma = c.cellIdentity
        val ss: CellSignalStrengthWcdma = c.cellSignalStrength
        m["type"] = "WCDMA"
        m["cid"] = id.cid
        m["lac"] = id.lac
        m["mcc"] = safe { id.mccString }
        m["mnc"] = safe { id.mncString }
        m["asuLevel"] = ss.asuLevel
        m["dbm"] = ss.dbm
        m["level"] = ss.level
      }
      is CellInfoLte -> {
        val id: CellIdentityLte = c.cellIdentity
        val ss: CellSignalStrengthLte = c.cellSignalStrength
        m["type"] = "LTE"
        m["ci"] = id.ci
        m["tac"] = id.tac
        m["mcc"] = safe { id.mccString }
        m["mnc"] = safe { id.mncString }
        m["asuLevel"] = ss.asuLevel
        m["dbm"] = ss.dbm
        m["level"] = ss.level
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          m["rsrp"] = ss.rsrp
          m["rsrq"] = ss.rsrq
          m["rssnr"] = ss.rssnr
        }
      }
      is CellInfoCdma -> {
        val ss: CellSignalStrengthCdma = c.cellSignalStrength
        m["type"] = "CDMA"
        m["asuLevel"] = ss.asuLevel
        m["dbm"] = ss.dbm
        m["level"] = ss.level
      }
      is CellInfoTdscdma -> {
        val id: CellIdentityTdscdma = c.cellIdentity
        val ss: CellSignalStrengthTdscdma = c.cellSignalStrength
        m["type"] = "TDSCDMA"
        m["cid"] = id.cid
        m["lac"] = id.lac
        m["mcc"] = safe { id.mccString }
        m["mnc"] = safe { id.mncString }
        m["asuLevel"] = ss.asuLevel
        m["dbm"] = ss.dbm
        m["level"] = ss.level
      }
      is CellInfoNr -> {
        m["type"] = "NR"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          val ss = safe { c.cellSignalStrength as CellSignalStrengthNr }
          val id = safe { c.cellIdentity as CellIdentityNr }
          if (id != null) {
            m["nci"] = id.nci
            m["tac"] = id.tac
            m["nrarfcn"] = id.nrarfcn
          }
          if (ss != null) {
            m["dbm"] = ss.dbm
            m["level"] = ss.level
          }
        }
      }
      else -> {
        m["type"] = c.javaClass.simpleName
      }
    }
    return m
  }

  private fun getNetworkInfo(): HashMap<String, Any?> {
    val context = applicationContext
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

    val info = hashMapOf<String, Any?>()

    val active = cm.activeNetwork
    val caps = cm.getNetworkCapabilities(active)

    fun has(transport: Int): Boolean {
      return caps?.hasTransport(transport) == true
    }

    info["wifi"] = has(NetworkCapabilities.TRANSPORT_WIFI)
    info["cellular"] = has(NetworkCapabilities.TRANSPORT_CELLULAR)

    // Bluetooth/Satellite presence (may be false if not active)
    info["bluetooth"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      has(NetworkCapabilities.TRANSPORT_BLUETOOTH)
    } else false
    info["satellite"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      has(NetworkCapabilities.TRANSPORT_SATELLITE)
    } else false

    // Roaming (best-effort)
    info["roaming"] = safe {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) telephony.isDataRoamingEnabled
      else @Suppress("DEPRECATION") telephony.isNetworkRoaming
    }

    // Metered
    @Suppress("DEPRECATION")
    val isMetered = cm.isActiveNetworkMetered
    info["metered"] = isMetered

    // Bandwidth (kbps)
    info["downKbps"] = caps?.linkDownstreamBandwidthKbps
    info["upKbps"] = caps?.linkUpstreamBandwidthKbps

    // Extra
    info["vpn"] = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    info["validated"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
    } else null

    return info
  }

  private fun getWifiInfo(): HashMap<String, Any?> {
    val ctx = applicationContext
    val wifi = ctx.getSystemService(Context.WIFI_SERVICE) as WifiManager
    val map = hashMapOf<String, Any?>()
    val wi: WifiInfo? = try { wifi.connectionInfo } catch (t: Throwable) { null }

    if (wi != null) {
      val freq = wi.frequency // MHz
      map["frequencyMHz"] = freq
      map["band"] = bandFromFrequency(freq)
      val ssidRaw = wi.ssid
      map["ssid"] = if (ssidRaw != null) ssidRaw.trim('"') else null
      map["linkSpeedMbps"] = wi.linkSpeed
      map["rssiDbm"] = wi.rssi
      map["bssid"] = wi.bssid
      map["ip"] = intIpToString(wi.ipAddress)
    }

    val bands = hashMapOf<String, Any?>()
    bands["2_4GHz"] = safe {
      try { wifi.javaClass.getMethod("is24GHzBandSupported").invoke(wifi) as Boolean } catch (t: Throwable) { null }
    }
    bands["5GHz"] = safe { wifi.is5GHzBandSupported }
    bands["6GHz"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) safe { wifi.is6GHzBandSupported } else null
    bands["60GHz"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) safe { wifi.is60GHzBandSupported } else null
    map["bandsSupported"] = bands

    return map
  }

  private fun bandFromFrequency(freqMHz: Int): String {
    return when (freqMHz) {
      in 2400..2500 -> "2.4 GHz"
      in 4900..5900 -> "5 GHz"
      in 5925..7125 -> "6 GHz"
      in 57000..71000 -> "60 GHz"
      else -> "Unbekannt"
    }
  }

  private fun intIpToString(ip: Int): String {
    return String.format(
      "%d.%d.%d.%d",
      (ip and 0xff),
      (ip shr 8 and 0xff),
      (ip shr 16 and 0xff),
      (ip shr 24 and 0xff)
    )
  }

  private fun networkTypeToString(type: Int): String = when (type) {
    TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS"
    TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE"
    TelephonyManager.NETWORK_TYPE_UMTS -> "UMTS"
    TelephonyManager.NETWORK_TYPE_CDMA -> "CDMA"
    TelephonyManager.NETWORK_TYPE_EVDO_0 -> "EVDO_0"
    TelephonyManager.NETWORK_TYPE_EVDO_A -> "EVDO_A"
    TelephonyManager.NETWORK_TYPE_1xRTT -> "1xRTT"
    TelephonyManager.NETWORK_TYPE_HSDPA -> "HSDPA"
    TelephonyManager.NETWORK_TYPE_HSUPA -> "HSUPA"
    TelephonyManager.NETWORK_TYPE_HSPA -> "HSPA"
    TelephonyManager.NETWORK_TYPE_IDEN -> "IDEN"
    TelephonyManager.NETWORK_TYPE_EVDO_B -> "EVDO_B"
    TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
    TelephonyManager.NETWORK_TYPE_EHRPD -> "EHRPD"
    TelephonyManager.NETWORK_TYPE_HSPAP -> "HSPAP"
    TelephonyManager.NETWORK_TYPE_GSM -> "GSM"
    TelephonyManager.NETWORK_TYPE_TD_SCDMA -> "TD_SCDMA"
    TelephonyManager.NETWORK_TYPE_IWLAN -> "IWLAN"
    TelephonyManager.NETWORK_TYPE_NR -> "NR"
    else -> "UNKNOWN"
  }

  private fun <T> safe(block: () -> T?): T? {
    return try { block() } catch (t: Throwable) { null }
  }
}
