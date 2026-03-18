# BakingTray #

<a href="https://raw.githubusercontent.com/wiki/SWC-Advanced-Microscopy/images/example_acq.jpg">
<img src="https://raw.githubusercontent.com/wiki/BaselLaserMouse/BakingTray/images/example_acq_thumb.jpg">
</a>

### What is it?
BakingTray is an open source [MATLAB](http://www.mathworks.com/)-based  serial section 2-photon imaging system inspired by the [TeraVoxel](https://github.com/TeravoxelTwoPhotonTomography) ([Economo, et al](https://elifesciences.org/articles/10566)) and [MouseLight](https://github.com/MouseLightPipeline) ([Winnubst, et al](https://www.sciencedirect.com/science/article/pii/S0092867419308426?via%3Dihub)) projects.
The software is for research and development purposes. 
BakingTray is not scanning software: it is a wrapper around the [ScanImage](https://www.mbfbioscience.com/products/scanimage/) [API](https://github.com/SWC-Advanced-Microscopy/ScanImageAPI_Examples).

### Who is it for?
This software is aimed at technically-minded people who want to experiment with serial-section imaging and have full control over all aspects of the process. 
Setting up BakingTray from scratch on your rig requires _significant effort_, good MATLAB programming skills, knowledge of ScanImage, and the know-how to set up and run a 2-photon microscope. 
_This is not a turn-key solution_.
BakingTray will run on any hardware [supported by ScanImage](http://scanimage.vidriotechnologies.com/display/SI2017/Supported+Microscope+Hardware).

### How does it work?
BakingTray is based upon an [existing tile-scanner extension for ScanImage](https://github.com/SWC-Advanced-Microscopy/ScanImageTileScan).
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
* Integrates with our [StitchIt](https://github.com/SWC-Advanced-Microscopy/StitchIt) software for assembling the stitched images from raw tiles. 
* Easily resume a previously halted acquisition.
* Modular API allows developers to easily extend the software or adapt it to different hardware.
* Slack messages on acquisition completion.


### Getting started ###
The software has been tested on MATLAB R2019b to R2021a. 
It runs on ScanImage 5.6.x and Basic 2020 and 2021. 
See the documentation at [bakingtray.mouse.vision](https://bakingtray.mouse.vision)

Please do get in touch if use the software: especially if you are publishing with it!


### Related work
Serial section optical microscopy traces its roots back to at least 1990, when [Odgaard and colleagues](https://onlinelibrary.wiley.com/doi/10.1111/j.1365-2818.1990.tb03038.x) used resin embedding and brightfield microscopy to image small bone samples. 
Similar work was done by [Ewald in 2002](https://anatomypubs.onlinelibrary.wiley.com/doi/10.1002/dvdy.10169).
In 2008, [Mayerich](https://onlinelibrary.wiley.com/doi/10.1111/j.1365-2818.2008.02024.x) conducted serial section imaging by acquiring line scan data on the knife edge itself.
Serial block-face light microscopy over extended samples was performed in 1996, with the publication of the "[Visible Human Male](https://academic.oup.com/jamia/article/3/2/118/708716?login=true)" project, where a single individual was cryo-sectioned every 100µm and imaged via tile-scanning. 
[Chinese visible human](https://anatomypubs.onlinelibrary.wiley.com/doi/10.1002/ar.b.10035) data followed in 2003. 
On the other end of the spectrum, in 2004, Denk used [serial section electron microscopy](https://pmc.ncbi.nlm.nih.gov/articles/PMC524270/) to study synaptic structure in 3D. 

Large-scale fluorescence-based serial sectioning was first published in [2010 by Li and colleagues](https://www.science.org/doi/10.1126/science.1191776).
Two-photon-based serial sectioning followed soon after by [Ragan in 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC3297424/) and [Zheng in 2013](https://opg.optica.org/oe/fulltext.cfm?uri=oe-21-8-9839).
A similar approach was also published by [Economo in 2019](https://elifesciences.org/articles/10566) who used their system [in a subsequent publication to reconstruct hundreds of labelled neurons in the mouse brain](https://pmc.ncbi.nlm.nih.gov/articles/PMC6754285/).
Optical sectioning can also be acheived by other means, such as [Seiriki and colleagues](https://www.sciencedirect.com/science/article/pii/S0896627317304555) "FAST" system which employs a spinning disk confocal. 

