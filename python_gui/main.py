#!/usr/bin/env python3
"""
Voltage Controller Application
Entry point for the PyQt6-based voltage controller GUI
"""

import sys
import os
from PyQt6.QtWidgets import QApplication
from voltage_controller import VoltageController


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Voltage Controller")
    app.setApplicationVersion("1.0")
    
    controller = VoltageController()
    controller.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()