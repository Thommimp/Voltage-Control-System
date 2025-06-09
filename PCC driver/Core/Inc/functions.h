/*
 * functions.h
 *
 *  Created on: Jun 2, 2025
 *      Author: thomaspedersen
 */

#ifndef INC_FUNCTIONS_H_
#define INC_FUNCTIONS_H_

void set_dac_cs_pins_high();
void write_to_dac(uint8_t dac_num, uint8_t channel, uint16_t voltage);
uint16_t read_dac(uint8_t dac_num, uint8_t channel);
uint16_t volts_to_dac_value(float voltage);

#endif /* INC_FUNCTIONS_H_ */
