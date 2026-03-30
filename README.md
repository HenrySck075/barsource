![](assets/readme_img.png)

# BarSource Video Editing Library
The most library of all time

TODO: gpu on the ffmpeg

# Code example
```dart
import 'package:barsource/barsource.dart';

```

# Note
- All image operations are synchronous. Not because of the way the native library is built (it is) but because in the context of a video renderer it doesnt make sense to have them asynchronous.
- `RenderObject.paint` is called every frame.
- Package is named on the GitHub source code as `tennoji`

# FAQ
## Is it really that easy if you're familiar with Flutter?
yeah ofc its just swapping `runApp` with `render` plus delete the WidgetsApp widgets and adding a render config

## How fast is it tho
i have no idea, but it should be fast because it does less work on each cycle than flutter (obviously)

if you wanted to get technical, it also internally didn't use `Dart_Handle` to pass around objects between the two worlds unlike flutter, that is the main source of the slowness thumbsup emoji 

## who is that girl
rina tennoji

## ew ai slop
1. no its not
2. if i did it myself id spend 6 months copying the entire flutter framework over 
so i let something that knows how to selectively implements stuff to do the work. 
for a proof see the dart_ui folder

ignore the weird new line stuff the ssh window does not play well
with neovim

3. i used ai sparingly
