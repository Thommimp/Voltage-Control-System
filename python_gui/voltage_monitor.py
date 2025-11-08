"""
VoltageMonitor - Real-time voltage monitoring window
"""

import struct
import numpy as np
from typing import List, Optional
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel
from PyQt6.QtCore import QTimer, pyqtSignal, Qt
from PyQt6.QtGui import QFont
import pyqtgraph as pg

from serial_manager import SerialManager

class VoltageMonitor(QWidget):
    # Signals
    closed = pyqtSignal()
    data_parsed = pyqtSignal(object)  # Emits voltage data array
    
    # Constants
    PACKET_SIZE = 50  # Expected packet size: 2*24 channels + start/stop bytes
    NUM_CHANNELS = 24
    MAX_VOLTAGE = 30
    
    def __init__(self, serial_manager: SerialManager):
        super().__init__()
        self.serial_manager = serial_manager
        self.voltage_data = np.zeros(self.NUM_CHANNELS)
        
        # Timer for reading serial data
        self.read_timer = QTimer()
        self.read_timer.timeout.connect(self.read_serial_data)
        
        self.init_ui()
        self.start_monitoring()
        
    def init_ui(self):
        """Initialize the monitoring window UI"""
        self.setWindowTitle("Real-time Voltage Monitor")
        self.setGeometry(200, 200, 900, 600)
        
        layout = QVBoxLayout()
        
        # Title
        title = QLabel("Channel Voltages (Real-time)")
        title_font = QFont()
        title_font.setPointSize(14)
        title_font.setBold(True)
        title.setFont(title_font)
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Create the plot widget
        self.plot_widget = pg.PlotWidget()
        self.plot_widget.setLabel('left', 'Voltage (V)')
        self.plot_widget.setLabel('bottom', 'Channel Number')
        self.plot_widget.setTitle('Real-time Voltage Monitor')
        self.plot_widget.setYRange(0, self.MAX_VOLTAGE)
        self.plot_widget.setXRange(0.5, self.NUM_CHANNELS + 0.5)
        self.plot_widget.showGrid(x=True, y=True)
        
        # Create bar chart
        self.create_bar_chart()
        
        layout.addWidget(self.plot_widget)
        
        # Status label
        self.status_label = QLabel("Status: Monitoring...")
        layout.addWidget(self.status_label)
        
        # Voltage display labels
        self.create_voltage_labels(layout)
        
        self.setLayout(layout)
        
    def create_bar_chart(self):
        """Create the bar chart for voltage display"""
        x = np.arange(1, self.NUM_CHANNELS + 1)
        self.bar_chart = pg.BarGraphItem(
            x=x, 
            height=self.voltage_data, 
            width=0.8, 
            brush='skyblue',
            pen='black'
        )
        self.plot_widget.addItem(self.bar_chart)
        
    def create_voltage_labels(self, layout):
        """Create text labels showing current voltages"""
        voltage_layout = QHBoxLayout()
        voltage_layout.addWidget(QLabel("Current Voltages:"))
        
        self.voltage_display = QLabel("Waiting for data...")
        self.voltage_display.setStyleSheet("font-family: monospace; font-size: 10px;")
        voltage_layout.addWidget(self.voltage_display)
        
        layout.addLayout(voltage_layout)
        
    def start_monitoring(self):
        """Start monitoring serial data"""
        # Start reading timer (read every 50ms)
        self.read_timer.start(50)
        
    def read_serial_data(self):
        """Read and process serial data"""
        if not self.serial_manager.is_connected():
            self.status_label.setText("Status: Not connected")
            return
            
        data = self.serial_manager.read_available_data()
        if data:
            self.process_received_data(data)
            
    def process_received_data(self, data: bytes):
        """Process received data and extract voltage information"""
        try:
            # Look for complete packets in the data
            data_len = len(data)
            
            # Search for packet start (0xAA) and end (0x55) markers
            for i in range(data_len - self.PACKET_SIZE + 1):
                if (i + self.PACKET_SIZE <= data_len and 
                    data[i] == 0xAA and 
                    data[i + self.PACKET_SIZE - 1] == 0x55):
                    
                    packet = data[i:i + self.PACKET_SIZE]
                    self.parse_voltage_packet(packet)
                    break
                    
        except Exception as e:
            print(f"Error processing data: {e}")
            
    def parse_voltage_packet(self, packet: bytes):
        """Parse voltage data from packet"""
        try:
            # Extract voltage bytes (exclude start and end markers)
            voltage_bytes = packet[1:-1]  # Skip first and last byte
            
            # Convert pairs of bytes to 16-bit values (little-endian)
            num_voltage_values = len(voltage_bytes) // 2
            voltage_raw = struct.unpack(f'<{num_voltage_values}H', voltage_bytes)
            
            # Convert to actual voltages
            if len(voltage_raw) >= self.NUM_CHANNELS:
                voltage_data = np.array(voltage_raw[:self.NUM_CHANNELS])
                self.voltage_data = voltage_data * self.MAX_VOLTAGE / 65535.0
                
                # Emit signal for main window logging
                self.data_parsed.emit(self.voltage_data)
                
                # Update display
                self.update_display()
                
                # Log data (optional - can be removed for performance)
                #hex_packet = ' '.join([f'{b:02X}' for b in packet])
                #print(f"Raw packet: {hex_packet}")
                #voltage_str = ', '.join([f'{v:.2f}V' for v in self.voltage_data[:8]])  # Show first 8
                #print(f"Voltages (first 8): {voltage_str}")
                
        except Exception as e:
            print(f"Error parsing voltage packet: {e}")
            
    def update_display(self):
        """Update the visual display with new voltage data"""
        try:
            # Update bar chart
            self.bar_chart.setOpts(height=self.voltage_data)
            
            # Update text display (show first 12 channels)
            voltage_text = ""
            for i in range(min(12, self.NUM_CHANNELS)):
                if i % 6 == 0 and i > 0:
                    voltage_text += "\n"
                voltage_text += f"Ch{i+1:2d}: {self.voltage_data[i]:5.2f}V  "
                
            self.voltage_display.setText(voltage_text)
            self.status_label.setText("Status: Monitoring... (Data received)")
            
        except Exception as e:
            print(f"Error updating display: {e}")
            
    def send_stop_packet(self):
        """Send stop monitoring packet"""
        if self.serial_manager.is_connected():
            try:
                stop_packet = [170, 4, 6, 0]
                self.serial_manager.send_packet(stop_packet, "Stop monitoring")
            except Exception as e:
                print(f"Warning: Could not send stop packet: {e}")
                
    def closeEvent(self, event):
        """Handle window close event"""
        self.read_timer.stop()
        self.send_stop_packet()
        self.closed.emit()
        event.accept()