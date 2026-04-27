package com.fynotech.prankcall.ads

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.fynotech.prankcall.R
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * Inflates one of our XML native-ad layouts and binds it to a [NativeAdView].
 */
class NativeLayoutAdFactory(
  private val context: Context,
  private val layoutResId: Int
) : GoogleMobileAdsPlugin.NativeAdFactory {
  companion object {
    private const val KEY_INTRO_LARGE_NATIVE_BTN_COLOR = "intro_large_native_btn_color"
    private const val KEY_INTRO_AD_BG_COLOR = "intro_ad_bg_color"
  }

  override fun createNativeAd(nativeAd: NativeAd, customOptions: Map<String, Any>?): NativeAdView {
    val inflater = LayoutInflater.from(context)
    val adView = inflater.inflate(layoutResId, null) as NativeAdView

    // Bind assets by stable R.id (avoid reflection issues).
    adView.headlineView = adView.findViewById(R.id.ad_headline)
    adView.bodyView = adView.findViewById(R.id.ad_body)
    adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
    adView.iconView = adView.findViewById(R.id.ad_app_icon)
    adView.advertiserView = adView.findViewById(R.id.ad_advertiser)
    adView.priceView = adView.findViewById(R.id.ad_price)
    adView.storeView = adView.findViewById(R.id.ad_store)
    adView.adChoicesView = adView.findViewById<AdChoicesView?>(R.id.ad_choices)
    adView.mediaView = adView.findViewById<MediaView?>(R.id.ad_media)
    applyCustomIntroColors(adView, customOptions)

    // Populate views (null-safe).
    try {
      (adView.headlineView as? TextView)?.text = nativeAd.headline
      val body = nativeAd.body
      if (body != null) {
        (adView.bodyView as? TextView)?.text = body
        adView.bodyView?.visibility = View.VISIBLE
      } else {
        adView.bodyView?.visibility = View.GONE
      }

      val advertiser = nativeAd.advertiser
      if (advertiser != null) {
        (adView.advertiserView as? TextView)?.text = advertiser
        adView.advertiserView?.visibility = View.VISIBLE
      } else {
        adView.advertiserView?.visibility = View.GONE
      }

      val price = nativeAd.price
      if (price != null) {
        (adView.priceView as? TextView)?.text = price
        adView.priceView?.visibility = View.VISIBLE
      } else {
        adView.priceView?.visibility = View.GONE
      }

      val store = nativeAd.store
      if (store != null) {
        (adView.storeView as? TextView)?.text = store
        adView.storeView?.visibility = View.VISIBLE
      } else {
        adView.storeView?.visibility = View.GONE
      }

      val cta = nativeAd.callToAction
      if (cta != null) {
        (adView.callToActionView as? TextView)?.text = cta
        adView.callToActionView?.visibility = View.VISIBLE
      } else {
        adView.callToActionView?.visibility = View.GONE
      }

      val icon = nativeAd.icon
      if (icon != null) {
        (adView.iconView as? ImageView)?.setImageDrawable(icon.drawable)
        adView.iconView?.visibility = View.VISIBLE
      } else {
        adView.iconView?.visibility = View.GONE
      }
    } catch (_: Throwable) {
      // Don't crash on layout mismatches; just show whatever binds safely.
    }

    adView.setNativeAd(nativeAd)
    return adView
  }

  private fun applyCustomIntroColors(adView: NativeAdView, customOptions: Map<String, Any>?) {
    val ctaView = adView.findViewById<View?>(R.id.ad_call_to_action) as? TextView

    // Keep onboarding full-screen native CTA on app primary button style.
    if (layoutResId == R.layout.full_screen_native) {
      ctaView?.setBackgroundResource(R.drawable.bg_btn_splash)
      return
    }

    if (customOptions == null) return

    val bgColor = parseColorOrNull(customOptions[KEY_INTRO_AD_BG_COLOR])
    if (bgColor != null) {
      adView.findViewById<View?>(R.id.ad_root_container)?.setBackgroundColor(bgColor)
    }

    val buttonColor = parseColorOrNull(customOptions[KEY_INTRO_LARGE_NATIVE_BTN_COLOR])
    if (buttonColor != null) {
      ctaView?.setBackgroundColor(buttonColor)
    }
  }

  private fun parseColorOrNull(value: Any?): Int? {
    val raw = value?.toString()?.trim().orEmpty()
    if (raw.isEmpty()) return null
    return try {
      Color.parseColor(raw)
    } catch (_: Throwable) {
      null
    }
  }
}

