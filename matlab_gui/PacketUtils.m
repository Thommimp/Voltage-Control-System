classdef PacketUtils
    % Utility class for packet creation and serial communication
    
    methods (Static)
        function packet = createVoltagePacket(channelNum, startVoltage, endVoltage, steps, maxVoltage)
            % Create a voltage control packet for a specific channel
            %
            % Inputs:
            %   channelNum - Channel number (1-24)
            %   startVoltage - Starting voltage (0-maxVoltage)
            %   endVoltage - Ending voltage (0-maxVoltage)
            %   steps - Number of steps (1-65535)
            %   maxVoltage - Maximum voltage limit
            %
            % Output:
            %   packet - Byte array ready for transmission
            
            % Convert voltage to DAC values
            startValConv = startVoltage * 65535 / maxVoltage;
            endValConv = endVoltage * 65535 / maxVoltage;
            
            % Prepare byte arrays (flip for endianness)
            startInt = fliplr(typecast(uint16(startValConv), 'uint8'));
            endInt = fliplr(typecast(uint16(endValConv), 'uint8'));
            stepsInt = fliplr(typecast(uint16(steps), 'uint8'));
            
            % Create packet: [Header, Length, Command, Channel, StartVoltage, EndVoltage, Steps, Checksum]
            packet = [170, 11, 1, channelNum, startInt, endInt, stepsInt, 0];
        end
        
        function packet = createFrequencyPacket(frequency)
            % Create a frequency control packet
            %
            % Input:
            %   frequency - Frequency value in Hz
            %
            % Output:
            %   packet - Byte array ready for transmission
            
            freqInt = fliplr(typecast(uint32(frequency), 'uint8'));
            freq3bytes = freqInt(2:4);  % Keep only the lowest 3 bytes
            
            % Create packet: [Header, Length, Command, Frequency_bytes, Checksum]
            packet = [170, 7, 8, freq3bytes, 0];
        end
        
        function packet = createStartPacket()
            % Create a start data collection packet
            packet = [170, 4, 2, 0];
        end
        
        function packet = createStopPacket()
            % Create a stop data collection packet
            packet = [170, 4, 8, 0];
        end
        
        function hexString = packetToHexString(packet)
            % Convert packet bytes to hex string for display
            %
            % Input:
            %   packet - Byte array
            %
            % Output:
            %   hexString - Formatted hex string (e.g., "AA 0B 01 ...")
            
            packetHex = arrayfun(@(b) sprintf('%02X', b), packet, 'UniformOutput', false);
            hexString = strjoin(packetHex, ' ');
        end
        
        function voltages = parseVoltageData(rawData, maxVoltage)
            % Parse raw voltage data from serial communication
            %
            % Inputs:
            %   rawData - Raw byte array from serial port
            %   maxVoltage - Maximum voltage for scaling
            %
            % Output:
            %   voltages - Array of voltage values
            
            if length(rawData) ~= 48
                error('Expected 48 bytes of voltage data, got %d', length(rawData));
            end
            
            % Convert pairs of bytes to uint16 values
            voltages16 = typecast(uint8(rawData), 'uint16');
            
            % Convert to voltage values (0xFFFF -> maxVoltage)
            voltages = double(voltages16) * maxVoltage / 65535;
        end
        
        function ports = getAvailableSerialPorts()
            % Get list of available serial ports (filtered for macOS)
            %
            % Output:
            %   ports - Cell array of available port names
            
            allPorts = serialportlist("all");
            
            % Filter for macOS USB/serial ports
            if ismac()
                ports = allPorts(startsWith(allPorts, "/dev/cu."));
            elseif ispc()
                ports = allPorts(startsWith(allPorts, "COM"));
            else
                % Linux/Unix
                ports = allPorts(startsWith(allPorts, "/dev/tty"));
            end
            
            if isempty(ports)
                ports = {'No ports found'};
            end
        end
        
        function isValid = validateVoltageRange(voltage, maxVoltage)
            % Validate that voltage is within acceptable range
            %
            % Inputs:
            %   voltage - Voltage value to validate
            %   maxVoltage - Maximum allowed voltage
            %
            % Output:
            %   isValid - Boolean indicating if voltage is valid
            
            isValid = voltage >= 0 && voltage <= maxVoltage && ~isnan(voltage);
        end
        
        function isValid = validateStepsRange(steps)
            % Validate that steps value is within acceptable range
            %
            % Input:
            %   steps - Steps value to validate
            %
            % Output:
            %   isValid - Boolean indicating if steps value is valid
            
            isValid = steps >= 1 && steps <= 65535 && ~isnan(steps) && floor(steps) == steps;
        end
        
        function displayPacketInfo(packet, description)
            % Display packet information for debugging
            %
            % Inputs:
            %   packet - Byte array packet
            %   description - Descriptive string for the packet
            
            hexString = PacketUtils.packetToHexString(packet);
            fprintf('%s packet (%d bytes): %s\n', description, length(packet), hexString);
        end
    end
end