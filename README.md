# BarSource Video Editing Library
The most programmatic video editing library of all time....2

# Code example
see the example folder

# Note
- All image operations are synchronous. Not because of the way the native library is built (it is) but because in the context of a video renderer it doesnt make sense to have them asynchronous.
- `RenderObject.paint` is called every frame.
- GPU acceleration feature was only tested on an Intel i5-7200U system using Vulkan (linux), other backend's and device's stability are not guaranteed. Especially MediaCodec (android) i still need to figure out how to compile a custom dartdev that actually supports android build hooks

# FAQ
## Is it really that easy if you're familiar with Flutter?
yeah ofc its just swapping `runApp` with `render` plus delete the WidgetsApp widgets and adding a render config

> TODO: add WidgetsApp 

## How fast is it tho
i have no idea, but it should be fast because it does less work on each cycle than flutter (obviously)

if you wanted to get technical, it also internally didn't use `Dart_Handle` to pass around objects between the two worlds unlike flutter, that is the main source of the slowness thumbsup emoji 

## who is that girl
[:D](https://google.com/search?q=rina+tennoji)

also remind me to remove that image from the repo when we get serious

## does barsource means anything
[no](https://wikipedia.org/wiki/Thanh_H%C3%B3a)

## why is the native backend named libtennoji
whole project historically named that and i didnt bother renaming the backend since almost nobody interacts with them directly anyway

## what did you even learn from this
i know how to abuse render objects!
