/*
 * functions.c
 *
 *  Created on: Jun 2, 2025
 *      Author: thomaspedersen
 */



#include "main.h"

void set_dac_cs_pins_high() {
GPIOA->BSRR = DAC_CS1_PIN_HIGH;
 GPIOA->BSRR = DAC_CS2_PIN_HIGH;
 GPIOA->BSRR = DAC_CS3_PIN_HIGH;

}

void write_to_dac(uint8_t dac_num, uint8_t channel, uint16_t voltage) {
	uint8_t tx_array[3];
	//set the DAC low, ready for comm
	GPIOA->BSRR = (1 << (16 + (dac_num-1)));

	tx_array[0] = (channel & 0x0F);

	tx_array[1] = (voltage >> 8);

	tx_array[2] = (voltage & 0xFF);

	HAL_SPI_Transmit(&hspi5, tx_array, 3, HAL_MAX_DELAY);

	GPIOA->BSRR = (1 << ((dac_num-1)));

}

uint16_t read_dac(uint8_t dac_num, uint8_t channel) {



	GPIOA->BSRR = (1 << (16 + (dac_num-1)));

	uint8_t read_array[3] = {0x00, 0x00, 0x00};
	read_array[0] = 0x80 | (channel & 0x0F);

	uint8_t rx_buffer[3];


	HAL_SPI_TransmitReceive(&hspi5, read_array, rx_buffer, 3, HAL_MAX_DELAY);

	uint16_t channel_voltage = (rx_buffer[1] << 8) | rx_buffer[2];

	GPIOA->BSRR = (1 << ((dac_num-1)));

	return channel_voltage;


}

uint16_t volts_to_dac_value(uint32_t voltage_uv) {
    uint32_t vref_mv = 5000000;
    if (voltage_mv > vref_mv) voltage_uv = vref_mv;
    return (uint16_t)(((uint32_t)voltage_uv * 65535) / vref_mv);
}



