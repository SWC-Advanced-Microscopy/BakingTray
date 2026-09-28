# Release 22nd September 2022

This release encapsulates changes made between February 2022 and 22nd September 2022. The last major release was 7th December 2021.

## Highlights
- **Laser power in mW shown in ScanImage**, updating automatically with wavelength.
- **`assessAverage`** shows how much averaging you need without bleaching the sample.
- **Running `BakingTray` also starts ScanImage.**
- **More robust acquisition resume.**


## New features

### assessAverage
There is a function called `assessAverage` that you can run when you are over the brain during set up. It will take 16 frames and show you what they look like at different levels of averaging. The idea is that you run this before you have scanned the area and do so at the laser power you will end up using. This is a more effective way of estimating how much you might want to average, as dwelling over an area in Focus mode will *rapidly bleach the sample* and so cause you to over-estimate how effective averaging is.

### Starting ScanImage
Running `BakingTray` at the command line will now start ScanImage if it is not already started.

### Laser power in mW in ScanImage
You can now display laser power in mW in ScanImage and have it automatically update when the wavelength is changed. The feature has been tested only with ScanImage 2022 but hopefully will work in some earlier versions also.

To use it:
1. Open the Laser GUI in BakingTray.
2. Turn on the laser and open the shutter.
3. Set desired wavelength in the laser GUI.
4. In ScanImage run the beam calibration function from the beams widget. You will need a photodiode in the path. If you do not have this, you can use the power meter at the objective so long as the sensor is fast enough. Connect the AO from the sensor to an AI line on the DAQ. In the machine config file where the beam is configured, tell ScanImage which AI line to look at. You should get a nice smooth curve with the calibration tool.
5. Measure min and max power and set these in the MDF GUI under the laser. You can access this from the gear icon on the beams widget.
6. Confirm with power meter that the curve makes sense by looking at a few different values. It is normal to be off by about 10% and for low values (e.g. 10 mW) to be off by 50%. For the values typically used for imaging, however, it should be accurate enough.
7. Run `BakingTray.utils.addLaserCalib`. This will store the information in a .MAT file and over-write any existing calibration at the same wavelengths, should this exist.
8. Run this for your commonly used wavelengths. e.g. 920 nm, 800 nm, 780 nm. When you change wavelength, BakingTray will look for the closest calibration file. e.g. if you did the above three calibrations and you go to 930 nm, it will load the 920 nm calibration. If the laser wavelength is more than 20 nm from any existing calibration file, then it will not report laser power at all.

You may list existing calibrations with `BakingTray.utils.listLaserCalib`


## Bug fixes
- The system no longer hangs in scanning mode if the brain has vanished during AutoROI. This sometimes happened and stopped a clean shutdown of Bake.
- PMT trip reset works in newer SI versions.
- A bug fix associated with the default Y position being wrong under certain situations.
- The code that handles Pockels power supply being switched on with the laser is now working properly.

Two fixes/improvements to resuming of acquisitions:
- A bugfix when creating the backup recipes during resume.
- BakingTray will no longer write into a directory marked as FINISHED.


Other small changes: see the ChangeLog file.
