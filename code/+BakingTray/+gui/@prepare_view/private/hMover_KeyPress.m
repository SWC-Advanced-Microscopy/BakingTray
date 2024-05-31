function hMover_KeyPress(~, eventdata, obj)
    % Handles WASD keys for stage moves

    key=eventdata.Key;
    ctrlMod=ismember('shift', eventdata.Modifier);

    if ctrlMod
        stepSize = 'largeStep';
    else
        stepSize = 'smallStep';
    end
    switch key
        case 'a'
            runCallBack(obj.(stepSize).left)
        case 'd'
            runCallBack(obj.(stepSize).right)
        case 'w'
            runCallBack(obj.(stepSize).away)
        case 's'
            runCallBack(obj.(stepSize).towards)
        case 'q'
            if obj.lockZ_checkbox.Value == 1, return, end
            runCallBack(obj.(stepSize).up)
        case 'e'
            if obj.lockZ_checkbox.Value == 1, return, end
            runCallBack(obj.(stepSize).down)
        case 'r'
            if obj.lockZ_checkbox.Value == 1, return, end
            runCallBack(obj.(stepSize).up)
        case 'f'
            if obj.lockZ_checkbox.Value == 1, return, end
            runCallBack(obj.(stepSize).down)
        otherwise
    end

end



function runCallBack(buttonObj)
    C=get(buttonObj,'Callback');
    C(get(buttonObj));
end

