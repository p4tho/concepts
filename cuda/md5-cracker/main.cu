#include <cuda_runtime.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <optional>

struct Arguments {
    std::string hash;
    std::string wordlist;
};

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

    return 0;
}