import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/Tools.dart';
import 'package:LoliSnatcher/libBooru/BooruItem.dart';
import 'package:LoliSnatcher/widgets/BorderedText.dart';

class LoadingElement extends StatefulWidget {
  final BooruItem item;

  final bool hasProgress;
  final bool isFromCache;
  final bool isDone;

  final bool isStopped;
  final List<String> stopReasons;
  final bool isViewed;

  final RxInt total;
  final RxInt received;
  final RxInt startedAt;

  final void Function()? startAction;
  final void Function()? stopAction;

  LoadingElement({
    Key? key,
    required this.item,

    required this.hasProgress,
    required this.isFromCache,
    required this.isDone,

    required this.isStopped,
    this.stopReasons = const [],
    required this.isViewed,

    required this.total,
    required this.received,
    required this.startedAt,

    required this.startAction,
    required this.stopAction,

  }) : super(key: key);

  @override
  _LoadingElementState createState() => _LoadingElementState();
}

class _LoadingElementState extends State<LoadingElement> {
  final SettingsHandler settingsHandler = Get.find<SettingsHandler>();

  bool isVisible = false;
  int _total = 0, _received = 0, _startedAt = 0;
  Timer? _checkInterval, _debounceBytes;
  StreamSubscription? _totalListener, _receivedListener, _startedAtListener;

  int _prevReceivedAmount = 0, _lastReceivedAmount = 0, _lastReceivedTime = 0;

  @override
  void initState() {  
    super.initState();

    _total = widget.total.value;
    _received = widget.received.value;
    _startedAt = widget.startedAt.value;
  
    _totalListener = widget.total.listen((int value) {
      _onBytesAdded(null, value);
    });

    _receivedListener = widget.received.listen((int value) {
      _onBytesAdded(value, null);
    });

    _startedAtListener = widget.startedAt.listen((int value) {
      _total = 0;
      _received = 0;
      _startedAt = value;
    });

    _checkInterval = Timer.periodic(const Duration(seconds: 1), (timer) {
      // force restate every second to refresh all timers/indicators, even when loading has stopped
      if(!widget.isDone) {
        updateState();
      }
    });
  }

  void _onBytesAdded(int? received, int? total) {
    // always save incoming bytes, but restate only after [debounceDelay]MS
    const int debounceDelay = 100;

    _received = received ?? _received;
    _total = total ?? _total;

    bool isActive = _debounceBytes?.isActive ?? false;

    if (!isActive) {
      // update after a debounce delay
      updateState();
      _debounceBytes = Timer(const Duration(milliseconds: debounceDelay), () {});
    } else if(_total > 0 && _received >= _total) {
      // update if completed
      updateState();
    }
  }

  void updateState() {
    if(this.mounted) {
      setState(() { });
    }
  }

  void disposables() {
    _total = 0;
    _received = 0;
    _startedAt = 0;

    _prevReceivedAmount = 0;
    _lastReceivedAmount = 0;
    _lastReceivedTime = 0;

    _totalListener?.cancel();
    _receivedListener?.cancel();
    _startedAtListener?.cancel();
    _checkInterval?.cancel();
    _debounceBytes?.cancel();
  }

  @override
  void dispose() {
    disposables();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int nowMils = DateTime.now().millisecondsSinceEpoch;
    int sinceStart = _startedAt == 0 ? 0 : nowMils - _startedAt;
    bool showLoading = !widget.isDone && (widget.isStopped || (widget.isViewed && sinceStart > 999));
    // delay showing loading info a bit, so we don't clutter interface for fast loading files

    // return buildElement(context);

    return AnimatedOpacity(
      duration: Duration(milliseconds: settingsHandler.appMode == 'Desktop' ? 50 : 300),
      curve: Curves.linear,
      opacity: showLoading ? 1 : 0,
      onEnd: () {
        isVisible = showLoading;
        updateState();
      },
      child: buildElement(context, nowMils, sinceStart),
    );
  }

  Widget buildElement(BuildContext context, int nowMils, int sinceStart) {
    if(widget.isDone && !isVisible) {
      //  Don't do or render anything after file is loaded and widget faded out
      return const SizedBox();
    }

    if(settingsHandler.shitDevice) {
      if(settingsHandler.loadingGif) {
        return Center(child: Image(image: AssetImage('assets/images/loading.gif')));
      } else {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Get.theme.colorScheme.secondary)
          )
        );
      }
    }


    bool hasProgressData = widget.hasProgress && (_total > 0);
    int expectedBytes = hasProgressData ? _received : 0;
    int totalBytes = hasProgressData ? _total : 0;

    double speedCheckInterval = 1000 / 4;
    if(hasProgressData && (nowMils - _lastReceivedTime) > speedCheckInterval) {
      _prevReceivedAmount = _lastReceivedAmount;
      _lastReceivedAmount = expectedBytes;

      _lastReceivedTime = nowMils;
    }

    double percentDone = hasProgressData ? (expectedBytes / totalBytes) : 0;
    String loadedSize = hasProgressData ? Tools.formatBytes(expectedBytes, 1) : '';
    String expectedSize = hasProgressData ? Tools.formatBytes(totalBytes, 1) : '';

    bool isVideo = widget.item.isVideo();

    String percentDoneText = '';
    if(hasProgressData) {
      if(isVideo) {
        percentDoneText = (percentDone == 1) ? 'Rendering...' : '${(percentDone * 100).toStringAsFixed(2)}%';
      } else {
        percentDoneText = (percentDone == 1) ? '${widget.isFromCache ? 'Loading and rendering from cache' : 'Rendering'}...' : '${(percentDone * 100).toStringAsFixed(2)}%';
      }
    } else {
      if(isVideo) {
        percentDoneText = '${widget.isFromCache ? 'Loading from cache' : 'Buffering'}...';
      } else {
        percentDoneText = widget.isDone ? 'Rendering...' : 'Loading${widget.isFromCache ? ' from cache' : ''}...';
      }
    }

    String filesizeText = (hasProgressData && percentDone < 1) ? ('$loadedSize / $expectedSize') : '';

    int expectedSpeed = hasProgressData ? ((_lastReceivedAmount - _prevReceivedAmount) * (1000 / speedCheckInterval).round()) : 0;
    String expectedSpeedText = (hasProgressData && percentDone < 1) ? (Tools.formatBytes(expectedSpeed, 1) + '/s') : '';

    double expectedTime = hasProgressData ? ((totalBytes - expectedBytes) / expectedSpeed) : 0;
    String expectedTimeText = (hasProgressData && expectedTime > 0 && percentDone < 1) ? ("~" + expectedTime.toStringAsFixed(1) + " second${expectedTime == 1 ? '' : 's'} left") : '';

    int sinceStartSeconds = (sinceStart / 1000).floor();
    String sinceStartText = (!widget.isDone && percentDone < 1) ? 'Started ${sinceStartSeconds.toString()} second${sinceStartSeconds == 1 ? '' : 's'} ago' : '';

    bool isMovedBelow = settingsHandler.previewMode == 'Sample' && !widget.item.isHated.value;

    // print('$percentDone | $percentDoneText');

    if(!widget.isViewed) {
      // Do the calculations, but don't render anything if not viewed
      return const SizedBox();
    }

    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 6,
            child: RotatedBox(
              quarterTurns: -1,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Get.theme.colorScheme.secondary),
                backgroundColor: Colors.transparent,
                value: percentDone == 0 ? null : percentDone,
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: EdgeInsets.fromLTRB(10, 10, 10, 30), child: Column(
              // move loading info lower if preview is of sample quality (except when item is hated)
              mainAxisAlignment: isMovedBelow ? MainAxisAlignment.end : MainAxisAlignment.center,
              children: widget.isStopped
                ? [
                    ...widget.stopReasons.map((reason){
                      return BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        )
                      );
                    }),
                    TextButton.icon(
                      icon: Icon(Icons.play_arrow, size: 44, color: Colors.blue),
                      label: BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          widget.item.isHated.value ? 'Load Anyway' : 'Restart Loading',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        )
                      ),
                      onPressed: () {
                        widget.startAction?.call();
                      },
                    ),
                    if(isMovedBelow) const SizedBox(height: 60),
                  ]
                : (settingsHandler.loadingGif
                  ? [
                      Center(child: Image(image: AssetImage('assets/images/loading.gif'))),
                      const SizedBox(height: 30),
                      if(percentDoneText != '')
                        BorderedText(
                          strokeWidth: 3,
                          child: Text(
                            percentDoneText,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          )
                        ),
                    ]
                  : [
                    if(percentDoneText != '')
                      BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          percentDoneText,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        )
                      ),

                    if(filesizeText != '')
                      BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          filesizeText,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        )
                      ),

                    if(expectedSpeedText != '')
                      BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          expectedSpeedText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        )
                      ),

                    if(expectedTimeText != '')
                      BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          expectedTimeText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        )
                      ),

                    if(sinceStartText != '')
                      BorderedText(
                        strokeWidth: 3,
                        child: Text(
                          sinceStartText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        )
                      ),

                    const SizedBox(height: 10),
                    if(percentDone < 1)
                      TextButton.icon(
                        icon: Icon(
                          Icons.stop,
                          size: 44,
                          color: Get.theme.colorScheme.error,
                        ),
                        label: BorderedText(
                          strokeWidth: 3,
                          child: Text(
                            'Stop Loading',
                            style: TextStyle(
                              fontSize: 18,
                              color: Get.theme.colorScheme.error,
                            ),
                          )
                        ),
                        onPressed: () {
                          widget.stopAction?.call();
                        },
                      ),

                    if(isMovedBelow) const SizedBox(height: 60),
                  ]
                )
            ))
          ),
          SizedBox(
            width: 6,
            child: RotatedBox(
              quarterTurns: percentDone != 0 ? -1 : 1,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Get.theme.colorScheme.secondary),
                backgroundColor: Colors.transparent,
                value: percentDone == 0 ? null : percentDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}






// For thumbnails
class ThumbnailLoadingElement extends StatefulWidget {
  final BooruItem item;

  final bool hasProgress;
  final bool? isFromCache;
  final bool isDone;
  final bool isFailed;

  final RxInt total;
  final RxInt received;
  final RxInt startedAt;

  final void Function()? restartAction;

  ThumbnailLoadingElement({
    Key? key,
    required this.item,

    required this.hasProgress,
    required this.isFromCache,
    required this.isDone,
    required this.isFailed,

    required this.total,
    required this.received,
    required this.startedAt,

    required this.restartAction,

  }) : super(key: key);

  @override
  _ThumbnailLoadingElementState createState() => _ThumbnailLoadingElementState();
}

class _ThumbnailLoadingElementState extends State<ThumbnailLoadingElement> {
    final SettingsHandler settingsHandler = Get.find<SettingsHandler>();

  bool isVisible = false;
  int _total = 0, _received = 0, _startedAt = 0;
  Timer? _debounceBytes;
  StreamSubscription? _totalListener, _receivedListener, _startedAtListener;

  @override
  void initState() {  
    super.initState();

    _total = widget.total.value;
    _received = widget.received.value;
    _startedAt = widget.startedAt.value;
  
    _totalListener = widget.total.listen((int value) {
      _onBytesAdded(null, value);
    });

    _receivedListener = widget.received.listen((int value) {
      _onBytesAdded(value, null);
    });

    _startedAtListener = widget.startedAt.listen((int value) {
      _total = 0;
      _received = 0;
      _startedAt = value;
    });
  }

  void _onBytesAdded(int? received, int? total) {
    // always save incoming bytes, but restate only after [debounceDelay]MS
    const int debounceDelay = 250;
    bool isActive = _debounceBytes?.isActive ?? false;

    _received = received ?? _received;
    _total = total ?? _total;

    if (!isActive) {
      // update after a debounce delay
      updateState();
      _debounceBytes = Timer(const Duration(milliseconds: debounceDelay), () {});
    } else if(_total > 0 && _received >= _total) {
      // update if completed
      updateState();
    }
  }

  void updateState() {
    if(this.mounted) {
      setState(() { });
    }
  }

  void disposables() {
    _total = 0;
    _received = 0;
    _startedAt = 0;

    _totalListener?.cancel();
    _receivedListener?.cancel();
    _startedAtListener?.cancel();
    _debounceBytes?.cancel();
  }

  @override
  void dispose() {
    disposables();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int nowMils = DateTime.now().millisecondsSinceEpoch;
    int sinceStart = _startedAt == 0 ? 0 : nowMils - _startedAt;
    bool showLoading = !widget.isDone && (widget.isFailed || (sinceStart > 499));
    // delay showing loading info a bit, so we don't clutter interface for fast loading files

    // return buildElement(context);

    return AnimatedOpacity(
      duration: Duration(milliseconds: settingsHandler.appMode == 'Desktop' ? 50 : 300),
      curve: Curves.linear,
      opacity: showLoading ? 1 : 0,
      onEnd: () {
        isVisible = showLoading;
        updateState();
      },
      child: buildElement(context),
    );
  }

  Widget buildElement(BuildContext context) {
    if (widget.isFailed) {
      return Center(
        child: InkWell(
          child: Container(
            height: 90,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image
                ),
                BorderedText(
                  strokeWidth: 2,
                  child: Text(
                    'ERROR',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  )
                ),
                BorderedText(
                  strokeWidth: 2,
                  child: Text(
                    'Tap to retry!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  )
                ),
              ]
            )
          ),
          onTap: widget.restartAction,
        )
      );
    }

    bool hasProgressData = widget.hasProgress && (_total > 0);
    int expectedBytes = hasProgressData ? _received : 0;
    int totalBytes = hasProgressData ? _total : 0;

    double percentDone = hasProgressData ? (expectedBytes / totalBytes) : 0;
    // String? percentDoneText = hasProgressData
    //     ? ((percentDone ?? 0) == 1 ? null : '${(percentDone! * 100).toStringAsFixed(2)}%')
    //     : (isFromCache == true ? '...' : null);

    if(widget.isFromCache != false) {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 2,
          child: RotatedBox(
            quarterTurns: -1,
            child: LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Get.theme.colorScheme.secondary),
              backgroundColor: Colors.transparent,
              value: percentDone
            ),
          ),
        ),

        SizedBox(
          width: 2,
          child: RotatedBox(
            quarterTurns: -1,
            child: LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Get.theme.colorScheme.secondary),
              backgroundColor: Colors.transparent,
              value: percentDone
            ),
          ),
        ),
        // SizedBox(
        //   height: 100 / widget.columnCount,
        //   width: 100 / widget.columnCount,
        //   child: CircularProgressIndicator(
        //     strokeWidth: 14 / widget.columnCount,
        //     valueColor: AlwaysStoppedAnimation<Color>(GET.Get.theme.colorScheme.secondary),
        //     value: percentDone,
        //   ),
        // ),
        // if(widget.columnCount < 5 && percentDoneText != null) // Text element overflows if too many thumbnails are shown
        //   ...[
        //     Padding(padding: EdgeInsets.only(bottom: 10)),
        //     Text(
        //       percentDoneText,
        //       style: TextStyle(
        //         fontSize: 12,
        //       ),
        //     ),
        //   ],
      ],
    );
  }
}