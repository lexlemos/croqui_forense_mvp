# --- OPÇÃO NUCLEAR: Ignorar avisos gerais ---
# Isso diz ao R8: "Se faltar alguma classe de anotação, apenas continue"
-ignorewarnings

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

# --- Manter nomes de métodos nativos (Essencial para SQLCipher) ---
-keepclasseswithmembernames class * {
    native <methods>;
}