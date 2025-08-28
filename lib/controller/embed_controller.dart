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
  Future<void> replaceSettingsWithCustomControls() async {
    await controller.evaluateJavascript(source: """
    (function() {
      // Remove default settings button
      const settingsBtn = document.querySelector('.ytp-settings-button');
      if (settingsBtn) settingsBtn.remove();

      // Find the right controls container
      const controls = document.querySelector('.ytp-right-controls');
      if (!controls) return;

      // Avoid duplicates
      if (document.querySelector('#custom-speed-btn')) return;

      // Create Speed button
      const speedBtn = document.createElement('button');
      speedBtn.id = 'custom-speed-btn';
      speedBtn.className = 'ytp-button';
      speedBtn.innerHTML = '⚡'; // You can replace with SVG
      speedBtn.title = 'Change Speed';

      speedBtn.onclick = function(e) {
        e.stopPropagation();
        e.preventDefault();
        const video = document.querySelector('video');
        if (!video) return;

        // Cycle speeds: 1x -> 1.5x -> 2x -> back to 1x
        const speeds = [1, 1.5, 2];
        let current = video.playbackRate;
        let idx = speeds.indexOf(current);
        let next = speeds[(idx + 1) % speeds.length];
        video.playbackRate = next;
        alert('Speed set to ' + next + 'x');
      };

      // Create Quality button
      const qualityBtn = document.createElement('button');
      qualityBtn.id = 'custom-quality-btn';
      qualityBtn.className = 'ytp-button';
      qualityBtn.innerHTML = '📺';
      qualityBtn.title = 'Change Quality';

      qualityBtn.onclick = function(e) {
        e.stopPropagation();
        e.preventDefault();
        // YouTube’s internal API is not public, but you can try force quality like this:
        const player = document.querySelector('video');
        if (!player) return;
        // Force HD quality (depends on embed type, may not always work)
        const qualities = ['hd1080','hd720','large','medium','small'];
        let idx = Math.floor(Math.random() * qualities.length);
        const chosen = qualities[idx];
        try {
          ytplayer.config.args['vq'] = chosen;
          alert('Quality set to ' + chosen);
        } catch(e) {
          alert('Unable to set quality on this embed');
        }
      };

      // Add both buttons before fullscreen button
      const fullscreenBtn = document.querySelector('.ytp-fullscreen-button');
      if (fullscreenBtn) {
        controls.insertBefore(speedBtn, fullscreenBtn);
        controls.insertBefore(qualityBtn, fullscreenBtn);
      } else {
        controls.appendChild(speedBtn);
        controls.appendChild(qualityBtn);
      }
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
