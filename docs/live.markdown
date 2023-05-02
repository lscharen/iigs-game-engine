---
layout: page
---

<script>
    var emulator = new Emulator(document.querySelector("#canvas"),
                              null,
                              new MAMELoader(MAMELoader.driver("1943"),
                                             MAMELoader.nativeResolution(224, 256),
                                             MAMELoader.scale(3),
                                             MAMELoader.emulatorJS("emulators/mess1943.js"),
                                             MAMELoader.mountFile("1943.zip",
                                                                  MAMELoader.fetchFile("Game File",
                                                                                       "examples/1943.zip"))))
    emulator.start({ waitAfterDownloading: true });
</script>
<canvas id="canvas" width="800" height="600"></canvas>