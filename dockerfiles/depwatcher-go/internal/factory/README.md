# Factory Package Tests

This package has two types of tests:

## Unit Tests (Default)

Fast tests using mocked HTTP clients. Run by default with:

```bash
go test ./internal/factory/...
```

- **Speed**: ~0.004s
- **Dependencies**: None (fully mocked)
- **Purpose**: Test error handling, routing logic, parameter validation

## Integration Tests

Slower tests that make real HTTP requests to external services. Run with:

```bash
# Set GitHub token for GitHub API tests
export GITHUB_TOKEN="your_github_token_here"

# Run integration tests
go test -tags=integration ./internal/factory/...
```

- **Speed**: ~5-10s
- **Dependencies**: 
  - Network access
  - External APIs (php.net, python.org, npm, GitHub, etc.)
  - **GitHub Token**: Required for GitHub API tests (set `GITHUB_TOKEN`)
- **Purpose**: Verify the system works end-to-end with real data

### GitHub Token Requirement

Integration tests for GitHub (github_releases, github_tags) require authentication to:
- Avoid rate limiting (60 requests/hour unauthenticated vs 5000/hour authenticated)
- Test authenticated API access (production use case)
- Ensure reliable test execution

**Without a token**, GitHub tests will be skipped automatically.

**To create a GitHub token:**
1. Go to https://github.com/settings/tokens
2. Generate a new token (classic)
3. Select scopes: `public_repo` (read access to public repositories)
4. Export it: `export GITHUB_TOKEN="ghp_your_token_here"`

## Running Both

To run all tests (unit + integration):

```bash
# Unit tests (no token needed)
go test ./internal/factory/...

# Integration tests (with GitHub token)
export GITHUB_TOKEN="your_github_token"
go test -tags=integration ./internal/factory/...
```

## CI/CD Recommendations

- **PR checks**: Run unit tests only (fast feedback, no credentials needed)
- **Nightly builds**: Run integration tests with GitHub token (catch API changes)
- **Pre-release**: Run both with full credentials
