#!/bin/sh
set -x

echo "run_id: $RUN_ID in $ENVIRONMENT"
echo "profile: $PROFILE"

NOW=$(date +"%Y%m%d-%H%M%S")

if [ -z "${JM_HOME}" ]; then
  JM_HOME=/opt/perftest
fi

JM_SCENARIOS=${JM_HOME}/scenarios
JM_REPORTS=${JM_HOME}/reports
JM_LOGS=${JM_HOME}/logs

mkdir -p ${JM_REPORTS} ${JM_LOGS}

# Use PROFILE environment variable if set, otherwise fall back to TEST_SCENARIO or default to 'test'
# This allows selecting different JMeter scripts via the CDP Portal profile option
TEST_SCENARIO=${PROFILE:-${TEST_SCENARIO:-test}}
SCENARIOFILE=${JM_SCENARIOS}/${TEST_SCENARIO}.jmx
REPORTFILE=${NOW}-perftest-${TEST_SCENARIO}-report.csv
LOGFILE=${JM_LOGS}/perftest-${TEST_SCENARIO}.log

# Before running the suite, replace 'service-name' with the name/url of the service to test.
# ENVIRONMENT is set to the name of th environment the test is running in.
SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-trade-exports-packinglistparser.${ENVIRONMENT}.cdp-int.defra.cloud}
# PORT is used to set the port of this performance test container
SERVICE_PORT=${SERVICE_PORT:-443}
SERVICE_URL_SCHEME=${SERVICE_URL_SCHEME:-https}

# Log all configuration values
echo "=== Configuration ==="
echo "PACKING_LIST_BASE_URL: $packingListBaseUrl"
echo "DEFAULT_ESTABLISHMENT_ID: $defaultEstablishmentId"
echo "====================="

# Run the test suite
jmeter -n -t ${SCENARIOFILE} -e -l "${REPORTFILE}" -o ${JM_REPORTS} -j ${LOGFILE} -f \
-Jenv="${ENVIRONMENT}" \
-Jdomain="${SERVICE_ENDPOINT}" \
-Jport="${SERVICE_PORT}" \
-Jprotocol="${SERVICE_URL_SCHEME}" \
-JpackingListBaseUrl="${packingListBaseUrl}" \
-JdefaultEstablishmentId="${defaultEstablishmentId}"

# Publish the results into S3 so they can be displayed in the CDP Portal
if [ -n "$RESULTS_OUTPUT_S3_PATH" ]; then
  # Copy the CSV report file and the generated report files to the S3 bucket
   if [ -f "$JM_REPORTS/index.html" ]; then
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$REPORTFILE" "$RESULTS_OUTPUT_S3_PATH/$REPORTFILE"
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$JM_REPORTS" "$RESULTS_OUTPUT_S3_PATH" --recursive
      if [ $? -eq 0 ]; then
        echo "CSV report file and test results published to $RESULTS_OUTPUT_S3_PATH"
      fi
   else
      echo "$JM_REPORTS/index.html is not found"
      exit 1
   fi
else
   echo "RESULTS_OUTPUT_S3_PATH is not set"
   exit 1
fi

exit $test_exit_code
