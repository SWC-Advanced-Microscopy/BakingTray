# Release 28th September 2026

This release encapsulates changes made between June 2025 and September 2026. The 22nd June 2025 release was never merged into master, so its changes (calibration and power reporting for multiple beams) are also part of this release. See that release too.

## Highlights
- **Far fewer failed acquisitions.** Laser comms have been rebuilt. Previously, a laser could wrongly be reported as off or not modelocked, stopping around 20 acquisitions a year. That is fixed.
- **Multiple lasers.** BakingTray can now control more than one laser.
- **Coherent Axon support.**
- **Multi-beam power calibration and reporting.**

> [!IMPORTANT]
> **Laser testing status.** The laser control code has been largely rewritten (see below). The MaiTai and Axon classes have been tested on hardware. The Chameleon and Tiberius classes have been converted but have **NOT** yet been tested with a real laser. If you use one of these, please test carefully before running an acquisition and report any problems.


## New features

### Multiple lasers
BakingTray can now control more than one laser. Add each extra laser as a further element of the laser structure array in `componentSettings.m`. For example:

```matlab
laser(2).type='axon';
laser(2).COM=14;
laser(2).beamName='Axon-1064';
laser(2).wavelength=1064;
```

Laser 1 is the **primary** laser. It is the one controlled by the laser GUI and the one used by anything in BakingTray that is not yet multi-laser aware. With more than one laser, every laser must have a non-empty and unique `beamName` that matches the beam name in ScanImage (the string in the beam widget title). A laser that fails this is not attached. Single-laser settings files need no changes. The laser GUI still shows only the primary laser. The subsequent lasers can be controlled via the CLI and will power off automatically when acquisition finishes. 

### Laser monitoring during acquisition
A laser is monitored only if it has been turned on through BakingTray. A monitored laser must be connected and ready (e.g. modelocked) for an acquisition to start. If it is not, BakingTray says which laser is the problem. All monitored lasers are checked during Bake and the acquisition stops, without cutting, if one of them fails and can not be recovered. A laser that is not taking part in the acquisition is not checked. For lasers other than the primary, this can currently be set only at the command line: `hBT.lasers{n}.doMonitor`

### Coherent Axon support
There is a new `axon` class for the Coherent Axon fixed-wavelength fibre laser. The Axon can not report its wavelength over serial, so you must set it with `laser(n).wavelength` in `componentSettings.m`. Otherwise it reports 0 nm. The Axon has no software shutter: the shutter is always reported as open.

### SWC FabLabs DC motor controller
New `SWCserialCutter` class for driving the vibratome with the basic DC controller from SWC FabLabs.
This component is largely for testing and we have not made available the design files. An improved version of the device is under development. 


## Laser communication overhaul
Laser serial comms were brittle. The laser could be reported as off or not modelocked when it was in fact fine. This blocked acquisitions from starting and stopped around 20 running acquisitions a year for no reason. The laser code has been largely rewritten and this problem is gone:

- All lasers use a single background queue for serial comms. The GUI and the acquisition checks read cached values rather than talking to the laser directly. This removes command clashes, missed reads, and the pauses previously visible in the ScanImage Focus window.
- A laser that loses its serial connection after connecting is now marked as disconnected and handled gracefully.
- Fixed a bug where a laser could be reported as not connected at startup when it was.
- All laser classes have moved from the legacy `serial` interface to `serialport`.


## Bug fixes
- The estimated finish time now updates correctly and closely matches that shown by StitchIt.
- Resuming an acquisition failed on systems with a single laser.
- Resume now correctly restores the power/Z adjust type on systems with multiple beams.
- Laser calibration files were not being used due to a file naming issue.
- `singleAxisPriorController` can now connect.


## Other changes
- By default Slack messages are now sent only for errors. Set `SLACK.failureOnly=false` in `systemSettings.yml` to also get messages for successful acquisitions.
- Spaces in the sample ID are replaced with underscores and other illegal characters removed.
- The ScanImage version check handles patch numbers (e.g. 2023.1.2).
- Laser calibration files in the old naming format (no beam name) are still used, but a warning is printed. Re-generate these with `BakingTray.utils.addLaserCalib` when convenient.
- Documentation has moved to https://bakingtray.swcmicroscopy.com


## Settings file changes
New optional fields in `componentSettings.m`. See `ExampleConfigFiles/componentSettings.m`
- `laser.beamName` — needed only with more than one laser.
- `laser.wavelength` — needed only for fixed-wavelength lasers such as the Axon.


Other small changes: see the ChangeLog file.
