/* Deterministic register/UART/time mocks; no BSP and no board access. */
#define BAAD_HOST_TEST
#include "../src/firmware.c"
#include <stdio.h>
#include <stdlib.h>

static uint32_t regs[64],dma_regs[32];
static uint64_t mock_us;
static int mock_reset_stuck,mock_tx_stuck,mock_dds_stuck;
static uint8_t tx[131072],rx[131072];
static size_t tx_n,rx_n,rx_pos;
static unsigned flushes,invalidates,assertions;
#define CHECK(x) do {++assertions;if(!(x)) {fprintf(stderr,"FAIL %s:%d: %s\n",__FILE__,__LINE__,#x);exit(1);}} while(0)

void XTime_GetTime(XTime *value) {*value=mock_us++;}
uint32_t Xil_In32(UINTPTR a) {
    if(a==UART_BASE+XUARTPS_FIFO_OFFSET) {CHECK(rx_pos<rx_n);return rx[rx_pos++];}
    if(a>=DDS_BASE && a<DDS_BASE+sizeof(regs)) return regs[(a-DDS_BASE)/4];
    if(a>=DMA_BASE+XAXIDMA_RX_OFFSET && a<DMA_BASE+XAXIDMA_RX_OFFSET+sizeof(dma_regs)) {
        size_t i=(a-DMA_BASE-XAXIDMA_RX_OFFSET)/4;
        if(i==0 && !mock_reset_stuck) dma_regs[0]&=~XAXIDMA_CR_RESET_MASK;
        return dma_regs[i];
    }
    CHECK(0);return 0;
}
void Xil_Out32(UINTPTR a,uint32_t v) {
    if(a==UART_BASE+XUARTPS_FIFO_OFFSET) {CHECK(tx_n<sizeof(tx));tx[tx_n++]=(uint8_t)v;return;}
    if(a>=DDS_BASE && a<DDS_BASE+sizeof(regs)) {
        regs[(a-DDS_BASE)/4]=v;
        if(a==DDS_BASE+BAAD_DDS_CONTROL && mock_dds_stuck) regs[BAAD_DDS_STATUS/4]=BAAD_DDS_PENDING_ANY;
        return;
    }
    if(a>=DMA_BASE+XAXIDMA_RX_OFFSET && a<DMA_BASE+XAXIDMA_RX_OFFSET+sizeof(dma_regs)) {
        size_t i=(a-DMA_BASE-XAXIDMA_RX_OFFSET)/4;
        if(i==XAXIDMA_SR_OFFSET/4) dma_regs[i]&=~v; else dma_regs[i]=v;
        return;
    }
    CHECK(0);
}
void Xil_DCacheFlushRange(INTPTR a,uint32_t n) {CHECK(a==(INTPTR)dma_buffer);CHECK(n==DMA_BUFFER_BYTES);++flushes;}
void Xil_DCacheInvalidateRange(INTPTR a,uint32_t n) {CHECK(a==(INTPTR)dma_buffer);CHECK(n==DMA_BUFFER_BYTES);++invalidates;}
int XUartPs_IsTransmitFull(UINTPTR a) {(void)a;return mock_tx_stuck;}
int XUartPs_IsReceiveData(UINTPTR a) {(void)a;return rx_pos<rx_n;}

static void reset_state(void) {
    memset(regs,0,sizeof(regs));memset(dma_regs,0,sizeof(dma_regs));memset(dma_buffer,0,sizeof(dma_buffer));
    mock_us=0;mock_reset_stuck=mock_tx_stuck=mock_dds_stuck=0;tx_n=rx_n=rx_pos=0;flushes=invalidates=0;
    rx_count=packets_received=protocol_errors=records_sent=packets_sent=0;
    dma_errors=dma_timeouts=dma_resets=last_error=0;tx_sequence=0;
    rx_last_us=next_stream_us=dma_deadline_us=0;
    dma_active=streaming=burst_active=capture_ready=dma_fatal=identity_ok=false;
    stream_packet_record_count=3;stream_interval_ms=200;stream_failures=transfer_bytes=0;
    memset(&completed,0,sizeof(completed));regs[BAAD_DDS_BUILD_ID/4]=BAAD_BUILD_ID;
}
static size_t packet(uint8_t *out,uint8_t type,const void *p,uint16_t n) {
    put_le16(out,BAAD_SERIAL_MAGIC);out[2]=BAAD_SERIAL_VERSION;out[3]=type;
    put_le16(out+4,7);put_le16(out+6,n);if(n)memcpy(out+8,p,n);
    put_le16(out+8+n,baad_crc16_ccitt(out+2,n+6));return n+10u;
}
static void enqueue(uint8_t type,const void *p,uint16_t n) {rx_n+=packet(rx+rx_n,type,p,n);}
static void request(uint8_t type,const void *p,uint16_t n) {tx_n=0;enqueue(type,p,n);service_uart();}
static void check_tx(void) {
    size_t off=0;
    while(off<tx_n) {
        CHECK(off+10<=tx_n);CHECK(get_le16(tx+off)==BAAD_SERIAL_MAGIC);CHECK(tx[off+2]==2);
        uint16_t n=get_le16(tx+off+6);CHECK(off+n+10<=tx_n);
        CHECK(get_le16(tx+off+8+n)==baad_crc16_ccitt(tx+off+2,n+6));off+=n+10;
    }
}
static void ack(uint8_t code) {check_tx();CHECK(tx_n>=18);CHECK(tx[3]==(code?BAAD_PKT_NACK:BAAD_PKT_ACK));CHECK(tx[9]==code);}
static BaadStartStreamPayload stream_cfg(void) {BaadStartStreamPayload c={5000,0,1,3,1,1,200};return c;}
static void hello(void) {request(BAAD_PKT_HELLO,NULL,0);check_tx();CHECK(tx[3]==BAAD_PKT_HELLO_INFO);CHECK(identity_ok);}
static void start_stream(void) {hello();BaadStartStreamPayload c=stream_cfg();request(3,&c,sizeof(c));ack(0);arm_stream_if_needed();CHECK(dma_active);}
static void complete_summary(void) {
    for(unsigned i=0;i<stream_packet_record_count;i++) dma_buffer[12*i]=0xbaad0101000c0000ull;
    dma_regs[XAXIDMA_BUFFLEN_OFFSET/4]=transfer_bytes;dma_regs[XAXIDMA_SR_OFFSET/4]=XAXIDMA_IRQ_IOC_MASK;
    tx_n=0;service_dma();check_tx();
}
static void fill_burst(unsigned n,uint16_t flags) {
    memset(dma_buffer,0,sizeof(dma_buffer));
    dma_buffer[0]=0xbaad020400000000ull|((uint64_t)(n+10)<<16)|flags;
    dma_buffer[1]=(41ull<<32)|n;dma_buffer[2]=123;dma_buffer[3]=123+n-1;
    dma_buffer[4]=((uint64_t)62000000<<32)|(1u<<16);
    dma_buffer[6]=0x0000000100000008ull;
    for(unsigned i=0;i<n;i++)dma_buffer[8+i]=((uint64_t)i<<32)|((uint64_t)(uint16_t)(-i)<<16)|i;
    dma_buffer[n+8]=0x454e442100000000ull|((uint64_t)n<<16)|flags;
    dma_buffer[n+9]=0x4352433200000000ull|baad_crc32((uint8_t*)dma_buffer,(n+9)*8);
    dma_regs[XAXIDMA_BUFFLEN_OFFSET/4]=(n+10)*8;dma_regs[XAXIDMA_SR_OFFSET/4]=XAXIDMA_IRQ_IOC_MASK;
}
static void begin_burst(unsigned n) {hello();BaadBurstRequest b={(uint16_t)n,0,0};request(6,&b,sizeof(b));ack(0);CHECK(dma_active&&burst_active);}

static void test_identity_parser(void) {
    reset_state();BaadStartStreamPayload c=stream_cfg();request(3,&c,sizeof(c));ack(BAAD_ACK_INCOMPATIBLE);
    regs[BAAD_DDS_BUILD_ID/4]=0;request(1,NULL,0);CHECK(!identity_ok);regs[BAAD_DDS_BUILD_ID/4]=BAAD_BUILD_ID;hello();
    uint8_t p[32];size_t n=packet(p,5,NULL,0);tx_n=0;
    for(size_t i=0;i<n;i++) {rx[rx_n++]=p[i];service_uart();CHECK(packets_received==(i==n-1?4u:3u));}
    check_tx();CHECK(tx[3]==BAAD_PKT_STATUS);
    tx_n=0;n=packet(rx+rx_n,5,NULL,0);rx[rx_n+n-1]^=1;rx_n+=n;enqueue(5,NULL,0);service_uart();
    CHECK(protocol_errors==1);CHECK(packets_received==5);check_tx();
    rx[rx_n++]=0xad;rx[rx_n++]=0xba;service_uart();mock_us+=500001;service_uart();CHECK(rx_count==0);CHECK(protocol_errors==2);
    tx_n=0;for(unsigned i=0;i<100;i++)enqueue(5,NULL,0);service_uart();CHECK(packets_received==105);check_tx();
    puts("PASS identity, fragmented/coalesced packets, CRC recovery and partial timeout");
}
static void test_stream_dma(void) {
    reset_state();start_stream();CHECK(flushes==1);CHECK(transfer_bytes==288);CHECK(regs[BAAD_DDS_DMA_CONTROL/4]==3);
    dma_regs[1]=2;service_dma();CHECK(dma_active);CHECK(records_sent==0); /* Idle is not IOC. */
    complete_summary();CHECK(!dma_active);CHECK(records_sent==3);CHECK(tx[3]==BAAD_PKT_DMA_RECORD);CHECK(invalidates==1);
    uint64_t next=next_stream_us;mock_us=next-1;arm_stream_if_needed();CHECK(!dma_active);
    mock_us=next;arm_stream_if_needed();CHECK(dma_active);complete_summary();CHECK(records_sent==6);
    request(4,NULL,0);ack(0);CHECK(!streaming&&!dma_active);CHECK(regs[BAAD_DDS_DMA_CONTROL/4]==0);
    puts("PASS summary record counting, IOC-only completion, real-time cadence and stop");
}
static void test_dma_faults(void) {
    reset_state();start_stream();dma_regs[1]=0x10;service_dma();CHECK(dma_errors==1&&dma_resets==1&&streaming&&!dma_active);
    mock_us=next_stream_us;arm_stream_if_needed();CHECK(dma_active);dma_regs[1]=0x20;service_dma();CHECK(dma_errors==2&&!streaming);
    reset_state();start_stream();tx_n=0;mock_us=dma_deadline_us;service_dma();CHECK(dma_timeouts==1&&dma_errors==1);ack(BAAD_ACK_TIMEOUT);
    reset_state();start_stream();dma_regs[1]=XAXIDMA_IRQ_IOC_MASK;dma_regs[XAXIDMA_BUFFLEN_OFFSET/4]=transfer_bytes-8;service_dma();CHECK(last_error==0x20000004u);CHECK(!dma_active);
    reset_state();start_stream();dma_regs[1]=XAXIDMA_IRQ_IOC_MASK;service_dma();CHECK(last_error==0x20000006u);
    reset_state();start_stream();mock_reset_stuck=1;request(4,NULL,0);ack(BAAD_ACK_DMA_ERROR);CHECK(dma_fatal);CHECK(mock_us>=10000&&mock_us<11000);CHECK(!dma_start_capture(96,false));
    puts("PASS DMA error/retry budget, watchdog, wrong length/header and bounded stuck reset");
}
static void test_bursts(void) {
    for(unsigned n=256;n<=8192;n*=32) {
        reset_state();begin_burst(n);fill_burst(n,1);tx_n=0;service_dma();check_tx();CHECK(capture_ready&&!dma_active);CHECK(tx[3]==0x85);
        CHECK(completed.capture_id==41&&completed.total_bytes==(n+10)*8&&completed.flags==1);
        uint8_t saved[BAAD_BURST_CHUNK_BYTES];BaadReadCapture r={41,0,480,0};request(7,&r,sizeof(r));check_tx();CHECK(tx[3]==0x86);CHECK(get_le16(tx+6)==492);
        memcpy(saved,tx+20,480);CHECK(!memcmp(saved,dma_buffer,480));request(7,&r,sizeof(r));CHECK(!memcmp(saved,tx+20,480));
        r.offset=completed.total_bytes-8;r.length=8;request(7,&r,sizeof(r));check_tx();CHECK(tx[3]==0x86);
        r.offset=0xffffffffu;request(7,&r,sizeof(r));ack(3);r.offset=0;r.capture_id=40;request(7,&r,sizeof(r));ack(3);
        BaadBurstRequest b={256,1,0};request(6,&b,sizeof(b));ack(7);
        request(5,NULL,0);check_tx();CHECK(tx[sizeof(BaadStatusPayload)+13]==0x85);
        request(8,NULL,0);ack(0);CHECK(!capture_ready&&!burst_active&&!dma_active);
        request(6,&b,sizeof(b));ack(0);CHECK(burst_active);request(8,NULL,0);ack(0);CHECK(!dma_active);
    }
    reset_state();begin_burst(256);fill_burst(256,0);dma_buffer[20]^=1;service_dma();CHECK(last_error==0x20000005u&&!capture_ready&&!streaming);
    reset_state();begin_burst(256);fill_burst(256,0);dma_buffer[264]^=1;dma_buffer[265]=0x4352433200000000ull|baad_crc32((uint8_t*)dma_buffer,265*8);service_dma();CHECK(last_error==0x20000005u);
    reset_state();begin_burst(256);mock_us=dma_deadline_us;service_dma();CHECK(dma_timeouts==1&&!streaming&&!dma_active);
    puts("PASS min/max bursts, flags, CRC and trailer checks, idempotent chunks, invalid ranges, ready retry, abort/restart");
}
static void test_bounds_uart(void) {
    reset_state();hello();BaadStartStreamPayload c=stream_cfg();c.interval_ms=49;request(3,&c,sizeof(c));ack(3);c=stream_cfg();c.capture_flags=3;request(3,&c,sizeof(c));ack(3);
    BaadSetDdsPayload d={0};d.sample_rate_hz=62000000;d.if_hz=10000000;d.bandwidth_hz=20000001;request(2,&d,sizeof(d));ack(3);
    d.bandwidth_hz=20000000;d.pinc[5]=1u<<26;request(2,&d,sizeof(d));ack(3);d.pinc[5]=0;request(2,&d,sizeof(d));ack(0);
    regs[BAAD_DDS_STATUS/4]=BAAD_DDS_PENDING_ANY;request(2,&d,sizeof(d));ack(7);
    regs[BAAD_DDS_STATUS/4]=0;mock_dds_stuck=1;request(2,&d,sizeof(d));ack(4);
    reset_state();mock_tx_stuck=1;uint64_t start=mock_us;send_status();CHECK(last_error==0x10000001u);CHECK(mock_us-start<5100);CHECK(packets_sent==0&&tx_n==0);
    CHECK(baad_crc32((const uint8_t*)"123456789",9)==0xcbf43926u);CHECK(baad_crc16_ccitt((const uint8_t*)"123456789",9)==0x29b1u);
    puts("PASS command bounds, DDS timeout, bounded UART failure and standard CRC vectors");
}
int main(void) {test_identity_parser();test_stream_dma();test_dma_faults();test_bursts();test_bounds_uart();printf("PASS all firmware host tests (%u checks)\n",assertions);return 0;}
