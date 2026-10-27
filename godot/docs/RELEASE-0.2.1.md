## Driving and interface fixes

- All ten car models face forward when accelerating. The chase camera now looks at the rear of the vehicle.
- Speed is visible in a dedicated panel with km/h and the current forward or reverse gear.
- The timer, objective and lap counter fit the screen and have a dark backdrop for readability.
- Pause and results open in centered panels with a dimmed background. Menu buttons are clickable at all tested window sizes.
- Desktop play hides mobile pedals and their labels.
- Garage layout scales with the viewport; mouse and touch orbit starts outside its sidebar.

Verified in Godot 4.7.2 at window sizes 1280×720, 1920×1080 and 1024×600, including pointer clicks on Continue. All ten model directions were visually checked.

**Windows:** extract the archive completely and run `NeonDrift.exe`. Keep `NeonDrift.pck` beside it. Replace both files when updating from the previous preview. Godot editor users can open `godot/project.godot` and press F5.
