# BakingTray #

<a href="https://raw.githubusercontent.com/wiki/SWC-Advanced-Microscopy/images/example_acq.jpg">
<img src="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq_thumb.jpg">
</a>

### What is it?
BakingTray is a complete software platform for 2-photon serial-section microscopy. 
It plugs into [ScanImage](https://www.mbfbioscience.com/products/scanimage/) and runs within [MATLAB](http://www.mathworks.com/).
For more information see the SWC AMF [BrainSaw project page](https://swcmicroscopy.com/brainsaw/).

### Who is it for?
This software is aimed at technically-minded people who want to experiment with serial-section imaging and have full control over all aspects of the process. 
Setting up BakingTray from scratch on your rig requires _significant effort_, good MATLAB programming skills, knowledge of ScanImage, and the know-how to set up and run a 2-photon microscope. 
BakingTray will run on any hardware [supported by ScanImage](http://scanimage.vidriotechnologies.com/display/SI2017/Supported+Microscope+Hardware).

### How does it work?
BakingTray simply slices off the top of the sample after each tile-scan is complete, exposing fresh tissue for imaging. 
Imaging itself is performed via ScanImage, which is freely available MATLAB-based software for running 2-photon microscopes. 

### Current features
This software has been thoroughly stress-tested and is being run in several labs and facilities worldwide.
The current feature set is as follows:

* Easy sample set up: take a fast preview image of the sample, draw a box around the area to be imaged, "auto-ROI" feature for [imaging only the sample](https://www.youtube.com/watch?v=yHEkR3nZsOw).
* Acquisition of up to four channels using resonant or linear scanning.
* A low-resolution preview image of the current section is assembled in real time.
* Graceful acquisition abort (either immediately or at the end of the current section) and pausing.
* Automatically halts if the laser drops out of modelock. 
* PMTs and laser automatically switched off at the end of the acquisition.
* Support for multiple lasers via Scanimage.
* Easy control of illumination as a function of depth via ScanImage. 
* Integrates with our [StitchIt](https://github.com/SWC-Advanced-Microscopy/StitchIt) software for assembling the stitched images from raw tiles. 
* Easily resume a previously halted acquisition.
* Modular API allows developers to easily extend the software or adapt it to different hardware.
* Slack messages on acquisition completion.


### Getting started
The software has been tested on MATLAB R2019b to R2021a. 
It runs on Basic (latest version preferred) but previous versions should also work. 
See the documentation at [bakingtray.mouse.vision](https://bakingtray.mouse.vision)

Please do get in touch if use the software: especially if you are publishing with it!

