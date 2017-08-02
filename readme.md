# BakingTray #

<a href="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq.jpg">
<img src="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq_thumb.jpg">
</a>

### What is it?
BakingTray is a [ScanImage](https://vidriotechnologies.com/) wrapper that performs serial section 2-photon tomography (STP) within [MATLAB](http://www.mathworks.com/). 
The software is inspired the Svoboda lab's [TeraVoxel](https://github.com/TeravoxelTwoPhotonTomography) project but runs on NI hardware. 

### Who is it for?
Technically-minded people who want an open source STP solution. 
You'll need MATLAB programming skills and the know how to set up and run a 2-photon microscope. 
This is not a turn-key solution. 


### What hardware does it run on?
BakingTray will run on any hardware [supported by ScanImage](http://scanimage.vidriotechnologies.com/display/SI2017/Supported+Microscope+Hardware).
You can use either a linear or resonant scanner for the fast axis, but resonant is recommended for speed and is better supported by BakingTray.
Control of the 3-axis stage is done from within BakingTray, not ScanImage. 
Use a [supported device](https://github.com/BaselLaserMouse/BakingTray) or write your own controller class using the provided instructions. 


### How does it work?
BakingTray is based upon an [existing tile-scanner extension for ScanImage](https://github.com/BaselLaserMouse/ScanImageTileScan).
BakingTray simply slices off the top of the sample after each tile-scan is complete, exposing fresh tissue for imaging. 
Imaging itself is performed via ScanImage, which is freely available MATLAB-based software for running 2-photon microscopes. 
The ScanImage API [allows the software to be controlled progamatically](https://github.com/tenss/ScanImageAPI_Examples). 


### Current features
Whilst this software is under development, it has been thoroughly stress-tested and is capable of generating production-quality data.
Its current feature set is as follows:

* Easy sample set up: no need for the user to calculate the number of tiles.
* Fast "preview" image allows the block face to be rapidly imaged to aid set up.
* Acquisition of up to four channels.
* Real-time assembly of a downsampled image during scanning (all optical planes and channels) for quick visualisation.
* Graceful acquisition abort (either immediately or at the end of the current section).
* Pause the acquisition.
* Acquisition is automatically stopped if the system loses contact with the laser or the laser drops out of modelock. 
* The PMTs and laser are automatically switched off at the end of the acquisition.
* Support for multiple lasers via Scanimage.
* Easy control of illumination as a function of depth via ScanImage. 
* Integrates with our [StitchIt](https://github.com/BaselLaserMouse/StitchIt) software for assembling the stitched images from raw tiles. 
* Supports both resonant and linear scanning.
* A software "Stop" button to instantly halt motion on all stages.
* Easily resume a previously halted acquisition. 

### Under the hood
BakingTray is underpinned by a modular API that controls the three axis stage, laser power, vibratome, and the scanning software (ScanImage). 
Developers can swap any of these components (even the scanning software) for new ones of their own design. 
This allows for enormous flexibility in upgrading the microscope or modifying the behavior of the acquisition software. 


### Installation ###
- You will need a functioning ScanImage install.
- Add to your path: `code`, `resources`, and `components` plus its sub-directories. 
- You will need to define your hardware in the `componentSettings.m` file (no detailed notes on this yet). 
- Run `scanimage` 
- Run `BakingTray`
