#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include "baad_serial_protocol.h"
#ifdef BAAD_HOST_TEST
#include "firmware_mock.h"
#else
#include "xaxidma_hw.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xparameters.h"
#include "xuartps_hw.h"
#ifdef SDT
#include "xiltimer.h"
#else
#include "xtime_l.h"
#endif
#endif

#define UART_BASE XPAR_UART0_BASEADDR
#define DDS_BASE XPAR_DDS_AXI_CONFIG_REGS_0_BASEADDR
#define DMA_BASE XPAR_DMA_FRAME_BASEADDR
#define DMA_MAX_WORDS (BAAD_BURST_MAX_SAMPLES + 10u)
#define DMA_MAX_BYTES (DMA_MAX_WORDS * 8u)
#define DMA_BUFFER_BYTES ((DMA_MAX_BYTES + 63u) & ~63u)
#define RX_BUFFER_BYTES (BAAD_SERIAL_HEADER_BYTES + BAAD_SERIAL_MAX_PAYLOAD + BAAD_SERIAL_CRC_BYTES)
#define STREAM_MAX_PACKET_RECORDS 4u
#define STREAM_MIN_INTERVAL_MS 50u

static uint8_t rx_buffer[RX_BUFFER_BYTES];
static uint32_t rx_count,packets_received,protocol_errors,records_sent,packets_sent;
static uint32_t dma_errors,dma_timeouts,dma_resets,last_error;
static uint16_t tx_sequence;
static uint64_t rx_last_us,next_stream_us,dma_deadline_us;
static uint64_t dma_buffer[DMA_BUFFER_BYTES/8] __attribute__((aligned(64)));
static bool dma_active,streaming,burst_active,capture_ready,dma_fatal,identity_ok;
static uint16_t stream_packet_record_count=3,stream_interval_ms=200;
static unsigned stream_failures;
static uint32_t transfer_bytes;
static BaadCaptureReady completed;

static uint64_t now_us(void) {
    XTime t; XTime_GetTime(&t);
    return (t/COUNTS_PER_SECOND)*1000000u + ((t%COUNTS_PER_SECOND)*1000000u)/COUNTS_PER_SECOND;
}
static uint32_t dds_read(uint32_t off) { return Xil_In32(DDS_BASE+off); }
static void dds_write(uint32_t off,uint32_t v) { Xil_Out32(DDS_BASE+off,v); }
static uint32_t dma_rx_read(uint32_t off) { return Xil_In32(DMA_BASE+XAXIDMA_RX_OFFSET+off); }
static void dma_rx_write(uint32_t off,uint32_t v) { Xil_Out32(DMA_BASE+XAXIDMA_RX_OFFSET+off,v); }
static uint32_t dma_status(void) { return dma_rx_read(XAXIDMA_SR_OFFSET); }
static void put_le16(uint8_t *p,uint16_t v) {p[0]=v;p[1]=v>>8;}
static uint16_t get_le16(const uint8_t *p) {return (uint16_t)p[0]|((uint16_t)p[1]<<8);}

static bool uart_put_u8(uint8_t value) {
    uint64_t deadline=now_us()+5000;
    while(XUartPs_IsTransmitFull(UART_BASE)) {
        if(now_us()>=deadline) {last_error=0x10000001u;return false;}
    }
    Xil_Out32(UART_BASE+XUARTPS_FIFO_OFFSET,value);
    return true;
}
static bool uart_get_u8(uint8_t *value) {
    if(!XUartPs_IsReceiveData(UART_BASE)) return false;
    *value=Xil_In32(UART_BASE+XUARTPS_FIFO_OFFSET)&255u;return true;
}
static bool uart_write(const uint8_t *p,uint32_t n) {
    for(uint32_t i=0;i<n;i++) if(!uart_put_u8(p[i])) return false;
    return true;
}
static void send_packet(uint8_t type,const uint8_t *payload,uint16_t length) {
    uint8_t h[8],tail[2];
    put_le16(h,BAAD_SERIAL_MAGIC);h[2]=BAAD_SERIAL_VERSION;h[3]=type;
    put_le16(h+4,tx_sequence++);put_le16(h+6,length);
    uint16_t crc=baad_crc16_ccitt(h+2,6);
    crc=baad_crc16_ccitt_update(crc,payload,length);put_le16(tail,crc);
    /* A stuck UART aborts this packet once, rather than delaying every byte. */
    if(uart_write(h,8) && uart_write(payload,length) && uart_write(tail,2)) ++packets_sent;
}
static void send_ack(uint8_t type,uint8_t code,uint32_t detail) {
    BaadAckPayload a={type,code,0,detail};
    send_packet(code==BAAD_ACK_OK?BAAD_PKT_ACK:BAAD_PKT_NACK,(const uint8_t*)&a,sizeof(a));
}
static void send_status(void) {
    BaadStatusPayload s={0};
    s.dds_status=dds_read(BAAD_DDS_STATUS);s.dma_status=dma_status();
    s.records_sent=records_sent;s.packets_received=packets_received;s.protocol_errors=protocol_errors;
    s.streaming=streaming;s.uptime_us=now_us();s.packets_sent=packets_sent;
    s.records_emitted=dds_read(BAAD_RECORDS_EMITTED);s.records_dropped=dds_read(BAAD_RECORDS_DROPPED);
    s.dma_errors=dma_errors;s.dma_timeouts=dma_timeouts;s.dma_resets=dma_resets;s.last_error=last_error;
    s.capture_status=dds_read(BAAD_BURST_STATUS)|(capture_ready?1u:0u)|(dma_fatal?2u:0u);
    send_packet(BAAD_PKT_STATUS,(const uint8_t*)&s,sizeof(s));
}
static void flush_capture(void) {
    dds_write(BAAD_DDS_DMA_CONTROL,16u);
    uint64_t end=now_us()+10;while(now_us()<end) {}
    dds_write(BAAD_DDS_DMA_CONTROL,0u);
}
static bool dma_reset(void) {
    ++dma_resets;
    dma_rx_write(XAXIDMA_CR_OFFSET,XAXIDMA_CR_RESET_MASK);
    uint64_t end=now_us()+10000;
    while(dma_rx_read(XAXIDMA_CR_OFFSET)&XAXIDMA_CR_RESET_MASK) {
        if(now_us()>=end) {dma_fatal=true;last_error=0x20000001u;dma_active=false;return false;}
    }
    dma_active=false;return true;
}
static bool stop_capture(void) {
    dds_write(BAAD_DDS_DMA_CONTROL,0);dds_write(BAAD_BURST_CONTROL,2);
    bool ok=!dma_active || dma_reset();
    flush_capture();dds_write(BAAD_BURST_CONTROL,0);
    burst_active=false;capture_ready=false;
    return ok&&!dma_fatal;
}
static bool dma_start_capture(uint32_t bytes,bool burst) {
    UINTPTR addr=(UINTPTR)dma_buffer;
    if(dma_fatal || bytes>DMA_MAX_BYTES) return false;
#ifndef BAAD_HOST_TEST
    if((addr>>32)!=0 || (addr&63u)!=0) {last_error=0x20000002u;dma_fatal=true;return false;}
#endif
    flush_capture();
    Xil_DCacheFlushRange((INTPTR)dma_buffer,DMA_BUFFER_BYTES);
    dma_rx_write(XAXIDMA_SR_OFFSET,XAXIDMA_IRQ_ALL_MASK|XAXIDMA_ERR_ALL_MASK);
    dma_rx_write(XAXIDMA_DESTADDR_OFFSET,(uint32_t)addr);
    dma_rx_write(XAXIDMA_DESTADDR_MSB_OFFSET,0);
    dma_rx_write(XAXIDMA_CR_OFFSET,XAXIDMA_CR_RUNSTOP_MASK);
    dma_rx_write(XAXIDMA_BUFFLEN_OFFSET,bytes);
    transfer_bytes=bytes;burst_active=burst;dma_active=true;
    dma_deadline_us=now_us()+(burst?150000u:100000u);return true;
}
static uint32_t dma_record_payload_bytes(uint16_t expected) {
    uint32_t words=0;
    for(uint16_t i=0;i<expected;i++) {
        uint64_t h=dma_buffer[words];
        if((h>>32)!=0xbaad0101u || ((h>>16)&65535u)!=12u) return 0;
        words+=12;
    }
    return words*8;
}
static void fail_dma(uint32_t detail,bool timeout) {
    bool was_burst=burst_active;
    ++dma_errors;if(timeout) ++dma_timeouts;last_error=detail;
    stop_capture();
    if(was_burst || dma_fatal || ++stream_failures>=2) streaming=false;
    next_stream_us=now_us()+stream_interval_ms*1000u;
    send_ack(was_burst?BAAD_PKT_CAPTURE_BURST:BAAD_PKT_START_STREAM,
             timeout?BAAD_ACK_TIMEOUT:BAAD_ACK_DMA_ERROR,detail);
    send_status();
}
static void service_dma(void) {
    if(!dma_active) return;
    uint32_t sr=dma_status();
    if(sr&XAXIDMA_ERR_ALL_MASK) {fail_dma(sr,false);return;}
    if(!(sr&XAXIDMA_IRQ_IOC_MASK)) {
        if(now_us()>=dma_deadline_us) fail_dma(0x20000003u,true);
        return;
    }
    uint32_t received=dma_rx_read(XAXIDMA_BUFFLEN_OFFSET);
    Xil_DCacheInvalidateRange((INTPTR)dma_buffer,DMA_BUFFER_BYTES);
    if(received!=transfer_bytes) {fail_dma(0x20000004u,false);return;}
    dds_write(BAAD_DDS_DMA_CONTROL,0);
    if(burst_active) {
        uint64_t h=dma_buffer[0],tail=dma_buffer[transfer_bytes/8-1];
        uint32_t check=baad_crc32((const uint8_t*)dma_buffer,transfer_bytes-8);
        uint32_t count=(uint32_t)dma_buffer[1];
        uint64_t end=dma_buffer[transfer_bytes/8-2];
        if((h>>32)!=0xbaad0204u || ((h>>16)&65535u)*8!=transfer_bytes ||
           count<256 || count>BAAD_BURST_MAX_SAMPLES || (count+10u)*8u!=transfer_bytes ||
           (end>>32)!=0x454e4421u || ((end>>16)&65535u)!=count ||
           (end&65535u)!=(h&65535u) ||
           (tail>>32)!=0x43524332u || (uint32_t)tail!=check) {fail_dma(0x20000005u,false);return;}
        completed.capture_id=(uint32_t)(dma_buffer[1]>>32);
        completed.total_bytes=transfer_bytes;
        completed.crc32=baad_crc32((const uint8_t*)dma_buffer,transfer_bytes);
        completed.flags=(uint32_t)h&65535u;
        capture_ready=true;burst_active=false;dma_active=false;
        send_packet(BAAD_PKT_CAPTURE_READY,(const uint8_t*)&completed,sizeof(completed));
    } else {
        uint32_t bytes=dma_record_payload_bytes(stream_packet_record_count);
        if(bytes!=transfer_bytes || bytes>512) {fail_dma(0x20000006u,false);return;}
        dma_active=false;stream_failures=0;
        send_packet(BAAD_PKT_DMA_RECORD,(const uint8_t*)dma_buffer,(uint16_t)bytes);
        records_sent+=stream_packet_record_count;
    }
    dma_rx_write(XAXIDMA_SR_OFFSET,XAXIDMA_IRQ_ALL_MASK|XAXIDMA_ERR_ALL_MASK);
}
static void arm_stream_if_needed(void) {
    if(!streaming || dma_active || capture_ready || burst_active || now_us()<next_stream_us) return;
    if(!dma_start_capture(stream_packet_record_count*96u,false)) {streaming=false;send_status();return;}
    next_stream_us=now_us()+(uint64_t)stream_interval_ms*1000u;
    dds_write(BAAD_DDS_DMA_CONTROL,3u);
}
static void handle_set_dds(const uint8_t *p,uint16_t len) {
    BaadSetDdsPayload c;
    if(len!=sizeof(c)) {send_ack(2,BAAD_ACK_BAD_LENGTH,len);return;}
    memcpy(&c,p,len);
    if(c.sample_rate_hz!=BAAD_SYSTEM_SAMPLE_RATE_HZ || c.if_hz!=BAAD_SYSTEM_IF_HZ ||
       c.bandwidth_hz<1000 || c.bandwidth_hz>20000000u) {send_ack(2,BAAD_ACK_BAD_ARGUMENT,0);return;}
    if(burst_active || capture_ready) {send_ack(2,BAAD_ACK_BUSY,0);return;}
    for(unsigned i=0;i<6;i++) {
        if(c.tone_hz[i]<-31000000 || c.tone_hz[i]>31000000 || c.pinc[i]>=(1u<<26)) {
            send_ack(2,BAAD_ACK_BAD_ARGUMENT,i);return;
        }
    }
    /* Do not rewrite a DDS configuration still waiting on AXI-stream ready. */
    if(dds_read(BAAD_DDS_STATUS)&BAAD_DDS_PENDING_ANY) {
        send_ack(2,BAAD_ACK_BUSY,BAAD_DDS_PENDING_ANY);return;
    }
    if(!stop_capture()) {send_ack(2,BAAD_ACK_DMA_ERROR,last_error);return;}
    for(unsigned i=0;i<6;i++) dds_write(BAAD_DDS_PINC0+4*i,c.pinc[i]);
    dds_write(BAAD_DDS_CONTROL,BAAD_DDS_APPLY_ALL);
    uint64_t end=now_us()+10000;
    while(dds_read(BAAD_DDS_STATUS)&BAAD_DDS_PENDING_ANY) {
        if(now_us()>=end) {streaming=false;send_ack(2,BAAD_ACK_DDS_TIMEOUT,0);return;}
    }
    next_stream_us=now_us();send_ack(2,BAAD_ACK_OK,0);
}
static void handle_start_stream(const uint8_t *p,uint16_t len) {
    BaadStartStreamPayload c;
    if(len!=sizeof(c)) {send_ack(3,BAAD_ACK_BAD_LENGTH,len);return;}
    memcpy(&c,p,len);
    if(c.capture_flags!=BAAD_CAPTURE_FLAG_SUMMARY || c.power_threshold_hi>1 ||
       c.packet_record_count<1 || c.packet_record_count>4 || c.interval_ms<50 || c.interval_ms>60000) {
        send_ack(3,BAAD_ACK_BAD_ARGUMENT,0);return;
    }
    if(burst_active || capture_ready) {send_ack(3,BAAD_ACK_BUSY,0);return;}
    if(!stop_capture()) {send_ack(3,BAAD_ACK_DMA_ERROR,last_error);return;}
    dds_write(BAAD_DDS_THRESHOLD_LO,c.power_threshold_lo);
    dds_write(BAAD_DDS_THRESHOLD_HI,c.power_threshold_hi);
    dds_write(BAAD_DDS_DMA_RECORD_COUNT,c.packet_record_count);
    stream_packet_record_count=c.packet_record_count;stream_interval_ms=c.interval_ms;
    next_stream_us=now_us();stream_failures=0;streaming=true;send_ack(3,BAAD_ACK_OK,0);
}
static void handle_burst(const uint8_t *p,uint16_t len) {
    BaadBurstRequest c;
    if(len!=sizeof(c)) {send_ack(6,BAAD_ACK_BAD_LENGTH,len);return;}
    memcpy(&c,p,len);
    if(c.source>1 || c.reserved || c.sample_count<256 || c.sample_count>8192) {send_ack(6,BAAD_ACK_BAD_ARGUMENT,0);return;}
    if(burst_active || capture_ready) {send_ack(6,BAAD_ACK_BUSY,0);return;}
    if(!stop_capture() || !dma_start_capture((c.sample_count+10u)*8u,true)) {send_ack(6,BAAD_ACK_DMA_ERROR,last_error);return;}
    dds_write(BAAD_BURST_SAMPLE_COUNT,c.sample_count);
    dds_write(BAAD_BURST_CONTROL,1u|((uint32_t)c.source<<8));
    send_ack(6,BAAD_ACK_OK,dds_read(BAAD_BURST_CAPTURE_ID));
}
static void handle_read(const uint8_t *p,uint16_t len) {
    BaadReadCapture r;
    if(len!=sizeof(r)) {send_ack(7,BAAD_ACK_BAD_LENGTH,len);return;}
    memcpy(&r,p,len);
    if(!capture_ready || r.capture_id!=completed.capture_id || !r.length ||
       r.length>BAAD_BURST_CHUNK_BYTES || r.offset>completed.total_bytes ||
       r.length>completed.total_bytes-r.offset || r.reserved) {send_ack(7,BAAD_ACK_BAD_ARGUMENT,0);return;}
    BaadCaptureChunk chunk={0};
    chunk.capture_id=r.capture_id;chunk.offset=r.offset;chunk.length=r.length;
    memcpy(chunk.data,(const uint8_t*)dma_buffer+r.offset,r.length);
    send_packet(BAAD_PKT_CAPTURE_DATA,(const uint8_t*)&chunk,12+r.length);
}
static void handle_packet(uint8_t type,const uint8_t *payload,uint16_t length) {
    ++packets_received;
    if(type!=BAAD_PKT_HELLO && type!=BAAD_PKT_GET_STATUS && !identity_ok) {
        send_ack(type,BAAD_ACK_INCOMPATIBLE,dds_read(BAAD_DDS_BUILD_ID));return;
    }
    if((type==1 || type==4 || type==5 || type==8) && length) {send_ack(type,BAAD_ACK_BAD_LENGTH,length);return;}
    switch(type) {
    case BAAD_PKT_HELLO: {
        BaadHelloPayload h={dds_read(BAAD_DDS_BUILD_ID),BAAD_BUILD_ID,BAAD_SYSTEM_SAMPLE_RATE_HZ,BAAD_FFT_SIZE,8192,3};
        identity_ok=h.hardware_id==BAAD_BUILD_ID;
        send_packet(BAAD_PKT_HELLO_INFO,(const uint8_t*)&h,sizeof(h));send_status();break;
    }
    case BAAD_PKT_SET_DDS_CONFIG:handle_set_dds(payload,length);break;
    case BAAD_PKT_START_STREAM:handle_start_stream(payload,length);break;
    case BAAD_PKT_STOP_STREAM:
        streaming=false;
        if(stop_capture()) send_ack(type,BAAD_ACK_OK,0);else send_ack(type,BAAD_ACK_DMA_ERROR,last_error);
        send_status();break;
    case BAAD_PKT_GET_STATUS:
        send_status();
        if(capture_ready) send_packet(BAAD_PKT_CAPTURE_READY,(const uint8_t*)&completed,sizeof(completed));
        break;
    case BAAD_PKT_CAPTURE_BURST:handle_burst(payload,length);break;
    case BAAD_PKT_READ_CAPTURE:handle_read(payload,length);break;
    case BAAD_PKT_ABORT_CAPTURE:
        if(stop_capture()) send_ack(type,BAAD_ACK_OK,0);else send_ack(type,BAAD_ACK_DMA_ERROR,last_error);
        next_stream_us=now_us();break;
    default:send_ack(type,BAAD_ACK_UNKNOWN_TYPE,type);break;
    }
}
static bool try_parse_one_packet(void)
{
    while (rx_count >= BAAD_SERIAL_HEADER_BYTES) {
        if (get_le16(&rx_buffer[0]) == BAAD_SERIAL_MAGIC) {
            break;
        }
        memmove(&rx_buffer[0], &rx_buffer[1], rx_count - 1u);
        --rx_count;
    }

    if (rx_count < BAAD_SERIAL_HEADER_BYTES) {
        return false;
    }

    if (rx_buffer[2] != BAAD_SERIAL_VERSION) {
        memmove(&rx_buffer[0], &rx_buffer[1], rx_count - 1u);
        --rx_count;
        ++protocol_errors;
        return true;
    }

    uint16_t length = get_le16(&rx_buffer[6]);
    if (length > BAAD_SERIAL_MAX_PAYLOAD) {
        memmove(&rx_buffer[0], &rx_buffer[1], rx_count - 1u);
        --rx_count;
        ++protocol_errors;
        return true;
    }

    uint32_t total = BAAD_SERIAL_HEADER_BYTES + (uint32_t)length + BAAD_SERIAL_CRC_BYTES;
    if (rx_count < total) {
        return false;
    }

    uint16_t expected_crc = get_le16(&rx_buffer[BAAD_SERIAL_HEADER_BYTES + length]);
    uint16_t crc = baad_crc16_ccitt(&rx_buffer[2], BAAD_SERIAL_HEADER_BYTES - 2u);
    if (length != 0u) {
        crc = baad_crc16_ccitt_update(crc, &rx_buffer[BAAD_SERIAL_HEADER_BYTES], length);
    }

    if (crc != expected_crc) {
        uint8_t bad_type = rx_buffer[3];
        memmove(&rx_buffer[0], &rx_buffer[1], rx_count - 1u);
        --rx_count;
        ++protocol_errors;
        send_ack(bad_type, BAAD_ACK_BAD_CRC, crc);
        return true;
    }

    handle_packet(rx_buffer[3], &rx_buffer[BAAD_SERIAL_HEADER_BYTES], length);

    if (rx_count > total) {
        memmove(&rx_buffer[0], &rx_buffer[total], rx_count - total);
    }
    rx_count -= total;
    return true;
}

static void service_uart(void)
{
    uint8_t value;

    while (uart_get_u8(&value)) {
        rx_last_us = now_us();
        if (rx_count < RX_BUFFER_BYTES) {
            rx_buffer[rx_count++] = value;
            /* Consume complete commands as they arrive. Back-to-back legal
             * packets must not overflow the single-packet scratch buffer. */
            while (try_parse_one_packet()) {}
        } else {
            rx_count = 0u;
            ++protocol_errors;
        }
    }

    if (rx_count && now_us() - rx_last_us > 500000u) { rx_count=0; ++protocol_errors; }
    while (try_parse_one_packet()) {
    }
}

#ifndef BAAD_HOST_TEST
int main(void) {
    dds_write(BAAD_DDS_DMA_CONTROL,0);dds_write(BAAD_BURST_CONTROL,2);
    dma_reset();flush_capture();dds_write(BAAD_BURST_CONTROL,0);
    for(;;) {service_uart();service_dma();arm_stream_if_needed();}
}
#endif
