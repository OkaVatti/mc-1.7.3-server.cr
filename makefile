.PHONY: build run clean test release install

# Build the server in development mode
build:
	crystal build src/main.cr -o bin/minecraft-server

# Build with optimizations for release
release:
	crystal build src/main.cr -o bin/minecraft-server --release --no-debug

# Run the server
run: build
	./bin/minecraft-server

# Run with custom environment
run-custom:
	HOST=0.0.0.0 PORT=25565 MAX_PLAYERS=20 ./bin/minecraft-server

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf .crystal/

# Run tests
test:
	crystal spec

# Install dependencies
install:
	shards install

# Format code
format:
	crystal tool format

# Lint code
lint:
	bin/ameba

# Build example plugins
build-plugins:
	crystal build examples/example_plugin.cr -o plugins/example_plugin.so --dynamic

# Create necessary directories
setup:
	mkdir -p bin
	mkdir -p plugins
	mkdir -p worlds
	mkdir -p logs

# Full setup and build
all: setup install build

# Development mode with auto-reload would require additional tools
dev: build
	while true; do \
		./bin/minecraft-server; \
		sleep 1; \
	done