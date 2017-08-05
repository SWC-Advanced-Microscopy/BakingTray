classdef (Abstract) scanner < handle & loghandler
%%  scanner
%
% The scanner abstract class declares methods that are used by BakingTray
% to obtain an image and change imaging parameters programatically. 
%
% Currently, we anticipate only using ScanImage to acquire data, but in 
% future we might do things some other way. The SIBT class inherits scanner
% and provides a bridge between ScanImage and BakingTray.
%
% Rob Campbell - Basel 2016

    properties 
        hC      %A handle to scan object's API.
    end %close public properties
    
    properties (Hidden)
        parent  %A copy of the parent object (likely BakingTray) to which this component is attached
    end

    properties (SetAccess=protected)
        scannerID='' % This string should identify the scanner. e.g. "ScanImage via SIBT", "SpinningDisk", "DummyScanner"
    end


    % These are GUI-related properties. The view class that comprises the GUI listens to changes in these
    % properties to know when to update the GUI. It is therefore necessary for these to be updated as 
    % appropriate by classes which inherit scanner. e.g. the isAcquiring method should update isScannerAcquiring
    properties (Hidden, SetObservable, AbortSet)
        isScannerAcquiring %True if scanner is acquiring data (this will be false during cutting)
        acquisitionPaused=false %This indicates whether the acquisition has been paused
        channelsToSave % This should be updated with a listener
        channelLookUpTablesChanged=1 %Flips between 1 and -1 if any channel lookup table has changed
    end


    % The following are all critical methods that your class should define
    % You should also define a suitable destructor to clean up after you class
    methods (Abstract)

        success = connect(obj,API)
        % connect
        %
        % Behavior
        % This method establishes a connection between the concrete object and the 
        % API of the software that controls the scanner.
        %
        % Inputs
        % API - connect this API to the scanner object
        %
        % Outputs
        % success - true or false depending on whether a connection was established


        ready = isReady(obj)
        % isReady
        %
        % Behavior
        % Returns true if the scanner is ready to acquire data. False Otherwise
        % TODO: I need a better definition of "ready"
        %
        % Inputs
        % None
        % 
        % Outputs
        % ready - true or false 


        success = armScanner(obj)
        % armScanner
        % 
        % Behavior
        % This method is called after scanner.isReady and sets up the 
        % acquisition. It is expected this would be called before the 
        % start of each new physical section. e.g. this method might 
        % ensure that the scan parameters are at their correct values, 
        % ensure the scan software is in the correct mode to acquire 
        % the next section, etc. 
        %
        % Outputs
        % returns true or false depending on whether or not all steps
        % conducted by the method ran succesfully. 


        success = disarmScanner(obj)
        % disarmScanner
        % 
        % Behavior
        % This method is called when acquisition finishes (or aborted early).
        % Not all all scanners will need this. This method may do things such as 
        % as return the scanner to user control rather than remote control. To
        % stop scanning run scanner.abortScanning
        %
        % Outputs
        % returns true or false depending on whether or not all steps
        % conducted by the method ran succesfully. 

        abortScanning(obj)
        % abortScanning
        %
        % Behavior
        % Causes the scanning to stop immediately but does not perform any further
        % operations (like restoring scan settings) since these are done by 
        % scanner.disarmScanner

        acquiring = isAcquiring(obj)
        % isAcquiring
        %
        % Behavior
        % Returns true if the scanner object is in an active, data-acquiring, mode. 
        %
        %
        % Inputs
        % None
        %
        % Output
        % acquiring - true/false

        setUpTileSaving(obj)
        % setUpTileSaving
        % 
        % Behavior
        % Conduct any operations necessary to allow for image saving. e.g.
        % may need to tell the scanner what the path and filenames are.

        disableTileSaving(obj)
        % disableTileSaving
        % 
        % Behavior
        % Conduct any operations necessary to disable saving of image data. This
        % may not be necessary on all scanners or it may involve simply unchecking
        % a checkbox.


        initiateTileScan(obj)
        % initiateTileScan
        %
        % Behavior
        % This method is called once by BT.runTileScan and is used to initiate scanning of tiles. 
        % NOTE: the behavior of this method is not well defined right now since we only have 
        % SIBT as a possible scanner class. All it currently does is send a soft trigger to 
        % ScanImage. In future we might need a better definition (RAAC: April, 2017)

        scanSettings = returnScanSettings(obj)
        % returnScanSettings
        %
        % Behavior
        % reads key scan settings from the scanning software and returns them as a structure.
        % This method must return at least the following:
        % OUT.pixelsPerLine - number of pixels on each line of each tile as it's saved to disk
        % OUT.linesPerFrame - number of lines in each tile as it's saved to disk
        % OUT.micronsBetweenOpticalPlanes - number of microns separating one optical plane from the other (zero if none)
        % OUT.FOV_alongColsinMicrons - Number of imaged microns along the columns (within a line) of the image (to 2 decimal places)
        % OUT.FOV_alongRowsinMicrons - Number of imaged microns along the rows (the lines) of the image (to 2 decimal places)
        % OUT.micronsPerPixel_cols   - The number of microns per pixel along the columns (to 3 decimal places)
        % OUT.micronsPerPixel_rows   - The number of microns per pixel along the rows (to 3 decimal places)
        %
        % Other fields may be returned too if desired. But the above are the only critical ones.

        pauseAcquisition(obj)
        % pauseAcquisition
        %
        % Behavior
        % When run, performs whatever operations may be necessary to pause the acquisition
        % then sets the observable property scanner.acquisitionPaused to true.

        resumeAcquisition(obj)
        % resumeAcquisition
        %
        % Behavior
        % When run, performs whatever operations may be necessary to resume the acquisition
        % then sets the observable property scanner.acquisitionPaused to false.

        maxChannelsAvailable(obj)
        % maxChannelsAvailable
        %
        % Behavior
        % Returns an integer that defines the maximum number of channels the scanner can handle. 
        % So even if only one channel is being used, if the scanner can handle 4 channels then
        % the output of maxChannelsAvailable will be 4. 

        channelsToAcquire(obj)
        % channelsToAcquire
        % 
        % Behavior
        % Return the indexes of the channels which are active and will be saved to disk. 
        % e.g. if channels one and three are to be saved to disk this method should be [1,3]

        channelsToDisplay(obj)
        % channelsToDisplay
        % 
        % Behavior
        % Return the indexes of the channels which are going to be displayed during acquisition 
        % by the scanner software. 
        % e.g. if channels one and three are to be displayed this method should be [1,3]

        scannerType(obj)
        % scannerType
        %
        % Behavior
        % Returns a string describing the type of scanner. Should be either 'linear' or 'resonant'

        setImageSize(obj,imSize)
        % setImageSize
        % 
        % Behavior
        % This method accepts one input argument: the number of pixels per line and
        % changes the image size based on this. If the image was already square then it
        % remains square. If it was rectangular it remains so with the same aspect ratio.
        % FOV is maintained. 

        getPixelsPerLine(obj)
        % getPixelsPerLine
        %
        % Behavior
        % returns the number of pixels in one scan line

        getChannelLUT(obj,chanToReturn)
        % getChannelLUT(obj)
        %
        % Behavior
        % Return the look-up table of the channel defined by the integer chanToReturn.
        % The returned LUT should be a vector of length 2 with the first number indicating
        % the smallest displayed value and the first number indicating the largest 
        % displayed value.

        tearDown(obj)
        % tearDown(obj)
        %
        % Behavior
        % The tearDown method is called at the end of an acquisition to perform whatever
        % operations might be necessasry for the scanner at the end of acquisition. 
        % e.g. turn off the PMTS .

        getVersion(obj)
        % getVersion(obj)
        %
        % Behavior
        % Return a string describing the scanner version. This should be one line so it 
        % can be written to an acquisition log file as part of an sprintf command. Don't
        % add formatting characters like new lines.

        generateSettingsReport(obj)
        % generateSettingsReport(obj)
        %
        % Before begining acquisition we want the user to be presented with a list
        % of important scanner settings to summarize how the acquisition will be 
        % conducted. The list should indicate a friendly setting name (e.g. "channels to acquire"), 
        % the value for this acquisition, and if appropriate a suggested value.
        % For instance, bidirectional scanning should usually be true. So the user
        % will be shown a display the highlights this setting should it be false. 
        % Settings like this, that we don't *have* to enforce, we will allow the user
        % to choose what they like and just nudge them if it's no "ideal" since maybe
        % there is some reason for an unusual setting choice that we can't now predict.
        %
        % Inputs
        % settingsTo report should be a vector of structures with one one item per
        % setting. Each structure should be in the form:
        % 
        % S.friendlyName = 'bidirectional scanning'
        % S.currentValue = true
        % S.suggestedVal = true
        %
        % or:
        % S.friendlyName = 'channels to acquire'
        % S.currentValue = [1,2,3];
        % S.suggestedVal = @(x) length(x)>1; 
        %
        % If current value does not evaluate to true when passed through the anonymous function, 
        % the user will just be shown a highlighted value to indicate that something is not right. 
        %
        % NOTE: this function should return empty if no valid tests exist.

     end % close abstract methods


end %close classdef