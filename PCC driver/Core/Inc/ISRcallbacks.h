/*
 * ISRcallbacks.h
 *
 *  Created on: Aug 24, 2025
 *      Author: thomaspedersen
 */

#ifndef INC_ISRCALLBACKS_H_
#define INC_ISRCALLBACKS_H_

#include <stdint.h>
#include <main.h>
#include "config.h"


extern uint8_t rx_array[64];
extern uint8_t rx_flag;
extern uint8_t send_flag;


void USB_DataReceived(uint8_t* Buf, uint32_t Len);

#endif /* INC_ISRCALLBACKS_H_ */
