import 'dart:async';
import 'package:logging/logging.dart';

import 'package:tennoji/tennoji.dart';

class bomb extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _bombState(); 
}

class _bombState extends State<bomb> {
  late final ListController<String> _controller;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final CurvedAnimation _slideCurve;
  late final AnimationController _rotateCtrl;
  @override
  void initState() {
    super.initState();

    _controller = ListController<String>([]);
    _fadeCtrl = AnimationController(
      duration: Duration(seconds: 1),
    );
    _slideCtrl = AnimationController(
      duration: Duration(milliseconds: 500),
    );
    _slideCurve = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOut,
    );
    _rotateCtrl = AnimationController(
      duration: Duration(seconds: 2),
    );

    EngineTimer(Duration(seconds: 1), ()=>_controller.insert(0, "hi"));
    EngineTimer(Duration(seconds: 2), ()=>_controller.insert(1, "hello"));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _slideCurve.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoClip(source: "sample_video_720p.mp4"),
        Column(children: [
        // Fade in a red box over the first second
        FadeTransition(
          opacity: _fadeCtrl.drive(CurveTween(
            curve: Curves.easeIn,
          )),
          child: Container(
            width: 200,
            height: 200,
            color: Color(0xFFFF0000),
          ),
        ),
        // Slide in a green box from the left over 0.5s
        SlideTransition(
          offset: _slideCurve.drive(
            Tween<Offset>(
              begin: Offset(-1.0, 0.0), 
              end: Offset(0.0, 0.0)
            ),
          ),
          child: Container(
            width: 100,
            height: 100,
            color: Color(0xFF00FF00),
          ),
        ),
        // Spin a blue box one full turn over 2s
        RotationTransition(
          turns: _rotateCtrl.drive(
            CurveTween(curve: Curves.easeInOut)
          ),
          child: Container(
            width: 80,
            height: 80,
            color: Color(0xFF0000FF),
          ),
        ),
        Text(text: "Hello World"),
        ]),
        Text(text: "g"),
        AnimatedList<String>(
          listController: _controller,
          itemBuilder: (context, data, anim){
            return SlideTransition(
              offset: anim.drive(Tween<Offset>(
                begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0)
              )),
              child: Container(width: 200, height: 80,color:Color(0xFF363636), child: Text(text: data))
            );
          }
        )
      ]
    );
  }
}
void main(){
  render(bomb(), RenderConfig(
    output: "out.mp4", 
    duration: Duration(seconds: 5), 
    fps: 30, 
    resolution: Size(1280,720),
    logLevel: Level.ALL
  ));
}
