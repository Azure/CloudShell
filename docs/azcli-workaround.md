# Azure Cloud Shell Workaround for Latest Azure CLI

If you're using Azure Cloud Shell and need a newer version of a package (such as the Azure CLI) than what's provided by default, this guide outlines a reliable workaround using a Python virtual environment.

## Installing the Latest Azure CLI in Cloud Shell

The default Azure CLI version in Cloud Shell might not always be up to date. You can install the latest version in an isolated environment by following the steps below.

### Step 1: Create a Virtual Environment

```bash
# Set the installation directory
INSTALL_DIR="$HOME/azcli_venv"

# Create the virtual environment
echo "Creating virtual environment at $INSTALL_DIR..."
python3 -m venv "$INSTALL_DIR"

# Activate the virtual environment
source "$INSTALL_DIR/bin/activate"

# Upgrade pip and setuptools
echo "Upgrading pip and setuptools..."
pip install --upgrade pip setuptools

# Install the latest Azure CLI
echo "Installing the latest Azure CLI..."
pip install azure-cli

# Display the installed Azure CLI version
echo "Installation complete. Azure CLI version:"
az version

echo ""
echo "To deactivate this environment, run:"
echo "    deactivate"
echo ""
echo "To activate it in the future, run:"
echo "    source \"$INSTALL_DIR/bin/activate\""
echo ""
```

### Step 2: Auto-Activate the Environment (Optional)

If you want this environment to be automatically activated every time you start Cloud Shell, append the following lines to your `~/.bashrc`:

```bash
echo "" >> ~/.bashrc
echo "# Automatically activate azcli virtual environment" >> ~/.bashrc
echo "source \"$HOME/azcli_venv/bin/activate\"" >> ~/.bashrc
```

## Notes

- This approach installs the Azure CLI in a self-contained environment, avoiding conflicts with the system installation.
- Your Cloud Shell environment is only persisted if it is backed by a storage account. Make sure you have a storage account configured, or these changes will be lost between sessions.
