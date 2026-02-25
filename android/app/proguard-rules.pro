# --- ErrorProne (Avisos do Google) ---
-dontwarn com.google.errorprone.annotations.**
-keep class com.google.errorprone.annotations.** { *; }
-dontwarn com.google.errorprone.**

# --- Javax Annotations (O erro do Nullable) ---
-dontwarn javax.annotation.**
-keep class javax.annotation.** { *; }
-dontwarn javax.annotation.concurrent.**

# --- Animal Sniffer (Erro comum em libs Google) ---
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

# --- Criptografia (Tink e SQLCipher) ---
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

-keep class net.zetetic.database.sqlcipher.** { *; }
-dontwarn net.zetetic.database.sqlcipher.**

# --- Flutter Wrapper ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter/Dart
-dontwarn io.flutter.**
-dontwarn io.flutter.embedding.**

# Image Picker e Camera (comuns em gerar avisos)
-dontwarn com.google.android.gms.**
-dontwarn androidx.camera.**

# Pacote de PDF e Impressão (se houver avisos específicos)
-dontwarn com.sun.pdfview.**

# --- Manter nomes de métodos nativos (Essencial para SQLCipher) ---
-keepclasseswithmembernames class * {
    native <methods>;
}