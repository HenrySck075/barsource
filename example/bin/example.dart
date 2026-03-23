import 'package:tennoji/tennoji.dart';

void main(){
  render(Stack(
    children: [
      VideoClip(source: "sample_video_720p.mp4"),
      Column(children: [
      // Fade in a red box over the first second
      FadeTransition(
        animation: TimelineAnimation(
          duration: Duration(seconds: 1),
          curve: Curves.easeIn,
        ),
        opacity: Tween(begin: 0.0, end: 1.0),
        child: Container(
          width: 200,
          height: 200,
          color: Color(0xFFFF0000),
        ),
      ),
      // Slide in a green box from the left over 0.5s
      SlideTransition(
        animation: TimelineAnimation(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
        offset: OffsetTween(begin: (-1.0, 0.0), end: (0.0, 0.0)),
        child: Container(
          width: 100,
          height: 100,
          color: Color(0xFF00FF00),
        ),
      ),
      // Spin a blue box one full turn over 2s
      RotationTransition(
        animation: TimelineAnimation(
          duration: Duration(seconds: 2),
          curve: Curves.easeInOut,
        ),
        turns: Tween(begin: 0.0, end: 1.0),
        child: Container(
          width: 80,
          height: 80,
          color: Color(0xFF0000FF),
        ),
      ),
      ]),
      AnimatedList<String>(
        itemBuilder: (context, data, anim){
          return SlideTransition(
            animation: anim, offset: OffsetTween(begin: (1.0, 0.0), end: (0.0, 0.0)),
            child: Container(width: 100, height: 20,color:Color(0xFF363636), child: Text(text: data))
          );
        },
        instructions: [
          AnimatedListInstruction(
            type: .insert, 
            time: Duration(seconds: 1), 
            data: "hi"
          ),
          AnimatedListInstruction(
            type: .insert, 
            time: Duration(seconds: 2), 
            data: "hello"
          )
        ]
      )
    ]
  ), RenderConfig(
    output: "out.mp4", 
    duration: Duration(seconds: 5), 
    fps: 30, 
    resolution: Size(1280,720)
  ));
}
