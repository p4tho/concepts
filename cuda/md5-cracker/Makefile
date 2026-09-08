# Compiler
NVCC = nvcc

# Target executable name
TARGET = main

# Source files
SRC = main.cu hash.cu

all: $(TARGET)

$(TARGET): $(SRC)
	$(NVCC) $(CFLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)