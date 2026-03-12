# kernel_build Role
Deterministic, doctrine-aligned kernel build pipeline for CM3+ workers.  
This role breaks the kernel build process into clean, modular stages that are
safe to run at any time and easy for future maintainers to understand.

## Overview
The kernel build pipeline is composed of the following stages:

1. **fetch.yml**  
   Fetch and extract kernel sources into the persistent build root.  
   - Downloads kernel tarball  
   - Verifies checksum (optional)  
   - Extracts sources  
   - Prepares workspace directories  

2. **patch.yml**  
   Apply kernel patches deterministically.  
   - Applies all `*.patch` files in the patches directory  
   - Never fails if no patches exist  
   - Idempotent and safe  

3. **configure.yml**  
   Configure the kernel using a deterministic defconfig workflow.  
   - Installs defconfig  
   - Runs `make olddefconfig`  
   - Validates `.config`  

4. **build.yml**  
   **Compile the kernel** using distcc acceleration.  
   - Validates pump-mode (shim-based)  
   - Validates distccd state  
   - Runs `make -j{{ build_jobs }}`  
   - Captures build output  
   - Fails loudly on error  

5. **install.yml**  
   Install kernel modules and DTBs into deterministic output directories.  
   - Runs `modules_install`  
   - Runs `dtbs_install`  
   - Ensures artifact directories exist  

6. **artifacts.yml**  
   Collect kernel build artifacts.  
   - Copies zImage  
   - Copies DTBs  
   - Synchronizes modules  
   - Ensures deterministic artifact layout  

7. **validate.yml**  
   Validate that all expected artifacts exist.  
   - Checks zImage  
   - Checks DTBs  
   - Checks modules  
   - Produces explicit validation output  

8. **summary.yml**  
   Final ASCII banner summarizing the entire pipeline.  
   - Confirms all stages executed  
   - Confirms doctrine compliance  
   - Provides a clean end-of-run summary  

## Variables
User-tunable variables live in `defaults/main.yml`.  
Internal constants live in `vars/main.yml`.

## Doctrine Notes
- No tmpfs anywhere in the system.  
- All paths are deterministic and persistent.  
- Every major workflow ends with a clear ASCII summary.  
- Builder orchestrates; workers compile via distcc.  
- Idempotency and clarity are mandatory.  

## Entry Point
This role is typically invoked by:

ansible-playbook builder-kernel-build.yml
hich runs the full pipeline from fetch -> summary.
