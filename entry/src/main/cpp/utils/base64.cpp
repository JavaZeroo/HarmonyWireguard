#include "base64.h"
#include <cstring>

static const char base64_chars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

bool Base64Decode(const char* input, uint8_t* output, size_t* outputLen) {
    if (!input || !output || !outputLen) return false;

    size_t inLen = strlen(input);
    if (inLen == 0 || inLen % 4 != 0) return false;

    size_t outLen = inLen / 4 * 3;
    if (input[inLen - 1] == '=') outLen--;
    if (input[inLen - 2] == '=') outLen--;

    if (*outputLen < outLen) return false;

    int val = 0, valb = -8;
    size_t j = 0;
    for (size_t i = 0; i < inLen; i++) {
        if (input[i] == '=') break;
        const char* p = strchr(base64_chars, input[i]);
        if (!p) return false;
        val = (val << 6) + (p - base64_chars);
        valb += 6;
        if (valb >= 0) {
            output[j++] = (uint8_t)((val >> valb) & 0xFF);
            valb -= 8;
        }
    }
    *outputLen = j;
    return true;
}

bool Base64Encode(const uint8_t* input, size_t inputLen, char* output, size_t outputLen) {
    if (!input || !output || outputLen == 0) return false;

    size_t needed = 4 * ((inputLen + 2) / 3) + 1;
    if (outputLen < needed) return false;

    size_t i = 0, j = 0;
    while (i < inputLen) {
        uint32_t a = i < inputLen ? input[i++] : 0;
        uint32_t b = i < inputLen ? input[i++] : 0;
        uint32_t c = i < inputLen ? input[i++] : 0;
        uint32_t triple = (a << 16) | (b << 8) | c;
        output[j++] = base64_chars[(triple >> 18) & 0x3F];
        output[j++] = base64_chars[(triple >> 12) & 0x3F];
        output[j++] = (i > inputLen + 1) ? '=' : base64_chars[(triple >> 6) & 0x3F];
        output[j++] = (i > inputLen) ? '=' : base64_chars[triple & 0x3F];
    }
    output[j] = '\0';
    return true;
}
