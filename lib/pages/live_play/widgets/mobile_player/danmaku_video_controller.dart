import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter_barrage/flutter_barrage.dart';
import 'package:hot_live/common/index.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

class DanmakuText extends StatelessWidget {
  const DanmakuText({Key? key, required this.message}) : super(key: key);

  final String message;
  static const Color borderColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    SettingsProvider settings = Provider.of<SettingsProvider>(context);

    Widget cur = Text(
      message,
      maxLines: 1,
      style: TextStyle(
        fontSize: settings.danmakuFontSize,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      ),
    );

    // setting text border
    if (settings.danmakuFontBorder > 0) {
      cur = Stack(
        children: [
          Text(
            message,
            maxLines: 1,
            style: TextStyle(
              fontSize: settings.danmakuFontSize,
              fontWeight: FontWeight.w400,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = settings.danmakuFontBorder
                ..color = borderColor,
            ),
          ),
          cur,
        ],
      );
    }

    return cur;
  }
}

class DanmakuVideoController extends StatefulWidget {
  final GlobalKey playerKey;
  final BetterPlayerController controller;
  final DanmakuStream danmakuStream;
  final String title;
  final double? width;

  const DanmakuVideoController({
    Key? key,
    required this.controller,
    required this.danmakuStream,
    required this.playerKey,
    this.title = '',
    this.width,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return DanmakuVideoControllerState();
  }
}

class DanmakuVideoControllerState extends State<DanmakuVideoController>
    with SingleTickerProviderStateMixin {
  final barHeight = 56.0;
  final marginSize = 5.0;

  bool _hideStuff = false;
  bool _lockStuff = false;
  bool _displaySetting = false;
  Timer? _hideTimer;

  // 滑动调节控制
  bool _dragingBV = false;
  double? updatePrevDx;
  double? updatePrevDy;
  int? updatePosX;
  bool? isDargVerLeft;
  double? updateDargVarVal;
  VolumeController volumeController = VolumeController()..showSystemUI = false;
  ScreenBrightness brightnessController = ScreenBrightness();

  BetterPlayerController? _controller;
  late final SettingsProvider settings = Provider.of<SettingsProvider>(context);

  final BarrageWallController _barrageWallController = BarrageWallController();

  // We know that _controller is set in didChangeDependencies
  BetterPlayerController get controller => _controller!;
  VideoPlayerValue get latestValue => controller.videoPlayerController!.value;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller?.addEventsListener(eventListener);
    widget.danmakuStream.listen((info) {
      try {
        _barrageWallController
            .send([Bullet(child: DanmakuText(message: info.msg))]);
      } catch (e) {
        return;
      }
    });
    _cancelAndRestartHideTimer();
  }

  @override
  void dispose() {
    _barrageWallController.dispose();
    _controller?.removeEventsListener(eventListener);
    _hideTimer?.cancel();
    super.dispose();
  }

  dynamic eventListener(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
      setState(() {});
    }
  }

  void setBoxFit(int index) {
    settings.playerFitMode = index;
    final boxFit = index == 0
        ? BoxFit.contain
        : index == 1
            ? BoxFit.fill
            : BoxFit.fitWidth;
    controller.setOverriddenFit(boxFit);
  }

  @override
  Widget build(BuildContext context) {
    if (latestValue.hasError) {
      return Container();
    }

    List<Widget> ws = [];
    if (!settings.hideDanmaku) {
      ws.add(_buildDanmakuView());
    }
    ws.add(_buildHitArea());
    if (!_displaySetting) {
      ws.add(_buidLockStateButton());
      if (!_lockStuff) {
        ws.add(_buildActionBar());
        ws.add(_buildBottomBar());
      }
    }
    return Stack(children: ws);
  }

  Widget _buidLockStateButton() {
    return AnimatedOpacity(
      opacity: controller.isFullScreen && !_hideStuff ? 0.9 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(right: 20.0),
          child: IconButton(
            iconSize: 28,
            onPressed: () {
              _cancelAndRestartHideTimer();
              setState(() => _lockStuff = !_lockStuff);
            },
            icon:
                Icon(_lockStuff ? Icons.lock_rounded : Icons.lock_open_rounded),
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Danmaku widget
  Widget _buildDanmakuView() {
    double danmukuHeight = (controller.isFullScreen
            ? MediaQuery.of(context).size.height
            : (MediaQuery.of(context).size.width / 16 * 9)) *
        settings.danmakuArea;

    return Positioned(
      top: 0,
      width: MediaQuery.of(context).size.width,
      height: danmukuHeight,
      child: AnimatedOpacity(
        opacity: !settings.hideDanmaku ? settings.danmakuOpacity : 0.0,
        duration: const Duration(milliseconds: 300),
        child: BarrageWall(
          width: MediaQuery.of(context).size.width,
          height: danmukuHeight,
          speed: settings.danmakuSpeed.toInt(),
          controller: _barrageWallController,
          massiveMode: true,
          maxBulletHeight: settings.danmakuFontSize * 1.25,
          child: Container(),
        ),
      ),
    );
  }

  // Center hit and controller widgets
  Widget _buildHitArea() {
    if (_displaySetting) {
      return GestureDetector(
        onTap: () {
          _cancelAndRestartHideTimer();
          if (_displaySetting) {
            setState(() => _displaySetting = false);
          }
        },
        child: Container(
          color: Colors.transparent,
          child: _buildSettingView(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (latestValue.isPlaying) {
          _cancelAndRestartHideTimer();
        } else {
          _playPause();
        }
      },
      onDoubleTap: _toggleFullScreen,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        color: Colors.transparent,
        child: _dragingBV ? _buildDargVolumeAndBrightness() : Container(),
      ),
    );
  }

  Widget _buildDargVolumeAndBrightness() {
    IconData iconData = Icons.volume_up;

    if (_dragingBV) {
      if (isDargVerLeft!) {
        iconData = updateDargVarVal! <= 0
            ? Icons.brightness_low
            : updateDargVarVal! < 0.5
                ? Icons.brightness_medium
                : Icons.brightness_high;
      } else {
        iconData = updateDargVarVal! <= 0
            ? Icons.volume_mute
            : updateDargVarVal! < 0.5
                ? Icons.volume_down
                : Icons.volume_up;
      }
    }

    return Container(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: _dragingBV ? 0.8 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Card(
          color: Colors.black,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(iconData, color: Colors.white),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      height: 20,
                      child: LinearProgressIndicator(
                        value: updateDargVarVal,
                        backgroundColor: Colors.white38,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).indicatorColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingView() {
    SettingsProvider settings = Provider.of<SettingsProvider>(context);
    final isSelected = [false, false, false];
    isSelected[settings.playerFitMode] = true;

    const TextStyle label = TextStyle(color: Colors.white);
    const TextStyle digit = TextStyle(color: Colors.white);
    final Color color = Theme.of(context).colorScheme.primary.withOpacity(0.8);

    return Container(
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        opacity: _displaySetting ? 0.8 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: GestureDetector(
            onTap: () {},
            child: Card(
              color: Colors.black,
              child: SizedBox(
                width: 380,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '比例设置',
                        style: Theme.of(context)
                            .textTheme
                            .caption
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(10),
                      selectedBorderColor: color,
                      borderColor: color,
                      fillColor: color,
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('默认比例', style: label),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('填充屏幕', style: label),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('居中裁剪', style: label),
                        ),
                      ],
                      isSelected: isSelected,
                      onPressed: setBoxFit,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '弹幕设置',
                        style: Theme.of(context)
                            .textTheme
                            .caption
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        S.of(context).settings_danmaku_area,
                        style: label,
                      ),
                      title: Slider(
                        value: settings.danmakuArea,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => settings.danmakuArea = val,
                      ),
                      trailing: Text(
                        (settings.danmakuArea * 100).toInt().toString() + '%',
                        style: digit,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        S.of(context).settings_danmaku_opacity,
                        style: label,
                      ),
                      title: Slider(
                        value: settings.danmakuOpacity,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => settings.danmakuOpacity = val,
                      ),
                      trailing: Text(
                        (settings.danmakuOpacity * 100).toInt().toString() +
                            '%',
                        style: digit,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        S.of(context).settings_danmaku_speed,
                        style: label,
                      ),
                      title: Slider(
                        value: settings.danmakuSpeed,
                        min: 1.0,
                        max: 20.0,
                        onChanged: (val) => settings.danmakuSpeed = val,
                      ),
                      trailing: Text(
                        settings.danmakuSpeed.toInt().toString(),
                        style: digit,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        S.of(context).settings_danmaku_fontsize,
                        style: label,
                      ),
                      title: Slider(
                        value: settings.danmakuFontSize,
                        min: 10.0,
                        max: 30.0,
                        onChanged: (val) => settings.danmakuFontSize = val,
                      ),
                      trailing: Text(
                        settings.danmakuFontSize.toInt().toString(),
                        style: digit,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        S.of(context).settings_danmaku_fontBorder,
                        style: label,
                      ),
                      title: Slider(
                        value: settings.danmakuFontBorder,
                        min: 0.0,
                        max: 2.5,
                        onChanged: (val) => settings.danmakuFontBorder = val,
                      ),
                      trailing: Text(
                        settings.danmakuFontBorder.toStringAsFixed(2),
                        style: digit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Action bar widgets
  Widget _buildActionBar() {
    List<Widget> rows = [];
    if (controller.isFullScreen) {
      rows = [
        _buildBackButton(),
        Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        const Spacer(),
        _buildBatteryInfo(),
        _buildTimeInfo()
      ];
    } else {
      rows = [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.title,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        _buildPIPButton(),
      ];
    }

    return Positioned(
      top: 0,
      height: barHeight,
      width: widget.width ?? MediaQuery.of(context).size.width,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromRGBO(0, 0, 0, 0.02), Colors.black]),
          ),
          child: Row(children: rows),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _toggleFullScreen,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTimeInfo() {
    // get system time and format
    final dateTime = DateTime.now();
    var hour = dateTime.hour.toString();
    if (hour.length < 2) hour = '0$hour';
    var minute = dateTime.minute.toString();
    if (minute.length < 2) minute = '0$minute';

    return Container(
      height: barHeight,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Text(
        '$hour:$minute',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildBatteryInfo() {
    final batteryLevel = settings.batteryLevel;
    return Container(
      height: barHeight,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 4.0),
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: SizedBox(
              width: 20,
              height: 10,
              child: LinearProgressIndicator(
                value: batteryLevel / 100.0,
                backgroundColor: Colors.white38,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).indicatorColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$batteryLevel%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPIPButton() {
    return GestureDetector(
      onTap: () async {
        if (await controller.isPictureInPictureSupported()) {
          controller.enablePictureInPicture(widget.playerKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              margin: EdgeInsets.symmetric(horizontal: 16),
              content: Text('暂不支持画中画'),
            ),
          );
        }
      },
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: const Icon(
          CustomIcons.float_window,
          color: Colors.white,
        ),
      ),
    );
  }

  // Bottom bar widgets
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      height: barHeight,
      width: widget.width ?? MediaQuery.of(context).size.width,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.fromRGBO(0, 0, 0, 0.02), Colors.black]),
          ),
          child: Row(
            children: <Widget>[
              _buildPlayPauseButton(),
              _buildRefreshButton(),
              _buildDanmakuHideButton(),
              if (controller.isFullScreen) _buildSettingButton(),
              const Spacer(),
              _buildExpandButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          latestValue.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: () => controller.retryDataSource(),
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: const Icon(
          Icons.refresh_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDanmakuHideButton() {
    return GestureDetector(
      onTap: () {
        setState(() => settings.hideDanmaku = !settings.hideDanmaku);
      },
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          settings.hideDanmaku
              ? CustomIcons.danmaku_close
              : CustomIcons.danmaku_open,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSettingButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() => _displaySetting = !_displaySetting);
        },
        child: Container(
          height: barHeight,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: const Icon(
            CustomIcons.danmaku_setting,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: _toggleFullScreen,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          controller.isFullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // Callback functions
  void _cancelAndRestartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _hideStuff = true);
    });
    setState(() => _hideStuff = false);
  }

  void _playPause() {
    if (latestValue.isPlaying) {
      _cancelAndRestartHideTimer();
      controller.pause();
    } else {
      _hideTimer?.cancel();
      controller.play();
      _hideStuff = true;
    }
    setState(() {});
  }

  void _toggleFullScreen() {
    setState(() {
      _hideStuff = true;
      _lockStuff = false;
    });
    controller.toggleFullScreen();
  }

  // Gesture functions
  void _onVerticalDragStart(detills) async {
    if (_displaySetting || _lockStuff) return;

    double clientW = MediaQuery.of(context).size.width;
    setState(() {
      updatePrevDy = detills.globalPosition.dy;
      isDargVerLeft =
          (detills.globalPosition.dx > (clientW / 2)) ? false : true;
    });

    if (isDargVerLeft!) {
      // 亮度
      await brightnessController.current.then((double v) {
        _dragingBV = true;
        setState(() => updateDargVarVal = v);
      });
    } else {
      // 音量
      await volumeController.getVolume().then((double v) {
        _dragingBV = true;
        setState(() => updateDargVarVal = v);
      });
    }
  }

  void _onVerticalDragUpdate(detills) {
    if (!_dragingBV) return;

    double curDragDy = detills.globalPosition.dy;
    // 确定当前是前进或者后退
    int cdy = curDragDy.toInt();
    int pdy = updatePrevDy!.toInt();
    bool isBefore = cdy < pdy;
    // + -, 不满足, 上下滑动合法滑动值，> 3
    if (isBefore && pdy - cdy < 3 || !isBefore && cdy - pdy < 3) return;
    // 区间
    double dragRange =
        isBefore ? updateDargVarVal! + 0.03 : updateDargVarVal! - 0.03;
    // 是否溢出
    dragRange = dragRange > 1 ? 1.0 : dragRange;
    dragRange = dragRange < 0 ? 0.0 : dragRange;

    setState(() {
      updatePrevDy = curDragDy;
      _dragingBV = true;
      updateDargVarVal = dragRange;
      // 亮度 & 音量
      if (isDargVerLeft!) {
        brightnessController.setScreenBrightness(dragRange);
      } else {
        volumeController.setVolume(dragRange);
      }
    });
  }

  void _onVerticalDragEnd(detills) {
    setState(() => _dragingBV = false);
  }
}
