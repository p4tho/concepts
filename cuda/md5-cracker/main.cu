#include <array>
#include <cstring>
#include <cuda_runtime.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <string>
#include <string_view>
#include <vector>
#include "hash.cuh"

constexpr std::size_t BATCH_SIZE = 10'000;

struct Arguments {
    std::string hash;
    std::string wordlist;
};

void addCandidate(std::vector<Candidate>& batch, const std::string& line) {
    Candidate candidate{};
    candidate.length = static_cast<uint32_t>(line.size());

    std::memcpy(candidate.text, line.data(), line.size());

    // Append 1 bit right after string (0x10000000)
    candidate.text[line.size()] = 0x80;

    // Zero-fill until text reaches 56 bytes (448 bits)
    std::memset(candidate.text + line.size() + 1, 0, 56 - (line.size() + 1));

    // Append original string length
    uint64_t bitLength = line.size() * 8;
    std::memcpy(candidate.text + 56, &bitLength, sizeof(uint64_t));

    batch.push_back(candidate);
}

bool endsWithTxt(std::string_view str) {
    return str.length() >= 4 && str.substr(str.length() - 4) == ".txt";
}

std::optional<Arguments> parseArguments(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "[!] Error: Missing required positional hash argument.\n";
        return std::nullopt;
    }

    std::string_view posArg = argv[1];
    if (posArg.rfind('-', 0) == 0) {
        std::cerr << "[!] Error: First argument must be a valid positional hash, not a flag.\n";
        return std::nullopt;
    }

    std::string hash(posArg);
    std::string wordlistFile;

    for (int i = 2; i < argc; ++i) {
        if (std::string_view(argv[i]) == "-w") {
            if (i + 1 < argc) {
                std::string_view nextArg = argv[i + 1];
                if (!endsWithTxt(nextArg)) {
                    std::cerr << "[!] Error: Argument following '-w' must be a .txt file.\n";
                    return std::nullopt;
                }
                wordlistFile = std::string(nextArg);
                break;
            } else {
                std::cerr << "[!] Error: '-w' flag requires a wordlist file argument.\n";
                return std::nullopt;
            }
        }
    }

    if (wordlistFile.empty()) {
        std::cerr << "[!] Error: Missing required '-w' argument followed by a .txt file.\n";
        return std::nullopt;
    }

    if (!std::filesystem::exists(wordlistFile) || !std::filesystem::is_regular_file(wordlistFile)) {
        std::cerr << "[!] Error: Wordlist file does not exist. " << wordlistFile << "\n";
        return std::nullopt;
    }

    return Arguments{hash, wordlistFile};
}

int main(int argc, char* argv[]) {
    auto args = parseArguments(argc, argv);
    if (!args) {
        return 1;
    }

    // Check if CUDA device exists
    int deviceCount = 0;
    cudaError_t error = cudaGetDeviceCount(&deviceCount);

    if (error != cudaSuccess) {
        std::cerr << "[!] CUDA Error: " << cudaGetErrorString(error) << std::endl;
        return 1;
    }

    if (deviceCount == 0) {
        std::cout << "[!] No CUDA-capable devices found." << std::endl;
        return 1;
    }

    for (int i = 0; i < deviceCount; ++i) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);

        std::cout << "[*] Found " << prop.name << "." << std::endl;
    }

    // Iterate through each word in wordlist
    std::ifstream wordlistFile(args->wordlist);

    if (!wordlistFile.is_open()) {
        std::cerr << "[!] Error: Could not open file " << args->wordlist << "." << std::endl;
        return 1;
    }

    std::string line;
    std::vector<Candidate> batch;
    int batchCount = 1;

    while (std::getline(wordlistFile, line)) {
        if (line.empty()) {
            continue;
        }

        if (line.length() > MAX_CANDIDATE_LEN) {
            std::cout << "[?] Warning: " << line << " exceeds 32 character limit." << std::endl;
            continue;
        }

        addCandidate(batch, line);

        if (batch.size() == BATCH_SIZE) {
            // Do MD5 hash on batch and check if any match
            auto match = processBatch(batch, args->hash);

            if (match) {
                std::cout
                    << "found match: "
                    << *match
                    << '\n';

                return 0;
            } else {
                std::cout << "[*] No match found from batch " << batchCount << "." << std::endl;
                batchCount += 1;
            }

            batch.clear();

            continue;
        }
    }

    if (!batch.empty()) {
        // Do MD5 hash on batch and check if any match
        auto match = processBatch(batch, args->hash);

        if (match) {
            std::cout
                << "found match: "
                << *match
                << '\n';

            return 0;
        } else {
            std::cout << "[*] No match found from batch " << batchCount << "." << std::endl;
        }
    }

    return 0;
}
