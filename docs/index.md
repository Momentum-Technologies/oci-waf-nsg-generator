# Oracle Cloud WAF Security Group Generator

This tool is aimed at automating a Network Security Group creation that allows connections from the Oracle WAF.

# Requirements

This utility requires the oci-cli tool and the jq tool.

# Usage

```
./create-waf-nsg.sh COMPARTMENT_NAME VCN_NAME NSG_NAME
```

The script expects COMPARTMENT_NAME and VCN_NAME to be already defined.

If NSG_NAME already exists, rules will be appended.

# OCI Cli options

You can pass options to the OCI cli utility by setting OCI_CLI_OPTS variable.

export OCI_CLI_OPTS="--config-file=path/to/config.file"

# Troubleshoot

If you see this:

```
Error: Missing option(s) --compartment-id.
```

The oci-cli configuration file is not found or invalid.

If you see this:

```
FileNotFoundError: [Errno 2] No such file or directory: 'services'
```

It means that your credentials are incorrect, or you have configured an unsubscribed region. Check your authentication parameters.

Oracle PLS fix... meaningful messages would be nice.
