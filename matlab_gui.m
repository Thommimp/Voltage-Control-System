function voltageControllerUI
    MAX_VOLTAGE = 30;  % Max voltage constant
    numChannels = 24;

    fig = uifigure('Position', [100, 100, 700, 700], 'Name', 'Voltage Controller');

    % Title
    uilabel(fig, ...
        'Text', sprintf('Voltage Controller for %d Channels', numChannels), ...
        'FontSize', 16, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Position', [100, 650, 500, 30]);

    % Frequency input
    uilabel(fig, 'Text', 'Frequency (Hz):', 'Position', [50, 610, 100, 22], 'FontWeight', 'bold');
    frequencyField = uieditfield(fig, 'numeric', 'Position', [160, 610, 100, 22]);
    uibutton(fig, 'Text', 'Apply', ...
        'Position', [265, 610, 45, 22], ...
        'ButtonPushedFcn', @(btn, event) setFrequency(frequencyField.Value));

    % Table headers
    uilabel(fig, 'Text', 'Channel', 'Position', [50, 580, 60, 22], 'FontWeight', 'bold');
    uilabel(fig, 'Text', 'Start Voltage (V)', 'Position', [170, 580, 120, 22], 'FontWeight', 'bold');
    uilabel(fig, 'Text', 'End Voltage (V)', 'Position', [300, 580, 120, 22], 'FontWeight', 'bold');
    uilabel(fig, 'Text', 'Steps', 'Position', [470, 580, 100, 22], 'FontWeight', 'bold');

    % Scrollable panel
    scrollPanel = uipanel(fig, ...
        'Position', [50, 125, 600, 420], ...
        'Scrollable', 'on');

    rowHeight = 22;
    spacing = 4;
    totalHeight = numChannels * (rowHeight + spacing);
    yStart = totalHeight - rowHeight;

    startVoltageFields = gobjects(numChannels, 1);
    endVoltageFields = gobjects(numChannels, 1);
    stepFields = gobjects(numChannels, 1);

    for i = 1:numChannels
        y = yStart - (i-1)*(rowHeight + spacing);

        uilabel(scrollPanel, 'Text', sprintf('%d', i), 'Position', [20, y, 30, 22]);

        startVoltageFields(i) = uieditfield(scrollPanel, 'numeric', ...
            'Position', [120, y, 100, 22]);

        endVoltageFields(i) = uieditfield(scrollPanel, 'numeric', ...
            'Position', [250, y, 100, 22]);

        stepFields(i) = uieditfield(scrollPanel, 'numeric', ...
            'Position', [390, y, 100, 22]);
    end

    % Set All Fields (above column headers)
    uilabel(fig, 'Text', 'Set All:', 'Position', [50, 550, 60, 22], 'FontWeight', 'bold');

    setAllStart = uieditfield(fig, 'numeric', 'Position', [170, 550, 50, 22]);
    uibutton(fig, 'Text', 'Apply', ...
        'Position', [225, 550, 45, 22], ...
        'ButtonPushedFcn', @(btn, event) setAll(startVoltageFields, setAllStart.Value));

    setAllEnd = uieditfield(fig, 'numeric', 'Position', [300, 550, 50, 22]);
    uibutton(fig, 'Text', 'Apply', ...
        'Position', [355, 550, 45, 22], ...
        'ButtonPushedFcn', @(btn, event) setAll(endVoltageFields, setAllEnd.Value));

    setAllSteps = uieditfield(fig, 'numeric', 'Position', [440, 550, 50, 22]);
    uibutton(fig, 'Text', 'Apply', ...
        'Position', [495, 550, 45, 22], ...
        'ButtonPushedFcn', @(btn, event) setAll(stepFields, setAllSteps.Value));


    % Buttons - first row
    uibutton(fig, 'Text', 'Send Values', ...
        'Position', [20, 50, 110, 30], ...
        'ButtonPushedFcn', @(btn, event) updateVoltages());

    uibutton(fig, 'state', ...
        'Text', 'Auto Sweep', ...
        'Position', [280, 50, 100, 30], ...
        'ValueChangedFcn', @(btn, event) toggleSweep(btn));

    uibutton(fig, 'state', ...
        'Text', 'Connect', ...
        'Position', [390, 50, 90, 30], ...
        'ValueChangedFcn', @(btn, event) toggleConnect(btn));

    % Buttons - second row
    uibutton(fig, 'Text', 'Load Last values from stm32 ', ...
        'Position', [20, 10, 110, 30]);

    uibutton(fig, 'Text', 'Save Profile', ...
        'Position', [140, 10, 110, 30]);

    % === Callback Functions ===

    function autoRead()
        if s.NumBytesAvailable > 0
            data = readline(s);  % or read(s, s.NumBytesAvailable, "uint8")
            disp(['Received: ', data])
            % You can parse data here and update measuredLabels accordingly
        end
    end


    function updateVoltages()
        for i = 1:numChannels
            startVal = startVoltageFields(i).Value;
            endVal = endVoltageFields(i).Value;
            stepsval = stepFields(i).Value;

            % Check value ranges
            if startVal < 0 || startVal > MAX_VOLTAGE
                errordlg(sprintf('Start voltage out of range (0–%d) on channel %d', MAX_VOLTAGE, i), 'Value Error');
                return;
            end
            if endVal < 0 || endVal > MAX_VOLTAGE
                errordlg(sprintf('End voltage out of range (0–%d) on channel %d', MAX_VOLTAGE, i), 'Value Error');
                return;
            end
            if stepsval <= 0 || stepsval > 65535
                errordlg(sprintf('Steps must be between 1 and 65535 on channel %d', i), 'Value Error');
                return;
            end

            % Convert voltage to integer value for DAC
            startValconv = startVal * 65535 / MAX_VOLTAGE;
            endValconv = endVal * 65535 / MAX_VOLTAGE;


            % Prepare values (here converting startVal, but you probably want startValconv)
            startInt = fliplr(typecast(uint16(startValconv), 'uint8'));
            endInt = fliplr(typecast(uint16(endValconv), 'uint8'));
            stepsInt = fliplr(typecast(uint16(stepsval), 'uint8'));

            % Create packet
            packet = [170, 11, 1, i, startInt, endInt, stepsInt, 0];

            % Convert to hex string
            packetHex = arrayfun(@(b) sprintf('%02X', b), packet, 'UniformOutput', false);
            packetStr = strjoin(packetHex, ' ');

            fprintf('Channel %d packet: %s\n', i, packetStr);

            % Send/store packet here
        end
    end


    function toggleSweep(btn)
        if btn.Value
            btn.Text = 'Stop Sweep';
        else
            btn.Text = 'Auto Sweep';
        end
    end

    function toggleConnect(btn)
        if btn.Value
            btn.Text = 'Disconnect';
        else
            btn.Text = 'Connect';
        end
    end


    fig.CloseRequestFcn = @(~,~) cleanup();

    function cleanup()
        try
            stop(t);
            delete(t);
        catch
            % Timer was probably never created
        end

        try
            clear s;
        catch
            % Serial port was probably never opened
        end

        try
            delete(fig);
        catch
            % Already closed maybe
        end
    end



    function setAll(fieldArray, value)
        for i = 1:numel(fieldArray)
            fieldArray(i).Value = value;
        end
    end

    function setFrequency(Frequency)

        if Frequency > 200000
            errordlg(sprintf('Frequency set too high DACs can maximum handle up to 200Khz and you set %d hz', Frequency), 'Value Error');
            return;
        end

        freqInt = fliplr(typecast(uint32(Frequency), 'uint8'));
        freq3bytes = freqInt(2:4);  % Keep only the lowest 3 bytes


        freqpacket = [170, 7, 8, freq3bytes, 0];


        % Convert to hex string
        freqpacketHex = arrayfun(@(b) sprintf('%02X', b), freqpacket, 'UniformOutput', false);
        freqpacketStr = strjoin(freqpacketHex, ' ');

        fprintf('Frequency packet: %s\n', freqpacketStr);


    end
end
