/*
 * config.h
 *
 *  Created on: Jul 23, 2025
 *      Author: thomaspedersen
 */

#ifndef INC_CONFIG_H_
#define INC_CONFIG_H_

#define NUM_CHANNELS 24
#define MAX_VOLTAGE 30.0
#define MAX_STEPS 0xFF

typedef struct {
    uint16_t startVoltage;
    uint16_t endVoltage;
    uint16_t steps;
    uint16_t currentstep;
    int32_t step_value;
    uint16_t currentVoltage;
    uint8_t holdEndValue;
    int8_t direction;
    uint16_t readVoltage;
} ChannelConfig;


extern ChannelConfig channels[NUM_CHANNELS];

#endif /* INC_CONFIG_H_ */

