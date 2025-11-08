"""
VoltageController - Main GUI for controlling voltage channels
"""

import sys
import struct
import time
from typing import List, Optional
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, 
    QPushButton, QSpinBox, QDoubleSpinBox, QCheckBox, QComboBox,
    QScrollArea, QFrame, QMessageBox, QApplication, QTextEdit,
    QSplitter, QPushButton
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QFont

from serial_manager import SerialManager
from voltage_monitor import VoltageMonitor

class VoltageController(QWidget):
    # Constants
    MAX_VOLTAGE = 30
    NUM_CHANNELS = 24
    
    def __init__(self):
        super().__init__()
        self.serial_manager = SerialManager()
        self.monitor_window = None
        self.is_monitoring = False
        
        # UI Elements lists
        self.start_voltage_fields = []
        self.end_voltage_fields = []
        self.step_fields = []
        self.hold_end_checkboxes = []
        
        self.init_ui()
        self.setup_connections()
        
    def init_ui(self):
        """Initialize the user interface"""
        self.setWindowTitle("Voltage Controller")
        self.setGeometry(100, 100, 900, 900)
        
        # Create main splitter to divide controls and serial monitor
        main_splitter = QSplitter(Qt.Orientation.Vertical)
        
        # Upper widget for controls
        upper_widget = QWidget()
        layout = QVBoxLayout(upper_widget)
        
        # Title
        title = QLabel(f"Voltage Controller for {self.NUM_CHANNELS} Channels")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title.setFont(title_font)
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Control buttons row
        self.create_control_buttons(layout)
        
        # Frequency controls
        self.create_frequency_controls(layout)
        
        # Set all controls
        self.create_set_all_controls(layout)
        
        # Channel table
        self.create_channel_table(layout)
        
        # Action buttons
        self.create_action_buttons(layout)
        
        # Add upper widget to splitter
        main_splitter.addWidget(upper_widget)
        
        # Create serial monitor
        self.create_serial_monitor(main_splitter)
        
        # Set splitter proportions (70% controls, 30% monitor)
        main_splitter.setStretchFactor(0, 7)
        main_splitter.setStretchFactor(1, 3)
        
        # Set main layout
        main_layout = QVBoxLayout()
        main_layout.addWidget(main_splitter)
        self.setLayout(main_layout)
        
    def create_control_buttons(self, layout):
        """Create the main control buttons"""
        control_layout = QHBoxLayout()
        
        # Start/Stop button
        self.start_button = QPushButton("Start")
        self.start_button.setMinimumHeight(50)
        start_font = QFont()
        start_font.setPointSize(14)
        start_font.setBold(True)
        self.start_button.setFont(start_font)
        self.start_button.clicked.connect(self.toggle_monitoring)
        
        # Serial port controls
        port_layout = QVBoxLayout()
        port_layout.addWidget(QLabel("Serial Port:"))
        
        port_controls = QHBoxLayout()
        self.port_dropdown = QComboBox()
        self.port_dropdown.setMinimumWidth(120)
        
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self.refresh_ports)
        
        self.connect_button = QPushButton("Connect")
        self.connect_button.clicked.connect(self.toggle_connection)
        
        port_controls.addWidget(self.port_dropdown)
        port_controls.addWidget(refresh_btn)
        port_controls.addWidget(self.connect_button)
        
        port_layout.addLayout(port_controls)
        
        control_layout.addLayout(port_layout)
        control_layout.addStretch()
        control_layout.addWidget(self.start_button)
        
        layout.addLayout(control_layout)
        
    def create_frequency_controls(self, layout):
        """Create frequency control widgets"""
        freq_layout = QHBoxLayout()
        
        freq_layout.addWidget(QLabel("Frequency (Hz):"))
        self.frequency_field = QSpinBox()
        self.frequency_field.setRange(1, 200000)
        self.frequency_field.setValue(1000)
        
        freq_apply_btn = QPushButton("Apply")
        freq_apply_btn.clicked.connect(self.set_frequency)
        
        freq_layout.addWidget(self.frequency_field)
        freq_layout.addWidget(freq_apply_btn)
        freq_layout.addStretch()
        
        layout.addLayout(freq_layout)
        
    def create_set_all_controls(self, layout):
        """Create set all controls"""
        set_all_layout = QHBoxLayout()
        
        set_all_layout.addWidget(QLabel("Set All:"))
        
        # Start voltage
        self.set_all_start = QDoubleSpinBox()
        self.set_all_start.setRange(0, self.MAX_VOLTAGE)
        self.set_all_start.setDecimals(2)
        start_apply_btn = QPushButton("Apply Start")
        start_apply_btn.clicked.connect(lambda: self.set_all_values('start'))
        
        # End voltage
        self.set_all_end = QDoubleSpinBox()
        self.set_all_end.setRange(0, self.MAX_VOLTAGE)
        self.set_all_end.setDecimals(2)
        end_apply_btn = QPushButton("Apply End")
        end_apply_btn.clicked.connect(lambda: self.set_all_values('end'))
        
        # Steps
        self.set_all_steps = QSpinBox()
        self.set_all_steps.setRange(1, 65535)
        self.set_all_steps.setValue(100)
        steps_apply_btn = QPushButton("Apply Steps")
        steps_apply_btn.clicked.connect(lambda: self.set_all_values('steps'))
        
        set_all_layout.addWidget(self.set_all_start)
        set_all_layout.addWidget(start_apply_btn)
        set_all_layout.addWidget(self.set_all_end)
        set_all_layout.addWidget(end_apply_btn)
        set_all_layout.addWidget(self.set_all_steps)
        set_all_layout.addWidget(steps_apply_btn)
        set_all_layout.addStretch()
        
        layout.addLayout(set_all_layout)
        
    def create_channel_table(self, layout):
        """Create the channel configuration table"""
        # Headers
        header_layout = QGridLayout()
        headers = ["Channel", "Start Voltage (V)", "End Voltage (V)", "Steps", "Hold End?"]
        for i, header in enumerate(headers):
            label = QLabel(header)
            label.setStyleSheet("font-weight: bold;")
            header_layout.addWidget(label, 0, i)
        
        header_widget = QWidget()
        header_widget.setLayout(header_layout)
        layout.addWidget(header_widget)
        
        # Scrollable area for channels
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setMaximumHeight(400)
        
        scroll_widget = QWidget()
        scroll_layout = QGridLayout(scroll_widget)
        
        # Create channel rows
        for i in range(self.NUM_CHANNELS):
            row = i
            
            # Channel number
            scroll_layout.addWidget(QLabel(str(i + 1)), row, 0)
            
            # Start voltage
            start_field = QDoubleSpinBox()
            start_field.setRange(0, self.MAX_VOLTAGE)
            start_field.setDecimals(2)
            self.start_voltage_fields.append(start_field)
            scroll_layout.addWidget(start_field, row, 1)
            
            # End voltage
            end_field = QDoubleSpinBox()
            end_field.setRange(0, self.MAX_VOLTAGE)
            end_field.setDecimals(2)
            self.end_voltage_fields.append(end_field)
            scroll_layout.addWidget(end_field, row, 2)
            
            # Steps
            step_field = QSpinBox()
            step_field.setRange(1, 65535)
            step_field.setValue(100)
            self.step_fields.append(step_field)
            scroll_layout.addWidget(step_field, row, 3)
            
            # Hold end checkbox
            hold_checkbox = QCheckBox()
            self.hold_end_checkboxes.append(hold_checkbox)
            scroll_layout.addWidget(hold_checkbox, row, 4)
        
        scroll_area.setWidget(scroll_widget)
        layout.addWidget(scroll_area)
        
    def create_action_buttons(self, layout):
        """Create action buttons"""
        button_layout1 = QHBoxLayout()
        
        # First row
        send_values_btn = QPushButton("Send Values")
        send_values_btn.clicked.connect(self.update_voltages)
        
        button_layout1.addWidget(send_values_btn)
    

        # Add these two lines to add the button layouts to the main layout
        layout.addLayout(button_layout1)
        
        
    def create_serial_monitor(self, parent_splitter):
        """Create the built-in serial monitor"""
        monitor_widget = QWidget()
        monitor_layout = QVBoxLayout(monitor_widget)
        
        # Monitor header with controls
        header_layout = QHBoxLayout()
        
        monitor_title = QLabel("Serial Monitor")
        monitor_title.setStyleSheet("font-weight: bold; font-size: 12px;")
        header_layout.addWidget(monitor_title)
        
        header_layout.addStretch()
        
        # Clear button
        clear_btn = QPushButton("Clear")
        clear_btn.setMaximumWidth(60)
        clear_btn.clicked.connect(self.clear_serial_monitor)
        header_layout.addWidget(clear_btn)
        
        # Auto-scroll checkbox
        self.auto_scroll_cb = QCheckBox("Auto-scroll")
        self.auto_scroll_cb.setChecked(True)
        header_layout.addWidget(self.auto_scroll_cb)
        
        monitor_layout.addLayout(header_layout)
        
        # Serial output text area
        self.serial_monitor = QTextEdit()
        self.serial_monitor.setReadOnly(True)
        self.serial_monitor.setMaximumHeight(200)
        self.serial_monitor.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                color: #ffffff;
                font-family: 'Courier New', monospace;
                font-size: 10px;
                border: 1px solid #555;
            }
        """)
        monitor_layout.addWidget(self.serial_monitor)
        
        parent_splitter.addWidget(monitor_widget)
        
    def log_to_monitor(self, message: str, message_type: str = "info"):
        """Add message to serial monitor"""
        import datetime
        timestamp = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        
        # Color coding based on message type
        if message_type == "sent":
            color = "#00ff00"  # Green for sent
            prefix = "TX"
        elif message_type == "received":
            color = "#00aaff"  # Blue for received
            prefix = "RX"
        elif message_type == "error":
            color = "#ff4444"  # Red for errors
            prefix = "ERR"
        elif message_type == "connection":
            color = "#ffaa00"  # Orange for connection events
            prefix = "CONN"
        else:
            color = "#ffffff"  # White for info
            prefix = "INFO"
            
        formatted_message = f'<span style="color: #888888">[{timestamp}]</span> <span style="color: {color}; font-weight: bold">{prefix}:</span> <span style="color: {color}">{message}</span>'
        
        self.serial_monitor.append(formatted_message)
        
        # Auto-scroll to bottom if enabled
        if self.auto_scroll_cb.isChecked():
            scrollbar = self.serial_monitor.verticalScrollBar()
            scrollbar.setValue(scrollbar.maximum())
            
    def clear_serial_monitor(self):
        """Clear the serial monitor"""
        self.serial_monitor.clear()
        self.log_to_monitor("Serial monitor cleared", "info")
        
    def setup_connections(self):
        """Setup signal connections and initial state"""
        self.refresh_ports()
        
        # Connect serial manager signals to monitor
        self.serial_manager.packet_sent.connect(
            lambda msg: self.log_to_monitor(msg, "sent")
        )
        self.serial_manager.data_received.connect(
            lambda data: self.log_to_monitor(f"{data.decode('ascii', errors='replace')}", "received")
        )
        self.serial_manager.connection_changed.connect(
            lambda connected, port: self.log_to_monitor(
                f"{'Connected to' if connected else 'Disconnected from'} {port}", 
                "connection"
            )
        )
        
    def refresh_ports(self):
        """Refresh available serial ports"""
        ports = self.serial_manager.get_available_ports()
        self.port_dropdown.clear()
        if ports:
            self.port_dropdown.addItems(ports)
        else:
            self.port_dropdown.addItem("No ports found")
            
    def toggle_connection(self):
        """Toggle serial connection"""
        if self.serial_manager.is_connected():
            self.serial_manager.disconnect()
            self.connect_button.setText("Connect")
        else:
            port = self.port_dropdown.currentText()
            if port == "No ports found":
                self.log_to_monitor("No valid serial port selected", "error")
                QMessageBox.warning(self, "Connection Error", 
                                   "No valid serial port selected.")
                return
                
            if self.serial_manager.connect(port):
                self.connect_button.setText("Disconnect")
            else:
                self.log_to_monitor(f"Failed to connect to {port}", "error")
                QMessageBox.critical(self, "Connection Error", 
                                    f"Failed to connect to {port}")
                
    def toggle_monitoring(self):
        """Toggle voltage monitoring"""
        if self.is_monitoring:
            self.stop_monitoring()
        else:
            self.start_monitoring()
    def wait_for_confirmation(self, timeout_ms=2000):
        """Wait for a confirmation response from device
        
        Args:
            timeout_ms: Maximum time to wait in milliseconds
            
        Returns:
            bool: True if confirmation received, False if timeout
        """
        start_time = time.time()
        timeout_seconds = timeout_ms / 1000
        
        # Create a local event loop to wait without freezing the UI
        while time.time() - start_time < timeout_seconds:
            # Process events to keep UI responsive
            QApplication.processEvents()
            
            # Check for confirmation in received data
            if self.serial_manager.has_confirmation():
                return True
                
            time.sleep(0.01)  # Small sleep to avoid CPU hogging
            
        return False
            
    def start_monitoring(self):
        """Start voltage monitoring"""
        if not self.serial_manager.is_connected():
            self.log_to_monitor("Cannot start monitoring: not connected", "error")
            QMessageBox.warning(self, "Connection Error", 
                               "Please connect to a serial port first.")
            return
            
        self.is_monitoring = True
        self.start_button.setText("Running")
        self.log_to_monitor("Starting voltage monitoring", "info")
        
        # Send start data collection packet
        start_packet = [170, 4, 2, 0]
        self.serial_manager.send_packet(start_packet, "Start monitoring")

        # Wait for confirmation (with timeout)
        self.log_to_monitor(f"Waiting for confirmation from channel", "info")
        if self.wait_for_confirmation(2000):  # 2-second timeout
            self.log_to_monitor(f"Channel configuration confirmed", "info")
        else:
            self.log_to_monitor(f"No confirmation received for channel", "error")
            
        time.sleep(0.1)  # Small delay between packets
        
        # Open monitor window
        self.monitor_window = VoltageMonitor(self.serial_manager)
        self.monitor_window.closed.connect(self.stop_monitoring)
        
        # Connect monitor window logging
        self.monitor_window.data_parsed.connect(
            lambda voltages: self.log_to_monitor(
                f"Voltages: {', '.join([f'{v:.2f}V' for v in voltages[:6]])}...", 
                "received"
            )
        )
        
        self.monitor_window.show()
        
    def stop_monitoring(self):
        """Stop voltage monitoring"""
        self.is_monitoring = False
        self.start_button.setText("Start")
        self.log_to_monitor("Stopping voltage monitoring", "info")
        
        # Send stop data collection packet
        if self.serial_manager.is_connected():
            stop_packet = [170, 4, 8, 0]
            self.serial_manager.send_packet(stop_packet, "Stop monitoring")
            # Wait for confirmation (with timeout)
            self.log_to_monitor(f"Waiting for confirmation from channel", "info")
            if self.wait_for_confirmation(2000):  # 2-second timeout
                self.log_to_monitor(f"Channel configuration confirmed", "info")
            else:
                self.log_to_monitor(f"No confirmation received for channel", "error")
            time.sleep(0.1)  # Small delay between packets
            
        # Close monitor window
        if self.monitor_window:
            self.monitor_window.close()
            self.monitor_window = None
            
    def set_frequency(self):
        """Set DAC frequency"""
        frequency = self.frequency_field.value()
        
        if frequency > 200000:
            error_msg = f"Frequency too high. DACs can handle max 200kHz, you set {frequency} Hz"
            self.log_to_monitor(error_msg, "error")
            QMessageBox.warning(self, "Value Error", error_msg)
            return
            
        if not self.serial_manager.is_connected():
            error_msg = "Cannot set frequency: not connected"
            self.log_to_monitor(error_msg, "error")
            QMessageBox.warning(self, "Serial Port Error", 
                               "Please connect to a serial port first.")
            return
            
        # Convert frequency to bytes (big-endian, 3 bytes)
        freq_bytes = struct.pack('>I', frequency)[1:4]  # Take last 3 bytes
        freq_packet = [170, 7, 8] + list(freq_bytes) + [0]
        
        self.serial_manager.send_packet(freq_packet, f"Frequency ({frequency} Hz)")

        # Wait for confirmation (with timeout)
        self.log_to_monitor(f"Waiting for confirmation from channel", "info")
        if self.wait_for_confirmation(2000):  # 2-second timeout
            self.log_to_monitor(f"Channel configuration confirmed", "info")
        else:
            self.log_to_monitor(f"No confirmation received for channel", "error")
            
        time.sleep(0.1)  # Small delay between packets
    
        
    def set_all_values(self, field_type):
        """Set all values for a specific field type"""
        if field_type == 'start':
            value = self.set_all_start.value()
            for field in self.start_voltage_fields:
                field.setValue(value)
        elif field_type == 'end':
            value = self.set_all_end.value()
            for field in self.end_voltage_fields:
                field.setValue(value)
        elif field_type == 'steps':
            value = self.set_all_steps.value()
            for field in self.step_fields:
                field.setValue(value)
                
    def update_voltages(self):
        """Send voltage settings to all channels"""
        if not self.serial_manager.is_connected():
            error_msg = "Cannot send voltages: not connected"
            self.log_to_monitor(error_msg, "error")
            QMessageBox.warning(self, "Connection Error", 
                               "Please connect to a serial port first.")
            return
            
        self.log_to_monitor("Sending voltage configuration to all channels", "info")
        
        for i in range(self.NUM_CHANNELS):
            if not self.validate_channel_values(i):
                return
                
            packet = self.create_voltage_packet(i)
            self.serial_manager.send_packet(packet, f"Channel {i + 1}")

            # Wait for confirmation (with timeout)
            self.log_to_monitor(f"Waiting for confirmation from channel", "info")
            if self.wait_for_confirmation(2000):  # 2-second timeout
                self.log_to_monitor(f"Channel configuration confirmed", "info")
            else:
                self.log_to_monitor(f"No confirmation received for channel", "error")
                
            time.sleep(0.1)  # Small delay between packets
            
            
    def validate_channel_values(self, channel_num):
        """Validate voltage and step values for a channel"""
        start_val = self.start_voltage_fields[channel_num].value()
        end_val = self.end_voltage_fields[channel_num].value()
        steps_val = self.step_fields[channel_num].value()
        
        if start_val < 0 or start_val > self.MAX_VOLTAGE:
            QMessageBox.warning(self, "Value Error", 
                               f"Start voltage out of range (0-{self.MAX_VOLTAGE}V) on channel {channel_num + 1}")
            return False
            
        if end_val < 0 or end_val > self.MAX_VOLTAGE:
            QMessageBox.warning(self, "Value Error", 
                               f"End voltage out of range (0-{self.MAX_VOLTAGE}V) on channel {channel_num + 1}")
            return False
            
        if steps_val <= 0 or steps_val > 65535:
            QMessageBox.warning(self, "Value Error", 
                               f"Steps must be between 1 and 65535 on channel {channel_num + 1}")
            return False
            
        return True
        
    def create_voltage_packet(self, channel_num):
        """Create voltage control packet for a channel"""
        start_val = self.start_voltage_fields[channel_num].value()
        end_val = self.end_voltage_fields[channel_num].value()
        steps_val = self.step_fields[channel_num].value()
        hold_end_val = 1 if self.hold_end_checkboxes[channel_num].isChecked() else 0
        
        # Convert voltage to DAC values (16-bit)
        start_dac = int(start_val * 65535 / self.MAX_VOLTAGE)
        end_dac = int(end_val * 65535 / self.MAX_VOLTAGE)
        
        # Create packet with big-endian byte order
        packet = [170, 12, 1, channel_num + 1, hold_end_val]  # channel_num is 1-indexed
        packet.extend(struct.pack('>H', start_dac))  # Start value (big-endian)
        packet.extend(struct.pack('>H', end_dac))    # End value (big-endian)
        packet.extend(struct.pack('>H', steps_val))  # Steps (big-endian)
        packet.append(0)
        
        return packet
        
    def toggle_sweep(self):
        """Toggle auto sweep mode"""
        if self.auto_sweep_btn.isChecked():
            self.auto_sweep_btn.setText("Stop Sweep")
        else:
            self.auto_sweep_btn.setText("Auto Sweep")
            
    def closeEvent(self, event):
        """Handle application close event"""
        if self.monitor_window:
            self.monitor_window.close()
        self.serial_manager.disconnect()
        event.accept()