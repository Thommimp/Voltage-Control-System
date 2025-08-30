/*
 * functions.c
 *
 *  Created on: Jun 2, 2025
 *      Author: thomaspedersen
 */

#define EOT_FLAG (1u << 3)

#include "functions.h"



ChannelConfig channels[NUM_CHANNELS];


void set_dac_cs_pins_high() {
	GPIOA->BSRR = DAC_CS1_PIN_HIGH;
	GPIOA->BSRR = DAC_CS2_PIN_HIGH;
	GPIOA->BSRR = DAC_CS3_PIN_HIGH;

}

void transmit_dac_24bit(uint32_t dac_value) {
    // Extract 3 bytes from 24-bit value (assuming MSB first)
    uint8_t byte1 = (dac_value >> 16) & 0xFF;  // Most significant byte
    uint8_t byte2 = (dac_value >> 8) & 0xFF;   // Middle byte
    uint8_t byte3 = dac_value & 0xFF;          // Least significant byte

    // 1. Set transfer size to 3 frames (3 bytes)
    SPI5->CR2 = (SPI5->CR2 & ~0xFFFFU) | 3;

    // 2. Enable SPI peripheral
    SPI5->CR1 |= SPI_CR1_SPE;

    // 3. Start transfer
    SPI5->CR1 |= SPI_CR1_CSTART;

    // 4. Send first byte
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte1;

    // 5. Send second byte
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte2;

    // 6. Send third byte
    while ((SPI5->SR & SPI_SR_TXP) == 0);
    *(volatile uint8_t *)&SPI5->TXDR = byte3;

    // 7. Wait for all data to be transferred
    while ((SPI5->SR & SPI_SR_EOT) == 0);

    	// 8. Close transfer
    	SPI5->IFCR = SPI_SR_EOT;

         // Clear TXTF flag (like __HAL_SPI_CLEAR_TXTFFLAG)
      SPI5->IFCR = SPI_SR_TXTF;

      // Disable SPI peripheral (like __HAL_SPI_DISABLE)
      SPI5->CR1 &= ~SPI_CR1_SPE;
}






// Option 2: Low-level register access (properly fixed version)
void transmit_spi_register(uint8_t tx_data)
{
    // Pull CS low
//GPIOA->BSRR = (1 << (0 + 16)); // Pull CS low

    // CRITICAL: Clear EOT flag BEFORE starting new transfer
    if (SPI5->SR & SPI_SR_EOT) {
        SPI5->IFCR |= SPI_IFCR_EOTC;
    }

    // Ensure SPI is enabled
    if (!(SPI5->CR1 & SPI_CR1_SPE)) {
        SPI5->CR1 |= SPI_CR1_SPE;
    }

    // For newer STM32 SPI, set transfer size to 1 byte
    // IMPORTANT: Must be done while SPI is enabled but before CSTART
    SPI5->CR2 &= ~(0xFFFF << 0); // Clear TSIZE[15:0]
    SPI5->CR2 |= (1 << 0);       // Set TSIZE to 1

    // Start the transfer
    SPI5->CR1 |= SPI_CR1_CSTART;

    // Wait for TXP (Tx FIFO has space)
    while (!(SPI5->SR & SPI_SR_TXP));

    // Write data to TXDR
    *(volatile uint8_t*)&SPI5->TXDR = tx_data;

    // Wait for EOT (End of Transfer)
    while (!(SPI5->SR & SPI_SR_EOT));

    // Clear EOT flag immediately after detection
    SPI5->IFCR |= SPI_IFCR_EOTC;

    // Pull CS high
    //GPIOA->BSRR = (1 << 0);
}












void write_all_dacs3() {
    for (uint8_t ch = 0; ch < NUM_CHANNELS; ch++) {
        uint8_t dac_num = (ch / 8) + 1;

        GPIOA->BSRR = (1 << (16 + (dac_num - 1))); // CS low

        uint32_t data = 0;
        data |= (ch & 0x0F) << 16;                           // 4 bits for channel
        data |= (channels[ch].currentVoltage & 0xFFFF);     // 16-bit voltage



        HAL_SPI_Transmit(&hspi5, (uint8_t*)&data, 1, HAL_MAX_DELAY); // send one 24-bit word

        GPIOA->BSRR = (1 << (dac_num - 1)); // CS high
    }
}




void fillTestValues() {
    for (int i = 0; i < NUM_CHANNELS; i++) {
        channels[i].startVoltage = 1000 + i*20;
        channels[i].endVoltage = 2500;
        channels[i].steps = 100;
        channels[i].currentstep = 0;
        channels[i].step_value = 15;
        channels[i].currentVoltage = 2000 + i * 15;
        channels[i].holdEndValue = 1;
        channels[i].direction = 1;
    }
}
