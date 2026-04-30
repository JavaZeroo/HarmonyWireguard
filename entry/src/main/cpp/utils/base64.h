#ifndef BASE64_H
#define BASE64_H

#include <cstdint>
#include <cstddef>

// WireGuard 密钥 Base64 编解码
bool Base64Decode(const char* input, uint8_t* output, size_t* outputLen);
bool Base64Encode(const uint8_t* input, size_t inputLen, char* output, size_t outputLen);

#endif // BASE64_H
