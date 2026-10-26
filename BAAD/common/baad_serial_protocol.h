#ifndef BAAD_SERIAL_PROTOCOL_H
#define BAAD_SERIAL_PROTOCOL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BAAD_SERIAL_MAGIC             0xBAADu
#define BAAD_SERIAL_VERSION           0x02u
#define BAAD_BUILD_ID                 0x26091301u
#define BAAD_BURST_MAX_SAMPLES        8192u
#define BAAD_BURST_CHUNK_BYTES        480u
#define BAAD_DDS_BUILD_ID             0x0cu
#define BAAD_BURST_CONTROL            0x48u
#define BAAD_BURST_SAMPLE_COUNT       0x4cu
#define BAAD_BURST_STATUS             0x50u
#define BAAD_RECORDS_EMITTED          0x54u
#define BAAD_RECORDS_DROPPED          0x58u
#define BAAD_BURST_CAPTURE_ID         0x5cu
#define BAAD_SERIAL_MAX_PAYLOAD       512u
#define BAAD_SERIAL_HEADER_BYTES      8u
#define BAAD_SERIAL_CRC_BYTES         2u

#define BAAD_SYSTEM_SAMPLE_RATE_HZ    62000000u
#define BAAD_SYSTEM_IF_HZ             10000000
#define BAAD_DDS_PHASE_BITS           26u
#define BAAD_DDS_COUNT                6u
#define BAAD_FFT_SIZE                 2048u

#define BAAD_DDS_CONTROL              0x00u
#define BAAD_DDS_STATUS               0x04u
#define BAAD_DDS_INFO                 0x08u
#define BAAD_DDS_PINC0                0x10u
#define BAAD_DDS_THRESHOLD_LO         0x30u
#define BAAD_DDS_THRESHOLD_HI         0x34u
#define BAAD_DDS_DMA_CONTROL          0x38u
#define BAAD_DDS_DMA_RECORD_COUNT     0x3cu
#define BAAD_DDS_DMA_CIC_INTERVAL     0x40u
#define BAAD_DDS_DMA_PSD_INPUT_INTERVAL 0x44u
#define BAAD_DDS_APPLY_ALL            (1u << 8)
#define BAAD_DDS_PENDING_ANY          (1u << 16)

#define BAAD_CAPTURE_FLAG_SUMMARY     0x01u
#define BAAD_CAPTURE_FLAG_CIC         0x02u
#define BAAD_CAPTURE_FLAG_PSD_INPUT   0x04u

typedef enum BaadPacketType {
    BAAD_PKT_HELLO          = 0x01,
    BAAD_PKT_SET_DDS_CONFIG = 0x02,
    BAAD_PKT_START_STREAM   = 0x03,
    BAAD_PKT_STOP_STREAM    = 0x04,
    BAAD_PKT_GET_STATUS     = 0x05,
    BAAD_PKT_CAPTURE_BURST  = 0x06,
    BAAD_PKT_READ_CAPTURE   = 0x07,
    BAAD_PKT_ABORT_CAPTURE  = 0x08,

    BAAD_PKT_ACK            = 0x80,
    BAAD_PKT_NACK           = 0x81,
    BAAD_PKT_STATUS         = 0x82,
    BAAD_PKT_DMA_RECORD     = 0x83,
    BAAD_PKT_HELLO_INFO     = 0x84,
    BAAD_PKT_CAPTURE_READY  = 0x85,
    BAAD_PKT_CAPTURE_DATA   = 0x86
} BaadPacketType;

typedef enum BaadAckCode {
    BAAD_ACK_OK             = 0x00,
    BAAD_ACK_BAD_LENGTH     = 0x01,
    BAAD_ACK_BAD_CRC        = 0x02,
    BAAD_ACK_BAD_ARGUMENT   = 0x03,
    BAAD_ACK_DDS_TIMEOUT    = 0x04,
    BAAD_ACK_DMA_ERROR      = 0x05,
    BAAD_ACK_UNKNOWN_TYPE   = 0x06,
    BAAD_ACK_BUSY           = 0x07,
    BAAD_ACK_TIMEOUT        = 0x08,
    BAAD_ACK_INCOMPATIBLE   = 0x09
} BaadAckCode;

#pragma pack(push, 1)

typedef struct BaadSetDdsPayload {
    uint32_t sample_rate_hz;
    int32_t  if_hz;
    uint32_t bandwidth_hz;
    uint32_t pinc[BAAD_DDS_COUNT];
    int32_t  tone_hz[BAAD_DDS_COUNT];
} BaadSetDdsPayload;

typedef struct BaadStartStreamPayload {
    uint32_t power_threshold_lo;
    uint8_t  power_threshold_hi;
    uint8_t  capture_flags;
    uint16_t packet_record_count;
    uint16_t cic_sample_interval;
    uint16_t psd_input_sample_interval;
    uint16_t interval_ms;
} BaadStartStreamPayload;

typedef struct BaadAckPayload {
    uint8_t  request_type;
    uint8_t  code;
    uint16_t reserved;
    uint32_t detail;
} BaadAckPayload;

typedef struct BaadStatusPayload {
    uint32_t dds_status;
    uint32_t dma_status;
    uint32_t records_sent;
    uint32_t packets_received;
    uint32_t protocol_errors;
    uint8_t  streaming;
    uint8_t  reserved[3];
    uint64_t uptime_us;
    uint32_t packets_sent;
    uint32_t records_emitted;
    uint32_t records_dropped;
    uint32_t dma_errors;
    uint32_t dma_timeouts;
    uint32_t dma_resets;
    uint32_t last_error;
    uint32_t capture_status;
} BaadStatusPayload;

typedef struct BaadHelloPayload {
    uint32_t hardware_id, firmware_id, sample_rate_hz;
    uint16_t fft_size, max_samples;
    uint32_t capabilities;
} BaadHelloPayload;
typedef struct BaadBurstRequest { uint16_t sample_count; uint8_t source; uint8_t reserved; } BaadBurstRequest;
typedef struct BaadReadCapture { uint32_t capture_id, offset; uint16_t length, reserved; } BaadReadCapture;
typedef struct BaadCaptureReady { uint32_t capture_id, total_bytes, crc32, flags; } BaadCaptureReady;
typedef struct BaadCaptureChunk { uint32_t capture_id, offset; uint16_t length, reserved; uint8_t data[BAAD_BURST_CHUNK_BYTES]; } BaadCaptureChunk;

#pragma pack(pop)

static inline uint32_t baad_crc32(const uint8_t *data, uint32_t length)
{
    uint32_t crc=0xffffffffu;
    for(uint32_t i=0;i<length;++i) {
        crc ^= data[i];
        for(uint32_t b=0;b<8;++b) crc=(crc>>1) ^ (0xedb88320u & (0u-(crc&1u)));
    }
    return ~crc;
}

static inline uint16_t baad_crc16_ccitt_update(uint16_t crc, const uint8_t *data, uint32_t length)
{
    for (uint32_t i = 0; i < length; ++i) {
        crc ^= (uint16_t)data[i] << 8;
        for (uint32_t bit = 0; bit < 8; ++bit) {
            if ((crc & 0x8000u) != 0u) {
                crc = (uint16_t)((crc << 1) ^ 0x1021u);
            } else {
                crc = (uint16_t)(crc << 1);
            }
        }
    }

    return crc;
}

static inline uint16_t baad_crc16_ccitt(const uint8_t *data, uint32_t length)
{
    return baad_crc16_ccitt_update(0xffffu, data, length);
}

#ifdef __cplusplus
}
#endif

#endif
