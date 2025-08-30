/*
 * spi.c
 *
 *  Created on: Aug 4, 2025
 *      Author: thomaspedersen
 */
#include "spi.h"

// SPI Status Register flags
#define SPI_SR_TXP      (1UL << 1)   // TX Packet space available
#define SPI_SR_RXP      (1UL << 0)   // RX Packet available
#define SPI_SR_EOT      (1UL << 3)   // End of Transfer
#define SPI_SR_TXTF     (1UL << 4)   // TX Transfer Filled

// SPI Control Register 1 flags
#define SPI_CR1_SPE     (1UL << 0)   // SPI Enable
#define SPI_CR1_CSTART  (1UL << 9)   // Start transfer



void spi_init_24bit() {
    // CubeMX already configured everything, just enable it permanently
    SPI5->CR2 = (SPI5->CR2 & ~0xFFFFU) | 3;  // Set TSIZE=3 permanently for 24-bit
    SPI5->CR1 |= SPI_CR1_SPE;                // Enable permanently
}

void transmit_spi(uint32_t tx_data) {
    // 1. Set the number of data at current transfer (EXACTLY like HAL does)
    //SPI5->CR2 = (SPI5->CR2 & ~0xFFFFU) | 1;  // MODIFY_REG equivalent - set TSIZE to 1

    // 2. Enable SPI peripheral (HAL does this every time)
    SPI5->CR1 |= SPI_CR1_SPE;

    // 3. Master transfer start (only if in master mode)
    SPI5->CR1 |= SPI_CR1_CSTART;

    // 4. Wait until TXP flag is set to send data
    while ((SPI5->SR & SPI_SR_TXP) == 0);

    // 5. Write data (exactly like HAL for 8-bit)
    *(volatile uint8_t *)&SPI5->TXDR = tx_data;

    // 6. Wait for EOT flag (exactly like HAL does)
    while ((SPI5->SR & SPI_SR_EOT) == 0);

    SPI5->IFCR = SPI_SR_EOT;

        // Clear TXTF flag (like __HAL_SPI_CLEAR_TXTFFLAG)
     SPI5->IFCR = SPI_SR_TXTF;

     // Disable SPI peripheral (like __HAL_SPI_DISABLE)
    // SPI5->CR1 &= ~SPI_CR1_SPE;
}



__attribute__((always_inline))
inline void transmit_spi_24bit(uint32_t tx_data) {
    // Ensure only 24 bits are used
    //tx_data &= 0xFFFFFF;

    // 1. Set the number of data to 3 bytes (24 bits)
    //SPI5->CR2 = (SPI5->CR2 & ~0xFFFFU) | 3;  // TSIZE = 3

    // 2. Enable SPI peripheral
    //SPI5->CR1 |= SPI_CR1_SPE;

    // 3. Master transfer start
    SPI5->CR1 |= SPI_CR1_CSTART;

    // Pre-calculate bytes to avoid shifts during transmission
    uint8_t byte2 = tx_data >> 16;
    uint8_t byte1 = tx_data >> 8;
    uint8_t byte0 = tx_data;

    // 4. Send 3 bytes (24 bits) - MSB first
    // Byte 2 (bits 23-16)
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte2;

    // Byte 1 (bits 15-8)
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte1;

    // Byte 0 (bits 7-0)
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte0;

    // 5. Wait for transfer completion
    while ((SPI5->SR & SPI_SR_EOT) == 0);

    // 6. Clear flags
    SPI5->IFCR = SPI_SR_EOT | SPI_SR_TXTF;

    // 7. Disable SPI peripheral
    //SPI5->CR1 &= ~SPI_CR1_SPE;
}

__attribute__((always_inline))
inline void transmit_spi1_24bit(uint32_t tx_data) {
    // Ensure only 24 bits are used
    //tx_data &= 0xFFFFFF;

    // 1. Set the number of data to 3 bytes (24 bits)
    //SPI5->CR2 = (SPI5->CR2 & ~0xFFFFU) | 3;  // TSIZE = 3

    // 2. Enable SPI peripheral
    //SPI5->CR1 |= SPI_CR1_SPE;

    // 3. Master transfer start
    SPI1->CR1 |= SPI_CR1_CSTART;

    // 4. Send 3 bytes (24 bits) - MSB first
    // Byte 2 (bits 23-16)
    while ((SPI1->SR & SPI_SR_TXP) == 0);
    *(volatile uint32_t *)&SPI1->TXDR = tx_data;


    // 5. Wait for transfer completion
    while ((SPI1->SR & SPI_SR_EOT) == 0);

    // 6. Clear flags
    SPI1->IFCR = SPI_SR_EOT | SPI_SR_TXTF;

    // 7. Disable SPI peripheral
    //SPI5->CR1 &= ~SPI_CR1_SPE;
}


void write_to_dac(uint8_t dac_num, uint8_t channel, uint16_t voltage) {
    uint32_t tx_data_24bit;
    uint8_t tx_array[3];

    // Set the DAC low, ready for comm
    GPIOA->BSRR = (1 << (16 + (dac_num-1)));

    // Pack data into lower 24 bits of 32-bit integer
    // Bits 23-16: channel (only lower 4 bits used)
    // Bits 15-8:  voltage high byte
    // Bits 7-0:   voltage low byte
    tx_data_24bit = ((uint32_t)(channel & 0x0F) << 16) |
                    ((uint32_t)(voltage >> 8) << 8) |
                    (voltage & 0xFF);

    tx_array[0] = channel & 0x0F;
    tx_array[1] = (voltage >> 8);
    tx_array[2] = (voltage & 0xFF);

    // Ensure only 24 bits are used
    tx_data_24bit &= 0xFFFFFF;

    // Use the 24-bit DAC transmit function
    //transmit_dac_24bit(tx_data_24bit);

    for(uint8_t i = 0; i < 3; i++){
    	transmit_spi(tx_array[i]);
    }

    // Set DAC high, end communication
    GPIOA->BSRR = (1 << (dac_num-1));
}


void write_all_dacs() {
    //uint8_t tx_array[3];
    uint32_t tx_data_24bit;


    for (uint8_t dac_num = 1; dac_num <= 3; dac_num++) {




        for (uint8_t ch = 8; ch < 16; ch++) {
            GPIOA->BSRR = (1 << (16 + (dac_num - 1))); // CS lo

            uint8_t channel_index = (dac_num - 1) * 8 + (ch - 8);

            //tx_array[0] = (ch) & 0x0F;
            //tx_array[1] = (channels[channel_index].currentVoltage >> 8) & 0xFF;
            //tx_array[2] = channels[channel_index].currentVoltage & 0xFF;

            //for(uint8_t i = 0; i < 3; i++){
            //	transmit_spi(tx_array[i]);
           // }
            // Pack data into 24 bits
            //tx_data_24bit = ((uint32_t)(ch & 0x0F) << 16) |
               //             ((uint32_t)(channels[channel_index].currentVoltage >> 8) << 8) |
                     //       (channels[channel_index].currentVoltage & 0xFF);
            tx_data_24bit = ((uint32_t)(ch & 0x0F) << 16) | channels[channel_index].currentVoltage;

            // Send all 24 bits in one go!
            transmit_spi_24bit(tx_data_24bit);
            //HAL_SPI_Transmit(&hspi5, tx_array, 3, HAL_MAX_DELAY);


            GPIOA->BSRR = (1 << (dac_num - 1)); // CS high

        }




    }
}

void read_all_dacs() {
    uint8_t tx_buf[3];
    uint8_t rx_buf[3];

    for (uint8_t dac_num = 1; dac_num <= 3; dac_num++) {

        for (uint8_t ch = 8; ch < 16; ch++) {
            GPIOA->BSRR = (1 << (16 + (dac_num - 1))); // CS low

            uint8_t channel_index = (dac_num - 1) * 8 + (ch - 8);

            tx_buf[0] = 0x80 | (ch & 0x0F); // Read command
            tx_buf[1] = 0x00;
            tx_buf[2] = 0x00;

            HAL_SPI_TransmitReceive(&hspi5, tx_buf, rx_buf, 3, HAL_MAX_DELAY);

            uint16_t result = (rx_buf[1] << 8) | rx_buf[2];
            channels[channel_index].readVoltage = result;
            GPIOA->BSRR = (1 << (dac_num - 1)); // CS high

        }

    }
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
