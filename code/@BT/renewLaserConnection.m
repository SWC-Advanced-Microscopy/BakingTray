function success=renewLaserConnection(obj)
    % Detach and re-connect the laser to BT
    %
    % function success=renewLaserConnection(obj)
    %
    % Outputs
    % success - Returns true if a BT hardware component was built successfully. 
    %           The component itself is placed in the BT object as a property,
    %           so BT is a composite object.
    %
    %

    success=false;

    if ~isempty(obj.laser)
        currentCOM = obj.laser.controllerID;
        laserClass = class(obj.laser);
    end

    delete(obj.laser)

    %Build the component
    obj.laser=buildLaserComponent(laserClass, currentCOM);


    %Return false if the attachment failed
    if ~isempty(obj.laser)
        success=true;
    else
        %Add a link to the BT parent object to the component so this component can access
        %other attached components
        obj.laser.parent=obj;
    end

end