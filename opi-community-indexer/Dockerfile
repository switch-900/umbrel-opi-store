# Build stage for Rust components
FROM rust:1.70-slim-bullseye as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    pkg-config \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Build ord
WORKDIR /build
COPY ord .
RUN cargo build --release

# Final stage
FROM node:20-bullseye-slim

# Install Python and other dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install python-dotenv psycopg2-binary json5 stdiomask requests

# Copy ord binary from builder
COPY --from=builder /build/target/release/ord /usr/local/bin/
RUN chmod +x /usr/local/bin/ord

# Set up app directory
WORKDIR /app
COPY modules ./modules

# Install node dependencies for each module
RUN cd modules/main_index && npm install \
    && cd ../brc20_api && npm install \
    && cd ../bitmap_api && npm install \
    && cd ../pow20_api && npm install \
    && cd ../sns_api && npm install \
    && cd ../runes_api && npm install

# Copy entrypoint script
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 3000-3004

ENTRYPOINT ["/app/docker-entrypoint.sh"]
