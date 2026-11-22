import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fqapp/models/chapter_media.dart';
import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/pages/audio_page.dart';
import 'package:fqapp/pages/library_page.dart';
import 'package:fqapp/pages/player_page.dart';
import 'package:fqapp/pages/reader_page.dart';
import 'package:fqapp/pages/search_page.dart';
import 'package:fqapp/services/api_client.dart';
import 'package:fqapp/services/app_log.dart';
import 'package:fqapp/services/audio_preferences.dart';
import 'package:fqapp/services/backend_service.dart';
import 'package:fqapp/services/chapter_text_formatter.dart';
import 'package:fqapp/services/ios_audio_session.dart';
import 'package:fqapp/services/ios_platform.dart';
import 'package:fqapp/services/library_store.dart';
import 'package:fqapp/services/listening_session.dart';
import 'package:fqapp/services/native_player.dart';
import 'package:fqapp/services/native_secure_key_storage.dart';
import 'package:fqapp/services/platform_channel.dart';
import 'package:fqapp/services/secure_key_provider.dart';
import 'package:fqapp/services/shelf_store.dart';
import 'package:fqapp/services/shelf_view_store.dart';
import 'package:fqapp/services/system_tts.dart';
import 'package:fqapp/widgets/search/classic_search_result_row.dart';
import 'package:fqapp/widgets/search/search_media_tile.dart';

final _chapters = [
  Chapter(itemId: 'ios-check-1', title: '第一章', volumeName: ''),
  Chapter(itemId: 'ios-check-2', title: '第二章', volumeName: ''),
];
const _text = '这是云端模拟器里的实际朗读验证。暂停后继续，播放状态应当与朗读一致。';
const _session = MethodChannel('fqapp/audio_session');

MediaItem _book(
  String id,
  String title, {
  int status = 0,
  int words = 500000,
}) => MediaItem(
  id: id,
  title: title,
  cover: '',
  author: '云端验证',
  badge: '',
  ep: '',
  kind: 'book',
  creationStatus: status,
  wordNumber: words,
  categories: const ['都市'],
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS production pages, native media and persistent restart', (
    tester,
  ) async {
    expect(Platform.isIOS, isTrue);
    final root = await getApplicationDocumentsDirectory();
    final evidence = Directory('${root.path}/ios-interaction');
    await evidence.create(recursive: true);
    final firstReport = File('${evidence.path}/first.json');
    final secondLaunch = firstReport.existsSync();
    final report = <String, dynamic>{
      'revision': const String.fromEnvironment('FQAPP_VALIDATION_REVISION'),
      'phase': secondLaunch ? 'restart' : 'interaction',
      'passed': false,
      'checks': <String>[],
      'scope':
          'Production pages and native engines; fixed media/search fixtures '
          'are separate from live upstream search. No phone-call/Bluetooth acceptance.',
    };
    final checks = report['checks'] as List<String>;
    final players = <NativePlayer>[];
    final navigator = GlobalKey<NavigatorState>();

    Future<void> waitFor(bool Function() ready, String name) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          fail(
            '$name timed out; players=${players.map((p) => {'playing': p.playing, 'intent': p.playWhenReady, 'position': p.position.inMilliseconds, 'error': p.lastError?.toString()}).toList()}',
          );
        }
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await tester.pump();
    }

    Future<void> screenshot(String name) async {
      await tester.pump();
      final bytes = await binding.takeScreenshot(name);
      await File('${evidence.path}/$name.png').writeAsBytes(bytes, flush: true);
    }

    Future<void> mount(Widget page) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) =>
                AudioPlaybackScope(navigatorKey: navigator, child: child!),
            home: page,
          ),
        ),
      );
      await tester.pump();
    }

    Future<Map<Object?, Object?>> snapshot() async {
      final state = await _session.invokeMapMethod<Object?, Object?>(
        'debugSnapshot',
      );
      expect(state, isNotNull);
      expect(state!['session'], isA<int>());
      expect(state['playing'], isA<bool>());
      return state;
    }

    try {
      await IosPlatform.install();
      AppLog.instance.install();
      await AppLog.instance.startPersistence();
      await Hive.initFlutter();
      await LibraryStore.instance.init();
      await ShelfStore.instance.init();
      if (!secondLaunch) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('shelfLayout', 'list');
        await preferences.setString('reader_page_mode', 'scroll');
        await preferences.setBool('search_list_view', false);
      }
      await ShelfViewStore.instance.load();
      await AudioPreferences.instance.load();
      await BackendService.instance.start();
      expect(await SecureKeyProvider.instance.getOrCreateKey(), isNotNull);
      expect(Hive.isBoxOpen('shelf_enc'), isTrue);

      final persistedBook = _book('ios-persisted-book', '云端持久化书籍');
      const secureStorage = MethodChannelSecureKeyStorage();
      const probeKey = 'ios_interaction_keychain_probe';
      if (secondLaunch) {
        final original = jsonDecode(await firstReport.readAsString()) as Map;
        expect(original['passed'], isTrue);
        expect(original['revision'], report['revision']);
        expect(await secureStorage.read(probeKey), report['revision']);
        await secureStorage.delete(probeKey);
        expect(ShelfStore.instance.containsItem(persistedBook), isTrue);
        expect(AudioPreferences.instance.backgroundPlayback.value, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getBool('search_list_view'),
          isTrue,
        );
        await mount(const LibraryPage());
        await waitFor(
          () => find.text(persistedBook.title).evaluate().isNotEmpty,
          'shelf after process restart',
        );
        await screenshot('restart-shelf');
        checks.add(
          'Process restart reads encrypted shelf, Keychain and saved preferences',
        );
      } else {
        await secureStorage.write(probeKey, 'before-update');
        await secureStorage.write(probeKey, report['revision'] as String);
        expect(await secureStorage.read(probeKey), report['revision']);
        checks.add('Native Keychain create/update/read uses the real bridge');
        expect((await snapshot())['owner'], isNull);
        checks.add('Runtime initialization does not claim a media owner');

        await mount(const SearchPage(initialQuery: '小说'));
        await waitFor(
          () =>
              find.byType(ClassicSearchResultRow).evaluate().isNotEmpty ||
              find.byType(SearchNovelRow).evaluate().isNotEmpty ||
              find.byType(SearchBookGridTile).evaluate().isNotEmpty,
          'live upstream search results',
        );
        await screenshot('live-search');
        checks.add(
          'Live search through the default Rust-backed production SearchPage',
        );

        final results = [
          _book('ios-complete', '云端完结作品'),
          _book('ios-serial', '云端连载作品', status: 1, words: 200000),
        ];
        await mount(
          SearchPage(
            key: const ValueKey('fixed-search'),
            initialQuery: '云端',
            searchLoader: (_, {required tabType, required offset}) async => [
              SearchTab(title: '综合', items: results, hasMore: false),
            ],
          ),
        );
        await waitFor(
          () => find.text('云端完结作品').evaluate().isNotEmpty,
          'search fixture',
        );
        await tester.tap(find.text('状态不限'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('已完结').last);
        await tester.pumpAndSettle();
        expect(find.text('云端连载作品'), findsNothing);
        await tester.tap(find.text('字数不限'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('300 万字以上').last);
        await tester.pumpAndSettle();
        expect(find.text('云端完结作品'), findsNothing);
        expect(find.text('清除筛选'), findsWidgets);
        await screenshot('search-empty-filter');
        await tester.tap(find.text('清除筛选').first);
        await tester.pumpAndSettle();
        expect(find.text('云端完结作品'), findsOneWidget);
        expect(find.text('云端连载作品'), findsOneWidget);
        await tester.tap(find.byKey(const Key('search-layout-toggle')));
        await tester.pumpAndSettle();
        expect(
          (await SharedPreferences.getInstance()).getBool('search_list_view'),
          isTrue,
        );
        checks.add(
          'Fixed results: status/word-count empty state, reset, saved list layout',
        );

        await mount(
          ReaderPage(
            bookId: persistedBook.id,
            title: persistedBook.title,
            shelfItem: persistedBook,
            localOnly: true,
            chapters: _chapters,
            startIndex: 0,
            chapterLoader: (_) async => _text,
          ),
        );
        await waitFor(
          () => find
              .byKey(const ValueKey('reader-page-surface'))
              .evaluate()
              .isNotEmpty,
          'reader',
        );
        final more = find.byKey(const ValueKey('reader-header-more'));
        if (more.hitTestable().evaluate().isEmpty) {
          await tester.tapAt(
            tester.getCenter(find.byKey(const ValueKey('reader-page-surface'))),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(more);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reader-shelf-button')));
        await waitFor(
          () => ShelfStore.instance.containsItem(persistedBook),
          'add shelf from reader',
        );
        await mount(const LibraryPage());
        await waitFor(
          () => find.text(persistedBook.title).evaluate().isNotEmpty,
          'shelf renders saved book',
        );
        await screenshot('saved-shelf');
        checks.add(
          'Production reader menu adds book; production library renders encrypted record',
        );

        const origin = String.fromEnvironment('FQAPP_TEST_MEDIA_ORIGIN');
        expect(origin, isNotEmpty);
        var sourceAvailable = false;
        var attempts = 0;
        await mount(const Scaffold(body: Center(child: Text('云端媒体交互验证'))));
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => AudioPage(
              bookId: 'ios-check-audio',
              title: '云端听书验证',
              chapters: _chapters,
              playerFactory: () {
                final player = NativePlayer(audioOnly: true);
                players.add(player);
                return player;
              },
              voicesLoader: () async => defaultAudioVoices,
              sourceLoader: (itemId, {toneId}) async {
                ++attempts;
                if (!sourceAvailable) {
                  throw const ApiException('固定来源暂不可用', statusCode: 404);
                }
                return AudioSource(
                  itemId: itemId,
                  url: '$origin/encrypted.mp4',
                  keyHex: '00112233445566778899aabbccddeeff',
                );
              },
            ),
          ),
        );
        await waitFor(
          () => find.byKey(const ValueKey('audio-retry')).evaluate().isNotEmpty,
          'audio failure',
        );
        expect(attempts, 1);
        expect((await snapshot())['owner'], isNull);
        await screenshot('audio-failed');
        sourceAvailable = true;
        await tester.tap(find.byKey(const ValueKey('audio-retry')));
        await waitFor(
          () =>
              players.isNotEmpty && players.last.position.inMilliseconds > 1200,
          'encrypted audio retry',
        );
        final audio = players.last;
        final audioOwner = audio.iosMediaOwner;
        expect(IosAudioSession.owns(audioOwner), isTrue);
        expect((await snapshot())['owner'], audioOwner);
        expect((await snapshot())['title'], '云端听书验证');
        expect((await snapshot())['mode'], 'AVAudioSessionModeSpokenAudio');
        await screenshot('audio-playing');
        await tester.tap(find.byTooltip('暂停').first);
        await waitFor(() => !audio.playing, 'audio pause control');
        await audio.seek(const Duration(seconds: 12));
        await waitFor(
          () => audio.position.inSeconds >= 11,
          'paused audio seek',
        );
        expect(audio.playWhenReady, isFalse);
        await tester.tap(find.byTooltip('播放').first);
        await waitFor(
          () => audio.playing && audio.position.inSeconds >= 13,
          'audio resume',
        );
        await tester.tap(find.byTooltip('下一章').first);
        await waitFor(
          () =>
              players.length >= 2 &&
              players.last.position.inMilliseconds > 1000,
          'audio next chapter',
        );
        checks.add(
          'Real CENC audio retry, pause, seek, resume and next chapter with native card',
        );

        final video = NativePlayer();
        players.add(video);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(
              bookId: 'ios-check-video',
              title: '云端视频验证',
              eps: [_chapters.first],
              startIndex: 0,
              playerFactory: () => video,
              contentLoader: (_) async => {
                'video_url': '$origin/encrypted.mp4',
                'key_hex': '00112233445566778899aabbccddeeff',
              },
            ),
          ),
        );
        await waitFor(
          () => video.position.inMilliseconds > 1500 && video.videoWidth > 0,
          'encrypted video rendered',
        );
        expect(players[1].playWhenReady, isFalse);
        expect((await snapshot())['owner'], video.iosMediaOwner);
        expect((await snapshot())['title'], '云端视频验证');
        expect((await snapshot())['mode'], 'AVAudioSessionModeMoviePlayback');
        await screenshot('video-playing');
        await video.pause();
        await video.seek(const Duration(seconds: 8));
        await waitFor(() => video.position.inSeconds >= 7, 'video seek');
        await video.play();
        await waitFor(
          () => video.position.inSeconds >= 9 && video.playing,
          'video resume',
        );
        checks.add(
          'Real CENC video frame, position, seek/resume; video takes audio ownership',
        );

        var nativeTtsEvents = 0;
        final originalEvents = PlatformChannels.events!;
        PlatformChannels.events = (name) {
          final stream = originalEvents(name);
          return name == 'fqapp/system_tts_events'
              ? stream.map((event) {
                  if (event is Map &&
                      const {'range', 'done'}.contains(event['type'])) {
                    ++nativeTtsEvents;
                  }
                  return event;
                })
              : stream;
        };
        try {
          await AudioPlaybackScope.startSystemTts(
            tester.element(find.byType(PlayerPage)),
            SystemTtsBook(
              bookId: 'ios-check-tts',
              title: '云端朗读验证',
              chapters: _chapters,
              startIndex: 0,
              localOnly: true,
              initialContent: ChapterContent.fromPlainText(
                List.filled(10, _text).join('\n'),
              ),
              textLoader: (_) async => _text,
            ),
          );
          await waitFor(
            () => nativeTtsEvents > 0 && ListeningSession.instance.playing,
            'native TTS callback',
          );
          expect(video.playWhenReady, isFalse);
          expect((await snapshot())['title'], '云端朗读验证');
          navigator.currentState!.pop();
          await waitFor(
            () => find.byType(PlayerPage).evaluate().isEmpty,
            'close stale video page',
          );
          expect((await snapshot())['title'], '云端朗读验证');
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderPage(
                bookId: 'ios-check-tts',
                title: '云端朗读验证',
                localOnly: true,
                chapters: _chapters,
                startIndex: 0,
                chapterLoader: (_) async => _text,
              ),
            ),
          );
          final pill = find
              .byKey(const ValueKey('reader_player_pill'))
              .hitTestable();
          await waitFor(
            () => pill.evaluate().isNotEmpty,
            'production reader TTS control',
          );
          await tester.tap(pill);
          await waitFor(() => !ListeningSession.instance.playing, 'TTS pause');
          await tester.tap(pill);
          await waitFor(() => ListeningSession.instance.playing, 'TTS resume');
          await screenshot('tts-owns-session');
          await AudioPlaybackScope.stopSystemTtsForBook(
            tester.element(find.byType(ReaderPage)),
            'ios-check-tts',
          );
          await waitFor(
            () => !IosAudioSession.hasOwner,
            'TTS stop clears owner',
          );
          expect((await snapshot())['title'], isNull);
          report['native_tts_callbacks'] = nativeTtsEvents;
          checks.add(
            'Native TTS callbacks, pause/resume, stop and stale video close preserve new card',
          );
        } finally {
          PlatformChannels.events = originalEvents;
        }
        await AudioPreferences.instance.setBackgroundPlayback(false);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      for (final player in players) {
        await player.dispose();
      }
      await Hive.close();
      await AppLog.instance.flush();
      report['passed'] = true;
    } catch (error, stack) {
      report['error'] = error.toString();
      report['stack'] = stack.toString();
      try {
        await screenshot('failure-${secondLaunch ? 'restart' : 'interaction'}');
      } catch (_) {}
      rethrow;
    } finally {
      await AppLog.instance.flush();
      final target = File(
        '${evidence.path}/${secondLaunch ? 'restart' : 'first'}.json',
      );
      await target.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
