#!/bin/bash

copy_params() {
    source="${1}"
    destination="${2}"
    profile="${3}"

    eval "arr=( $(aws ssm get-parameters-by-path --path "/version/${source}/" | jq -r '@sh "\(.Parameters[].Name)"' ) )"

    for key in "${arr[@]}"
    do
        noquotes=$(echo "${key}" | sed 's/"//g')
        repo=$(echo "${noquotes}" | sed 's|.*/||')
        val=$(aws ssm get-parameter --name "${key}" | jq ".Parameter.Value")
        valnoquotes=$(echo "${val}" | sed 's/"//g')
        aws ssm put-parameter --name "/version/${destination}/${repo}" --type "String" --value "${valnoquotes}" --overwrite
    done
}

AWS_ACCESS_KEY_ID="${INPUT_AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${INPUT_AWS_SECRET_ACCESS_KEY}"
AWS_REGION="${INPUT_AWS_REGION}"
PROGRAM_NAME="${INPUT_PROGRAM_NAME}"
NEW_TAG="${INPUT_NEW_TAG}"
TEST_DIR="${INPUT_TEST_DIR}"
TEST_NAME="${INPUT_TEST_NAME}"

# Update unit-test version in parameter store
aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
aws configure set region "${AWS_REGION}"
copy_params staging unit-test ssm-param

if [ -n "${PROGRAM_NAME}" ]; then
    aws ssm put-parameter --name "/version/unit-test/${PROGRAM_NAME}" --type "String" --value "${NEW_TAG}" --overwrite 
fi

# Run tests
pushd "${GITHUB_WORKSPACE}"/"${TEST_DIR}"
go test -count=1 -v -timeout 30m "${TEST_NAME}"
gotest_result=$?
popd
[ "${gotest_result}" -eq 0 ] || exit 1

# Update staging version in parameter store
copy_params unit-test staging ssm-param
