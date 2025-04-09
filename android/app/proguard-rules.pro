-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

-keep class me.carda.awesome_notifications.** { *; }
-keepclassmembers class * {
    @me.carda.awesome_notifications.annotations.** *;
}
# ...existing code...