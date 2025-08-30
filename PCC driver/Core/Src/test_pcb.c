/*
 * test_pcb.c
 *
 *  Created on: Aug 23, 2025
 *      Author: thomaspedersen
 */


#include "test_pcb.h"

void test_everything() {


}
test_regulators() {
	 __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);

	 while(!__HAL_PWR_GET_FLAG(PWR_FLAG_VOSRDY)) {}

}

void test_dacs() {
	fillTestValues();
	printf("Testing DAC's");
	spi_init_24bit();

	write_all_dacs();

	read_all_dacs();

	for(uint8_t i = 0; i < NUM_CHANNELS; i++) {
		if (channels[i].currentVoltage == channels[i].readVoltage) {
	        printf("Test passed for channel %d\n", i);
		} else {
	        printf("Test failed for channel %d\n", i);
		}
	}
}
