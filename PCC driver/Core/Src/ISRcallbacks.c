/*
 * ISRcallbacks.c
 *
 *  Created on: Aug 24, 2025
 *      Author: thomaspedersen
 */

#include "ISRcallbacks.h"
uint8_t rx_array[64];
uint8_t rx_flag = 0;
//ISR usb intterupt rutine ting
void USB_DataReceived(uint8_t* Buf, uint32_t Len) {
    static uint8_t i = 0;
    GPIOB->BSRR = GPIO_PIN_2;

    // Copy ALL bytes from this USB packet
    for (uint32_t j = 0; j < Len; j++) {
        rx_array[i] = Buf[j];  // Buf[j], not Buf[i]
    	//CDC_Transmit_FS(&rx_array[i], 1);
        i++;
    }



    //rx_array[1] corresponds to the length of the packet
    if (i == rx_array[1]) {
        // finished
    	//CDC_Transmit_FS(rx_array, i);
    	rx_flag = 1;
    	CDC_Transmit_HS(rx_array, i);
        i = 0;
    }




}
