#include <cuda_runtime.h>
#include <cstdint>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>
#include "hash.cuh"

__device__ __constant__ uint32_t MD5_K[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

__device__ __constant__ uint32_t MD5_S[64] = {
     7,12,17,22,  7,12,17,22,  7,12,17,22,  7,12,17,22,
     5, 9,14,20,  5, 9,14,20,  5, 9,14,20,  5, 9,14,20,
     4,11,16,23,  4,11,16,23,  4,11,16,23,  4,11,16,23,
     6,10,15,21,  6,10,15,21,  6,10,15,21,  6,10,15,21
};

__device__ __forceinline__
uint32_t rotateLeft(
    uint32_t value,
    uint32_t amount
) {
    return (value << amount) | (value >> (32 - amount));
}

__device__ __forceinline__
uint32_t load32LE(const char* p) {
    const auto* bytes =
        reinterpret_cast<const unsigned char*>(p);

    return static_cast<uint32_t>(bytes[0]) |
           (static_cast<uint32_t>(bytes[1]) << 8) |
           (static_cast<uint32_t>(bytes[2]) << 16) |
           (static_cast<uint32_t>(bytes[3]) << 24);
}

static uint32_t parseHexByte(
    const std::string& hash,
    std::size_t offset
) {
    return static_cast<uint32_t>(
        std::stoul(hash.substr(offset, 2), nullptr, 16)
    );
}

static void parseTargetHash(
    const std::string& hash,
    uint32_t output[4]
) {
    if (hash.size() != 32) {
        throw std::invalid_argument(
            "MD5 hash must contain exactly 32 hex characters"
        );
    }

    for (int i = 0; i < 4; ++i) {
        std::size_t offset =
            static_cast<std::size_t>(i) * 8;

        uint32_t byte0 = parseHexByte(hash, offset + 0);
        uint32_t byte1 = parseHexByte(hash, offset + 2);
        uint32_t byte2 = parseHexByte(hash, offset + 4);
        uint32_t byte3 = parseHexByte(hash, offset + 6);

        output[i] =
            byte0 |
            (byte1 << 8) |
            (byte2 << 16) |
            (byte3 << 24);
    }
}

std::optional<std::string> processBatch(const std::vector<Candidate>& batch, const std::string& targetHashHex) {
    if (batch.empty()) return std::nullopt;;

    uint32_t h_targetHash[4];
    try {
        parseTargetHash(
            targetHashHex,
            h_targetHash
        );
    } catch (const std::exception& error) {
        std::cerr
            << "[!] Invalid target hash: "
            << error.what()
            << '\n';

        return std::nullopt;
    }

    Candidate* d_candidates = nullptr;
    uint32_t* d_targetHash = nullptr;
    unsigned int* d_found = nullptr;
    Candidate* d_match = nullptr;

    unsigned int h_found = false;
    Candidate h_match{};

    size_t batchBytes = batch.size() * sizeof(Candidate);

    cudaMalloc(&d_candidates, batchBytes);
    cudaMalloc(&d_targetHash, 4 * sizeof(uint32_t));
    cudaMalloc(&d_found, sizeof(unsigned int));
    cudaMalloc(&d_match, sizeof(Candidate));

    cudaMemcpy(d_candidates, batch.data(), batchBytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_targetHash, h_targetHash, 4 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(d_found, &h_found, sizeof(unsigned int), cudaMemcpyHostToDevice);

    int threadsPerBlock = 256;
    int blocksPerGrid = (batch.size() + threadsPerBlock - 1) / threadsPerBlock;

    processBatchKernel<<<blocksPerGrid, threadsPerBlock>>>(d_candidates, batch.size(), d_targetHash, d_found, d_match);

    cudaError_t error = cudaGetLastError();

    if (error == cudaSuccess) {
        error = cudaDeviceSynchronize();
    }

    if (error != cudaSuccess) {
        std::cerr
            << "[!] Kernel launch failed: "
            << cudaGetErrorString(error)
            << '\n';

        cudaFree(d_candidates);
        cudaFree(d_targetHash);
        cudaFree(d_found);

        return std::nullopt;
    }

    cudaMemcpy(&h_found, d_found, sizeof(unsigned int), cudaMemcpyDeviceToHost);

    std::optional<std::string> result;
    if (h_found == true) {
        cudaMemcpy(
            &h_match,
            d_match,
            sizeof(Candidate),
            cudaMemcpyDeviceToHost
        );

        result = std::string(h_match.text);
    }

    cudaFree(d_candidates);
    cudaFree(d_targetHash);
    cudaFree(d_found);
    cudaFree(d_match);

    return result;
}

__global__ void processBatchKernel(const Candidate* d_candidates, int count, const uint32_t* d_targetHash, unsigned int* d_found, Candidate* d_match) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx >= count) return;

    Candidate candidate = d_candidates[idx];

    uint32_t M[16];

    for (int i = 0; i < 16; ++i) {
        M[i] = load32LE(candidate.text + i * 4);
    }

    // Set up initial state
    uint32_t a = 0x67452301;
    uint32_t b = 0xefcdab89;
    uint32_t c = 0x98badcfe;
    uint32_t d = 0x10325476;

    for (uint32_t i = 0; i < 64; ++i) {
        uint32_t f;
        uint32_t g;

        if (i < 16) {
            f = (b & c) | (~b & d);
            g = i;
        } else if (i < 32) {
            f = (d & b) | (~d & c);
            g = (5 * i + 1) % 16;
        } else if (i < 48) {
            f = b ^ c ^ d;
            g = (3 * i + 5) % 16;
        } else {
            f = c ^ (b | ~d);
            g = (7 * i) % 16;
        }

        uint32_t oldD = d;

        d = c;
        c = b;

        uint32_t value =
            a + f + MD5_K[i] + M[g];

        b = b + rotateLeft(value, MD5_S[i]);
        a = oldD;
    }

    uint32_t digest[4] = {
        a + 0x67452301,
        b + 0xefcdab89,
        c + 0x98badcfe,
        d + 0x10325476
    };

    bool match =
        digest[0] == d_targetHash[0] &&
        digest[1] == d_targetHash[1] &&
        digest[2] == d_targetHash[2] &&
        digest[3] == d_targetHash[3];

    if (match && atomicCAS(d_found, 0u, 1u) == 0u) {
        *d_match = candidate;
    }
}