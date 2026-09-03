# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services & AdMob
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }

# Firebase & Firestore
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Desugaring & Java 8+ features
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-dontwarn java.lang.invoke.**

# Flutter Play Core (deferred components) - not used but referenced by Flutter engine
-dontwarn com.google.android.play.core.**
