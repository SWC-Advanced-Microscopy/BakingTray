# BakingTray #

<a href="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq.jpg">
<img src="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq_thumb.jpg">
</a>

### What is it?
BakingTray is an open-source serial section 2-photon imaging system inspired the [TeraVoxel](https://github.com/TeravoxelTwoPhotonTomography) project ([Economo et al](https://elifesciences.org/articles/10566)) but runs  within [MATLAB](http://www.mathworks.com/) using the [ScanImage](https://vidriotechnologies.com/) [API](https://github.com/tenss/ScanImageAPI_Examples).

### Who is it for?
This software is aimed at technically-minded people who want an open source STP solution that can be modified for their needs. 
Setting up BakingTray requires _significant effort_, good MATLAB programming skills, knowledge of ScanImage, and the know-how to set up and run a 2-photon microscope. 
_This is not a turn-key solution_.
BakingTray will run on any hardware [supported by ScanImage](http://scanimage.vidriotechnologies.com/display/SI2017/Supported+Microscope+Hardware).

### How does it work?
BakingTray is based upon an [existing tile-scanner extension for ScanImage](https://github.com/BaselLaserMouse/ScanImageTileScan).
BakingTray simply slices off the top of the sample after each tile-scan is complete, exposing fresh tissue for imaging. 
Imaging itself is performed via ScanImage, which is freely available MATLAB-based software for running 2-photon microscopes. 

### Current features
This software has been thoroughly stress-tested and is capable of generating production-quality data.
The current feature set is as follows:

* Easy sample set up: take a fast preview image of the sample then draw a box around the area to be imaged. 
* Acquisition of up to four channels using resonant or linear scanning.
* A low-resolution preview image of the current section is assembled in real time.
* Graceful acquisition abort (either immediately or at the end of the current section) and pausing.
* Automatically halts if the laser drops out of modelock. 
* PMTs and laser automatically switched off at the end of the acquisition.
* Support for multiple lasers via Scanimage.
* Easy control of illumination as a function of depth via ScanImage. 
* Integrates with our [StitchIt](https://github.com/BaselLaserMouse/StitchIt) software for assembling the stitched images from raw tiles. 
* Easily resume of a previously halted acquisition. 
* Modular API allows developers to easily extend the software or adapt it to different hardware.
* Slack messages on acquisition completion.

### Getting started ###
See [the wiki](https://github.com/BaselLaserMouse/BakingTray/wiki)


### Related work
* Economo *et al*. A New Platform for Brain-Wide Imaging and Reconstruction of Neurons. eLife 2016
* Li *et al*. Micro-Optical Sectioning Tomography to Obtain a High-Resolution Atlas of the Mouse Brain. Science. 2010
* Mayerich *et al*. Knife-edge scanning microscopy for imaging and reconstruction of three-dimensional anatomical structures… J. Microscopy. 2008
* Ragan *et al*. Serial two-photon tomography for automated ex-vivo mouse brain imaging. Nat. Meth. 2012
* Seiriki, *et al*. High-Speed and Scalable Whole-Brain Imaging in Rodents and Primates. Neuron 2017
* Zheng *et al*. Visualization of brain circuits using two-photon fluorescence micro-optical sectioning tomography. Opt. Express. 2013
