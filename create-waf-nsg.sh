#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 COMPARTMENT_NAME VCN_NAME NSG_NAME"
    exit 1
fi

check_component() {
    comp=$1
    if [ "$(type $comp | wc -l)" -eq 0 ]; then
        echo "This utility requires $comp to fullfil its existence, it feels incomplete without it."
        exit 1
    fi
}

check_component oci
check_component jq

export compartment_name=$1
export vcn_name=$2
export nsg_name=$3

OCI_CMD="oci ${OCI_CLI_OPTS}"

# Setup ENV
export COMPARTMENT_ID=$(${OCI_CMD} iam compartment list --all --access-level ACCESSIBLE | jq -r ".data[] | select( .name == "env.compartment_name" ).id")

if [ -z "${COMPARTMENT_ID}" ]; then
    echo "Compartment ${compartment_name} not found."
    exit 1
fi

export VCN_ID=$($OCI_CMD network vcn list --compartment-id ${COMPARTMENT_ID} --display-name ${vcn_name}| jq -r .data[0].id)

if [ -z "${VCN_ID}" ]; then
    echo "VCN ${vcn_name} not found."
    exit 1
fi

WAF_NSG=$($OCI_CMD network nsg list --compartment-id ${COMPARTMENT_ID} --display-name "${nsg_name}" |jq -r .data[0].id)

if [ -z "${WAF_NSG}" ]; then
    # Create a new network security group
    echo "Creating web network security group ${nsg_name}"
    echo "========================="
    ${OCI_CMD} network nsg create --compartment-id ${COMPARTMENT_ID} --vcn-id ${VCN_ID} --display-name "${nsg_name}"
    WAF_NSG=$(${OCI_CMD} network nsg list --compartment-id ${COMPARTMENT_ID} --display-name "${nsg_name}" |jq -r .data[0].id)

    if [ -z "${WAF_NSG}" ]; then
        echo "Unable to ID the network security group."
        exit 1
    fi
fi

echo "Cleanup endpoints definitions."
rm -f endpoints/*

echo "Generate rules for each endpoint."
for cidr in $(cat cidr.lst); do
    sed -e "s@__ENDPOINT_CIDR__@$cidr@g" template-http.json > endpoints/$(echo $cidr | tr '/' '-')-http.json
    sed -e "s@__ENDPOINT_CIDR__@$cidr@g" template-https.json > endpoints/$(echo $cidr | tr '/' '-')-https.json
done

EXISTING_RULES=$($OCI_CMD network nsg rules list --nsg-id ${WAF_NSG} --all | jq ' .[][]  .description' )

for def in $(ls endpoints); do
    current_rule=$(cat endpoints/$def | jq " .[0].description")
    if [ ! $(echo $EXISTING_RULES | grep "$current_rule" | wc -l) -eq 0 ]; then
        echo "Rule already exists: $current_rule"
        continue;
    fi
    echo "Loading rule $def"
    ${OCI_CMD} network nsg rules add --nsg-id ${WAF_NSG} --security-rules file://endpoints/$def
done