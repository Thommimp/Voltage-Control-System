function voltageControllerUI
    MAX_VOLTAGE = 30;  % Max voltage constant
    numChannels = 24;
    s = '';

    fig = uifigure('Position', [100, 100, 700, 700], 'Name', 'Voltage Controller');

    % Title
    uilabel(fig, ...
        'Text', sprintf('Voltage Controller for %d Channels', numChannels), ...
        'FontSize', 16, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Position', [100, 650, 500, 30]);

    % Big Start Button (top right corner)
    uibutton(fig, 'state',...
    'Text', 'Start', ...
    'FontSize', 18, ...
    'FontWeight', 'bold', ...
    'Position', [550, 610, 120, 50], ...
    'ValueChangedFcn', @(btn, event) openNewWindow(btn));


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

    allPorts = serialportlist("all");
    ports = allPorts(startsWith(allPorts, "/dev/cu."));
    disp(ports)  % Check if duplicates are here

    if isempty(ports)
        ports = {'No ports found'};
    end
    
    portDropdown = uidropdown(fig, ...
        'Items', ports, ...
        'Position', [390, 90, 90, 22], ...
        'Enable', 'on');

    uibutton(fig, 'Text', 'Refresh Ports', ...
    'Position', [490, 90, 90, 22], ...
    'ButtonPushedFcn', @(btn, event) refreshPorts());


    % === Callback Functions ===

    function refreshPorts()
    newPorts = serialportlist("all");
    if isempty(newPorts)
        newPorts = {'No ports found'};
    end
    portDropdown.Items = newPorts;
end

    function autoRead()
        if s.NumBytesAvailable > 0
          data = read(s, s.NumBytesAvailable, "uint8");
          disp("Received:");
          disp(data);

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
            write(s, packet, 'uint8');

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

        selectedPort = portDropdown.Value;
        if strcmp(selectedPort, 'No ports found')
            uialert(fig, 'No valid serial port selected.', 'Connection Error');
            btn.Value = false;
            btn.Text = 'Connect';
            return;
        end

        try
            s = serialport(selectedPort, 115200);
            disp(s)
            % Configure callback: triggers when 1 or more bytes arrive
            configureCallback(s, "byte", 1, @readSerial);
            flush(s);
        catch err
            uialert(fig, ['Failed to connect: ' err.message], 'Connection Error');
            btn.Value = false;
            btn.Text = 'Connect';
        end
    else
        btn.Text = 'Connect';
        if ~isempty(s)
            configureCallback(s, "off");  % Disable the callback
            clear s;
        end
    end
end

function readSerial(src, ~)
    bytesAvailable = src.NumBytesAvailable;
    if bytesAvailable > 0
        data = read(src, bytesAvailable, "uint8");
        % Format each byte as two-digit hex
        hexStrs = sprintf('%02X ', data);
        disp("Received (hex):");
        disp(hexStrs);

        disp("Received (decimal):");
        disp(data);
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
            configureCallback(s, "off");  % Disable the callback
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

function openNewWindow(btn)
    persistent newFig ax barPlot timerObj voltageData

    if btn.Value
        btn.Text = 'Running';
         startpacket = [170, 4, 2, 0];
        write(s, startpacket, 'uint8');

        try
            if isempty(newFig) || ~isvalid(newFig)
                newFig = uifigure('Name', 'Voltage Channels', 'Position', [200 200 700 400]);

                ax = uiaxes(newFig, 'Position', [50 80 600 300]);
                title(ax, 'Channel Voltages');
                xlabel(ax, 'Channel Number');
                ylabel(ax, 'Voltage (V)');
                ax.XLim = [0.5 24.5];
                ax.YLim = [0 30];
                ax.XTick = 1:24;

                voltageData = zeros(1, 24);
                barPlot = bar(ax, voltageData);
                
                newFig.CloseRequestFcn = @(src, event) onCloseFigure(src, btn);

                timerObj = timer('ExecutionMode', 'fixedSpacing', ...
                                 'Period', 0.1, ...
                                 'TimerFcn', @(~,~) updatePlot());
                start(timerObj);
            end
        catch
            btn.Text = 'Start';
            btn.Value = false;
        end
    else
        btn.Text = 'Start';
        %stoppacket = [170, 4, 6, 0];
       % write(s, stoppacket, 'uint8');
        try
            if isvalid(newFig)
                close(newFig);
                
            end
            if ~isempty(timerObj) && isvalid(timerObj)
                stop(timerObj);
                delete(timerObj);
                timerObj = [];
            end
        catch
        end
        newFigcl = [];
    end

    function updatePlot()
        if ~isempty(s) && s.NumBytesAvailable >= 48  % 24 channels * 2 bytes each
            rawData = read(s, 48, "uint8");  % read 48 bytes (24 uint16 values)
            % Convert pairs of bytes to uint16
            voltages16 = typecast(uint8(rawData), 'uint16'); 
            % Convert to voltage (max 0xFFFF -> 30V)
            voltageData = double(voltages16) * 30 / 65535;
            % Update bar plot data
            barPlot.YData = voltageData;
            drawnow limitrate
        end
    end
end




function onCloseFigure(fig, btn)
    btn.Text = 'Start';
    btn.Value = false;
    delete(fig);
    stoppacket = [170, 4, 8, 0];
    write(s, stoppacket, 'uint8');


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
       % disp(s)

       disp("Button pressed");

     % Check if 's' exists, is valid, and open
    if ~exist('s', 'var') || isempty(s) || ~isvalid(s) || ~strcmp(s.Status, 'open')
        errordlg('Please choose a valid serial port and connect first.', 'Serial Port Error');
        return;
    end
        write(s, freqpacket, 'uint8');

        disp("Sending packet...");

        %write(s, freqpacket, "uint8");


        % Convert to hex string
        freqpacketHex = arrayfun(@(b) sprintf('%02X', b), freqpacket, 'UniformOutput', false);
        freqpacketStr = strjoin(freqpacketHex, ' ');

        fprintf('Frequency packet: %s\n', freqpacketStr);


    end
end
