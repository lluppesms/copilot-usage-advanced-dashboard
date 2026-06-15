#!/bin/bash

# Validate prerequisites for running Copilot Usage Advanced Dashboard locally with Docker Compose.
# Run this script before 'docker-compose up' to catch configuration problems early.
#
# Usage: bash scripts/validate-local-setup.sh

set -e

echo ""
echo "=== Local Setup Validation ===" 
echo ""

ERRORS=0
WARNINGS=0

# -------------------------------------------------------------------------
# 1. Docker
# -------------------------------------------------------------------------
echo "Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "  ERROR: 'docker' is not installed or not on PATH."
    echo "  Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    ERRORS=$((ERRORS + 1))
else
    if ! docker info &> /dev/null; then
        echo "  ERROR: Docker daemon is not running. Start Docker Desktop and try again."
        ERRORS=$((ERRORS + 1))
    else
        DOCKER_VERSION=$(docker --version)
        echo "  OK: $DOCKER_VERSION"
    fi
fi

# -------------------------------------------------------------------------
# 2. Docker Compose
# -------------------------------------------------------------------------
echo "Checking Docker Compose..."
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    echo "  OK: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo "  OK (standalone): $COMPOSE_VERSION"
else
    echo "  ERROR: 'docker compose' is not available."
    echo "  Ensure Docker Desktop is up to date, or install the Compose plugin."
    ERRORS=$((ERRORS + 1))
fi

# -------------------------------------------------------------------------
# 3. .env file
# -------------------------------------------------------------------------
echo "Checking .env file..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$REPO_ROOT/.env" ]]; then
    echo "  ERROR: .env file not found at $REPO_ROOT/.env"
    echo "  Create it by running:"
    echo "    cp .env.template .env"
    echo "  Then edit .env and set GITHUB_PAT and ORGANIZATION_SLUGS."
    ERRORS=$((ERRORS + 1))
else
    echo "  OK: .env file exists."
    # Load .env for variable checks below
    set -o allexport
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
    set +o allexport
fi

# -------------------------------------------------------------------------
# 4. Required environment variables
# -------------------------------------------------------------------------
echo "Checking required environment variables..."

if [[ -z "${GITHUB_PAT}" ]] || [[ "${GITHUB_PAT}" == "ghp_your_token_here" ]]; then
    echo "  ERROR: GITHUB_PAT is not set or still contains the placeholder value."
    echo "  Create a Personal Access Token with the following scopes:"
    echo "    - manage_billing:copilot"
    echo "    - read:enterprise"
    echo "    - read:org"
    echo "  Token creation: https://github.com/settings/tokens"
    echo "  Then set GITHUB_PAT=ghp_<your-token> in .env"
    ERRORS=$((ERRORS + 1))
else
    # Mask token in output
    PAT_PREVIEW="${GITHUB_PAT:0:7}***"
    echo "  OK: GITHUB_PAT is set ($PAT_PREVIEW)."
fi

if [[ -z "${ORGANIZATION_SLUGS}" ]] || [[ "${ORGANIZATION_SLUGS}" == "your-org-name" ]]; then
    if [[ -z "${ENTERPRISE_SLUGS}" ]]; then
        echo "  ERROR: Neither ORGANIZATION_SLUGS nor ENTERPRISE_SLUGS is set."
        echo "  Set at least one of:"
        echo "    ORGANIZATION_SLUGS=my-github-org          (for org-level data)"
        echo "    ENTERPRISE_SLUGS=my-github-enterprise     (for enterprise-level data)"
        echo "    ORGANIZATION_SLUGS=standalone:my-slug     (for Copilot Standalone)"
        ERRORS=$((ERRORS + 1))
    else
        echo "  OK: ENTERPRISE_SLUGS is set (${ENTERPRISE_SLUGS})."
    fi
else
    echo "  OK: ORGANIZATION_SLUGS is set (${ORGANIZATION_SLUGS})."
fi

# -------------------------------------------------------------------------
# 5. Port availability
# -------------------------------------------------------------------------
echo "Checking port availability..."

check_port() {
    local port=$1
    local service=$2
    if command -v lsof &> /dev/null; then
        if lsof -iTCP:"$port" -sTCP:LISTEN &> /dev/null 2>&1; then
            echo "  WARNING: Port $port ($service) is already in use."
            echo "  Stop the conflicting process or edit docker-compose.yml to use a different host port."
            WARNINGS=$((WARNINGS + 1))
            return
        fi
    elif command -v ss &> /dev/null; then
        if ss -tlnp | grep -q ":$port "; then
            echo "  WARNING: Port $port ($service) is already in use."
            WARNINGS=$((WARNINGS + 1))
            return
        fi
    fi
    echo "  OK: Port $port ($service) is available."
}

check_port 8080 "Grafana"
check_port 9200 "Elasticsearch"

# -------------------------------------------------------------------------
# 6. Summary
# -------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo "All checks passed. You are ready to start the dashboard:"
    echo ""
    echo "  docker-compose up -d"
    echo ""
    echo "Then open http://localhost:8080 (admin / copilot)."
elif [[ $ERRORS -eq 0 ]]; then
    echo "Validation passed with $WARNINGS warning(s). Review the warnings above, then run:"
    echo ""
    echo "  docker-compose up -d"
    echo ""
else
    echo "Validation FAILED with $ERRORS error(s) and $WARNINGS warning(s)."
    echo "Fix the errors listed above before running docker-compose."
    echo ""
    exit 1
fi
