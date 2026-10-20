// ── exFAT 外接碟 ───────────────────────────────────────────────────────
//
// 專案放在 exFAT 上時，macOS 在每個檔案旁生出 `._*`（AppleDouble）。Gradle 會把
// `app/src/main/res/._mipmap-*`、`jniLibs/._libfoo.so` 之類當成資源或原生函式庫收進去，
// 建置中途的產物旁也會冒出來，症狀是 "… is not a directory"。
//
// 寫在 settings 裡：**任何** Gradle 呼叫（命令列、Android Studio、CI）都先經過這裡，
// 不必記得先跑哪一支腳本。做兩件事：
//   1. 每次進 Gradle 先清掉原始碼與產物目錄裡的 `._*`；
//   2. 在非 APFS／HFS+ 的磁碟上，沒有指定 KAIRUMO_GRADLE_BUILD_ROOT 時，自動把 build 目錄
//      導到本機 `~/Library/Caches/Kairumo/gradle/<專案路徑雜湊>/build`（build.gradle.kts 讀）。
//      雜湊讓主目錄與各 worktree 各用各的，不會互相蓋掉產物。
// 與 scripts/lib-exfat.sh 同一套規則；那支腳本設的環境變數優先。
run {
    val fsType = runCatching {
        java.nio.file.Files.getFileStore(settingsDir.toPath()).type().lowercase()
    }.getOrDefault("")
    val onAppleFs = fsType.isEmpty() || fsType.contains("apfs") || fsType.contains("hfs")

    var buildRoot = System.getenv("KAIRUMO_GRADLE_BUILD_ROOT")?.takeIf { it.isNotBlank() }
    if (buildRoot == null && !onAppleFs) {
        // 與 scripts/gradle.sh 同一個雜湊（路徑的 SHA-1 前 8 碼），兩條路用同一個建置目錄。
        val tag = java.security.MessageDigest.getInstance("SHA-1")
            .digest(settingsDir.absolutePath.toByteArray())
            .joinToString("") { "%02x".format(it) }.take(8)
        buildRoot = "${System.getProperty("user.home")}/Library/Caches/Kairumo/gradle/$tag/build"
        println("ℹ️  非 APFS 磁碟（$fsType）：Gradle 建置目錄改放 $buildRoot")
    }
    buildRoot?.let { gradle.extensions.extraProperties["kairumoBuildRoot"] = it }

    val dirs = listOf("app/src", "prebuilt", "app/build", "build", ".gradle", ".kotlin")
        .map { File(settingsDir, it) } + listOfNotNull(buildRoot?.let(::File))
    var removed = 0
    for (dir in dirs) {
        if (!dir.isDirectory) continue
        dir.walkTopDown()
            .filter { it.name.startsWith("._") && it.isFile }
            .forEach { if (it.delete()) removed++ }
    }
    if (removed > 0) println("🧹 Gradle 前清除 macOS 附屬檔 $removed 個")
}

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Kairumo"
include(":app")
