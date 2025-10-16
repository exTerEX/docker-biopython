# BUILD ARGUMENTS

# PYTHON_VERSION: Used to select the base Docker image (e.g., 3.11, 3.12)
ARG PYTHON_VERSION=3.11

# BASE BUILDER STAGE
FROM python:${PYTHON_VERSION}-slim AS base-builder

# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND=noninteractive

# INSTALL SYSTEM DEPENDENCIES
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    gcc \
    # Necessary tools for compiling Python packages with C extensions
    build-essential \
    pkg-config \
    libpq-dev \
    libpython3-dev \
    default-libmysqlclient-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Update pip
RUN pip install --upgrade pip

# SLIM BUILDER STAGE
FROM base-builder AS slim-builder

# Get Biopython version from argument
ARG BIOPYTHON_VERSION

# Install BioPython
RUN echo "--- Installing Biopython v${BIOPYTHON_VERSION} ---" \
    && pip install --no-cache-dir "biopython==${BIOPYTHON_VERSION}"

# FULL BUILDER STAGE
FROM slim-builder AS full-builder

# Get Biopython version from argument
ARG BIOPYTHON_VERSION

# INSTALL THE SPECIFIED BIOPYTHON VERSION ALONG WITH ADDITIONAL DEPENDENCIES
RUN echo "--- Installing Biopython v${BIOPYTHON_VERSION} optional dependencies ---" \
    && pip install --no-cache-dir \
    reportlab \
    matplotlib \
    networkx[default] \
    rdflib \
    mysql-connector-python \
    psycopg2 \
    mysqlclient

# FULL IMAGE STAGE
FROM python:${PYTHON_VERSION}-slim AS full

# SET ENVIRONMENT VARIABLES
ARG PYTHON_VERSION=${PYTHON_VERSION}

# Update pip
RUN pip install --upgrade pip

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libpq5 \
    libmariadb3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the installed Python packages from the builder stage's site-packages directory
COPY --from=full-builder /usr/local/lib/python${PYTHON_VERSION}/site-packages /usr/local/lib/python${PYTHON_VERSION}/site-packages
COPY --from=full-builder /usr/local/bin /usr/local/bin

# SETUP AND VERIFICATION COMMAND
WORKDIR /app

# SLIM IMAGE STAGE
FROM python:${PYTHON_VERSION}-slim

ARG PYTHON_VERSION=$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

# Update pip
RUN pip install --upgrade pip

# Copy the installed Python packages from the builder stage's site-packages directory
COPY --from=slim-builder /usr/local/lib/python${PYTHON_VERSION}/site-packages /usr/local/lib/python${PYTHON_VERSION}/site-packages
COPY --from=slim-builder /usr/local/bin /usr/local/bin

# SETUP AND VERIFICATION COMMAND
WORKDIR /app
