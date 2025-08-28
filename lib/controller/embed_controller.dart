import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_player_embed/enum/video_state.dart';

class EmbedController {
  final InAppWebViewController controller;
  const EmbedController(this.controller);

  Future<void> changeVideoTitle({
    String? customVideoTitle,
  }) async {
    await controller.evaluateJavascript(
      source: """
                document.querySelector('a.ytp-title-link').innerText = '${customVideoTitle}';
                document.querySelector('.ytp-title-text').firstChild.text = '${customVideoTitle}';
              """,
    );
  }


  Future<void> removeMoreOptionsAndShareButtons() async {
    await controller.evaluateJavascript(source: """
    (function() {
      const KILL_SELECTORS = [
        '.ytp-overflow-button',                   // More options button in controls
        '.ytp-share-button',                      // Share button in controls
        '.ytp-watch-later-button',                // Watch later
        '.ytp-watermark',                         // YouTube watermark
        '.ytp-youtube-button',                    // Logo button
        '.ytp-chrome-top-buttons',                // Top-right chrome controls
        '#bottom-sheet',                          // Bottom sheet menus
        'tp-yt-paper-item[title*="More options"]',
        'tp-yt-paper-item[title*="خيارات إضافية"]',
        'tp-yt-paper-item[title*="Share"]',
        'tp-yt-paper-item[title*="مشاركة"]',
        '[aria-label*="Share"]',
        '[aria-label*="مشاركة"]',
        '[aria-label*="More options"]',
        '[aria-label*="خيارات إضافية"]'
      ];

      function nukeElements(root=document) {
        KILL_SELECTORS.forEach(sel => {
          try {
            root.querySelectorAll(sel).forEach(el => {
              el.remove();
            });
          } catch(e){}
        });
      }

      function blockClicks() {
        KILL_SELECTORS.forEach(sel => {
          try {
            document.querySelectorAll(sel).forEach(el => {
              el.style.display = "none";
              el.onclick = (e) => { e.stopImmediatePropagation(); e.preventDefault(); return false; };
              el.addEventListener("click", e => { e.stopImmediatePropagation(); e.preventDefault(); return false; }, true);
            });
          } catch(e){}
        });
      }

      // Run once
      nukeElements();
      blockClicks();

      // Keep cleaning
      const obs = new MutationObserver(() => {
        nukeElements();
        blockClicks();
      });
      obs.observe(document.documentElement, { childList: true, subtree: true });

      // Handle shadow roots
      function observeShadowRoots(node) {
        if (node.shadowRoot) {
          new MutationObserver(() => {
            nukeElements(node.shadowRoot);
          }).observe(node.shadowRoot, { childList: true, subtree: true });
        }
        node.childNodes.forEach(observeShadowRoots);
      }
      document.querySelectorAll('*').forEach(observeShadowRoots);

      // Handle iframes
      document.querySelectorAll('iframe').forEach(frame => {
        try {
          const doc = frame.contentDocument || frame.contentWindow.document;
          new MutationObserver(() => {
            nukeElements(doc);
          }).observe(doc, { childList: true, subtree: true });
        } catch(e){}
      });
    })();
  """);
  }


  Future<void> onFullScreenStateChanged({
    required Function(VideoState state)? onVideoStateChange,
  }) async {
    // Inject JavaScript to listen for fullscreen changes
    await controller.evaluateJavascript(source: """
    document.addEventListener('fullscreenchange', function() {
      if (document.fullscreenElement) {
        window.flutter_inappwebview.callHandler('onEnterFullscreen');
      } else {
        window.flutter_inappwebview.callHandler('onExitFullscreen');
      }
    });
  """);

    // Register JavaScript handlers for fullscreen events
    controller.addJavaScriptHandler(
      handlerName: 'onEnterFullscreen',
      callback: (args) {
        // Notify Flutter when entering fullscreen
        if (onVideoStateChange != null) {
          onVideoStateChange.call(VideoState.fullscreen);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onExitFullscreen',
      callback: (args) {
        // Notify Flutter when exiting fullscreen
        if (onVideoStateChange != null) {
          onVideoStateChange.call(VideoState.normalView);
        }
      },
    );
  }

  Future<void> createVideoListeners() async {
    await controller.evaluateJavascript(
      source: """
                // Ensure the video element is loaded
                const checkVideoElement = () => {
                  const video = document.querySelector('video');
                  if (video) {
                    console.log('Video element found.');

                    // video.addEventListener('click',() => {});

                    // Add event listeners for video state changes
                    video.addEventListener('play', () => {
                      console.log('Video is playing.');
                      window.flutter_inappwebview.callHandler('onVideoStateChange', 'playing');
                    });

                    //// Add event listeners for video pause
                    video.addEventListener('pause', () => {
                      console.log('Video is paused.');
                      if(!video.ended){
                        window.flutter_inappwebview.callHandler('onVideoStateChange', 'paused');
                      }
                    });

                    //// Add event listeners for video end
                    video.addEventListener('ended', () => {
                      console.log('Video ended.');
                      window.flutter_inappwebview.callHandler('onVideoEnd');
                    });

                    //// add event listeners for video seek
                    video.addEventListener('seeking', () => {
                      console.log('Video seeking to: ', video.currentTime);
                      window.flutter_inappwebview.callHandler('onVideoSeek', video.currentTime);
                    });

                    //// add event listeners for video time update
                    video.addEventListener('timeupdate', () => {
                      console.log('Current video time: ', video.currentTime);
                      window.flutter_inappwebview.callHandler('onVideoTimeUpdate', video.currentTime);
                    });

                    // Detect mute and unmute events using the 'muted' property
                    let wasMuted = video.muted;
                    setInterval(() => {
                      if (video.muted && !wasMuted) {
                        console.log('Video muted.');
                        window.flutter_inappwebview.callHandler('onVideoStateChange', 'muted');
                      } else if (!video.muted && wasMuted) {
                        console.log('Video unmuted.');
                        window.flutter_inappwebview.callHandler('onVideoStateChange', 'unmuted');
                      }
                      wasMuted = video.muted;
                    }, 500);
                  } else {
                    console.log('Video element not found. Retrying...');
                    setTimeout(checkVideoElement, 500); // Retry until video is available
                  }
                };
                // Start checking for the video element
                checkVideoElement();
                """,
    );
  }

  void callBackWhenVideoStateChange({
    required Function(VideoState state)? onVideoStateChange,
  }) {
    controller.addJavaScriptHandler(
      handlerName: 'onVideoStateChange',
      callback: (args) {
        final String state = args.first;
        VideoState? videoState;

        switch (state) {
          case 'playing':
            videoState = VideoState.playing;
            break;
          case 'paused':
            videoState = VideoState.paused;
            break;
          case 'muted':
            videoState = VideoState.muted;
            break;
          case 'unmuted':
            videoState = VideoState.unmuted;
            break;
        }

        if (videoState != null) {
          onVideoStateChange?.call(videoState);
          print('<<< Video state changed: $state >>>');
        }

        return null;
      },
    );
  }

  void callBackWhenVideoTimeUpdate({
    required Function(double currentTime)? onVideoTimeUpdate,
  }) {
    controller.addJavaScriptHandler(
      handlerName: 'onVideoTimeUpdate',
      callback: (args) {
        final currentTime = args.first as double;

        onVideoTimeUpdate?.call(currentTime);

        return null;
      },
    );
  }

  void callBackWhenVideoSeek({
    required Function(double currentTime)? onVideoSeek,
  }) {
    controller.addJavaScriptHandler(
      handlerName: 'onVideoSeek',
      callback: (args) {
        final currentTime = args.first as double;

        onVideoSeek?.call(currentTime);

        return null;
      },
    );
  }

  void callBackWhenVideoEnd({
    required Function()? onVideoEnd,
  }) {
    controller.addJavaScriptHandler(
      handlerName: 'onVideoEnd',
      callback: (args) {
        onVideoEnd?.call();

        return null;
      },
    );
  }

  Future<void> removeYoutubeWatermark() async {
    await controller.evaluateJavascript(
      source: """
                document.querySelector('.ytp-watermark').style.display = 'none';  
                decument.querySelector('.ytp-impression-link ').style.display = 'none';
                """,
    );
  }

  Future<void> removeChannleImage({
    required bool hidenChannelImage,
  }) async {
    if (hidenChannelImage) {
      await controller.evaluateJavascript(
        source: """
                document.querySelector('.ytp-title-channel').style.display = 'none';   
                """,
      );
    }
  }

  Future<void> hidenVideoTitle({
    bool hiden = true,
  }) async {
    await controller.evaluateJavascript(
      source: _getHidenTitleJavaScript(hiden: hiden),
    );
  }

  String _getHidenTitleJavaScript({bool hiden = true}) {
    if (hiden) {
      return """
             document.querySelector('.ytp-title').style.display = 'none';
             document.querySelector('.ytp-title-text').firstChild.text = '';
            """;
    } else {
      return """
             document.querySelector('.ytp-title').style.display = ''; 
            """;
    }
  }
}
