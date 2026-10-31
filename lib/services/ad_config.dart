/// fqapp 广告配置：全部 ID 集中在这里，正式 ID 到手后只改这一个文件。
///
/// 当前全部是插件 example 自带的 DEMO ID（App ID `222700`），仅用于
/// 验证 SDK 初始化、加载回调与广告位接线，**没有填充、没有结算**。
/// 正式的 fqapp 灰鲸 App ID / 广告位 ID 由用户在灰鲸后台为 fqapp
/// 单独申请后填到这里；绝不复用陪玩或风月天气的正式 ID。
/// 频率默认值是提议值（短剧 feed 每 5 集、10 集后激励解锁、小说
/// 每 3 章章末插屏），改数字即可调频，不用改调用处。
class AdConfig {
  const AdConfig._();

  /// 总开关：关掉后所有广告位都不加载、不展示，播放与阅读不受影响。
  static const bool enabled = true;

  /// 灰鲸 App ID（DEMO）。
  static const String appId = '222700';

  /// 开屏广告位（DEMO，v1 未接，仅预留）。
  static const String splashId = '8184694064941594';

  /// 插屏广告位（DEMO）：短剧切集、小说章末共用。
  static const String interstitialId = '8586650432385914';

  /// 激励视频广告位（DEMO）：短剧 10 集后解锁用。
  static const String rewardId = '2868305903877175';

  /// 信息流原生广告位（DEMO）：短剧 feed 卡片用，仅模板（express）形态。
  static const String feedId = '1720369284141436';

  /// 横幅广告位（DEMO，v1 未接，仅预留）。
  static const String bannerId = '8918335087174889';

  /// 短剧 feed 里原生广告卡出现的间隔（每 N 张卡片叠加一张广告卡）。
  static const int feedCardEvery = 5;

  /// 短剧免费集数：前 N 集直接看，从第 N+1 集起需要激励解锁。
  static const int rewardFreeEpisodes = 10;

  /// 小说章末插屏间隔（每 N 章出现一次）。
  static const int novelInterstitialEveryChapters = 3;

  /// 插屏最短展示间隔：两次插屏之间至少隔这么久，避免连弹。
  static const Duration interstitialMinInterval = Duration(minutes: 3);

  /// 播放页切集插屏间隔（每 N 集出现一次，1-based 集号整除时触发）。
  static const int episodeInterstitialEvery = 5;
}
