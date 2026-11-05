/// fqapp 广告配置：全部 ID 集中在这里，正式 ID 到手后只改这一个文件。
///
/// 正式 ID（灰鲸后台“什锦铺”，App ID `246351`，全部审核通过）：开屏、
/// 插屏、激励、横幅已填正式 ID。信息流原生暂无正式 ID，已用
/// [feedEnabled] 关闭，正式 ID 到手后填 [feedId] 并打开开关即可恢复。
/// 绝不复用陪玩或其它应用的正式 ID。
/// 频率默认值是提议值（短剧 feed 每 5 集、5 集后激励解锁、小说
/// 每 3 章章末插屏），改数字即可调频，不用改调用处。
class AdConfig {
  const AdConfig._();

  /// 总开关：关掉后所有广告位都不加载、不展示，播放与阅读不受影响。
  static const bool enabled = true;

  /// 灰鲸 App ID（正式）。
  static const String appId = '246351';

  /// 各联盟 App ID：只填公开的 App ID，不要填密钥。
  /// 穿山甲/快手/百度/腾讯的激励不出，就是因为之前初始化时只传了
  /// 灰鲸 App ID，这四个联盟的 SDK 各要自己的 App ID 才能初始化。
  /// 从各联盟开放平台取（穿山甲开放平台、优量汇、快手联盟、百青藤），
  /// 空字符串表示不初始化该联盟；填好后重新构建才会生效。
  static const String csjAppId = '';

  /// 腾讯优量汇 App ID。
  static const String gdtAppId = '';

  /// 快手联盟 App ID。
  static const String kuaishouAppId = '';

  /// 百度联盟（百青藤）App ID。
  static const String baiduAppId = '';

  /// 各联盟 App ID 汇总（空的自动去掉）：初始化时传给原生侧。
  /// 日志里只记联盟名，不记 ID。
  static Map<String, String> get networkAppIds => <String, String>{
        if (csjAppId.isNotEmpty) 'csj': csjAppId,
        if (gdtAppId.isNotEmpty) 'gdt': gdtAppId,
        if (kuaishouAppId.isNotEmpty) 'kuaishou': kuaishouAppId,
        if (baiduAppId.isNotEmpty) 'baidu': baiduAppId,
      };

  /// 开屏广告位（正式）。
  static const String splashId = '1204449094057364';

  /// 插屏广告位（正式）：短剧切集、小说章末、漫画章末共用。
  static const String interstitialId = '4378475733228785';

  /// 激励视频广告位（正式）：5 集 / 章后解锁用。
  static const String rewardId = '0501744650090826';

  /// 信息流原生广告开关：暂无正式 ID，先关闭；正式 ID 到手后填
  /// [feedId] 并把这里改成 true。
  static const bool feedEnabled = false;

  /// 信息流原生广告位（DEMO 占位，正式 ID 待申请）：短剧 feed 卡片用，
  /// 仅模板（express）形态。当前 [feedEnabled] 为 false，不加载。
  static const String feedId = '1720369284141436';

  /// 横幅广告位（正式）。
  static const String bannerId = '5125440644328103';

  /// 短剧 feed 里原生广告卡出现的间隔（每 N 张卡片叠加一张广告卡）。
  static const int feedCardEvery = 5;

  /// 激励门免费集数：前 N 集 / 章直接看，从第 N+1 集 / 章起需要激励解锁。
  /// 短剧、漫剧、小说、漫画、听书共用这组数值。
  static const int rewardFreeEpisodes = 5;

  /// 一次激励解锁覆盖的集数：拿到一次奖励后，从当集 / 章起往后 N 集 / 章
  /// 直接看，不再弹激励；看完这批后下一集 / 章再出一次激励。
  static const int rewardUnlockBatch = 5;

  /// 小说章末插屏间隔（每 N 章出现一次）。
  static const int novelInterstitialEveryChapters = 3;

  /// 插屏最短展示间隔：两次插屏之间至少隔这么久，避免连弹。
  static const Duration interstitialMinInterval = Duration(minutes: 3);

  /// 播放页切集插屏间隔（每 N 集出现一次，1-based 集号整除时触发）。
  static const int episodeInterstitialEvery = 5;
}
