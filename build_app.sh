#!/bin/bash
# Helper script to build the app when npm is not in the global path

# Add the discovered nvm node path to PATH
export PATH=$HOME/.nvm/versions/node/v20.19.4/bin:$PATH

if ! command -v npm &> /dev/null
then
    echo "npm could not be found even after updating PATH. Please check your node installation."
    exit 1
fi

echo "Building application..."
npm run build
