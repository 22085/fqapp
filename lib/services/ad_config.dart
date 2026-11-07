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

  /// 灰鲸 App ID（正式）。各联盟不用在 APP 里单独配 App ID：灰鲸
  /// 是服务端聚合，联盟账号、瀑布流都在灰鲸后台配，APP 只传灰鲸
  /// App ID + 广告位 ID，服务端下发瀑布流后各联盟 SDK 再初始化。
  static const String appId = '246351';

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
