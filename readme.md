# BakingTray #


### What is it?
BakingTray is a [ScanImage 5.2](https://vidriotechnologies.com/) wrapper that performs serial section 2-photon tomography (STP) within [MATLAB](http://www.mathworks.com/). 
The software is inspired the Svoboda lab's [TeraVoxel](https://github.com/TeravoxelTwoPhotonTomography) project but runs on NI hardware. 

### How does it work?
BakingTray combines ScanImage and an existing ScanImage [tile-scanner](https://github.com/BaselLaserMouse/ScanImageTileScan) extension to perform 2-photon tomography.
ScanImage is freely available MATLAB-based software for running 2-photon microscopes with resonant or linear scanners. 
The ScanImage API [allows the software to be controlled progamatically](https://github.com/tenss/ScanImageAPI_Examples). 
BakingTray coordinates stage motions and image acquisition to implement tile-scanning. 
After the acquisition of each section, the freshly-exposed sample surface is imaged. 


### Current features
This software is under heavy development but it has been used to produce real data and has been stress-tested.
Its current feature set is as follows:

* Easy sample set up: no need for the user to calculate the number of tiles or manually find the front-left starting position for the tile grid.
* Fast "preview" image allows the block face to be rapidly imaged to aid set up.
* Acquisition of up to four channels.
* Real-time assembly of a downsampled image during scanning (all optical planes and channels) for quick visualisation.
* Graceful acquisition abort (either immediately or at the end of the current section).
* Pause the acquisition.
* Acquisition is automatically stopped if the system loses contact with the laser or the laser drops out of modelock. 
* The PMTs and laser are automatically switched off at the end of the acquisition.
* Support for multiple lasers via Scanimage.
* Easy control of illumination correction as a function of depth via ScanImage. 
* Integrates with our *StitchIt* software for assembling the stitched images from raw tiles. 
* Resonant and linear  scanning.
* A software "Stop" button to instantly halt motion on all stages.


### Under the hood
BakingTray is underpinned by a modular API that controls the three axis stage, laser power, vibratome, and the scanning software (ScanImage). 
Developers can swap any of these components (even the scanning software) for new ones of their own design. 
This allows for enormous flexibility in upgrading the microscope: faster stages, a faster laser power modulator, resonant scanners, etc.
Furthermore, the API itself is sufficiently generic that it becomes possible to easily write custom code to perform very unusual acquisition scenarios. 
For instance, it would be trivial to acquire tiles from a section at one wavelength then tune the laser to a different wavelength and re-image the section before slicing and moving on to the next section. 
Another possible scenario would be to image most of the sample at a resolution of, say, 5 microns per pixel but to have one quadrant imaged at 0.5 microns per pixel. 

BakingTray is composed of an object-oriented API to which the components controlling the hardware and the scanner are attached. 
All of BakingTray's features can be accessed via the API. 
BakingTray's GUI sits on top of the API and contains minimal logic, so it can easily be swapped out or modified. 
The source files themselves are well commented and some more detailed documentation is also available. 



### Installation ###
- You will need a functioning ScanImage 5.2 install.
- Add to your path: `code`, 'resources`, and `components` plus its sub-directories. 
- You will need to define your hardware in the `componentSettings.m` file (no detailed notes on this yet). 
- Run `scanimage` 
- Run `BakingTray`
