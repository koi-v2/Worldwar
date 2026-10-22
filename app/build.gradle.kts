plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.koi.growworld"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.koi.growworld"
        minSdk = 23
        targetSdk = 28
        versionCode = 1
        versionName = "0.1"
    }
}
