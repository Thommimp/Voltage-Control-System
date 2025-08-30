/*
 * functions.h
 *
 *  Created on: Jun 2, 2025
 *      Author: thomaspedersen
 */

#ifndef INC_FUNCTIONS_H_
#define INC_FUNCTIONS_H_
#include "main.h"
#include "config.h"


void set_dac_cs_pins_high();
uint16_t volts_to_dac_value(float voltage);
void fillTestValues();

void start_next_transfer();
void write_all_dacs_super_fast();


#endif /* INC_FUNCTIONS_H_ */
