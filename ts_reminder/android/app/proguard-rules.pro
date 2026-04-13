# Protect the notification plugin from being scrambled
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keep class * extends com.google.gson.reflect.TypeToken
