# trade-exports-plp-perf-tests

A JMeter based performance test runner for the Trade Exports Packing List Parser service on the CDP Platform.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Available Test Scenarios](#available-test-scenarios)
- [Build](#build)
- [Running Tests on CDP Portal](#running-tests-on-cdp-portal)
- [Running Tests Locally](#running-tests-locally)
- [Adding New Test Scenarios](#adding-new-test-scenarios)
- [Configuration Options](#configuration-options)
- [Test Data](#test-data)
- [Viewing Results](#viewing-results)
- [Troubleshooting](#troubleshooting)
- [Licence](#licence)

## Overview

This repository contains JMeter-based performance tests for the Trade Exports Packing List Parser service. The tests are designed to run on the CDP (Core Delivery Platform) but can also be executed locally using Docker Compose.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker** (version 20.10 or higher)
- **Docker Compose** (version 2.0 or higher)
- **Git** for version control
- **JMeter** (optional, for editing `.jmx` files locally)

## Repository Structure

```
trade-exports-plp-perf-tests/
├── compose.yml              # Docker Compose configuration for local testing
├── Dockerfile               # Container definition for the test runner
├── entrypoint.sh            # Script that orchestrates test execution
├── user.properties          # JMeter user properties file
├── compose/
│   ├── aws.env              # AWS environment variables for LocalStack
│   └── localstack/
│       ├── 05-setup.sh      # Creates S3 bucket, SQS queue, SNS topic
│       └── 99-ready.sh      # Signals LocalStack readiness
├── data/
│   └── applications.csv     # Test data for parameterized tests
└── scenarios/
    ├── test.jmx             # Basic health check test (default)
    ├── load.jmx             # Load testing scenario
    ├── ramp.jmx             # Ramp-up testing scenario
    └── soak.jmx             # Soak/endurance testing scenario
```

## Available Test Scenarios

| Scenario | File | Description | Use Case |
|----------|------|-------------|----------|
| **test** | `test.jmx` | Basic health endpoint check | Quick validation, smoke testing |
| **load** | `load.jmx` | Sustained load with constant throughput | Measure performance under expected load |
| **ramp** | `ramp.jmx` | Gradually increasing load | Find breaking points |
| **soak** | `soak.jmx` | Extended duration testing | Identify memory leaks, stability issues |

## Build

Test suites are built automatically by the [.github/workflows/publish.yml](.github/workflows/publish.yml) action whenever changes are committed to the `main` branch. A successful build results in a Docker container that is capable of running your tests on the CDP Platform and publishing the results to the CDP Portal.

## Running Tests on CDP Portal

The performance test suites are designed to be run from the CDP Portal. The CDP Platform runs test suites in much the same way it runs any other service—it takes a Docker image and runs it as an ECS task, automatically provisioning infrastructure as required.

### Basic Execution

1. Navigate to your test suite page on the CDP Portal
2. Click **Run**
3. Press **Start** to begin the default `test.jmx` scenario

### Using Profiles to Run Specific Scenarios

Profiles allow you to run different JMeter test scripts without changing the code:

1. Go to your test suite page
2. In the **Run** section, press **Yes** under **Profile**
3. Enter the scenario name (without `.jmx` extension):
   - `test` - Health check test (default)
   - `load` - Load testing
   - `ramp` - Ramp-up testing
   - `soak` - Soak testing
4. Press **Start**

If no profile is specified, the default `test.jmx` script will be run.

## Running Tests Locally

You can run the entire performance test stack locally using Docker Compose, including LocalStack, Redis, and the target service. This is useful for development, integration testing, or verifying your test scripts **before committing to `main`**.

### Option 1: Using Docker Compose (Recommended)

#### 1. Build the Docker image

```bash
docker compose build --no-cache development
```

This ensures any changes to `entrypoint.sh` or other scripts are picked up properly.

#### 2. Start the test stack

```bash
docker compose up --build
```

This brings up:

- `development`: the container that runs your performance tests
- `localstack`: simulates AWS S3, SNS, SQS, etc.
- `redis`: backing service for cache
- `service`: the application under test

Once all services are healthy, your performance tests will automatically start.

#### 3. Run a specific test scenario

To run a different test scenario, set the `PROFILE` environment variable:

```bash
PROFILE=load docker compose up --build
```

#### 4. View results

Test results are written to the `./reports` directory on your host machine.

### Option 2: Using LocalStack Only

If you want to run tests against an external service:

#### 1. Build the Docker image

```bash
docker build . -t my-performance-tests
```

#### 2. Start LocalStack

```bash
docker run -d --name localstack \
  -p 4566:4566 \
  -e SERVICES=s3 \
  localstack/localstack:4.3.0
```

#### 3. Create the S3 bucket

```bash
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-results
```

#### 4. Run the tests

```bash
docker run --rm \
  -e S3_ENDPOINT='http://host.docker.internal:4566' \
  -e RESULTS_OUTPUT_S3_PATH='s3://test-results' \
  -e AWS_ACCESS_KEY_ID='test' \
  -e AWS_SECRET_ACCESS_KEY='test' \
  -e AWS_REGION='eu-west-2' \
  -e SERVICE_ENDPOINT=your-service-url \
  -e SERVICE_PORT=443 \
  -e PROFILE=test \
  my-performance-tests
```

### Notes

- S3 bucket is expected to be `s3://test-results`, automatically created inside LocalStack.
- Logs and reports are written to `./reports` on your host.
- `entrypoint.sh` contains the logic to wait for dependencies and kick off the test run.
- The `depends_on` healthchecks ensure services like `localstack` and `service` are ready before tests start.

## Adding New Test Scenarios

### 1. Create a new JMeter test file

Create a new `.jmx` file in the `scenarios/` directory:

```bash
scenarios/my-new-test.jmx
```

### 2. Use JMeter variables for configuration

Your test should use the following JMeter properties for flexibility:

```
${__P(domain, default-domain)}    # Service domain
${__P(port, 443)}                 # Service port
${__P(protocol, https)}           # Protocol (http/https)
${__P(env)}                       # Environment name
```

### 3. Test locally

```bash
PROFILE=my-new-test docker compose up --build
```

### 4. Commit and push

Once verified locally, commit your changes:

```bash
git add scenarios/my-new-test.jmx
git commit -m "Add new performance test scenario"
git push origin main
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PROFILE` | JMeter scenario to run (without `.jmx`) | `test` |
| `SERVICE_ENDPOINT` | Service hostname/URL | `trade-exports-packinglistparser.{env}.cdp-int.defra.cloud` |
| `SERVICE_PORT` | Service port | `443` |
| `SERVICE_URL_SCHEME` | Protocol (`http` or `https`) | `https` |
| `ENVIRONMENT` | Deployment environment name | - |
| `S3_ENDPOINT` | S3 endpoint URL | `https://s3.eu-west-2.amazonaws.com` |
| `RESULTS_OUTPUT_S3_PATH` | S3 path for results | - |
| `packingListBaseUrl` | Base URL for packing list service | - |
| `defaultEstablishmentId` | Default establishment ID | - |

### JMeter Properties

Properties can be passed to JMeter via the command line using `-J` flags. The following are configured in `entrypoint.sh`:

- `env` - Environment name
- `domain` - Service domain
- `port` - Service port
- `protocol` - URL scheme
- `packingListBaseUrl` - Packing list base URL
- `defaultEstablishmentId` - Default establishment ID

## Test Data

Test data is stored in `data/applications.csv`. This file contains sample application IDs and filenames used for parameterized testing:

```csv
application_id,filename
1762431248564,ac1-notnirms-pass.xlsx
1762431248567,ac3-invalidnirms-fail.xlsx
...
```

### Adding Test Data

1. Edit `data/applications.csv`
2. Ensure the CSV format matches: `application_id,filename`
3. The first row is treated as a header and ignored

## Viewing Results

### Local Testing

Results are saved to:
- `./reports/` - HTML report and CSV data
- View `./reports/index.html` in a browser for detailed results

### CDP Portal

After a test run completes on CDP:
1. Navigate to your test suite
2. Click on the completed run
3. View the results dashboard and download reports

## Troubleshooting

### Tests fail to start locally

**Problem**: Services not healthy

**Solution**: Ensure all services have started correctly:
```bash
docker compose ps
```

Check logs for specific service:
```bash
docker compose logs service
```

### Results not uploading to S3

**Problem**: `RESULTS_OUTPUT_S3_PATH is not set`

**Solution**: Ensure the environment variable is set:
```bash
export RESULTS_OUTPUT_S3_PATH=s3://test-results
```

### LocalStack bucket not found

**Problem**: S3 bucket doesn't exist

**Solution**: The bucket should be created automatically by `compose/localstack/05-setup.sh`. If not:
```bash
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-results
```

### JMeter scenario file not found

**Problem**: `SCENARIOFILE not found`

**Solution**: Verify the profile name matches a file in `scenarios/`:
```bash
ls scenarios/
```

### Debug Mode

For more verbose output:
```bash
docker compose up --build 2>&1 | tee debug.log
```

## Licence

THIS INFORMATION IS LICENSED UNDER THE CONDITIONS OF THE OPEN GOVERNMENT LICENCE found at:

<http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3>

The following attribution statement MUST be cited in your products and applications when using this information.

> Contains public sector information licensed under the Open Government licence v3

### About the licence

The Open Government Licence (OGL) was developed by the Controller of Her Majesty's Stationery Office (HMSO) to enable information providers in the public sector to license the use and re-use of their information under a common open licence.

It is designed to encourage use and re-use of information freely and flexibly, with only a few conditions.
