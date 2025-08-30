/*
 * spi.h
 *
 *  Created on: Aug 4, 2025
 *      Author: thomaspedersen
 */

#ifndef INC_SPI_H_
#define INC_SPI_H_

#include "main.h"
#include "config.h"


void write_to_dac(uint8_t dac_num, uint8_t channel, uint16_t voltage);
void read_all_dacs();
void write_all_dacs();
uint16_t read_dac(uint8_t dac_num, uint8_t channel);
void spi_init_24bit();


#endif /* INC_SPI_H_ */
