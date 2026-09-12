#include <stdint.h>
#include <stddef.h>

// ONNX Runtime stub
void* OrtGetApiBase(void) {
    return NULL;
}

// Opus stubs
int opus_encoder_get_size(int channels) { return 1024; }
int opus_encoder_init(void *st, int32_t Fs, int channels, int application) { return 0; }
void* opus_encoder_create(int32_t Fs, int channels, int application, int *error) {
    if (error) *error = 0;
    static uint8_t dummy_enc[1024];
    return dummy_enc;
}
int opus_encode(void *st, const int16_t *pcm, int frame_size, unsigned char *data, int32_t max_data_bytes) { return 0; }
int opus_encode_float(void *st, const float *pcm, int frame_size, unsigned char *data, int32_t max_data_bytes) { return 0; }
void opus_encoder_destroy(void *st) {}
int opus_encoder_ctl(void *st, int request, ...) { return 0; }

int opus_decoder_get_size(int channels) { return 1024; }
int opus_decoder_init(void *st, int32_t Fs, int channels) { return 0; }
void* opus_decoder_create(int32_t Fs, int channels, int *error) {
    if (error) *error = 0;
    static uint8_t dummy_dec[1024];
    return dummy_dec;
}
int opus_decode(void *st, const unsigned char *data, int32_t len, int16_t *pcm, int frame_size, int decode_fec) { return 0; }
int opus_decode_float(void *st, const unsigned char *data, int32_t len, float *pcm, int frame_size, int decode_fec) { return 0; }
void opus_decoder_destroy(void *st) {}
int opus_decoder_ctl(void *st, int request, ...) { return 0; }

int opus_packet_get_nb_samples(const unsigned char packet[], int32_t len, int32_t Fs) { return 320; }
int opus_packet_get_nb_frames(const unsigned char packet[], int32_t len) { return 1; }
int opus_packet_get_samples_per_frame(const unsigned char *data, int32_t Fs) { return 320; }
int opus_packet_parse(const unsigned char *data, int32_t len, unsigned char *out_toc, const unsigned char *frames[48], int16_t size[48], int *payload_offset) { return 1; }
const char *opus_strerror(int error) { return "Opus stub"; }
const char *opus_get_version_string(void) { return "libopus-stub"; }

int opus_repacketizer_get_size(void) { return 1024; }
void* opus_repacketizer_create(void) {
    static uint8_t dummy_rep[1024];
    return dummy_rep;
}
void opus_repacketizer_destroy(void *rp) {}
int opus_repacketizer_get_nb_frames(void *rp) { return 1; }

