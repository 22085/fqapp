# Vendoring notes — flutter_ads_plugin (Huijing 5.6.1.2 / ad-mill 5.6.1)
#
# Source: user-supplied `flutter_ads_plugin-hj561_3_45sm.zip` (plugin
# version 0.0.1, Android-only). Vendored at `plugins/flutter_ads_plugin`
# as a path dependency so fqapp can patch it without forking the SDK.
# The 17 AARs in `android/libs/` are byte-identical to the ones bundled
# in the peiwan Huijing build (sampled SHA-256 matches); only the
# wrapper code below was changed. No AAR was modified.
#
# Patches applied on top of the supplied zip:
# 1. `FlutterAdsPlugin.java`: `setDebugEnable(true)` -> `false` (both
#    init paths). DJX removed: `init2` no longer builds a
#    WMNetworkConfig/DJXSdk init block, and the `openDJX` branch plus
#    `TubeActivity` (and its layout) are deleted. fqapp has its own
#    drama player and never calls `openDJX`; keeping DJX would pull
#    pangrowth deps that do not resolve under fqapp's toolchain.
# 2. Dart (`lib/flutter_ads_plugin.dart`): one shared `StreamSubscription`
#    per event channel (splash/interstitial/reward), cancelled before
#    each new load, instead of a fresh `listen()` per load call that
#    leaked listeners and double-fired callbacks.
# 3. `FeedView`/`BannerView.dispose()`: detach the view hierarchy and
#    drop the native ad / method-call handler instead of doing nothing.
# 4. `AndroidManifest.xml`: stripped READ_PHONE_STATE, storage,
#    location, QUERY_ALL_PACKAGES, REQUEST_INSTALL_PACKAGES, GET_TASKS,
#    EXPAND_STATUS_BAR and CHANGE_WIFI_STATE; removed the upstream
#    permissive `network_security_config` (fqapp's own strict config
#    wins in the manifest/resource merge) and the TubeActivity entry.
# 5. `android/build.gradle`: rewritten to the modern Flutter plugin
#    form (no AGP 7.4.2 buildscript pin, compileSdk from the Flutter
#    toolchain, Java 17, okhttp 4.12.0 to match fqapp, AARs via
#    `files()`). Pangrowth DJX deps dropped with TubeActivity.
# 6. Removed: `example/`, docx notes, `.idea/`, Gradle caches, the
#    plugin's own `pubspec.lock`.
#
# fqapp-side requirements (outside this plugin):
# - `android/gradle.properties`: `android.enableJetifier=true` (the
#   Kuaishou/Pangle providers extend support-library FileProvider;
#   without Jetifier the app crashes at provider install, as peiwan
#   1.9.3/1.9.6 did).
# - `android/app/src/main/AndroidManifest.xml`: `tools:replace`
#   for `android:allowBackup` (Baidu AAR declares allowBackup=true;
#   fqapp declares false).
#
# IDs: all placement IDs used by fqapp live in
# `lib/services/ad_config.dart` and are DEMO IDs from the plugin
# example until fqapp's formal Huijing IDs are supplied. Never reuse
# peiwan's or WeatherMaster's formal IDs here.

7. AAR wiring: AGP 9 refuses direct `files('libs/*.aar')` dependencies in
   a library module (the AARs would not be packaged in the plugin AAR).
   The 18 AARs are therefore declared via a `flatDir { dirs 'libs' }`
   repository as `api(name: '<file name minus .aar>', ext: 'aar')`. The
   AAR files themselves are untouched. (The `files()` form was masked
   in earlier runs: the Gradle daemon died of OOM during R8 before the
   bundle task reported it.) The flatDir repository must ALSO be
   declared in the root `allprojects` repositories
   (android/build.gradle.kts): dependency resolution runs in the
   consuming (:app) project's context, so a flatDir declared only in
   the plugin is invisible there and every AAR fails with
   "Could not find :<name>:" at :app:mergeReleaseNativeLibs.

# 8. 2026-11-05 广告优化：
# - 联盟初始化：`FlutterAdsPlugin.init` 在 `startWithAppId` 之前
#   按 `AdConfig.networkAppIds` 组装 `WMNetworkConfig` 再调
#   `setInitNetworkConfig`（另调 `setInitForGromore/Pangle/Gdt/
#   Kuaishou`）。之前只传灰鲸 App ID，`startWithAppId` 内部读到的
#   `wmNetworkConfig` 为空，穿山甲/快手/百度/腾讯的 SDK 从没初始
#   化，激励只有别的联盟能出。各联盟 App ID 填在 `AdConfig` 里
#   （csjAppId/gdtAppId/kuaishouAppId/baiduAppId），空的跳过；
#   穿山甲同时按 CSJ 和 GROMORE 两个 id 登记，共用同一个 App ID。
# - 激励大退：`RewardAd.java` 所有事件改走 `sendEvent`，close/
#   error 后 `endStream` 并丢弃 sink，迟到回调不再往已结束的流里
#   发；`AdService` 的 `destroyReward` 从 `finally` 移到下一次
#   加载前（广告刚关闭、Activity 还在收尾时 destroy 会把宿主带掉）。
# - 横幅不出：`AdBanner` 加载失败不再永久隐藏，退避重试
#   15s/30s/60s…最多 5 次，重试时重建 AndroidView 重新拉；
#   `BannerView` 的 load error 同时回传 code，不止 msg。
