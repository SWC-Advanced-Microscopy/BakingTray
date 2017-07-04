function success=attachLaser(obj,settings)
    % Attach laser to BT
    %
    % function success=attachLaser(obj,settings)
    %
    % Inputs (optional)
    % settings - this is the laser field from the settings structure produced by
    %            the settings reader BakingTray.settings.readComponentSettings
    %            If left empty, the the settings file is read by this function 
    %            and the correct field is extracted.
    %
    % Outputs
    % success - Returns true if a BT hardware component was built successfully. 
    %           The component itself is placed in the BT object as a property,
    %           so BT is a composite object.
    %
    %

    success=false;

    %Read the settings file if a structure was not supplied for this component
    if nargin<2
         settings=BakingTray.settings.readComponentSettings;
         settings=settings.laser;
    end

    %Build the component
    obj.laser=buildLaserComponent(settings.type, settings.COM);

    %Return false if the attachment failed
    if ~isempty(obj.laser)
        success=true;
    else
        %Add a link to the BT parent object to the component so this component can access
        %other attached components
        obj.laser.parent=obj;
    end

end