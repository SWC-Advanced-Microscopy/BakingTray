# Release 20th June 2021

This release encapsulates changes made between 4th May 2021 and 20th June 2021.

## Highlights
- **vDAQ fully supported.**
- **No more long lag** after pressing Bake.
- **New tiling pattern:** the Y stage, which pushes less mass, now does most of the moves.


## Changes for end-users
- Trim slices during sample preparation are now always started from the cutting start point. So if the sample was located in a different position, it is moved to the cutting start point then all future cuts are also taken from this position.
- **Bugfix:** A bug that caused auto-ROI acquisitions to crash very near the end is now trapped. The acquisition still stops but now does so more gracefully.
- The long lag in starting an acquisition after Bake is pressed is now fixed.
- The tiling pattern has been modified so that the upper (Y) stage now does most of the motions. This stage pushes a lower mass and so this change makes sense. The change can be reverted to the previous behavior by altering a new setting (`settings.SYSTEM.dominantTilingDirection`) in the system settings file. The new setting is automatically added when BakingTray is started. To alter it you need to edit then re-start BakingTray. **NOTE: using the Y tile direction will require StitchIt to be updated too!**
- If PMTs are left with auto-on enabled, this is disabled when Bake is pressed or the scanner is armed. If this fails and the auto-on remains in place, the acquisition will not start until the user disables it. This is because the auto-on feature has caused crashes in some acquisitions and because on some rigs the Pockels cell power is gated by PMT power state. PMTs are in any case turned off at the end of the acquisition.


## Changes for developers and power users
- vDAQ is now tested and fully supported.
- The position of the Y stage during cutting is no longer fixed at 0 mm. It can be set to a different number via the `settings.SLICER.defaultYcutPos` setting in the system settings file. This is automatically added on start. Edit and restart BakingTray for it to take effect.
- There is a hack for obtaining laser power at sample on ScanImage BASIC systems. This feature is unstable. See commit on May 11th.
- Support for a new Zaber linear stage type.
- Added code for assessing stage settling performance using a camera. This is partially documented in-line and located in `BakingTray/diagnostic/measuring_xy_accuracy`
