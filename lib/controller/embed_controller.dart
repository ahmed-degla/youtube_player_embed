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
        '.ytp-overflow-button',                   // More options button
        '.ytp-share-button',                      // Share button
        '.ytp-watch-later-button',                // Watch later
        '.ytp-watermark',                         // Watermark
        '.ytp-youtube-button',                    // Logo
        '.ytp-chrome-top-buttons',                // Top-right controls
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
            root.querySelectorAll(sel).forEach(el => el.remove());
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

      // Global click interceptor (kills even recreated buttons)
      document.addEventListener("click", e => {
        if (e.target.closest('.ytp-overflow-button,[aria-label*="More options"],[aria-label*="خيارات إضافية"],.ytp-share-button,[aria-label*="Share"],[aria-label*="مشاركة"]')) {
          e.stopImmediatePropagation();
          e.preventDefault();
          return false;
        }
      }, true);

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
  Future<void> killSettingsButton() async {
    await controller.evaluateJavascript(source: """
    (function() {
      var SELECTOR = '.ytp-settings-button';

      function injectStyle() {
        var styleId = 'no-settings-btn-style';
        if (document.getElementById(styleId)) return;
        var style = document.createElement('style');
        style.id = styleId;
        style.innerHTML = SELECTOR + ` {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          pointer-events: none !important;
          width: 0 !important;
          height: 0 !important;
          overflow: hidden !important;
        }`;
        document.head.appendChild(style);
      }

      // Run now
      injectStyle();
      document.querySelectorAll(SELECTOR).forEach(function(el) {
        el.style.display = "none";
        el.remove();
      });

      // Keep hammering it
      var obs = new MutationObserver(function() {
        document.querySelectorAll(SELECTOR).forEach(function(el) {
          el.style.display = "none";
          el.remove();
        });
        injectStyle();
      });
      obs.observe(document.documentElement, { childList: true, subtree: true });

      // Block clicks anyway
      document.addEventListener("click", function(e) {
        if (e.target.closest(SELECTOR)) {
          e.stopImmediatePropagation();
          e.preventDefault();
          return false;
        }
      }, true);
    })();
  """);
  }


  Future<void> onFullScreenStateChanged({
    required Function(VideoState state)? onVideoStateChange,
  }) async {
    await controller.evaluateJavascript(source: """
      document.addEventListener('fullscreenchange', function() {
        if (document.fullscreenElement) {
          window.flutter_inappwebview.callHandler('onEnterFullscreen');
        } else {
          window.flutter_inappwebview.callHandler('onExitFullscreen');
        }
      });
    """);

    controller.addJavaScriptHandler(
      handlerName: 'onEnterFullscreen',
      callback: (args) {
        if (onVideoStateChange != null) {
          onVideoStateChange.call(VideoState.fullscreen);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onExitFullscreen',
      callback: (args) {
        if (onVideoStateChange != null) {
          onVideoStateChange.call(VideoState.normalView);
        }
      },
    );
  }

  Future<void> createVideoListeners() async {
    await controller.evaluateJavascript(
      source: """
        const checkVideoElement = () => {
          const video = document.querySelector('video');
          if (video) {
            video.addEventListener('play', () => {
              window.flutter_inappwebview.callHandler('onVideoStateChange', 'playing');
            });
            video.addEventListener('pause', () => {
              if(!video.ended){
                window.flutter_inappwebview.callHandler('onVideoStateChange', 'paused');
              }
            });
            video.addEventListener('ended', () => {
              window.flutter_inappwebview.callHandler('onVideoEnd');
            });
            video.addEventListener('seeking', () => {
              window.flutter_inappwebview.callHandler('onVideoSeek', video.currentTime);
            });
            video.addEventListener('timeupdate', () => {
              window.flutter_inappwebview.callHandler('onVideoTimeUpdate', video.currentTime);
            });
            let wasMuted = video.muted;
            setInterval(() => {
              if (video.muted && !wasMuted) {
                window.flutter_inappwebview.callHandler('onVideoStateChange', 'muted');
              } else if (!video.muted && wasMuted) {
                window.flutter_inappwebview.callHandler('onVideoStateChange', 'unmuted');
              }
              wasMuted = video.muted;
            }, 500);
          } else {
            setTimeout(checkVideoElement, 500);
          }
        };
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
          case 'playing': videoState = VideoState.playing; break;
          case 'paused': videoState = VideoState.paused; break;
          case 'muted': videoState = VideoState.muted; break;
          case 'unmuted': videoState = VideoState.unmuted; break;
        }
        if (videoState != null) {
          onVideoStateChange?.call(videoState);
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
        document.querySelector('.ytp-watermark')?.remove();  
        document.querySelector('.ytp-impression-link')?.remove();
      """,
    );
  }

  Future<void> removeChannleImage({
    required bool hidenChannelImage,
  }) async {
    if (hidenChannelImage) {
      await controller.evaluateJavascript(
        source: """
          document.querySelector('.ytp-title-channel')?.remove();   
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
        document.querySelector('.ytp-title')?.style.setProperty('display','none');
        if (document.querySelector('.ytp-title-text')) {
          document.querySelector('.ytp-title-text').firstChild.textContent = '';
        }
      """;
    } else {
      return """
        document.querySelector('.ytp-title')?.style.removeProperty('display'); 
      """;
    }
  }
}
