# Code snippets to test frame multiplexing before integrating it

ScanImage has been modified (pre-release version) to allow for frame multiplexing

The magic all sits in `hSI.hScan2D.hAcq`, which contains parallel lists that must have exactly one element per output file. 



## Example -- separating channels
Put channel 2 in one file on its own and channels 3 and 4 together in their own file. 

```matlab
hSI.hScan2D.hAcq.FrameSelectFileSuffixList={'chan_02','chans_03_04'};
hSI.hScan2D.hAcq.FrameSelectChannelIndexList={[2],[3,4]};
hSI.hScan2D.hAcq.FrameSelectSelectionList(1) = struct('StartIndex',1,'EndIndex',inf, 'StrideIndex',1);
hSI.hScan2D.hAcq.FrameSelectSelectionList(2) = struct('StartIndex',1,'EndIndex',inf, 'StrideIndex',1);
```

## Alternating wavelengths by frame
This is the core example. It allows us to take a z stack with alternating frames scanned by a different wavelength and frames saved to different files according to wavelength. Chosen channels can even be acquired twice -- once with each wavelength -- as well as just once. 

Here we take a fast z stack with 4 slices, 2 frames per slice (total 8 frames) with odd frames being illuminated by laser 1 and even frames by laser 2. 

### First we set up the TIFF routing
```matlab
hSI.hScan2D.hAcq.FrameSelectFileSuffixList={'laser_01','laser_02'};
hSI.hScan2D.hAcq.FrameSelectChannelIndexList={[2,3],[4]};
hSI.hScan2D.hAcq.FrameSelectSelectionList(1) = struct('StartIndex',1,'EndIndex',inf, 'StrideIndex',2);
hSI.hScan2D.hAcq.FrameSelectSelectionList(2) = struct('StartIndex',2,'EndIndex',inf, 'StrideIndex',2);
```


### Next we configure the beam powers
```matlab
hSI.hBeams.powerPerFrameSelectionList = struct( ...
    'StartIndex',     {uint64(1), uint64(2)}, ....
    'EndIndex',       {inf,       inf}, ....
    'StrideIndex',    {uint64(2), uint64(2)}, ....
    'PowerFractions', {[0.8,0.0], [0.0,0.66]});
```

### Next we set the zs 
We start with a state where the user has already asked for 4 planes 10 microns apart:
```
>> hSI.hStackManager.zs

ans =

   94.1480  104.1480  114.1480  124.1480
```


But that is only 4 frames. We need to duplicate this:
```
>> z = hSI.hStackManager.zs;
>> z=repmat(z,2,1);
>> hSI.hStackManager.arbitraryZs=round(r(:));
>> hSI.hStackManager.zs

ans =

    94    94   104   104   114   114   124   124
```

Right 