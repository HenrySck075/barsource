![](assets/readme_img.png)



TODO: gpu on the ffmpeg


# Note
- All image operations are synchronous. Not because of the way the native library is built (it is) but because in the context of a video renderer it doesnt make sense to have them asynchronous.

# FAQ
## Is it really that easy if you're familiar with Flutter?
yeah ofc its just swapping `runApp` with `render` plus delete the WidgetsApp widgets and adding a render config

## How fast is it tho
i have no idea, but it should be fast because it does less work on each cycle than flutter (obviously)

if you wanted to get technical, it also internally didn't use `Dart_Handle` to pass around objects between the two worlds unlike flutter, that is the main source of the slowness. however 2 programs does 2 things differently so i think its justified

## who is that girl
rina tennoji