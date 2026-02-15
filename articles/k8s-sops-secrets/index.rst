.. meta::
   :description:
      Transparent Kubernetes secret management using SOPS, Age encryption, and Git for secure GitOps workflows with automatic encryption and decryption.

   :keywords:
      SOPS, Age, Kubernetes, secrets, GitOps, encryption, security, Git, transparent


:Publish Date: 2024-08-16

****************************************************
Kubernetes Secret Management with SOPS + Age + Git
****************************************************

.. article-info::
    :date: Aug 16, 2024
    :read-time: 15 min read

I don't like managing secrets in Kubernetes. Solutions like HashiCorp Vault are 
complicated and resource-intensive. Kubeseal was actually great but now that Bitnami 
got aquired by Broadcom, I'm concerned about the future of the apiVersion: bitnami.com/ API domain.

I wanted something fully transparent, so I can work with normal secrets in my repo, git 
commit, have the secrets provisioned on my k8s cluster and never have to care about 
encryption and secret management.

This repo boilerplate uses SOPS (Secrets OPerationS), AGE encryption and advanced 
gitattributes filters in order to provide a transparent workflow for developers to 
manage their secrets.

While this may be enough by itself we can also use sops-secrets-operator when using 
ArgoCD or Flux for GitOps.

.. seealso::

    https://github.com/getsops/sops
    https://github.com/FiloSottile/age

All configurations and examples are available in the `k8s-sops-secrets-boilerplate repository <https://github.com/epheo/k8s-sops-secrets-boilerplate>`_.


Why SOPS + Age for Secret Management?
======================================

Advantages of This Approach
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. **Transparency**: Secrets appear as plain text in your working directory
2. **Simplicity**: No external secret management infrastructure required
3. **Git Integration**: Automatic encryption when committing to Git
4. **Developer Friendly**: Works with existing tooling and workflows
5. **Secure**: Strong encryption with Age's modern cryptographic design
6. **Selective**: Only encrypt what needs to be encrypted using annotations

Architecture Overview
~~~~~~~~~~~~~~~~~~~~~

The workflow is completely transparent:

1. Edit secrets in plain text locally
2. Git automatically encrypts them when staging changes
3. Secrets are stored encrypted in the upstream repository
4. Working directory always shows decrypted content

Setting Up the Environment
==========================

Installing Required Tools
~~~~~~~~~~~~~~~~~~~~~~~~~~

First, install the required dependencies and tools:

.. code-block:: bash

   # Install Python dependencies
   pip3 install PyYAML

   # Install SOPS
   curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.amd64
   sudo mv sops-v3.9.1.linux.amd64 /usr/local/bin/sops
   sudo chmod +x /usr/local/bin/sops

   # Install Age
   curl -LO https://github.com/FiloSottile/age/releases/latest/download/age-v1.1.1-linux-amd64.tar.gz
   tar xf age-v1.1.1-linux-amd64.tar.gz
   sudo mv age/age* /usr/local/bin/
   sudo chmod +x /usr/local/bin/age*

.. note::
   Check the `SOPS releases <https://github.com/getsops/sops/releases>`_ and
   `Age releases <https://github.com/FiloSottile/age/releases>`_ pages for latest versions.

Generating Age Keys
~~~~~~~~~~~~~~~~~~~

Create encryption keys for your project:

.. code-block:: bash

   # Create age directory and generate key pair
   mkdir -p .age
   age-keygen -o .age/age.key

   # Extract the public key for SOPS configuration
   grep "public key:" .age/age.key

   # Add age directory to gitignore
   echo ".age/" >> .gitignore

   # Secure the private key
   chmod 600 .age/age.key

.. note::

   Store the private key securely and share only the public key with team members who need to encrypt secrets.


Project Configuration
=====================

SOPS Configuration
~~~~~~~~~~~~~~~~~~

Create a `.sops.yaml` configuration file in your repository root:

.. code-block:: yaml
   :caption: .sops.yaml

   creation_rules:
     - path_regex: \.secrets\.ya?ml$
       age: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(data|stringData)$'
     - path_regex: secrets/.*\.ya?ml$
       age: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(data|stringData)$'

Key configuration options:

* **path_regex**: Files matching this pattern will be encrypted
* **age**: Public key for encryption
* **encrypted_regex**: Only encrypt specified YAML keys (data, stringData for secrets)

Git Filter Setup
~~~~~~~~~~~~~~~~~

The repository includes Python scripts for Git filter integration. First, make them executable:

.. code-block:: bash

   # Make filter scripts executable
   chmod +x sops-clean.py sops-smudge.py

Configure Git to automatically encrypt/decrypt files:

.. code-block:: bash
   :caption: .gitattributes

   *.secrets.yaml filter=sops diff=sops
   *.secrets.yml filter=sops diff=sops
   secrets/*.yaml filter=sops diff=sops
   secrets/*.yml filter=sops diff=sops

Configure Git filters using the Python scripts:

.. code-block:: bash

   # Configure SOPS filters with Python scripts
   git config filter.sops.clean './sops-clean.py'
   git config filter.sops.smudge './sops-smudge.py'
   git config filter.sops.required true

Environment Variables
~~~~~~~~~~~~~~~~~~~~~

Set required environment variables to point to your age key:

.. code-block:: bash
   :caption: .envrc (if using direnv)

   export SOPS_AGE_KEY_FILE=.age/age.key

Or add to your shell profile:

.. code-block:: bash

   echo 'export SOPS_AGE_KEY_FILE=.age/age.key' >> ~/.bashrc

Creating Encrypted Secrets
===========================

Basic Secret Creation
~~~~~~~~~~~~~~~~~~~~~

Create a Kubernetes secret with transparent encryption:

.. code-block:: yaml
   :caption: app.secrets.yaml

   apiVersion: v1
   kind: Secret
   metadata:
     name: app-secrets
     namespace: production
     annotations:
       # This annotation ensures the secret is managed by our system
       secrets.k8s.io/managed-by: sops
   type: Opaque
   data:
     database-url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc3dvcmRAZGIuZXhhbXBsZS5jb20vbXlkYg==
     api-key: bG9sLCB5b3UgcmVhbGx5IHRob3VnaHQgSSBkaWQsIHJpZ2h0ID8K
   stringData:
     config.json: |
       {
         "database": {
           "host": "db.example.com",
           "port": 5432,
           "username": "myuser",
           "password": "mypassword"
         },
         "api": {
           "key": "super-secret-api-key",
           "endpoint": "https://api.example.com"
         }
       }

When you edit this file locally, you see plain text. When committed to Git, only the `data` and `stringData` sections are encrypted.

TLS Certificate Secrets
~~~~~~~~~~~~~~~~~~~~~~~~

Manage TLS certificates securely:

.. code-block:: yaml
   :caption: tls.secrets.yaml

   apiVersion: v1
   kind: Secret
   metadata:
     name: app-tls
     namespace: production
   type: kubernetes.io/tls
   data:
     tls.crt: |
       LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t
       xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       BAMMGnNlbGYtc2lnbmVkLWNlcnRpZmljYXRlLTAwHhcNMjEwMzEwMTYwNDAxWhcN
       ...
       LS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ==
     tls.key: |
       LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t
       xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       wxPBDkdPPDGBX8YXbMR7cGVOcLd9qnkL4Zx7gV7lY1P5zt8jRB9XvV4qS4A1z8PF
       ...
       LS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLQ==

Working with Encrypted Secrets
===============================

Daily Workflow
~~~~~~~~~~~~~~

The beauty of this system is its transparency:

.. code-block:: bash

   # Edit secrets normally - they appear as plain text
   vim app.secrets.yaml

   # Add the file to Git - it gets encrypted automatically
   git add app.secrets.yaml

   # Commit - the encrypted version is stored
   git commit -m "Update database credentials"

   # Other team members can clone and immediately see decrypted content
   git clone <repository>
   cd <project>
   cat app.secrets.yaml  # Shows decrypted content

Manual Encryption/Decryption
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For advanced use cases, use SOPS directly:

.. code-block:: bash

   # Encrypt a file manually
   sops --encrypt --in-place secrets/app.secrets.yaml

   # Decrypt a file manually  
   sops --decrypt secrets/app.secrets.yaml

   # Edit encrypted file directly
   sops secrets/app.secrets.yaml

   # View decrypted content without modifying
   sops --decrypt secrets/app.secrets.yaml | less

Key Rotation
~~~~~~~~~~~~

Rotate encryption keys periodically:

.. code-block:: bash

   # Generate new Age key
   age-keygen -o new-key.txt

   # Update .sops.yaml with new public key
   # Re-encrypt all secrets with new key
   find . -name "*.secrets.yaml" -exec sops updatekeys {} \;

   # Update team members' key files
   cp new-key.txt .age/age.key

Kubernetes Integration
======================

SOPS Secrets Operator
~~~~~~~~~~~~~~~~~~~~~~

For automated secret management, deploy the SOPS Secrets Operator:

.. code-block:: yaml
   :caption: sops-secrets-operator.yaml

   apiVersion: v1
   kind: Namespace
   metadata:
     name: sops-secrets-operator
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: sops-secrets-operator
     namespace: sops-secrets-operator
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: sops-secrets-operator
     template:
       metadata:
         labels:
           app: sops-secrets-operator
       spec:
         serviceAccountName: sops-secrets-operator
         containers:
         - name: manager
           image: isindir/sops-secrets-operator:0.12.0
           env:
           - name: WATCH_NAMESPACE
             value: ""
           - name: SOPS_AGE_KEY
             valueFrom:
               secretKeyRef:
                 name: sops-age-key
                 key: key.txt
           resources:
             requests:
               cpu: 100m
               memory: 128Mi
             limits:
               cpu: 500m
               memory: 512Mi

The operator automatically syncs encrypted secrets from Git to Kubernetes secrets.

Advanced Patterns
=================

Conditional Encryption
~~~~~~~~~~~~~~~~~~~~~~

Use SOPS path-based rules for selective encryption:

.. code-block:: yaml
   :caption: .sops.yaml (advanced)

   creation_rules:
     # Production secrets - always encrypted
     - path_regex: prod/.*\.ya?ml$
       age: agexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(data|stringData|password|secret|key|token)$'
     
     # Development secrets - only sensitive fields
     - path_regex: dev/.*\.ya?ml$
       age: agexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(password|secret|key|token)$'
     
     # Test secrets - minimal encryption
     - path_regex: test/.*\.ya?ml$
       age: agexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(password)$'

Multi-Key Management
~~~~~~~~~~~~~~~~~~~~

Support multiple teams with different keys:

.. code-block:: yaml
   :caption: .sops.yaml (multi-team)

   creation_rules:
     # Platform team secrets
     - path_regex: platform/.*\.ya?ml$
       age: >-
         agexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
         age1xyz...platform-team-key
       encrypted_regex: '^(data|stringData)$'
     
     # Development team secrets  
     - path_regex: apps/.*\.ya?ml$
       age: >-
         age1abc...dev-team-key,
         agexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
       encrypted_regex: '^(data|stringData)$'


Audit and Compliance
=======================

Track secret changes with Git history:

.. code-block:: bash

   # View secret change history
   git log --oneline -- secrets/
   
   # See who changed secrets
   git blame secrets/production.secrets.yaml
   
   # Diff encrypted secrets
   git diff HEAD~1 secrets/production.secrets.yaml


Testing and Validation
=======================

Repository Testing Framework
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The repository includes comprehensive end-to-end testing scripts:

.. code-block:: bash

   # Quick filter testing - tests Git filters work correctly
   ./run-e2e-tests.sh local

   # Complete GitOps workflow test - full end-to-end validation
   ./run-e2e-tests.sh full

These tests validate:

- Git filter encryption/decryption functionality
- SOPS configuration correctness  
- Complete GitOps workflow with ArgoCD/Flux integration
- Secret operator deployment and management

Manual Validation Scripts
~~~~~~~~~~~~~~~~~~~~~~~~~

Create additional validation scripts for your workflow:

.. code-block:: bash
   :caption: validate-secrets.sh

   #!/bin/bash
   
   # Validate all secret files can be decrypted
   find . -name "*.secrets.yaml" | while read file; do
       echo "Validating $file..."
       if sops --decrypt "$file" > /dev/null 2>&1; then
           echo "✓ $file is valid"
       else
           echo "✗ $file failed validation"
           exit 1
       fi
   done
   
   # Check for unencrypted sensitive data
   if grep -r "password:\|secret:\|key:" . --include="*.yaml" --exclude="*.secrets.yaml"; then
       echo "⚠ Found potential unencrypted secrets"
       exit 1
   fi
   
   echo "All validations passed"

Debugging Commands
~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   # Test SOPS configuration
   sops --config .sops.yaml encrypt /dev/null

   # Verify Age key
   age-keygen -y .age/age.key

   # Check Git filters
   git config --list | grep sops

   # Test encryption/decryption
   echo "test: secret" | sops --encrypt /dev/stdin | sops --decrypt /dev/stdin

   # Test Git filter scripts
   ./sops-clean.py < test.secrets.yaml
   ./sops-smudge.py < encrypted-test.yaml
