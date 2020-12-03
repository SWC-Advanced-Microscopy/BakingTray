# BakingTray #

<a href="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq.jpg">
<img src="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq_thumb.jpg">
</a>

### What is it?
BakingTray is an open source [MATLAB](http://www.mathworks.com/)-based  serial section 2-photon imaging system inspired by the [TeraVoxel](https://github.com/TeravoxelTwoPhotonTomography) ([Economo, et al](https://elifesciences.org/articles/10566)) and [MouseLight](https://github.com/MouseLightPipeline) ([Winnubst, et al](https://www.sciencedirect.com/science/article/pii/S0092867419308426?via%3Dihub)) projects.
The software is for research and development purposes. 
BakingTray is not scanning software: it is a wrapper around the [ScanImage](https://vidriotechnologies.com/) [API](https://github.com/tenss/ScanImageAPI_Examples).

### Who is it for?
This software is aimed at technically-minded people who want to experiment with serial-section imaging and have full control over all aspects of the process. 
Setting up BakingTray from scratch on your rig requires _significant effort_, good MATLAB programming skills, knowledge of ScanImage, and the know-how to set up and run a 2-photon microscope. 
_This is not a turn-key solution_.
BakingTray will run on any hardware [supported by ScanImage](http://scanimage.vidriotechnologies.com/display/SI2017/Supported+Microscope+Hardware).

### How does it work?
BakingTray is based upon an [existing tile-scanner extension for ScanImage](https://github.com/BaselLaserMouse/ScanImageTileScan).
BakingTray simply slices off the top of the sample after each tile-scan is complete, exposing fresh tissue for imaging. 
Imaging itself is performed via ScanImage, which is freely available MATLAB-based software for running 2-photon microscopes. 

### Current features
This software has been thoroughly stress-tested and is capable of generating production-quality data.
The current feature set is as follows:

* Easy sample set up: take a fast preview image of the sample, draw a box around the area to be imaged, "auto-ROI" feature for [imaging only the sample](https://www.youtube.com/watch?v=yHEkR3nZsOw).
* Acquisition of up to four channels using resonant or linear scanning.
* A low-resolution preview image of the current section is assembled in real time.
* Graceful acquisition abort (either immediately or at the end of the current section) and pausing.
* Automatically halts if the laser drops out of modelock. 
* PMTs and laser automatically switched off at the end of the acquisition.
* Support for multiple lasers via Scanimage.
* Easy control of illumination as a function of depth via ScanImage. 
* Integrates with our [StitchIt](https://github.com/SainsburyWellcomeCentre/StitchIt) software for assembling the stitched images from raw tiles. 
* Easily resume a previously halted acquisition.
* Modular API allows developers to easily extend the software or adapt it to different hardware.
* Slack messages on acquisition completion.


### Getting started ###
See the documentation at [bakingtray.mouse.vision](https://bakingtray.mouse.vision)
Please do get in touch if use the software: especially if you are publishing with it!


### Related work
* Winnubst *et al*. Reconstruction of 1,000 Projection Neurons Reveals New Cell Types and Organization of Long-Range Connectivity in the Mouse Brain. Cell 2019
* Economo *et al*. A New Platform for Brain-Wide Imaging and Reconstruction of Neurons. eLife 2016
* Li *et al*. Micro-Optical Sectioning Tomography to Obtain a High-Resolution Atlas of the Mouse Brain. Science. 2010
* Mayerich *et al*. Knife-edge scanning microscopy for imaging and reconstruction of three-dimensional anatomical structures… J. Microscopy. 2008
* Ragan *et al*. Serial two-photon tomography for automated ex-vivo mouse brain imaging. Nat. Meth. 2012
* Seiriki, *et al*. High-Speed and Scalable Whole-Brain Imaging in Rodents and Primates. Neuron 2017
* Zheng *et al*. Visualization of brain circuits using two-photon fluorescence micro-optical sectioning tomography. Opt. Express. 2013
