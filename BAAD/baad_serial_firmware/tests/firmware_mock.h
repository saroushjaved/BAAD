#ifndef FIRMWARE_MOCK_H
#define FIRMWARE_MOCK_H
#include <stdint.h>
#include <stddef.h>
typedef uintptr_t UINTPTR;
typedef intptr_t INTPTR;
typedef uint64_t XTime;
#define COUNTS_PER_SECOND 1000000ull
#define XPAR_UART0_BASEADDR 0xff000000u
#define XPAR_DDS_AXI_CONFIG_REGS_0_BASEADDR 0xa0010000u
#define XPAR_DMA_FRAME_BASEADDR 0xa0000000u
#define XUARTPS_FIFO_OFFSET 0x30u
#define XAXIDMA_RX_OFFSET 0x30u
#define XAXIDMA_CR_OFFSET 0u
#define XAXIDMA_SR_OFFSET 4u
#define XAXIDMA_DESTADDR_OFFSET 0x18u
#define XAXIDMA_DESTADDR_MSB_OFFSET 0x1cu
#define XAXIDMA_BUFFLEN_OFFSET 0x28u
#define XAXIDMA_CR_RESET_MASK 4u
#define XAXIDMA_CR_RUNSTOP_MASK 1u
#define XAXIDMA_IRQ_IOC_MASK 0x1000u
#define XAXIDMA_IRQ_ALL_MASK 0x7000u
#define XAXIDMA_ERR_ALL_MASK 0x770u
void XTime_GetTime(XTime *value);
uint32_t Xil_In32(UINTPTR address);
void Xil_Out32(UINTPTR address,uint32_t value);
void Xil_DCacheFlushRange(INTPTR address,uint32_t length);
void Xil_DCacheInvalidateRange(INTPTR address,uint32_t length);
int XUartPs_IsTransmitFull(UINTPTR address);
int XUartPs_IsReceiveData(UINTPTR address);
#endif
