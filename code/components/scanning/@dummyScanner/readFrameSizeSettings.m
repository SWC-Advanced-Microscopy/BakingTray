function readFrameSizeSettings(obj)
    % Right now we just copy this from SIBT (31/08/2019 -- Rob Campbell)
    frameSizeFname=fullfile(BakingTray.settings.settingsLocation,'frameSizes.yml');
    if exist(frameSizeFname, 'file')
        tYML=BakingTray.yaml.ReadYaml(frameSizeFname);
        tFields = fields(tYML);
        popUpText={};
        for ii=1:length(tFields)
            tSet = tYML.(tFields{ii});

            % The following is hard-coded in order to make it more likely an error will be
            % generated here rather than down the line
            obj.frameSizeSettings(ii).objective = tSet.objective;
            obj.frameSizeSettings(ii).pixelsPerLine = tSet.pixelsPerLine;
            obj.frameSizeSettings(ii).linesPerFrame = tSet.linesPerFrame;
            obj.frameSizeSettings(ii).zoomFactor = tSet.zoomFactor;
            obj.frameSizeSettings(ii).nominalMicronsPerPixel = tSet.nominalMicronsPerPixel;
            obj.frameSizeSettings(ii).fastMult = tSet.fastMult;
            obj.frameSizeSettings(ii).slowMult = tSet.slowMult;
            obj.frameSizeSettings(ii).objRes = tSet.objRes;

            %This is used by StitchIt to correct barrel or pincushion distortion
            if isfield(tSet,'lensDistort')
                obj.frameSizeSettings(ii).lensDistort = tSet.lensDistort;
            else
                obj.frameSizeSettings(ii).lensDistort = [];
            end
            %This is used by StitchIt to affine transform the images to correct things like shear and rotation
            if isfield(tSet,'affineMat')
                obj.frameSizeSettings(ii).affineMat = tSet.affineMat;
            else
                obj.frameSizeSettings(ii).affineMat = [];
            end
            %This is used by StitchIt to tweaak the nomincal stitching mics per pixel
            if isfield(tSet,'stitchingVoxelSize')
                obj.frameSizeSettings(ii).stitchingVoxelSize = tSet.stitchingVoxelSize;
            else
                thisStruct(ii).stitchingVoxelSize = [];
            end
        end

    else % Report no frameSize file found
        fprintf('\n\n dummyScanner finds no frame size file found at %s\n\n', frameSizeFname)
        obj.frameSizeSettings=struct;
    end
end % function readFrameSizeSettings(obj)
