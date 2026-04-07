package com.example.noor_new // ✅ Ensure this matches your applicationId

import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class MyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        // Empty implementation. 
        // The widget layout is defined in XML (sos_widget.xml).
        // The click action is handled by the Flutter background callback.
        // No Kotlin code is needed for basic functionality.
    }
}