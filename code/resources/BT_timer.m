function BT_timer (src,event,varargin)
    %Used to time events

    persistent T;
    persistent frameTimes;

    switch event.EventName
        case 'acqModeStart'
            frameTimes=[];     
            fprintf('Entered acqModeStart at %s\n', datestr(now,'hh:mm:ss'))
            T=tic;
        case 'frameAcquired'

            if src.hSI.hScan2D.hAcq.hAI.running
                availableSamples = src.hSI.hScan2D.hAcq.hAI.hTask.get('readAvailSampPerChan');
            else
                availableSamples=0;
            end

            thisTime=toc(T);
              fprintf('frameAcquired at %s (t=%0.2f). %d samples in AI buffer.\n', ...
                datestr(now,'hh:mm:ss'), thisTime, availableSamples)
            frameTimes(end+1)=thisTime;
            T=tic;


        case {'acqDone'}
            framePerVol=src.hSI.hFastZ.numFramesPerVolume;
            if length(frameTimes<(framePerVol+1))
                muF = mean([frameTimes(1)/2,frameTimes(2:end)]);
            else
                muF = mean([frameTimes(framPerVol+1),frameTimes(2:end)]); 
            end

            fprintf('acqDone (End) at %s. %d frames at %0.2f s per frame.\n\n', ...
                datestr(now,'hh:mm:ss'), length(frameTimes), muF);

            %Report FOV  and mics per pixel
            fov=abs(src.hSI.hRoiManager.imagingFovUm(1)-src.hSI.hRoiManager.imagingFovUm(2));
            pix = src.hSI.hRoiManager.pixelsPerLine;

            micsPix = fov/pix;
            %fprintf('FOV: %0.1f microns. %0.3f mics/pixel\n',fov,micsPix)
            Xtiles=11;
            YTiles=15;
            phySec=220;
            totalFrams = Xtiles*YTiles*phySec*src.hSI.hFastZ.numFramesPerVolume;
            %fprintf('assuming %d tiles by %d tiles and %d physical sections, acq will take %0.1f hours\n',...
              %  Xtiles,YTiles,phySec,(totalFrams*muF)/60^2)

            if src.hSI.active
                pause(0.2) %Simulate x/y motion
                src.hSI.hScan2D.trigIssueSoftwareAcq
            end

        case {'acqModeDone'}
            %calculate the average time per z stack
            framePerVol=src.hSI.hFastZ.numFramesPerVolume;

            muF = mean([frameTimes(framePerVol+1),frameTimes(2:end)]); %don't use first frame as it's always way off

            %Report FOV  and mics per pixel
            fov=abs(src.hSI.hRoiManager.imagingFovUm(1)-src.hSI.hRoiManager.imagingFovUm(2));
            pix = src.hSI.hRoiManager.pixelsPerLine;

            micsPix = fov/pix;
            fprintf('\nFOV: %0.1f microns. %0.3f mics/pixel\n',fov,micsPix)
            Xtiles=11;
            YTiles=15;
            phySec=220;
            totalFrams = Xtiles*YTiles*phySec*framePerVol;
            fprintf('assuming %d tiles by %d tiles and %d physical sections, acq will take %0.1f hours\n',...
                Xtiles,YTiles,phySec,(totalFrams*muF)/60^2)
    
            phySec=370;
            totalFrams = Xtiles*YTiles*phySec*framePerVol;
            fprintf('assuming %d tiles by %d tiles and %d physical sections, acq will take %0.1f hours\n',...
                Xtiles,YTiles,phySec,(totalFrams*muF)/60^2)




    end
end