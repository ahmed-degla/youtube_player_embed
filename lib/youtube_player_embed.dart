import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'controller/embed_controller.dart';
import 'controller/video_controller.dart';
import 'enum/video_state.dart';

import 'dart:io' show Platform;

//// YOUTUBE PLAYER VIEW WIDGET
class YoutubePlayerEmbed extends StatefulWidget {
  //// PROPERTIES
  final String videoId;
  final String? customVideoTitle;
  final bool autoPlay;
  final bool hidenVideoControls;
  final bool enabledShareButton;
  final bool mute;
  final bool hidenChannelImage;
  final double? aspectRatio;
  final VoidCallback? onVideoEnd;
  final Function(double currentTime)? onVideoSeek;
  final Function(double currentTime)? onVideoTimeUpdate;
  final Function(VideoState state)? onVideoStateChange;
  final Function(VideoController)? callBackVideoController;

  //// CONSTRUCTOR
  YoutubePlayerEmbed({
    Key? key,
    required this.videoId,
    this.callBackVideoController,
    this.customVideoTitle,
    this.autoPlay = true,
    this.hidenVideoControls = false,
    this.mute = false,
    this.hidenChannelImage = true,
    this.aspectRatio,
    this.enabledShareButton = false,
    this.onVideoEnd,
    this.onVideoSeek,
    this.onVideoTimeUpdate,
    this.onVideoStateChange,
  }) : super(key: key);

  //// CREATE STATE
  @override
  State<YoutubePlayerEmbed> createState() => _YoutubePlayerEmbedState();
}

//// YOUTUBE PLAYER VIEW STATE
class _YoutubePlayerEmbedState extends State<YoutubePlayerEmbed> {
  //// VARIABLES
  bool preventTap = true;
  String url = '';
  EmbedController? embedController;

  //// INIT STATE
  @override
  void initState() {
    //// BUILD VIDEO URL
    url = '''
    https://www.youtube.com/embed/${widget.videoId}
    ?autoplay=${widget.autoPlay ? '1' : '0'}
    &mute=${widget.mute ? '1' : '0'}
    &controls=${widget.hidenVideoControls ? '0' : '1'}
    &rel=0
    '''
        .replaceAll('\n', '');
    super.initState();
  }

  //// BUILD WIDGET
  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: preventTap,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio ?? 16 / 9,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(url.replaceAll(" ", "")),
          ),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            javaScriptEnabled: true,
            allowsInlineMediaPlayback: true,
            iframeAllowFullscreen: true,
            allowsBackForwardNavigationGestures: false,
            supportZoom: false,
            // applicationNameForUserAgent: "no-referrer-when-downgrade",
          ),

          //// OVERRIDE URL LOADING
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            if (Platform.isAndroid) {
              return NavigationActionPolicy.CANCEL;
            } else {
              if (navigationAction.request.url.toString() !=
                  url.replaceAll(" ", "")) {
                return NavigationActionPolicy.CANCEL;
              } else {
                return NavigationActionPolicy.ALLOW;
              }
            }
          },

          //// ON WEBVIEW CREATED
          onWebViewCreated: (controller) async {
            //// INITIALIZE CONTROLLERS
            embedController = EmbedController(controller);
            widget.callBackVideoController?.call(VideoController(controller));

            //// HIDE VIDEO TITLE
            await embedController?.hidenVideoTitle(hiden: true);
            await embedController?.replaceSettingsWithCustomControls();

            //// REMOVE CHANNEL IMAGE
            await embedController?.removeChannleImage(
              hidenChannelImage: widget.hidenChannelImage,
            );

            //// IF SHARE BUTTON DISABLED
            if (!widget.enabledShareButton) {
              //// REMOVE YOUTUBE WATERMARK
              await embedController?.removeMoreOptionsAndShareButtons();
            }

            await embedController?.onFullScreenStateChanged(
              onVideoStateChange: (videoState) {
                widget.onVideoStateChange?.call(videoState);
              },
            );

            //// CALL BACK WHEN VIDEO END
            embedController?.callBackWhenVideoEnd(
              onVideoEnd: widget.onVideoEnd,
            );

            //// CALL BACK WHEN VIDEO SEEK
            embedController?.callBackWhenVideoSeek(
              onVideoSeek: widget.onVideoSeek,
            );

            //// CALL BACK WHEN VIDEO TIME UPDATE
            embedController?.callBackWhenVideoStateChange(
              onVideoStateChange: (videoState) async {
                ////
                widget.onVideoStateChange?.call(videoState);

                //// IF AUTO PLAY DISABLED
                if (!widget.autoPlay && videoState == VideoState.playing) {
                  //// HIDEN VIDEO TITLE AFTER EDIT
                  await embedController?.hidenVideoTitle(
                    hiden: true,
                  );

                  //// WAIT FOR 500 milliseconds TO SHOW NEW VIDEO TITLE
                  await Future.delayed(
                    Duration(milliseconds: 500),
                    () async {
                      //// CHECK IF CUSTOM VIDEO TITLE
                      if (widget.customVideoTitle != null) {
                        //// CHANGE VIDEO TITLE
                        await embedController?.changeVideoTitle(
                          customVideoTitle: widget.customVideoTitle!,
                        );

                        //// SHOW VIDEO TITLE AFTER EDIT
                        await embedController?.hidenVideoTitle(
                          hiden: false,
                        );
                      }
                      ////
                    },
                  );
                }
                ////
              },
            );
          },

          //// ON LOAD STOP
          onLoadStop: (controller, uri) async {
            await embedController?.changeVideoTitle(
              customVideoTitle: widget.customVideoTitle!,
            );

            //// HIDE VIDEO TITLE
            await embedController?.hidenVideoTitle();

            //// REMOVE CHANNEL IMAGE
            await embedController?.removeChannleImage(
              hidenChannelImage: widget.hidenChannelImage,
            );

            //// CREATE VIDEO LISTENERS
            await embedController?.createVideoListeners();

            if (!widget.enabledShareButton) {
              //// REMOVE UI ELEMENTS
              await embedController?.removeMoreOptionsAndShareButtons();
            }

            //// CHECK IF CUSTOM VIDEO TITLE
            if (widget.customVideoTitle != null) {
              //// CHANGE VIDEO TITLE
              await embedController?.changeVideoTitle(
                customVideoTitle: widget.customVideoTitle!,
              );
              //// SHOW VIDEO TITLE AFTER EDIT
              await embedController?.hidenVideoTitle(hiden: false);
            }

            //// UPDATE STATE
            setState(() {
              preventTap = false;
            });
          },
        ),
      ),
    );
  }
}
