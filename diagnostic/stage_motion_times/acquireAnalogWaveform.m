function data = acquireAnalogWaveform
    % Acquire analog waveform on an NI DAQ. Can be used to debug timing during tile scans.
    %
    % function data = acquireAnalogWaveform
    %
    % Purpose
    % This function is a bit rough and ready but should do the job. You will need to change
    % the DAQ name and maybe channel for your purposes. Copy file to a different location to
    % do this. If you edit in place in the BakingTray path, then you will need to revert
    % changes if you pull the latest version from GitHub. 
    %
    % This function comes from the 'vidrio' AI examples at https://github.com/SWC-Advanced-Microscopy/MATLAB_DAQmx_examples
    % This code will NOT work with a vDAQ 
    %
    % 
    % Inputs
    % None -- please read through and edit the code to ensure you understand how it works
    %
    % Outputs
    % data -- vector data values from the desired AI line.
    %
    %
    % Rob Campbell - SWC, 2024
    


    %Define a cleanup function
    tidyUp = onCleanup(@cleanUpFunction);

    %% Parameters for the acquisition (device and channels)
    devName = 'resscan';   % the name of the DAQ device as shown in MAX
    taskName = 'hardAI';   % A string that will provide a label for the task
    physicalChannels = 0;  % A scalar or an array with the channel numbers



    % Task configuration
    sampleRate = 1E3;     % Sample Rate in Hz (1 kHz is plenty for most purposes)
    secsToAcquire = 10;   % Number of seconds over which to acquire data


    try 
        % Create a DAQmx task
        hTask = dabs.ni.daqmx.Task(taskName); 


        % Set up analog input on device defined by variable devName
        hTask.createAIVoltageChan(devName,physicalChannels,[],-10,10);


        % Configure the sampling rate and the number of samples
        numberOfSamples = secsToAcquire * sampleRate; % The finite number of samples to acquire
        hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',numberOfSamples,'OnboardClock');


        %We configured no triggers, so the acquisition starts as soon as hTask.start is run


        % Start the task and plot the data
        hTask.start  % start the acquisition 

        fprintf('Acquiring data...')
        hTask.waitUntilTaskDone;  % wait till all requested samples are acquired
        fprintf('\n')

        % "Scaled" sets the input to be represented as a voltage value. 
        % "Native" would have it be a raw integer (e.g. 16 bit number if this is a 16 bit DAQ)
        data = hTask.readAnalogData([],'scaled',0); % read all available data 

    catch ME
       daqDemosHelpers.errorDisplay(ME)
       return

    end %try/catch


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    function cleanUpFunction
        %This runs when the function ends
        if exist('hTask','var')
            fprintf('Cleaning up DAQ task\n');
            hTask.stop;    % Calls DAQmxStopTask
            delete(hTask); % The destructor (dabs.ni.daqmx.Task.delete) calls DAQmxClearTask
        else
            fprintf('No task variable present for clean up\n')
        end
    end %close cleanUpFunction

end























