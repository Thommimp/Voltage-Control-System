"""
SerialManager - Handles serial port communication
"""

import serial
import serial.tools.list_ports
import struct
from typing import List, Optional
from PyQt6.QtCore import QObject, pyqtSignal

class SerialManager(QObject):
    # Signals
    data_received = pyqtSignal(bytes)
    packet_sent = pyqtSignal(str)
    connection_changed = pyqtSignal(bool, str)  # connected, port
    
    def __init__(self):
        super().__init__()
        self.connection: Optional[serial.Serial] = None
        
    def get_available_ports(self) -> List[str]:
        """Get list of available serial ports"""
        ports = serial.tools.list_ports.comports()
        # Filter for common port patterns (adjust as needed for your system)
        available_ports = []
        for port in ports:
            port_name = port.device
            # On macOS/Linux, look for USB/cu ports
            if '/dev/cu.' in port_name or '/dev/ttyUSB' in port_name or '/dev/ttyACM' in port_name:
                available_ports.append(port_name)
            # On Windows, include COM ports
            elif 'COM' in port_name:
                available_ports.append(port_name)
        
        # If no filtered ports, return all ports
        if not available_ports:
            available_ports = [port.device for port in ports]
            
        return available_ports
        
    def connect(self, port: str, baudrate: int = 115200) -> bool:
        """Connect to serial port"""
        try:
            self.connection = serial.Serial(
                port=port,
                baudrate=baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=1
            )
            
            # Clear any existing data
            self.connection.reset_input_buffer()
            self.connection.reset_output_buffer()
            
            print(f"Connected to {port} at {baudrate} baud")
            self.connection_changed.emit(True, port)
            return True
            
        except Exception as e:
            print(f"Failed to connect to {port}: {e}")
            self.connection = None
            self.connection_changed.emit(False, port)
            return False
        
    def has_confirmation(self):
        """Check if a confirmation message was received
        
        Returns:
            bool: True if confirmation was received
        """
        # Look for confirmation in the buffer
        # This implementation depends on your device's protocol
        # Common confirmations: ACK (0x06), "OK", etc.
        if not self.is_connected():
            return False
            
        data = self.read_available_data()
        if data:
            # Check if data contains confirmation (adjust based on your protocol)
            if b'\x06' in data or b'OK' in data:
                return True
                
        return False
    def disconnect(self):
        """Disconnect from serial port"""
        if self.connection and self.connection.is_open:
            try:
                port_name = self.connection.port
                self.connection.close()
                print("Disconnected from serial port")
                self.connection_changed.emit(False, port_name)
            except Exception as e:
                print(f"Error disconnecting: {e}")
        self.connection = None
        
    def is_connected(self) -> bool:
        """Check if connected to serial port"""
        return self.connection is not None and self.connection.is_open
        
    def send_packet(self, packet: List[int], description: str = ""):
        """Send packet over serial connection"""
        if not self.is_connected():
            print("Cannot send packet: not connected")
            return False
            
        try:
            # Convert to bytes
            packet_bytes = bytes(packet)
            self.connection.write(packet_bytes)
            
            # Create log message
            packet_hex = ' '.join([f'{b:02X}' for b in packet_bytes])
            if description:
                log_msg = f"{description}: {packet_hex}"
            else:
                log_msg = f"Packet sent: {packet_hex}"
                
            print(log_msg)
            self.packet_sent.emit(log_msg)
            return True
            
        except Exception as e:
            error_msg = f"Error sending packet: {e}"
            print(error_msg)
            self.packet_sent.emit(error_msg)
            return False
            
    def read_available_data(self) -> Optional[bytes]:
        """Read all available data from serial port"""
        if not self.is_connected():
            return None
            
        try:
            if self.connection.in_waiting > 0:
                data = self.connection.read(self.connection.in_waiting)
                hex_str = ' '.join(f'{b:02X}' for b in data)
                print(hex_str)
                if data:
                    self.data_received.emit(data)
                return data
        except Exception as e:
            print(f"Error reading data: {e}")
            
        return None
        
    def read_packet(self, size: int) -> Optional[bytes]:
        """Read a specific number of bytes"""
        if not self.is_connected():
            return None
            
        try:
            if self.connection.in_waiting >= size:
                return self.connection.read(size)
        except Exception as e:
            print(f"Error reading packet: {e}")
            
        return None
        
    def flush_buffers(self):
        """Flush input and output buffers"""
        if self.is_connected():
            try:
                self.connection.reset_input_buffer()
                self.connection.reset_output_buffer()
            except Exception as e:
                print(f"Error flushing buffers: {e}")