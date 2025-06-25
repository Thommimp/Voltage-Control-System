# Voltage Controller MATLAB Application

A modular MATLAB application for controlling voltage channels through serial communication with an STM32 microcontroller.

## Project Structure

```
voltage_controller/
├── main.m                  % Entry point script
├── VoltageController.m     % Main GUI controller class
├── VoltageMonitor.m        % Real-time voltage monitoring window
├── PacketUtils.m           % Utility functions for packet handling
└── README.md              % This documentation
```

## Files Description

### `main.m`
- Entry point for the application
- Creates and initializes the VoltageController instance
- Includes error handling for initialization

### `VoltageController.m`
- Main class handling the primary GUI interface
- Manages 24 voltage channels with start/end voltages and steps
- Handles serial port communication and connection management
- Features frequency control, bulk operations, and profile management
- Integrates with VoltageMonitor for real-time data visualization

### `VoltageMonitor.m`
- Dedicated class for the real-time voltage monitoring window
- Creates bar chart visualization of all 24 channels
- Handles timer-based data updates at 10Hz
- Manages its own lifecycle and cleanup

### `PacketUtils.m`
- Static utility class for packet creation and data handling
- Provides methods for creating different types of command packets
- Includes data validation and parsing functions
- Handles cross-platform serial port detection

## Usage

1. **Starting the Application:**
   ```matlab
   main
   ```

2. **Basic Workflow:**
   - Connect to STM32 device via serial port
   - Set frequency using the frequency control
   - Configure voltage parameters for channels (start voltage, end voltage, steps)
   - Use "Set All" features for bulk operations
   - Send values to update the device
   - Use "Start" button to begin real-time monitoring

3. **Key Features:**
   - **Multi-channel Control:** Configure up to 24 voltage channels independently
   - **Real-time Monitoring:** Live bar chart showing current voltage levels
   - **Frequency Control:** Set DAC update frequency (up to 200kHz)
   - **Serial Communication:** Robust serial port handling with automatic detection
   - **Data Validation:** Input validation for voltage ranges and step counts
   - **Bulk Operations:** Set all channels to the same values quickly

## Hardware Communication Protocol

The application communicates with STM32 hardware using custom packet protocols:

- **Voltage Control Packet:** `[170, 11, 1, channel, start_voltage_bytes, end_voltage_bytes, steps_bytes, 0]`
- **Frequency Control Packet:** `[170, 7, 8, frequency_3bytes, 0]`
- **Start Data Collection:** `[170, 4, 2, 0]`
- **Stop Data Collection:** `[170, 4, 8, 0]`

## Requirements

- MATLAB R2020b or later (for App Designer components)
- Instrument Control Toolbox (for serial communication)
- STM32 hardware with compatible firmware

## Configuration

### Voltage Limits
- Maximum voltage: 30V (configurable via `MAX_VOLTAGE` constant)
- Voltage resolution: 16-bit (65535 steps)
- Channel count: 24 (configurable via `NUM_CHANNELS` constant)

### Serial Communication
- Baud rate: 115200
- Data format: 8-N-1
- Flow control: None

## Error Handling

The application includes comprehensive error handling for:
- Serial port connection failures
- Invalid voltage range inputs
- Frequency limits exceeded
- Hardware communication timeouts
- GUI component initialization errors

## Troubleshooting

### Common Issues

1. **"No ports found" in dropdown:**
   - Check USB connection to STM32 device
   - Verify device drivers are installed
   - Click "Refresh Ports" button

2. **Connection fails:**
   - Ensure no other applications are using the serial port
   - Check baud rate matches hardware configuration (115200)
   - Verify STM32 firmware is running correctly

3. **No data in monitoring window:**
   - Confirm serial connection is established
   - Check that "Start" button has been pressed
   - Verify STM32 is sending data in expected format (48 bytes per update)

4. **Voltage out of range errors:**
   - Check that all voltage values are between 0 and 30V
   - Ensure step values are between 1 and 65535

## Customization

### Modifying Channel Count
To change the number of channels, update the `NUM_CHANNELS` constant in `VoltageController.m`:
```matlab
properties (Constant)
    NUM_CHANNELS = 32;  % Change from 24 to desired number
end
```

### Changing Voltage Limits
To modify maximum voltage, update the `MAX_VOLTAGE` constant:
```matlab
properties (Constant)
    MAX_VOLTAGE = 50;  % Change from 30V to desired maximum
end
```

### Adding New Packet Types
Extend `PacketUtils.m` with new static methods:
```matlab
function packet = createCustomPacket(param1, param2)
    % Your custom packet creation logic
    packet = [170, length, command, param1, param2, 0];
end
```

## Development Notes

### Code Organization Benefits
- **Separation of Concerns:** UI logic, data processing, and utilities are separated
- **Maintainability:** Each class has a single responsibility
- **Reusability:** PacketUtils can be used by other applications
- **Testability:** Individual components can be unit tested
- **Extensibility:** Easy to add new features or modify existing ones

### Future Enhancements
- Configuration file support for saving/loading setups
- Data logging capabilities
- Advanced plotting options (time series, multiple channels)
- Network communication support
- Automated testing framework

## License

This project is provided as-is for educational and research purposes.