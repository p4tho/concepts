#include <cstdint>

constexpr std::size_t MAX_CANDIDATE_LEN = 32;
constexpr std::size_t MD5_CHUNK_SIZE = 64;

struct Candidate {
    uint32_t length;
    char text[MD5_CHUNK_SIZE];
};

std::optional<std::string> processBatch(const std::vector<Candidate>& batch, const std::string& targetHash);
__global__ void processBatchKernel(const Candidate* d_candidates, int count, const uint32_t* d_targetHash, unsigned int* d_found, Candidate* d_match);