/// scary name aside this is thrown on [RenderAudioClip.duration] and [RenderVideoClip.duration] setters because they dont allow you to change it.
/// its an override setter as [RenderObject.duration] is a thing i cant just delete it man
class IllegalExecution {}
